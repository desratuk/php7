"""Local FastCGI smoke/regression checks; never contacts a live host."""
import hashlib,json,os,socket,struct,subprocess,time
from pathlib import Path
expected_version=subprocess.check_output(['php7.2','-r','echo PHP_VERSION;']).decode()
assert subprocess.check_output(['php7.2','-r','echo PHP_VERSION_ID;'])==b'70234'
root=Path('/tmp/php72-integration');root.mkdir(exist_ok=True);root.chmod(0o777)
(root/'sess_isolated72test').unlink(missing_ok=True)
(root/'probe.php').write_text('''<?php
session_start();
$_SESSION['count'] = isset($_SESSION['count']) ? $_SESSION['count'] + 1 : 1;
$upload = isset($_FILES['sample']) ? $_FILES['sample'] : null;
echo json_encode(array('version'=>PHP_VERSION, 'count'=>$_SESSION['count'],
'field'=>isset($_POST['hello']) ? $_POST['hello'] : null,
'upload'=>$upload ? array('error'=>$upload['error'], 'size'=>$upload['size'],
'valid'=>is_uploaded_file($upload['tmp_name']), 'sha256'=>hash_file('sha256',$upload['tmp_name'])) : null));
''')
(root/'oom.php').write_text('''<?php
class Sentinel { function __destruct() { file_put_contents('/tmp/php72-integration/destructor-ran', 'bad'); } }
$sentinel = new Sentinel(); $x = str_repeat('x', 32 * 1024 * 1024);
''')
(root/'fpm.conf').write_text('''[global]
error_log = /tmp/php72-integration/fpm.log
daemonize = no
[probe]
listen = /tmp/php72-integration/fpm.sock
listen.mode = 0666
user = www-data
group = www-data
pm = static
pm.max_children = 1
php_admin_value[memory_limit] = 8M
php_admin_value[session.save_path] = /tmp/php72-integration
''')

def record(kind,data,request=1):
 padding=(-len(data))%8
 return struct.pack('!BBHHBB',1,kind,request,len(data),padding,0)+data+b'\0'*padding

def request(script='probe.php',body=b'',ctype=''):
 values={'SCRIPT_FILENAME':str(root/script),'SCRIPT_NAME':'/'+script,'REQUEST_METHOD':'POST' if body else 'GET','CONTENT_LENGTH':str(len(body)),'CONTENT_TYPE':ctype,'SERVER_PROTOCOL':'HTTP/1.1','GATEWAY_INTERFACE':'CGI/1.1','SERVER_NAME':'localhost','SERVER_PORT':'80','REMOTE_ADDR':'127.0.0.1','HTTP_COOKIE':'PHPSESSID=isolated72test'}
 data=b''.join(bytes([len(k),len(v)])+k.encode()+v.encode() for k,v in values.items())
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(15);s.connect(str(root/'fpm.sock'));s.sendall(record(1,struct.pack('!HB5x',1,0))+record(4,data)+record(4,b'')+record(5,body)+record(5,b''));out=b''
  def read(n):
   b=b''
   while len(b)<n:
    chunk=s.recv(n-len(b))
    if not chunk:raise EOFError('FPM closed request')
    b+=chunk
   return b
  while True:
   _,kind,_,length,pad,_=struct.unpack('!BBHHBB',read(8));part=read(length);read(pad)
   if kind==6:out+=part
   if kind==3:break
  return out

oom=subprocess.run(['php7.2','-n','-d','memory_limit=8M',str(root/'oom.php')],capture_output=True)
assert oom.returncode==1 and b'Allowed memory size' in (oom.stdout+oom.stderr), 'Unexpected OOM exit behavior'
assert not (root/'destructor-ran').exists()

proc=subprocess.Popen(['php-fpm7.2','-F','-y',str(root/'fpm.conf')])
try:
 for _ in range(100):
  if (root/'fpm.sock').exists():break
  if proc.poll() is not None:raise RuntimeError('FPM failed to start')
  time.sleep(.1)
 def parsed(raw):return json.loads(raw.split(b'\r\n\r\n',1)[1])
 first=parsed(request());second=parsed(request());assert first['version']==expected_version,first;assert first['count']==1 and second['count']==2,(first,second)
 payload=b'isolated multipart upload\n';boundary='php72testboundary'
 body=(f'--{boundary}\r\nContent-Disposition: form-data; name="hello"\r\n\r\nworld\r\n--{boundary}\r\nContent-Disposition: form-data; name="sample"; filename="sample.txt"\r\nContent-Type: text/plain\r\n\r\n'.encode()+payload+f'\r\n--{boundary}--\r\n'.encode())
 upload=parsed(request(body=body,ctype='multipart/form-data; boundary='+boundary));assert upload['field']=='world';assert upload['upload']=={'error':0,'size':len(payload),'valid':True,'sha256':hashlib.sha256(payload).hexdigest()}
 # The backport must terminate a worker on OOM without running user destructors.
 try:request('oom.php')
 except (EOFError,ConnectionResetError):pass
 assert not (root/'destructor-ran').exists(),'User destructor ran after OOM'
 recovered=parsed(request());assert recovered['version']==expected_version
 print(json.dumps({'fpm_requests':'passed','session_across_requests':'passed','multipart_field_and_upload':'passed','cli_oom_exit_1_no_destructor':'passed','oom_no_user_destructor':'passed','fpm_recovery':'passed'},indent=2))
finally:
 proc.terminate();proc.wait(timeout=10)
