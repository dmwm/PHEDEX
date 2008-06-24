import re

from graphtool.database.query_handler import QueryHandler, results_parser, simple_results_parser, complex_pivot_parser

regexp_cache = {}

def match_regexp( str, str_reg ):
    if str_reg.startswith('@'): do_match = True; str_reg = str_reg[1:]
    else: do_match = False
    if str_reg in regexp_cache.keys():
        reg = regexp_cache[str_reg]
    else:
        reg = re.compile( str_reg )
        regexp_cache[str_reg] = reg
    if do_match:
        match = reg.match( str )
    else:
        match = reg.search( str )
    if match == None: return None
    if do_match:
        groups = match.groups()
        if len( groups ) == 0:
            return match.group()
        else:
            return groups[0]
    else:
        return str

def phedex_link( *args, **kw ):
    # Extract to and from node from the arguments
    from_node, to_node = args

    # Filter out the MSS nodes if requested
    if 'no_mss' in kw.keys() and kw['no_mss'].lower().find('t') >= 0:
        if from_node.find('MSS') >= 0: return None
        if to_node.find('MSS') >= 0: return None

    # Apply regexps, if they are present
    if 'from_node' in kw.keys():
        from_node = match_regexp( from_node, kw['from_node'] )
    if 'to_node' in kw.keys():
        to_node = match_regexp( to_node, kw['to_node'] )

    # If either doesn't match regexp, bail out.
    if (from_node == None) or (to_node == None): return None

    # Finally, return the filtered name.  
    if 'link' in kw.keys():
        if kw['link'] == 'link':
            kw['query'].pivot_name = 'Link'
            #return (from_node, to_node)
            return from_node + ' to ' + to_node
        elif kw['link'] == 'dest' or kw['link'] == 'destination':
            kw['query'].pivot_name = 'Destination'
            return to_node
        elif kw['link'] == 'src' or kw['link'] == 'source':
            kw['query'].pivot_name = 'Source'
            return from_node
    else:
        # Default, return the link.
        return (from_node, to_node)

def phedex_node( *args, **kw ):
    # Take the database name from the arguments
    node = args[0]

    # Filter out the MSS nodes if requested
    if 'no_mss' in kw.keys() and kw['no_mss'].lower().find('t') >= 0:
        if node.find('MSS') >= 0: return None

    # Apply regexp if one is present.
    if 'node' in kw.keys():
        node = match_regexp( node, kw['node'] )
    return node

def phedex_link_alt( *args, **kw ):
    from_node, to_node = args
    if 'link' in kw.keys(): 
        if kw['link'] == 'link':
            kw['query'].pivot_name = 'Link'
            return (from_node, to_node)
        elif kw['link'] == 'dest':
            kw['query'].pivot_name = 'Destination'
            return to_node.split('_')[1]
        elif kw['link'] == 'src':
            kw['query'].pivot_name = 'Source'
            return from_node.split('_')[1]
    else:
        return (from_node, to_node)

def phedex_quality( *args, **kw ):
    try:
        done, failed, tried, expired = args[0]
    except:
        raise ValueError("Could not unpack 4 arguments from %s" % str(args))
    show_expired = kw.get('show_expired',True)
    if show_expired:
        return done, failed+expired, tried+expired, expired
    else:
        return done, failed, tried, expired

