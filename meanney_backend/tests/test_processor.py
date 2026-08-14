import asyncio
import os
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import processor
import fftools


class ProcessorFallbackTests(unittest.TestCase):
    def test_fallback_audio_generation_uses_existing_audio_file(self):
        output_audio = Path(self._testMethodName + '.mp3')
        output_audio.write_bytes(b'fake-audio-data')
        try:
            result = processor._generate_audio_with_fallback('hello', str(output_audio))
            self.assertEqual(result, str(output_audio))
            self.assertTrue(output_audio.exists())
            self.assertGreater(output_audio.stat().st_size, 0)
        finally:
            if output_audio.exists():
                output_audio.unlink()

    def test_build_subtitle_filter_uses_font_style(self):
        srt_path = r"C:\temp\sample.srt"
        fonts_dir = r"C:\temp\fonts"
        filter_string = processor.build_subtitle_filter(srt_path, fonts_dir)

        self.assertIn("subtitles=", filter_string)
        self.assertIn("force_style=", filter_string)
        self.assertIn("Fontname=Khmer OS Battambang", filter_string)
        self.assertIn("FontSize=13", filter_string)
        self.assertIn("PrimaryColour=&H00FFFFFF&", filter_string)
        self.assertIn("OutlineColour=&H00000000", filter_string)
        self.assertIn("Outline=1.5", filter_string)
        self.assertIn("Shadow=1", filter_string)
        self.assertIn("Spacing=1.0", filter_string)
        self.assertIn("Alignment=2", filter_string)
        self.assertIn("MarginV=15", filter_string)
        self.assertIn("fontsdir='", filter_string)

    def test_build_translation_prompt_includes_voice_tag_instruction(self):
        prompt = processor.build_translation_prompt("Hello there")

        self.assertIn("professional translator", prompt)
        self.assertIn("Do NOT include any voice direction tags", prompt)
        self.assertIn("spoken Khmer", prompt)
        self.assertIn("សង្ហា", prompt)
        self.assertIn("Hello there", prompt)

    def test_generate_srt_audios_accepts_missing_input_video(self):
        class FakeCommunicate:
            def __init__(self, text, voice_name):
                self.text = text
                self.voice_name = voice_name

            async def save(self, output_file):
                with open(output_file, 'wb') as fh:
                    fh.write(b'fake-audio-data')

        class FakeGTTS:
            def __init__(self, text, lang):
                self.text = text
                self.lang = lang

            def save(self, output_file):
                with open(output_file, 'wb') as fh:
                    fh.write(b'fake-audio-data')

        fake_edge_tts = types.SimpleNamespace(Communicate=FakeCommunicate)

        with tempfile.TemporaryDirectory() as tmpdir, \
            patch.object(processor, 'edge_tts', fake_edge_tts, create=True), \
            patch.object(processor, 'gTTS', FakeGTTS, create=True), \
            patch.object(processor, 'imageio_ffmpeg', types.SimpleNamespace(get_ffmpeg_exe=lambda: 'ffmpeg'), create=True), \
            patch.object(processor, 'detect_speaker_gender', None, create=True):
            subtitles = [{'start': 0.0, 'end': 1.0, 'final_srt_text': 'សួស្តី'}]
            result = asyncio.run(processor.generate_srt_audios(subtitles, voice_gender='female', temp_dir=tmpdir))

            self.assertEqual(len(result), 1)
            self.assertEqual(result[0]['start'], 0.0)
            self.assertEqual(result[0]['end'], 1.0)
            self.assertEqual(os.path.basename(result[0]['file']), 'seg_0.mp3')
            self.assertTrue(os.path.exists(result[0]['file']))
            self.assertGreater(os.path.getsize(result[0]['file']), 0)

    def test_generate_srt_audios_uses_per_segment_speaker_metadata(self):
        recorded_voice_names = []

        class FakeCommunicate:
            def __init__(self, text, voice_name):
                self.text = text
                self.voice_name = voice_name

            async def save(self, output_file):
                recorded_voice_names.append(self.voice_name)
                with open(output_file, 'wb') as fh:
                    fh.write(b'fake-audio-data')

        class FakeGTTS:
            def __init__(self, text, lang):
                self.text = text
                self.lang = lang

            def save(self, output_file):
                with open(output_file, 'wb') as fh:
                    fh.write(b'fake-audio-data')

        fake_edge_tts = types.SimpleNamespace(Communicate=FakeCommunicate)

        with tempfile.TemporaryDirectory() as tmpdir, \
            patch.object(processor, 'edge_tts', fake_edge_tts, create=True), \
            patch.object(processor, 'gTTS', FakeGTTS, create=True), \
            patch.object(processor, 'imageio_ffmpeg', types.SimpleNamespace(get_ffmpeg_exe=lambda: 'ffmpeg'), create=True), \
            patch.object(processor, 'detect_speaker_gender', None, create=True):
            subtitles = [
                {'start': 0.0, 'end': 1.0, 'final_srt_text': 'សួស្តី', 'speaker_id': 'speaker_male'},
                {'start': 1.0, 'end': 2.0, 'final_srt_text': 'អ្នកណា', 'speaker_id': 'speaker_female'},
            ]
            asyncio.run(processor.generate_srt_audios(subtitles, voice_gender='female', temp_dir=tmpdir, forced_gender='female'))

        self.assertEqual(recorded_voice_names[0], 'km-KH-PisethNeural')
        self.assertEqual(recorded_voice_names[1], 'km-KH-SreynomNeural')

    def test_build_subtitle_filter_uses_subtitles_filter_for_ass_files(self):
        srt_path = r"C:\temp\sample.ass"
        fonts_dir = r"C:\temp\fonts"
        filter_string = processor.build_subtitle_filter(srt_path, fonts_dir)

        self.assertIn("subtitles=", filter_string)
        self.assertIn("fontsdir=", filter_string)
        self.assertNotIn("ass=filename=", filter_string)

    def test_build_simple_audio_merge_command_uses_audio_only_ffmpeg_flow(self):
        with patch('processor.imageio_ffmpeg.get_ffmpeg_exe', return_value='C:/ffmpeg.exe'):
            cmd = processor._build_simple_audio_merge_command('input.mp4', 'dub.wav', 'out.mp4')

        self.assertEqual(cmd[0], 'C:/ffmpeg.exe')
        self.assertIn('-map', cmd)
        self.assertIn('0:v:0', cmd)
        self.assertIn('1:a:0', cmd)
        self.assertIn('-c:v', cmd)
        self.assertIn('copy', cmd)
        self.assertIn('-shortest', cmd)

    def test_auto_translate_to_khmer_uses_explicit_locale_mapping(self):
        translated = processor.auto_translate_to_khmer("UK")
        self.assertEqual(translated, "អង់គ្លេស")

    def test_extract_speaker_tag_detects_male_and_female(self):
        self.assertEqual(processor.extract_speaker_tag("Male: Hello there"), "male")
        self.assertEqual(processor.extract_speaker_tag("Female: Hello there"), "female")
        self.assertEqual(processor.extract_speaker_tag("Hello there"), "")

    def test_parse_srt_preserves_exact_supplied_khmer_text(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            srt_path = os.path.join(tmpdir, 'input_khmer.srt')
            with open(srt_path, 'w', encoding='utf-8') as fh:
                fh.write(
                    '1\n'
                    '00:00:00,000 --> 00:00:02,000\n'
                    'Olivia!\n\n'
                )

            subtitles = processor.parse_srt(srt_path)
            self.assertEqual(len(subtitles), 1)
            self.assertEqual(subtitles[0]['final_srt_text'], 'Olivia!')
            self.assertEqual(subtitles[0]['khmer_text'], 'Olivia!')

    def test_build_clean_srt_from_subtitles_uses_cleaned_text(self):
        subtitles = [
            {
                'start': 1.0,
                'end': 2.5,
                'final_srt_text': '(female) Hello there',
                'khmer_text': 'សួស្តី',
                'srt_text': 'Hello there',
            }
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            srt_path = os.path.join(tmpdir, 'burn_in.srt')
            processor.build_clean_srt_from_subtitles(subtitles, srt_path)

            with open(srt_path, 'r', encoding='utf-8') as f:
                content = f.read()

            self.assertIn('Hello there', content)
            self.assertNotIn('(female)', content)
            self.assertIn('00:00:01,000 --> 00:00:02,500', content)

    def test_build_clean_srt_from_subtitles_uses_non_overlapping_timing(self):
        subtitles = [
            {'start': 0.0, 'end': 2.0, 'final_srt_text': 'សួស្តី', 'khmer_text': 'សួស្តី', 'srt_text': 'សួស្តី'},
            {'start': 1.0, 'end': 3.0, 'final_srt_text': 'អ្នកណា', 'khmer_text': 'អ្នកណា', 'srt_text': 'អ្នកណា'},
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            srt_path = os.path.join(tmpdir, 'timing.srt')
            processor.build_clean_srt_from_subtitles(subtitles, srt_path)

            with open(srt_path, 'r', encoding='utf-8') as f:
                content = f.read()

            self.assertIn('00:00:00,200 --> 00:00:02,000', content)
            self.assertIn('00:00:02,200 --> 00:00:03,000', content)
            self.assertNotIn('00:00:01,000 --> 00:00:03,000', content)

    def test_adjust_subtitles_to_audio_preserves_exact_frame_timestamps(self):
        subtitles = [
            {'start': 0.0, 'end': 2.2, 'final_srt_text': 'ចុះម៉េចក៏មានបុរសសង្ហាខ្លាំងម្ល៉េះ?', 'khmer_text': 'ចុះម៉េចក៏មានបុរសសង្ហាខ្លាំងម្ល៉េះ?', 'srt_text': 'ចុះម៉េចក៏មានបុរសសង្ហាខ្លាំងម្ល៉េះ?'}
        ]
        audio_segments = [
            {'file': 'fake.mp3', 'start': 0.0, 'end': 2.2}
        ]

        with patch('processor.get_audio_duration_seconds', return_value=0.8), patch('processor.os.path.exists', return_value=True):
            result = processor.adjust_subtitles_to_audio(subtitles, audio_segments)

        self.assertEqual(result[0]['start'], 0.0)
        self.assertEqual(result[0]['end'], 2.2)

    def test_build_ass_subtitle_from_srt_uses_ass_timestamp_format(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            srt_path = os.path.join(tmpdir, 'burn_in.srt')
            ass_path = os.path.join(tmpdir, 'burn_in.ass')
            with open(srt_path, 'w', encoding='utf-8') as fh:
                fh.write(
                    '1\n'
                    '00:00:00,000 --> 00:00:02,200\n'
                    'ចុះម៉េចក៏មានបុរសសង្ហាខ្លាំងម្ល៉េះ?\n\n'
                )

            processor.build_ass_subtitle_from_srt(srt_path, ass_path)

            with open(ass_path, 'r', encoding='utf-8') as fh:
                ass_text = fh.read()

            self.assertIn('Dialogue: 0,00:00:00.000,00:00:02.200,Default', ass_text)
            self.assertNotIn('Dialogue: 0,00:00:00,000,00:00:02,200,Default', ass_text)

    def test_mix_tts_and_bgm_uses_resolved_ffmpeg_binary(self):
        with patch('fftools._resolve_ffmpeg_binary', return_value='C:/ffmpeg.exe'), patch('fftools.subprocess.run') as mock_run:
            mock_run.return_value = unittest.mock.Mock(returncode=0, stderr='', stdout='')

            fftools.mix_tts_and_bgm('tts.mp3', 'bgm.mp3', 'out.mp3', bgm_volume=0.15)

            command = mock_run.call_args[0][0]
            self.assertEqual(command[0], 'C:/ffmpeg.exe')
            self.assertIn('-stream_loop', command)
            self.assertIn('-1', command)
            self.assertIn('out.mp3', command)

            filter_arg = next(arg for arg in command if arg.startswith('[1:a]volume='))
            self.assertIn('volume=0.15', filter_arg)

    def test_normalize_audio_uses_loudnorm_filter(self):
        with patch('fftools._resolve_ffmpeg_binary', return_value='C:/ffmpeg.exe'), patch('fftools.subprocess.run') as mock_run:
            mock_run.return_value = unittest.mock.Mock(returncode=0, stderr='', stdout='')

            fftools.normalize_audio('input.mp3', 'output.mp3')

            command = mock_run.call_args[0][0]
            self.assertEqual(command[0], 'C:/ffmpeg.exe')
            self.assertIn('-af', command)
            self.assertIn('loudnorm=I=-16:TP=-1.5:LRA=11', command)
            self.assertIn('output.mp3', command)


if __name__ == '__main__':
    unittest.main()
