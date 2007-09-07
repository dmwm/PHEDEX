#!/usr/bin/env python
from optparse import OptionParser
from random import choice
import datetime, time, pickle, os, os.path
import xml.dom.minidom, xml.dom.ext
import string

def do_options():
    parser = OptionParser ()
    parser.add_option ("-s", "--site",
                   help="Files are injected onto SITE",
                   metavar = "SITE",
                   dest="site")

    parser.add_option ("-d", "--destinations",
                   help="Files are injected to be downloaded by DESTINATIONS. Can be a single entry or comma separated list.",
                   metavar = "DESTINATIONS",
                   dest="dest")
    
    parser.add_option ("-i", "--instance",
                       help="The PhEDEx instance to inject into, used for labeling blocks, default is Debug.",
                       metavar="INSTANCE",
                       default='Debug',
                       dest='instance')
                       
    parser.add_option ("--inbox",
                   help="Inbox of the drop publish agent, script will write xml drops to INBOX.",
                   metavar = "INBOX",
                   dest="inbox")

    parser.add_option ("--inject_home",
                   help="Location of the LoadTest07_files_info, also where status of the injections are stored.",
                   metavar = "DIR",
                   default='.',
                   dest="inject_home")
    
    parser.add_option ("-r", "--rate",
                   help="Files are injected to meet a rate of RATE MB/s.",
                   metavar = "RATE",
                   dest="rate")    

    parser.add_option ("--injectnow",
                   help="Inject FILES now.",
                   metavar = "FILES",
                   dest="inject")
 
    parser.add_option ("-b", "--blocksize",
                   help="Files are injected into a block up to BLOCKSIZE, default is 100.",
                   metavar = "BLOCKSIZE",
                   default=100,
                   dest="blocksize")

    parser.add_option ("--datasets",
                   help="Create #DATASETS datasets, default is 20.",
                   metavar = "DATASETS",
                   default=20,
                   dest="datasets")
    
    parser.add_option ("--nocloseblocks",
                   help="Don't close blocks when BLOCKSIZE is reached.",
                   action="store_false",
                   default=True,
                   dest="close")
    
    parser.add_option ("-v", "--verbose",
                   help="Be more verbose.",
                   default=False,
                   action="store_true", 
                   dest="verbose")
   
    parser.add_option ("--debug",
                   help="Be really verbose.",
                   default=False,
                   action="store_true", 
                   dest="debug")   
        
    options, args = parser.parse_args ()
    
    if options.debug:
        print "Options = ", options
        
    if not options.rate and not options.inject:
        print "No rate or injectnow specified. Please consult the help (-h flag)"
        return None
    if not options.site:
        print "No injection site specified. Please consult the help (-h flag)"
        return None
    
    if not options.dest:
        print "No destination site specified. Please consult the help (-h flag)"
        return None
    else:
        options.dest = options.dest.split(',')
    if not options.inbox:
        print "No inbox specified, cannot create drops. Please consult the help (-h flag)"
        return None
    
    return options
   
def read_info(path):
    #return the name checksum and sizefor file as a dictionary
    # from LoadTest_files_info which looks like 0B,4044096268,2764217632
    path = path + '/LoadTest07_files_info'
    if os.path.isfile(path):
        f = open(path,'r')
        dict = {}
        for line in f.readlines():
            l = line.split(',')
            dict[l[0]] = {'size': l[2].strip(), 'cksum': l[1].strip()}
        f.close()
        return dict
    else:
        print """ERROR: Can't read LoadTest07_files_info file, this could be because of an incorrect 
        command flag or because the file does not exist.
        Expecting to read : %s""" % path

def read_status(source, destination, path):
    # Read the last file and block injected and the time it was injected
    status = {}
    for d in destination:
        if os.path.isfile('%s/%s_%s' % (path, source, d)):
            pkl_file = open('%s/%s_%s' % (path, source, d), 'rb')
            data = pickle.load(pkl_file)
            pkl_file.close()
            file = data['file']
            block = data['block']
            if block < 600: block = 600
            stamp = data['stamp']
            status[d] = file, block, stamp
        else:
            print """WARNING: Can't read status file, this could be because of an incorrect 
            command flag, because the file has been removed or because this script has not 
            been run before for %s (in which case don't worry)
            Expecting to read : %s""" % (destination, '%s/%s_%s' % (path, source, d))
            status[d] = 0, 600, int(time.mktime(datetime.datetime.now().timetuple()))
    return status

def write_status(source, status, path):
    # Write out the last file injected and the time injected
    for d in status.keys():
        if os.path.isdir('%s' % (path)):
            output = open('%s/%s_%s' % (path, source, d), 'wb')
            file, block, stamp = status[d]
            data = {'source':source, 
                    'destination':d, 
                    'file':file, 
                    'block':block,
                    'stamp':stamp,
                    'path':path}
            # Pickle dictionary using protocol 0.
            pickle.dump(data, output)
                
            output.close()
        else:
            print """ERROR: Can't write status file, this could be because of an incorrect 
            command flag or because the directory has not been created or been removed.
            Expecting to write to : %s""" % '%s/%s_%s' % (path, source, d)

def calculate_rate(then, rate):
    # number of files = (timediff * rate) / size
    now = int(time.mktime(datetime.datetime.now().timetuple()))
    timediff = now - then
    size = 2500 #MB Rough estimate.... 
    return (timediff * rate) / size

