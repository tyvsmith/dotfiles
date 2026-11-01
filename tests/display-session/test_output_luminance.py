"""Exercise the read-only query against a minimal Wayland socket peer."""
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import threading
import unittest
ROOT = Path(__file__).resolve().parents[2]

HELPER=ROOT/'home/dot_local/bin/executable_scb-output-luminance'

def words(*values): return struct.pack('='+'I'*len(values), *values)
def string(value):
    data=value.encode()+b'\0'
    return words(len(data))+data+b'\0'*(-len(data)%4)

class OutputLuminanceTest(unittest.TestCase):
    def query(self, peak=80, missing=False, fail=False, target='PF-test'):
        errors=[]
        with tempfile.TemporaryDirectory() as tmp:
            path=str(Path(tmp)/'wayland-test')
            with socket.socket(socket.AF_UNIX) as server:
                server.bind(path);server.listen();server.settimeout(3)
                def serve():
                    try:
                        with server.accept()[0] as peer:
                            peer.settimeout(3)
                            objects={1:'display'}
                            def emit(obj,op,data=b''):
                                packet=words(obj,((8+len(data))<<16)|op)+data
                                # Split headers as well as payloads to exercise stream framing.
                                peer.sendall(packet[:3]);peer.sendall(packet[3:])
                            def read(n):
                                data=b''
                                while len(data)<n:
                                    chunk=peer.recv(n-len(data))
                                    if not chunk: raise EOFError
                                    data+=chunk
                                return data
                            while True:
                                obj,head=struct.unpack('=II',read(8));op=head&65535
                                body=read((head>>16)-8)
                                kind=objects[obj]
                                if kind=='display' and op==1:
                                    reg,=struct.unpack('=I',body);objects[reg]='registry'
                                    emit(reg,0,words(11)+string('wl_output')+words(4))
                                    emit(reg,0,words(22)+string('wp_color_manager_v1')+words(1))
                                elif kind=='display' and op==0:
                                    cb,=struct.unpack('=I',body);emit(cb,0,words(0))
                                elif kind=='registry':
                                    global_id,=struct.unpack_from('=I',body)
                                    new_id,=struct.unpack_from('=I',body,len(body)-4)
                                    objects[new_id]='output' if global_id==11 else 'manager'
                                    if global_id==11: emit(new_id,4,string('PF-test'));emit(new_id,2)
                                elif kind=='manager':
                                    self.assertEqual(op,1)  # get_output, never a surface or creator
                                    new_id,output=struct.unpack('=II',body)
                                    self.assertEqual(objects[output],'output');objects[new_id]='color_output'
                                elif kind=='color_output':
                                    self.assertEqual(op,1)
                                    new_id,=struct.unpack('=I',body);objects[new_id]='description'
                                    emit(new_id,0,words(0)+string('unavailable')) if fail else emit(new_id,1,words(1))
                                elif kind=='description':
                                    self.assertEqual(op,1)
                                    new_id,=struct.unpack('=I',body)
                                    if not missing: emit(new_id,6,words(2000,peak,203))
                                    emit(new_id,0)
                    except (EOFError,BrokenPipeError,ConnectionResetError): pass
                    except Exception as exc: errors.append(exc)
                thread=threading.Thread(target=serve);thread.start()
                result=subprocess.run(['/usr/bin/python',str(HELPER),target],env=os.environ|{'WAYLAND_DISPLAY':path},capture_output=True,text=True,timeout=5)
                thread.join(4)
                self.assertFalse(thread.is_alive())
                self.assertEqual(errors,[])
                return result

    def test_reads_exact_output_luminance(self):
        for peak in [80,400,1600]:
            result=self.query(peak=peak)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(json.loads(result.stdout),{'output':'PF-test','max_luminance':peak,'reference_luminance':203})

    def test_missing_luminance_is_distinct_from_failed_query(self):
        result=self.query(missing=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIsNone(json.loads(result.stdout)['max_luminance'])

    def test_failed_description_has_no_metadata(self):
        result=self.query(fail=True)
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,'')

    def test_wrong_output_is_not_used(self):
        result=self.query(target='PF-other')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,'')
