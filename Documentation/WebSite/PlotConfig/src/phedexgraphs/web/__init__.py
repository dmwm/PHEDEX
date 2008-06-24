
import threading, time, cStringIO, re
from xml.sax.saxutils import XMLGenerator

import cherrypy

from graphtool.database import DatabaseInfoV2
from graphtool.database.connection_manager import OracleDatabase

class TfcRule:
  
  def __init__( self, mapper ):
    self.chain = None 
    self.protocol = None
    self.destination_match = None
    self.path_match = None 
    self.result = None
    self.mapper = mapper
    self.type = None
    
  def set( self, destination_match = None, path_match = None ):
    if destination_match != None:
      self.destination_match = re.compile( destination_match )
      self.destination_match_str = destination_match
    if path_match != None:
      self.path_match_str = path_match
      self.path_match = re.compile( path_match )
      
  def doesMatch( self, input, protocol, dest="" ):
    if protocol != self.protocol:
      return False 
    if self.destination_match and re.match( self.destination_match, dest ) == None:
      return False
    #if re.match( self.path_match, input ) == None:
    #  return False
    return True
    
  def map( self, input, protocol, dest="" ):
    orig_input = str(input)
    if not self.doesMatch(input, protocol, dest):
      return None
    if self.type == 'to_pfn':
      input = self.do_chain( input, protocol, dest )
      if input == None:
        raise ValueError("Could not map input %s using current TFC rules." % orig_input)
    my_match = re.match( self.path_match, input )
    if not my_match:
        #raise ValueError("Could not match input %s to rule %s." % (input, self.path_match_str))
        return None
    groups = my_match.groups()
    current_string = self.result
    for group, ind in zip(groups, range(len(groups)) ):
      pattern_str = '\$' + str(ind+1)
      sub_pattern = re.compile( pattern_str )
      current_string = re.sub( sub_pattern, group, current_string )
    if self.type == 'to_lfn':
      current_string = self.do_chain( current_string, protocol, dest )
    return current_string

  def do_chain( self, input, prot, dest ):
    #print "Doing chain", input, prot, self.chain
    if self.chain != None:
      if self.type == 'to_pfn':
        map = self.mapper.map_to_pfn
      else:
        map = self.mapper.map_to_lfn
      real_input = map( input, self.chain, dest )
    else:
      real_input = input
    return real_input

class TfcMapper(object):

  def __init__( self, dom=None ):
    self.to_pfn_rules = []
    self.to_lfn_rules = []
    if dom != None:
      self.start_parse( dom )

  def start_parse( self, dom ):
    sm = dom.getElementsByTagName('storage-mapping')
    if len(sm) > 1:
      raise ValueError("Only one storage mapping permitted per TFC.")
    if len(sm) == 0:
      raise ValueError("No storage mapping present!")
    self.parse_sm( sm[0] )

  def parse_sm( self, sm ):
    lfn_to_pfns = sm.getElementsByTagName('lfn-to-pfn')
    for lfn_to_pfn in lfn_to_pfns:
      self.parse_lfn_to_pfn( lfn_to_pfn )

    pfn_to_lfns = sm.getElementsByTagName('pfn-to-lfn')
    for pfn_to_lfn in pfn_to_lfns:
      self.parse_pfn_to_lfn( pfn_to_lfn )

  def parse_lfn_to_pfn( self, lfn_to_pfn ):
    rule = self.parse_rule( lfn_to_pfn )
    rule.type = "to_pfn"
    self.to_pfn_rules.append( rule )

  def parse_pfn_to_lfn( self, pfn_to_lfn ):
    rule = self.parse_rule( pfn_to_lfn )
    rule.type = "to_lfn"
    self.to_lfn_rules.append( rule )

  def parse_rule( self, rule ):
    my_rule = TfcRule( self )
    my_rule.protocol = rule.getAttribute('protocol')
    my_rule.set( destination_match = rule.getAttribute('destination-match') )
    my_rule.set( path_match = rule.getAttribute('path-match') )
    if len(rule.getAttribute('chain')) > 0:
      my_rule.chain = rule.getAttribute('chain')
    my_rule.result = rule.getAttribute('result')
    return my_rule

  def map_to_pfn( self, input, protocol, dest="" ):
    return self.map( input, protocol, dest, self.to_pfn_rules )

  def map_to_lfn( self, input, protocol, dest="" ):
    return self.map( input, protocol, dest, self.to_lfn_rules )

  def map( self, input, protocol, dest, rules ):
    result = None
    for rule in rules:
      result = rule.map( input, protocol, dest )
      if result != None:
        return result

class TfcXmlMapper( TfcMapper ):

    def _rule_to_attrs(self, rule):
             
            attrs = { \
                    'protocol' : rule.protocol,
                    'result' : rule.result,
                    'path-match' : rule.path_match_str,
                    }
            if getattr(rule, 'destination_match_str', None):
                attrs['destination-match'] = rule.destination_match_str
            if getattr(rule, 'chain', None):
                attrs['chain'] = rule.chain
            return attrs      

    def xml(self, gen):
        for rule in self.to_pfn_rules:
            attrs = self._rule_to_attrs( rule )
            gen.startElement('lfn-to-pfn', attrs)
            gen.endElement('lfn-to-pfn')
            gen.characters('\n\t\t')
        for rule in self.to_lfn_rules:
            attrs = self._rule_to_attrs( rule )
            gen.startElement('pfn-to-lfn', attrs)
            gen.endElement('pfn-to-lfn')
            gen.characters('\n\t\t')

