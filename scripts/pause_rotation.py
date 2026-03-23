import socket, json
s = socket.socket()
s.settimeout(5)
s.connect(('127.0.0.1', 9877))
s.send(json.dumps({'type': 'pause_rotation', 'params': {}}).encode() + b'\n')
s.recv(4096)
s.close()
