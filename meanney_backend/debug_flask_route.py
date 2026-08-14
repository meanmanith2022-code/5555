import os
import traceback
from main import app

client = app.test_client()
print('cwd', os.getcwd())
print('input exists', os.path.exists(os.path.join(os.getcwd(), 'input_video.mp4')))
response = client.post('/api/generate-dub', json={
    'text': 'Hello from web test',
    'voice_gender': 'female',
    'original_volume': 0.0,
    'dub_volume': 1.0,
    'add_subtitle': True,
})
print('status', response.status_code)
print('body', response.get_data(as_text=True))
