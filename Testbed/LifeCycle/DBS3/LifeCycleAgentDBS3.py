#!/usr/bin/env python
import traceback

from dbs.apis.dbsClient import *

url=os.environ['DBS_READER_URL'] 
api = DbsApi(url=url)

## first step (list all StoreResults datasets in DBS3)
datasets = api.listDatasets(dataset="/*/StoreResults*/USER")

## second step (list blocks for each of the datasets)
blockList = []

for dataset in datasets:
    dataset = dataset['dataset']
    
    print "Getting blocks for dataset %s" % (dataset)

    ## Some DBS2 migrated datasets are not fulfilling current input validation (Ticket #2571)
    try: 
        blocks = api.listBlocks(dataset=dataset)
    except Exception, ex:
        msg = traceback.format_exc()
        print "Details: \n%s" % (msg)
    else:
        blockList.append(blocks)

## third step (getting files for each block)
fileList = []

for blocks in blockList:
    for block in blocks:
        block=block['block_name']
        print "Getting files for block %s" % (block)
        files = api.listFiles(block_name=block)
        fileList.append({block : files})
     
