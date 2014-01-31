#!/usr//bin/python
import sys
import os

def setCnsHost():
    if not os.getenv("CNS_HOST"):
        try:
            configFile=open("/etc/castor/castor.conf")
            for line in configFile:
                if line.startswith("CNS"):
                    words=line.split()
                    if words[1]=="HOST":
                        os.putenv("CNS_HOST", words[2])
                        break
            configFile.close()
        except IOError:
            os.putenv("CNS_HOST", "castorns.ads.rl.ac.uk")
    if not os.getenv("CNS_HOST"):
        os.putenv("CNS_HOST", "castorns.ads.rl.ac.uk")


if __name__ == '__main__':
        if len(sys.argv) != 3:
                print 'Usage: pnsls <castorPath> <dumpFile>'
                sys.exit(1)
        #setCnsHost()    # nsls at CERN works without this setting
        cmd = 'nsls -lR --checksum ' + sys.argv[1]
        (pin, pout) = os.popen2(cmd)
        dumpFile = open(sys.argv[2], 'w')
        rootdir=''
        isEmptyDir=False
        for line in pout.readlines():
                line=line.strip()
                if len(line) == 0:
                        continue
                #if line.startswith('/castor/ads.rl.ac.uk'):
                if line.startswith('/'):    #  this will remove directory entries
                        if isEmptyDir:
                                dumpFile.write(rootdir + '\n')
                        rootdir = line.rstrip(':')
                        rootdir = rootdir + '/'
                        isEmptyDir=True
                        continue
                isEmptyDir=False
                if not line.startswith('d'):
                        elements = line.split()
                        if len(elements) != 11:
                                # File has no checksum, replace with '--'
                                elements.insert(8,'--')
                                elements.insert(9,'   --   ')
                        file=rootdir + elements[len(elements)-1]
                        elements[len(elements)-1]=file
                        dumpFile.write('\t'.join(elements))
                        dumpFile.write('\n')
        dumpFile.close()