class TfcMapperPhedex( DatabaseInfoV2 ):
  
    _cp_config = {}

    stmt = """
           SELECT 
               n.name, c.rule_type, c.protocol, c.chain, 
               c.destination_match, c.path_match, c.result_expr
           FROM t_xfer_catalogue c
           JOIN t_adm_node n ON c.node = n.id
           """

    se_stmt = """
           SELECT
               name, se_name
           FROM t_adm_node
           """

    update_interval = 600

    def __init__( self, dom=None ):
        super( TfcMapperPhedex, self ).__init__( dom=dom )
        self.nodes = {}
        self.updateThread = threading.Thread(target=self.ruleCron)
        self.lastUpdate = 0
        self.killFlag = False
        self.updateRules()
        self.updateSE()
        self.updateThread.start()

    def kill(self):
        self.killFlag = True

    def ruleCron(self):
        while self.killFlag == False:
            time.sleep(1)
            now = time.time()
            if now - self.update_interval > self.lastUpdate:
                try:
                    self.updateRules()
                    self.updateSE()
                except:
                    pass
                self.lastUpdate = time.time()

    def updateRules( self ):
        # Download rules from DB
        rows = self.execute_sql( self.stmt, {} )
        tmp_sorting = {}
        for row in rows:
            node, info = row[0], row[1:]
            if node in tmp_sorting:
                tmp_sorting[node].append(info)
            else:
                tmp_sorting[node] = [info]
        # Create the TfcMapper instances from these rules:
        for node, rules in tmp_sorting.items():
            mapper = TfcXmlMapper()
            for rule_tuple in rules:
                rule = TfcRule( mapper )
                rule.protocol = rule_tuple[1]
                rule.chain = rule_tuple[2]
                rule.set( destination_match=rule_tuple[3] )
                rule.set( path_match=rule_tuple[4] )
                rule.result = rule_tuple[5]
                if rule_tuple[0] == 'pfn-to-lfn':
                    mapper.to_lfn_rules.append(rule)
                    rule.type = 'to_lfn'
                else:
                    mapper.to_pfn_rules.append(rule)
                    rule.type = 'to_pfn'
            self.nodes[node] = mapper

    def updateSE(self):
        # Download SE mappings from DB:
        rows = self.execute_sql( self.se_stmt, {} )
        se_map = {}
        rows.reverse()
        se_tuples = []
        for row in rows:
            node, se = row
            se_map[se] = node
            se_tuples.append( (se, node) )
        self._map_se = se_map
        self._se_tuples = se_tuples

    def xml( self, node=None ):
        if node != None:
            return self.xml_node( node )
        output = cStringIO.StringIO()
        gen = XMLGenerator( output, 'utf-8' )
        gen.startDocument()
        output.write('<!DOCTYPE mappings>\n')
        gen.startElement('mappings',{})
        gen.characters('\n\t')
        for node, mapper in self.nodes.items():
            gen.startElement('storage-mapping',{'node':node})
            gen.characters('\n\t\t')
            mapper.xml(gen)
            gen.endElement('storage-mapping')
            gen.characters('\n\t')
        gen.endElement('mappings')
        gen.characters('\n')
        gen.endDocument()
        cherrypy.response.headers['Content-Type'] = 'text/xml'
        return output.getvalue()
    xml.exposed = True

    def xml_node( self, node ):
        if node not in self.nodes:
            raise ValueError("Unknown node.")
        output = cStringIO.StringIO()
        gen = XMLGenerator( output, 'utf-8' )
        gen.startDocument()
        output.write('<!DOCTYPE storage-mapping>\n')
        gen.startElement('storage-mapping',{})
        gen.characters('\n\t\t')
        self.nodes[node].xml(gen)
        gen.endElement('storage-mapping')
        gen.characters('\n')
        gen.endDocument()
        cherrypy.response.headers['Content-Type'] = 'text/xml'
        return output.getvalue()

    def map_se(self, se, multiple=False):
        cherrypy.response.headers['Content-Type'] = 'text/plain'
        if se not in self._map_se:
            raise ValueError("SE %s unknown to PhEDEx." % str(se))
        if not multiple:
            return self._map_se[se]
        else:
            possible_str = ''
            for altse, node in self._se_tuples:
                if se == altse:
                    possible_str += node + '\n'
            return possible_str[:-1]
    map_se.exposed = True
        
    def map(self, node, lfn=None, pfn=None, protocol="srm"):
        if lfn == None and pfn == None:
            raise ValueError("Must specify an LFN or PFN to map.")
        if node not in self.nodes:
            raise ValueError("Unknown PhEDEx node.")
        if lfn != None:
            return self.nodes[node].map_to_pfn( lfn, protocol )
        else:
            return self.nodes[node].map_to_lfn( pfn, protocol )
    map.exposed = True

    def lastRefresh(self):
        if self.lastUpdate == 0:
            return "Rules have never been updated!"
        else:
            return "Last rules refresh was %i seconds ago." % \
                int(time.time() - self.lastUpdate)
    lastRefresh.exposed = True

