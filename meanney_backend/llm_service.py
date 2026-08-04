import json
import os
from pathlib import Path

# Ensure temporary working directories exist
for directory in [
    Path(__file__).resolve().parent / "uploads",
    Path(__file__).resolve().parent / "outputs" / "temp_audio",
    Path(__file__).resolve().parent / "outputs" / "temp_srt_audio",
]:
    directory.mkdir(parents=True, exist_ok=True)

try:
    import imageio_ffmpeg
except Exception:  # pragma: no cover - fallback for missing dependency
    imageio_ffmpeg = None

try:
    import pydub
except Exception:  # pragma: no cover - fallback for missing dependency
    pydub = None

if imageio_ffmpeg is not None:
    ffmpeg_path = imageio_ffmpeg.get_ffmpeg_exe()
    if ffmpeg_path:
        os.environ["IMAGEIO_FFMPEG_EXE"] = ffmpeg_path
        if pydub is not None:
            pydub.AudioSegment.converter = ffmpeg_path

try:
    from google import genai as google_genai
except Exception:  # pragma: no cover - fallback for missing dependency
    google_genai = None

try:
    import google.generativeai as legacy_genai
except Exception:  # pragma: no cover - fallback for missing dependency
    legacy_genai = None

# Read the API key from environment or a local JSON file for convenience.
# Priority: environment variable `GEMINI_API_KEY`, then `.runtime_api_keys.json`.
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
_key_source = 'env'

if not GEMINI_API_KEY:
    base_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(base_dir, '..', '.runtime_api_keys.json')
    try:
        if os.path.exists(json_path):
            with open(json_path, 'r', encoding='utf-8') as f:
                keys_data = json.load(f)
                if isinstance(keys_data, list) and len(keys_data) > 0:
                    GEMINI_API_KEY = keys_data[0]
                    _key_source = json_path
                elif isinstance(keys_data, dict):
                    GEMINI_API_KEY = keys_data.get('gemini_api_key') or keys_data.get('api_key')
                    if GEMINI_API_KEY:
                        _key_source = json_path
    except Exception as e:
        print(f"Error reading JSON key file {json_path}: {e}")

client = None
if GEMINI_API_KEY:
    if google_genai is not None:
        try:
            client = google_genai.Client(api_key=GEMINI_API_KEY)
            print('Gemini client configured via google.genai.')
            if _key_source != 'env':
                print(f'Gemini API Key loaded successfully from {_key_source}!')
        except Exception as exc:
            print(f"Unable to configure google.genai: {exc}")
    elif legacy_genai is not None:
        try:
            legacy_genai.configure(api_key=GEMINI_API_KEY)
            client = legacy_genai.GenerativeModel('gemini-2.5-flash')
            print('Gemini client configured via google.generativeai.')
            if _key_source != 'env':
                print(f'Gemini API Key loaded successfully from {_key_source}!')
        except Exception as exc:
            print(f"Unable to configure google.generativeai: {exc}")
else:
    print("Warning: GEMINI_API_KEY is not set!")

def _build_gender_context(voice_option: str = 'auto') -> str:
    value = (voice_option or 'auto').strip().lower()
    if value == 'male':
        return (
            'The speaker is Male. Use appropriate male pronouns and polite particles '
            '(បាទ/លោក) in Khmer translation.'
        )
    if value == 'female':
        return (
            'The speaker is Female. Use appropriate female pronouns and polite particles '
            '(ចាស/អ្នកមីង/នាង) in Khmer translation.'
        )
    return 'Detect the speaker gender from context and use matching Khmer pronouns.'


def translate_subtitles_to_khmer(subtitle_text: str, voice_option: str = 'auto') -> str:
    """
    បកប្រែ Subtitle ទៅជាភាសាខ្មែរសម្រាប់ធ្វើ Voiceover/Dubbing
    """
    gender_context = _build_gender_context(voice_option)
    prompt = f"""
    You are an expert translator specializing in dubbing and voiceovers.
    Translate the following text/subtitles into natural, conversational Khmer suitable for spoken dubbing.

    Guidelines:
    - Keep sentences short and natural for speech.
    - Preserve context and emotion.
    - {gender_context}
    - Output ONLY the translated Khmer text, no extra explanations.

    Text:
    {subtitle_text}
    """

    if client is None:
        print('Gemini client is unavailable; returning the original text.')
        return subtitle_text

    try:
        if hasattr(client, 'models'):
            response = client.models.generate_content(
                model='gemini-2.5-flash',
                contents=prompt,
            )
            text = getattr(response, 'text', None)
            if text:
                return text.strip()
        elif hasattr(client, 'generate_content'):
            response = client.generate_content(prompt)
            text = getattr(response, 'text', None)
            if text:
                return text.strip()
        return subtitle_text
    except Exception as e:
        print(f"Gemini API Error: {e}")
        return subtitle_text


def translate_to_khmer(text_content: str, voice_option: str = 'auto') -> str:
    """Backward-compatible wrapper for the previous helper name."""
    return translate_subtitles_to_khmer(text_content, voice_option=voice_option)
    