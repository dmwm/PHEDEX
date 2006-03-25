import socket

# Type will normally be socket.SOCK_STREAM or socket.SOCK_DGRAM. Host
# should be the host portion of the address tuple that is passed to
# bind.
def boundSocket(type, ports, host, family=socket.AF_INET):
    s = socket.socket(family, type)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    bindSocket(sock=s, host=host, ports=ports)
    return s
        
def bindSocket(sock, host, ports):
    for port in ports:
        try:
            sock.bind((host, port))
        except socket.error:
            if port == ports[-1]:
                raise
        else:
            return
    raise "should not get here"