def random():
    chars = string.letters + string.digits
    junk = ''.join([choice(chars) for i in range(8)])
    return junk

def make_drop(sites, instance, filerange, blockid, close, home, inbox):
#     Create the drop XML 
#     sites = [source, destinaton]
#     file = [filename, size, checksum]
#     block = number
#     if close is true close the current block after this injection   
#    <dbs name="LoadTest07"  dls="lfc:unknown">
#        <dataset name="/PhEDEx_Debug/LoadTest07_RAL/Estonia" is-open="y" is-transient="y">
#                <block name="/PhEDEx_Debug/LoadTest07_RAL_Estonia#101" is-open="y">
#                        <file lfn="/store/PhEDEx_LoadTest07/LoadTest07_Debug_RAL/Estonia/101/LoadTest07_RAL_3F_BLhY6TaG_101" size="2771862256" checksum="cksum:2313426155"/>
#                </block>
#        </dataset>
#    </dbs>
    files = read_info(home)
    infosize = len(files)
    if options.verbose:
        print 'Info file contains %s files' % infosize
    source = sites[0]
    for dest in sites[1]:
        doc = xml.dom.minidom.Document()
        root = doc.createElement('dbs')
        root.setAttribute("name", "LoadTest07")
        root.setAttribute("dls","lfc:unknown")

        dataset = doc.createElement('dataset')
        dataset.setAttribute("name", "/PhEDEx_Debug/LoadTest07_%s/%s" % (source, dest))
        dataset.setAttribute("is-open", "y")
        dataset.setAttribute("is-transient", "y")
        
        block = doc.createElement('block')
        block.setAttribute("name", "/PhEDEx_Debug/LoadTest07_%s_%s#%s" % (source, dest, blockid))
        
        fid = min(filerange) % infosize
        for f in filerange:
            fid += 1
            cut_f = f % 256
            try:
                file_info = files['%0.2X' % cut_f]
                if options.debug:
                    print 'cut_f, f', f, cut_f
                    print 'cut_f and f %0.2X' % cut_f, f
                    print 'file_info', file_info
                    
                lfn = "/store/PhEDEx_LoadTest07/LoadTest07_%s_%s/%s/%s/LoadTest07_%s_%0.2X_%s_%s" % (instance, source, 
                                                                          dest, blockid, source, cut_f, random(), blockid)
                file = doc.createElement('file')
                file.setAttribute("lfn", lfn)
    
                file.setAttribute("size",file_info['size'].strip())
                file.setAttribute("checksum","cksum:%s" % file_info['cksum'])
                block.appendChild(file)
    
                if fid >= int(options.blocksize):
                    if options.verbose:
                        print "closing block"
                    if options.close:
                        block.setAttribute("is-open", "n")
                    else:
                        block.setAttribute("is-open", "y")
                    if options.debug:
                        print "writing block"
                    dataset.appendChild(block)
                    blockid += 1
                    block = doc.createElement('block')
                    block.setAttribute("name", "/PhEDEx_Debug/LoadTest07_%s_%s#%s" % (source, dest, blockid))
                    fid = 0
            except:
                print "WARNING file %s not listed in info file, your info file is incomplete" % cut_f
        if fid:
            if options.verbose:
                print "writing open block"
            block.setAttribute("is-open", "y")        
            dataset.appendChild(block)
        root.appendChild(dataset)
        doc.appendChild(root)                
        if options.debug:
            xml.dom.ext.PrettyPrint(doc)
        # create the drop
        path = '%s/%s_%s' % (inbox, dest, random())
        os.mkdir(path)
        filename = "%s/%s_%s.xml" % (path, dest, random())
        handle = open(filename, "w")
        xml.dom.ext.PrettyPrint(doc, handle)
        handle.close()
        # touch the go file
        handle = open("%s/go" % path, "w")
        handle.close()
        
    return blockid
                
if __name__ == "__main__":
    options = do_options()
    if options:
        if options.verbose and options.inject: 
            print "Starting injector %s %s %s files (blocksize %s)" % (options.site, options.dest, options.inject, options.blocksize)
        elif options.verbose:
            print "Starting injector %s %s %s MB/s (blocksize %s)" % (options.site, options.dest, options.rate, options.blocksize)
        
        # Read in previous status
        status = read_status(options.site, options.dest, options.inject_home)
        
        if options.verbose:
            print status
        
        for d in status.keys():
            file, block, stamp = status[d]
            # Decide how many files to add
            add_files = 0
            if options.inject: add_files = int(options.inject)   
            elif options.rate:
                #Calculate the rate and corresponding required number of files
                add_files = calculate_rate(stamp, int(options.rate))
                
            if options.verbose:
                print 'Adding %s files' % add_files
                
            # Create the drops
            if add_files > 0:
                block = make_drop([options.site, options.dest], options.instance, 
                          range(file, file + add_files), block, options.close, options.inject_home, options.inbox)
                
                # Update status    
                file = file + add_files           
               
                if options.debug:
                    print status
                if options.rate:
                    # Don't need to record the timestamp for injectnow injections
                    stamp = int(time.mktime(datetime.datetime.now().timetuple()))
                status[d] = file, block, stamp
                
            write_status(options.site, status, options.inject_home)
                
            print "Added %s files" % add_files
            