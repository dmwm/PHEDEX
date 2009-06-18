import gfal

class File:
    def __init__(self, surl):
        self.surl = surl
        self.status = []

    def set(self, filestatus):
        for key in filestatus.keys():
            self.status[key] = filestatus[key]

    def get(self):
        return self.status


class Request:
    def __init__(self,request):
        rc, self.gfal, errmsg = gfal.gfal_init(request)
        if rc < 0:
            raise RequestError(errmsg)

    def status(self):
        rc, self.gfal, results = gfal.gfal_get_results(self.gfal)
        if rc < 0:
            raise RequestError(errmsg)
        return results

    def abort(self):
        rc, self.gfal, errmsg = gfal.gfal_abortrequest(self.gfal)
        if rc < 0:
            raise RequestError(errmsg)

    def release(self):
        rc, self.gfal, errmsg = gfal.gfal_release(self.gfal)
        if rc < 0:
            raise RequestError(errmsg)

    def token(self):
        nfiles, self.gfal, reqid, fileids, token = \
                gfal.gfal_get_ids(self.gfal)
        if nfiles < 0:
            raise RequestError(errmsg)
        return token

    def set_token(self, token):
        rc, self.gfal, errmsg = gfal.gfal_set_ids(self.gfal, None, 0, token)
        if rc < 0:
            raise RequestError(errmsg)
            
    def free(self):
        gfal.gfal_internal_free(self.gfal)

class LsRequest(Request):
    def ls(self):
        rc, self.gfal, errmsg = gfal.gfal_ls(self.gfal)
        if rc < 0:
            raise RequestError(errmsg)
    
class PrestageRequest(Request):
    def submit(self):
        rc, self.gfal, errmsg = gfal.gfal_prestage(self.gfal)
        if rc < 0:
            raise RequestError(errmsg)

    def poll(self):
        rc, self.gfal, errmsg = gfal.gfal_prestagestatus(self.gfal)
        if rc < 0:
            raise RequestError(errmsg)

class RequestError(Exception):
    def __init__(self, errmsg):
        self.errmsg = errmsg

    def message(self):
        return self.errmsg
