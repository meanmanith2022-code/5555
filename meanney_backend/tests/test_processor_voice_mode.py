import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import processor


class VoiceModeTests(unittest.TestCase):
    def test_resolve_voice_for_segment_honors_manual_modes(self):
        self.assertEqual(processor.resolve_voice_for_segment('male', 'Auto'), processor.MALE_VOICE)
        self.assertEqual(processor.resolve_voice_for_segment('female', 'Auto'), processor.FEMALE_VOICE)
        self.assertEqual(processor.resolve_voice_for_segment('female', 'Sreymom'), processor.FEMALE_VOICE)
        self.assertEqual(processor.resolve_voice_for_segment('female', 'Piseth'), processor.MALE_VOICE)

    def test_resolve_voice_for_segment_uses_speaker_tag_when_present(self):
        self.assertEqual(
            processor.resolve_voice_for_segment(speaker_tag='Male: hello'),
            processor.MALE_VOICE,
        )
        self.assertEqual(
            processor.resolve_voice_for_segment(speaker_tag='Female: hello'),
            processor.FEMALE_VOICE,
        )
        self.assertEqual(
            processor.resolve_voice_for_segment(speaker_tag='Piseth: hello'),
            processor.MALE_VOICE,
        )
        self.assertEqual(
            processor.resolve_voice_for_segment(speaker_tag='[Sreymom] hello'),
            processor.FEMALE_VOICE,
        )

    def test_resolve_auto_clone_voice_matches_detected_gender(self):
        auto_clone_voices = {
            'male': 'Mean.wav',
            'female': 'Malyn.wav',
        }

        self.assertEqual(processor.resolve_auto_clone_voice('female', auto_clone_voices), 'Malyn.wav')
        self.assertEqual(processor.resolve_auto_clone_voice('male', auto_clone_voices), 'Mean.wav')
        self.assertEqual(processor.resolve_auto_clone_voice('unknown', auto_clone_voices), 'Malyn.wav')

    def test_resolve_clone_voice_choice_matches_clone_option(self):
        self.assertEqual(processor.resolve_clone_voice_choice('male', 'female'), 'Mean')
        self.assertEqual(processor.resolve_clone_voice_choice('female', 'male'), 'Malyn')
        self.assertEqual(processor.resolve_clone_voice_choice('auto', 'female'), 'Malyn')
        self.assertEqual(processor.resolve_clone_voice_choice('auto', 'male'), 'Mean')

    def test_resolve_clone_voice_choice_uses_gender_for_auto_detect(self):
        self.assertEqual(processor.resolve_clone_voice_choice('auto', 'unknown'), 'Malyn')
        self.assertEqual(processor.resolve_clone_voice_choice('auto', 'male'), 'Mean')
        self.assertEqual(processor.resolve_clone_voice_choice('auto', 'female'), 'Malyn')
