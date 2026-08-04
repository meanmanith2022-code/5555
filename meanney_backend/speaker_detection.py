import os

try:
    import librosa
    import numpy as np
except Exception:  # pragma: no cover - fallback for missing dependency
    librosa = None
    np = None


def _normalize_speaker_name(value):
    if not value:
        return None
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {'piseth', 'male', 'ប្រុស', 'man', 'boy', 'm'}:
            return 'Piseth'
        if normalized in {'sreymom', 'female', 'ស្រី', 'woman', 'girl', 'f'}:
            return 'Sreymom'
    return None


def detect_speaker_gender(audio_segment_path: str, forced_gender: str = None, speaker_hint: str = None) -> str:
    """Return a speaker identity using explicit hints first, then audio-based detection."""
    explicit_name = _normalize_speaker_name(forced_gender) or _normalize_speaker_name(speaker_hint)
    if explicit_name:
        return explicit_name

    if not audio_segment_path or not os.path.exists(audio_segment_path):
        return 'Sreymom'

    if librosa is None or np is None:
        print('librosa/numpy unavailable; defaulting to Sreymom.')
        return 'Sreymom'

    try:
        y, sr = librosa.load(audio_segment_path, sr=None)
        pitches, magnitudes = librosa.piptrack(y=y, sr=sr)
        pitch_values = []

        for t in range(pitches.shape[1]):
            index = magnitudes[:, t].argmax()
            pitch = pitches[index, t]
            if 50 < pitch < 400:
                pitch_values.append(pitch)

        if not pitch_values:
            return 'Sreymom'

        avg_pitch = float(np.mean(pitch_values))
        print(f"🎙️ Detected Audio Pitch: {avg_pitch:.2f} Hz")
        return 'Piseth' if avg_pitch < 175 else 'Sreymom'
    except Exception as exc:
        print(f'Gender detection error: {exc}')
        return 'Sreymom'


def assign_segment_voice(extracted_segments, forced_gender=None):
    """Example helper that mirrors the requested per-segment loop and returns the resolved voice per segment."""
    assigned_voices = []
    for segment in extracted_segments or []:
        audio_path = segment.get('audio_path')
        detected_speaker = detect_speaker_gender(
            audio_segment_path=audio_path,
            forced_gender=forced_gender,
            speaker_hint=segment.get('speaker_gender'),
        )
        assigned_voices.append({
            **segment,
            'detected_speaker': detected_speaker,
        })
    return assigned_voices


def process_audio_segment(segment_audio_path, translated_text, user_voice_choice):
    """Select a voice for a single audio segment based on UI choice or automatic detection."""
    if user_voice_choice == 'male':
        selected_voice = 'Piseth'
    elif user_voice_choice == 'female':
        selected_voice = 'Sreymom'
    else:
        selected_voice = detect_speaker_gender(
            audio_segment_path=segment_audio_path,
            forced_gender=None,
        )

    print(f"🎙️ Segment Audio: {segment_audio_path} -> Assigned Voice: {selected_voice}")
    return selected_voice