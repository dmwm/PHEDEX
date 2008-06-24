from graphtool.database.connection_manager import ConnectionManager

class PhedexConnectionManager( ConnectionManager ):
    def parse_dom( self ):
        super( ConnectionManager, self ).parse_dom()
        if 'default' not in self.__dict__.keys():
            self.default = None
        if 'DBParam' in self.__dict__.keys():
            self.parse_DBParam( self.expand_path( self.DBParam ) )
        for connection in self.dom.getElementsByTagName('connection'):
            self.parse_connection( connection )

    def parse_DBParam( self, filename ):
        try:
            file = open( filename, 'r' )
        except Exception, e:
            raise Exception( "Unable to open specified DBParam file %s\nCheck the path and the permissions.  \nInitial exception: %s" % (filename,str(e)) )
        rlines = file.readlines()
        info = {}
        current_section = False
        for line in rlines:
            if len(line.lstrip()) == 0 or line.lstrip()[0] == '#':
                continue
            tmp = line.split(); tmp[1] = tmp[1].strip()
            if tmp[0] == "Section" and current_section == False:
                current_section = tmp[1]
            if self.default == None:
                self.default = current_section
            elif tmp[0] == "Section":
                self.db_info[ current_section ] = info
                self.db_objs[ current_section ] = None
                info = {}
                current_section = tmp[1]
            if current_section != False:
                info[tmp[0]] = tmp[1]
            if current_section == False:
                raise Exception( "Could not find any sections in: %s\nCheck filename and contents!" % filename )
            else:
                self.db_info[ current_section ] = info
                self.db_objs[ current_section ] = None
