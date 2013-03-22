# Diverse python tools
# by Fred Stober (stober@cern.ch)

import time, os

def expath(fn):
	return os.path.realpath(os.path.expanduser(fn))

def sec2str(sec):
	if sec / 3600 > 99:
		return '%dd %02d:%02d:%02d' % (sec / (24*3600), (sec / 3600) % 24, (sec / 60) % 60, sec % 60)
	return '%02d:%02d:%02d' % (sec / 3600, (sec / 60) % 60, sec % 60)

def byte2str(bytes, output = None, prec = 3):
	fmt = '%%.%df' % prec
	if output == None:
		if bytes < 1024:
			output = 'B'
		elif bytes < 1024**2:
			output = 'KB'
		elif bytes < 1024**3:
			output = 'MB'
		elif bytes < 1024**4:
			output = 'GB'
		elif bytes < 1024**5:
			output = 'TB'
		else:
			output = 'PB'
	if output == 'B':
		return '%d Byte' % (bytes)
	elif output == 'KB':
		return (fmt + ' KB') % (bytes / 1024.)
	elif output == 'MB':
		return (fmt + ' MB') % (bytes / 1024.**2)
	elif output == 'GB':
		return (fmt + ' GB') % (bytes / 1024.**3)
	elif output == 'TB':
		return (fmt + ' TB') % (bytes / 1024.**4)
	elif output == 'PB':
		return (fmt + ' PB') % (bytes / 1024.**5)
	else:
		raise Exception('Invalid output format: %d!' % output)

def unixdate2str(unixdate):
	return time.strftime('%Y-%m-%d %T', time.gmtime(unixdate))

def nice_json(data):
	import json
	return json.dumps(data, sort_keys = True, indent = 4)

def red(value):
	return '\033[0;31m%s\033[0m' % value

def green(value):
	return '\033[0;32m%s\033[0m' % value

def yellow(value):
	return '\033[0;33m%s\033[0m' % value

def blue(value):
	return '\033[0;34m%s\033[0m' % value
