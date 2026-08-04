import os
import traceback
from processor import process_dubbing

input_video = os.path.join(os.getcwd(), 'input_video.mp4')
output_video = os.path.join(os.getcwd(), 'outputs', 'dubbed_khmer_output_test.mp4')
print('cwd', os.getcwd())
print('input exists', os.path.exists(input_video))
print('output path', output_video)
try:
    out = process_dubbing(input_video, 'សួស្តី', output_video)
    print('OK', out)
    print('output exists', os.path.exists(out))
    if os.path.exists(out):
        print('size', os.path.getsize(out))
except Exception:
    traceback.print_exc()
