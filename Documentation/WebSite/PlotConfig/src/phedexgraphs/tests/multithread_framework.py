
import threading, time, sys

def multithread(job_list, threads=10, spin=.1):
    
    job_lock = threading.Lock()
    result_lock = threading.Lock()
    result_list = []

    thread_list = []
    for i in range(threads):
        t = threading.Thread( target=processing_thread, args=(job_lock, \
            job_list, result_lock, result_list) )
        t.setName("Worker Thread %i" % i)
        t.setDaemon(True)
        t.start()
        thread_list.append( t )

    do_exit = False
    while not do_exit:
        do_exit = True
        try:
            for t in thread_list:
                if t.isAlive():
                    do_exit = False
                    break
            time.sleep(spin)
        except (KeyboardInterrupt, SystemExit):
            print "Exiting due to external interrupt."
            sys.exit(3)

    return result_list

def processing_thread(job_lock, job_list, result_lock, result_list):
    t = threading.currentThread()
    counter = 0
    while True:
        job_lock.acquire()
        try:
            if len(job_list) == 0:
                #print "%s is exiting because all jobs are finished." % \
                #    t.getName()
                break
            function, args = job_list.pop()
        finally: 
            job_lock.release()
        try:
            results = function( *args )
            counter += 1
            #print "%s has finished %03i units of work; %i remaining" % \
            #    (t.getName(), counter, len(job_list))
        except Exception, e:
            #print "%s has encountered the following exception: `%s`.  " \
            #    "Ignoring." % (t.getName(), str(e)) 
            job_lock.acquire()
            try:
                job_list.append( (function, args) )
            finally:
                job_lock.release()
            continue
        result_lock.acquire()
        try:
            result_list += [results]
        finally:
            result_lock.release()

