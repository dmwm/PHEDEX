import traceback

def currentStackTrace():
    return traceback.extract_stack()[:-1]

def formatStackTrace(stackTrace):
    return "".join(traceback.format_list(stackTrace))

def formatCurrentStackTrace():
    return formatStackTrace(currentStackTrace())
