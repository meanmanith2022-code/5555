import os
import traceback
import json
import requests

BASE_DIR = os.getcwd()
print('cwd', BASE_DIR)
print('input exists', os.path.exists(os.path.join(BASE_DIR, 'input_video.mp4')))

url = 'http://127.0.0.1:5000/api/generate-dub'
headers = {'Content-Type': 'application/json'}
payload = {
    'text': 'Hello from test',
    'voice_gender': 'female',
    'original_volume': 0.0,
    'dub_volume': 1.0,
    'add_subtitle': True,
}

try:
    response = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    print('status', response.status_code)
    print('response', response.text)
except Exception:
    traceback.print_exc()
