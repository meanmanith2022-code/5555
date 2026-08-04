import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import main
from srt_parser import build_khmer_srt_from_text


class MainSrtTests(unittest.TestCase):
    def test_save_srt_content_writes_file(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            target_path = os.path.join(temp_dir, 'translated_khmer.srt')
            saved_path = main.save_srt_content(
                '1\n00:00:00,000 --> 00:00:02,000\nសួស្តី\n\n',
                target_path,
            )

            self.assertEqual(saved_path, target_path)
            self.assertTrue(os.path.exists(target_path))
            with open(target_path, 'r', encoding='utf-8') as fh:
                self.assertIn('00:00:00,000 --> 00:00:02,000', fh.read())

    def test_build_khmer_srt_from_text_writes_srt_file(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            output_path = os.path.join(temp_dir, 'auto_generated.srt')
            build_khmer_srt_from_text('សួស្តី ពិភាក្សា', 3.5, output_path)

            self.assertTrue(os.path.exists(output_path))
            with open(output_path, 'r', encoding='utf-8') as fh:
                content = fh.read()
            self.assertIn('សួស្តី ពិភាក្សា', content)
            self.assertIn('00:00:00,000 --> 00:00:03,500', content)

    def test_generate_dub_options_returns_cors_headers(self):
        client = main.app.test_client()
        response = client.options('/api/generate-dub')

        self.assertEqual(response.status_code, 200)
        self.assertIn('*', response.headers.get('Access-Control-Allow-Origin', ''))

    def test_dubbing_status_endpoint_returns_progress_payload(self):
        client = main.app.test_client()
        response = client.get('/api/dubbing-status')

        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data['status'], 'idle')
        self.assertEqual(data['current_step'], 0)
        self.assertEqual(data['percent'], 0.0)

    def test_generate_dub_accepts_json_paths_payload(self):
        client = main.app.test_client()
        uploads_dir = main.BASE_DIR / 'uploads'
        uploads_dir.mkdir(parents=True, exist_ok=True)

        video_path = uploads_dir / 'sample.mp4'
        srt_path = uploads_dir / 'sample.srt'
        video_path.write_bytes(b'fake-video')
        srt_path.write_text('1\n00:00:00,000 --> 00:00:02,000\nHello\n\n', encoding='utf-8')

        original_processor = main.process_full_dubbing

        def fake_process_full_dubbing(**kwargs):
            output_path = Path(kwargs['output_video'])
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(b'fake-output')
            return str(output_path)

        try:
            main.process_full_dubbing = fake_process_full_dubbing
            response = client.post('/api/generate-dub', json={
                'video_path': 'uploads/sample.mp4',
                'srt_path': 'uploads/sample.srt',
                'target_voice': 'auto',
            })
        finally:
            main.process_full_dubbing = original_processor

        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data['status'], 'completed')
        self.assertIn('video_url', data)


if __name__ == '__main__':
    unittest.main()
