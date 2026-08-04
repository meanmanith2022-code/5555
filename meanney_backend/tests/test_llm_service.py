import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import llm_service


class LlmServiceTests(unittest.TestCase):
    def test_translate_and_detect_gender_parses_json_payload(self):
        class DummyResponse:
            text = '[{"id": 1, "khmer_text": "សួស្តី", "gender": "female"}]'

        class DummyClient:
            def generate_content(self, prompt):
                return DummyResponse()

        with patch.object(llm_service, 'client', DummyClient()):
            result = llm_service.translate_and_detect_gender(['Hello there'])

        self.assertEqual(result, [{'id': 1, 'khmer_text': 'សួស្តី', 'gender': 'female'}])

    def test_translate_and_detect_gender_falls_back_when_client_missing(self):
        with patch.object(llm_service, 'client', None):
            result = llm_service.translate_and_detect_gender(['Hello there', 'How are you?'])

        self.assertEqual(result[0]['id'], 1)
        self.assertEqual(result[0]['khmer_text'], 'Hello there')
        self.assertEqual(result[0]['gender'], 'female')
        self.assertEqual(result[1]['id'], 2)
        self.assertEqual(result[1]['khmer_text'], 'How are you?')
        self.assertEqual(result[1]['gender'], 'female')

    def test_translate_and_detect_gender_fallback_infers_known_male_gender(self):
        with patch.object(llm_service, 'client', None):
            result = llm_service.translate_and_detect_gender(['Kendrick is here'])

        self.assertEqual(result[0]['gender'], 'male')

    def test_translate_and_detect_gender_fallback_infers_known_female_gender(self):
        with patch.object(llm_service, 'client', None):
            result = llm_service.translate_and_detect_gender(['Mother said it was okay'])

        self.assertEqual(result[0]['gender'], 'female')
