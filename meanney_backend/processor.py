import os
import re
import asyncio
import subprocess
import imageio_ffmpeg
import edge_tts
from gtts import gTTS
from deep_translator import GoogleTranslator
from fftools import mix_tts_and_bgm, normalize_audio, probe, escape_ffmpeg_path

try:
    from speaker_detection import detect_speaker_gender
except Exception:  # pragma: no cover - fallback if helper is unavailable
    def detect_speaker_gender(_audio_path, forced_gender=None):
        """Fallback no-op detector used when the speaker-gender helper is unavailable."""
        if forced_gender and forced_gender.strip():
            g = forced_gender.strip().lower()
            return 'Piseth' if g in ['piseth', 'male', 'ប្រុស'] else 'Sreymom'
        return "Sreymom"


def _ensure_ffmpeg_on_path():
    """Prepend known FFmpeg locations to PATH so PyDub can discover ffmpeg/ffprobe."""
    candidates = []

    try:
        bundled_ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
        if bundled_ffmpeg and os.path.exists(bundled_ffmpeg):
            candidates.append(os.path.dirname(bundled_ffmpeg))
    except Exception:
        pass

    common_paths = [
        r"C:\ffmpeg\bin",
        r"C:\Program Files\ffmpeg\bin",
        r"C:\Program Files (x86)\ffmpeg\bin",
    ]
    for path in common_paths:
        if os.path.isdir(path):
            candidates.append(path)

    current_path = os.environ.get("PATH", "")
    for candidate in candidates:
        if candidate and candidate not in current_path.split(os.pathsep):
            os.environ["PATH"] = candidate + os.pathsep + current_path
            current_path = os.environ["PATH"]


_ensure_ffmpeg_on_path()

import pydub
from pydub import AudioSegment


def _configure_pydub_ffmpeg_paths():
    """Point PyDub at the bundled FFmpeg binaries when available."""
    try:
        bundled_ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
        bundled_ffprobe = imageio_ffmpeg.get_ffprobe_exe()
        if bundled_ffmpeg and os.path.exists(bundled_ffmpeg):
            pydub.AudioSegment.converter = bundled_ffmpeg
        if bundled_ffprobe and os.path.exists(bundled_ffprobe):
            pydub.AudioSegment.ffprobe = bundled_ffprobe
    except Exception:
        pass


_configure_pydub_ffmpeg_paths()


def is_khmer_text(text):
    khmer_pattern = re.compile(r'[\u1780-\u17FF]')
    return bool(khmer_pattern.search(text))


def auto_translate_to_khmer(text):
    if not text or not text.strip():
        return ""

    normalized = clean_subtitle_text(text)
    if not normalized:
        return ""

    direct_mapping = {
        'uk': 'ចក្រភពអង់គ្លេស',
        'united kingdom': 'ចក្រភពអង់គ្លេស',
        'england': 'ចក្រភពអង់គ្លេស',
        'london': 'ឡុងដ៍',
        'paris': 'ប៉ារីស',
        'japan': 'ជប៉ុន',
        'china': 'ចិន',
        'korea': 'កូរ៉េ',
        'america': 'សហរដ្ឋអាមេរិក',
        'usa': 'សហរដ្ឋអាមេរិក',
        'us': 'សហរដ្ឋអាមេរិក',
    }

    lowered = normalized.lower().strip()
    if lowered in direct_mapping:
        mapped = direct_mapping[lowered]
        print(f"[INFO] Explicit Khmer mapping: '{text}' -> '{mapped}'")
        return mapped

    if is_khmer_text(normalized):
        print(f"[INFO] Direct Khmer SRT: {normalized}")
        return normalized

    try:
        translated = GoogleTranslator(source='auto', target='km').translate(normalized)
        print(f"[TRANSLATED] '{normalized}' -> '{translated}'")
        return translated
    except Exception as e:
        print(f"[WARN] Translation failed ({e}), using raw text.")
        return normalized


def parse_time_str(time_str):
    normalized = time_str.strip().replace(',', '.')
    parts = normalized.split(':')

    if len(parts) == 3:
        hours, minutes, seconds = parts
        return float(hours) * 3600 + float(minutes) * 60 + float(seconds)

    if len(parts) == 2:
        minutes, seconds = parts
        return float(minutes) * 60 + float(seconds)

    raise ValueError(f'Unsupported SRT timestamp format: {time_str}')


def clean_subtitle_text(text):
    """Remove parenthetical tags and normalize stray whitespace for Khmer-safe subtitle text."""
    if not text:
        return ""

    cleaned = re.sub(r'\s*\([^)]*\)', '', text)
    cleaned = cleaned.replace('\u00a0', ' ')
    cleaned = re.sub(r'[\u200b-\u200d\u2060\ufeff]', '', cleaned)
    cleaned = re.sub(r'\s+', ' ', cleaned)
    return cleaned.strip()


def cleanup_render_cache(work_dir):
    """Delete stale subtitle cache/temp files so the next render always uses the latest edited SRT."""
    if not work_dir or not os.path.isdir(work_dir):
        return

    for name in os.listdir(work_dir):
        path = os.path.join(work_dir, name)
        if not os.path.isfile(path):
            continue

        lower_name = name.lower()
        should_delete = any(token in lower_name for token in ['temp', 'cache', 'cached', 'burn_in', 'translated', 'subtitle'])
        if should_delete or lower_name.endswith(('.ass', '.srt', '.json', '.tmp', '.log', '.mp4')):
            try:
                os.remove(path)
                print(f"[INFO] Removed stale subtitle cache file: {path}")
            except Exception as exc:
                print(f"[WARN] Failed to remove cache file {path}: {exc}")


def assign_correct_voice(speaker_tag: str) -> str:
    """Map speaker tags to the correct voice name for TTS generation."""
    tag = (speaker_tag or '').lower()

    if any(k in tag for k in ['male', 'boy', 'man', 'ប្រុស', 'piseth']):
        return 'Piseth'
    if any(k in tag for k in ['female', 'girl', 'woman', 'ស្រី', 'sreymom']):
        return 'Sreymom'

    return 'Sreymom'


def _create_audio_segment_from_video(input_video, output_wav, start_time, end_time):
    """Extract a short audio chunk from the source video for speaker detection."""
    if not input_video or not os.path.exists(input_video):
        return None
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    duration = max(float(end_time) - float(start_time), 0.1)
    cmd = [
        ffmpeg_exe,
        '-y',
        '-ss', str(start_time),
        '-i', input_video,
        '-t', str(duration),
        '-vn',
        '-acodec', 'pcm_s16le',
        output_wav,
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print(f"[WARN] Failed to extract audio segment for speaker detection: {result.stderr}")
        return None
    return output_wav


def _matches_speaker_token(text, tokens):
    if not text:
        return False
    lower_text = text.lower()
    for token in tokens:
        pattern = rf"(?:^|[_\s-]){re.escape(token)}(?:$|[_\s-])"
        if re.search(pattern, lower_text):
            return True
    return False


def resolve_speaker_voice(subtitle, forced_gender=None, fallback_audio_path=None, index=None):
    """Resolve a voice for a segment using per-segment speaker metadata first, then the source video audio, then an explicit override."""
    if isinstance(subtitle, dict) and 'speaker_id' in subtitle and 'forced_gender' in subtitle and forced_gender is None:
        forced_gender = subtitle.get('forced_gender')
        subtitle = {'speaker_id': subtitle.get('speaker_id')}

    speaker_candidates = []
    speaker_candidates.extend([
        subtitle.get('speaker_id') if isinstance(subtitle, dict) else None,
        subtitle.get('speaker') if isinstance(subtitle, dict) else None,
        subtitle.get('speaker_type') if isinstance(subtitle, dict) else None,
        subtitle.get('role') if isinstance(subtitle, dict) else None,
        subtitle.get('speaker_tag') if isinstance(subtitle, dict) else None,
        subtitle.get('speaker_hint') if isinstance(subtitle, dict) else None,
    ])

    for candidate in speaker_candidates:
        if not candidate:
            continue
        if isinstance(candidate, str):
            candidate_text = candidate.strip()
            if not candidate_text:
                continue
            if _matches_speaker_token(candidate_text, ['male', 'boy', 'man', 'piseth', 'ប្រុស']):
                return 'km-KH-PisethNeural'
            if _matches_speaker_token(candidate_text, ['female', 'girl', 'woman', 'sreymom', 'ស្រី']):
                return 'km-KH-SreynomNeural'

    
        print(f"=== AI DETECT ឃើញភេទ៖ {fallback_speaker} ===")
        if fallback_speaker.lower() in {'male', 'piseth'}:
            return 'km-KH-PisethNeural'
        return 'km-KH-SreynomNeural'

    if forced_gender and forced_gender.strip():
        fg_lower = forced_gender.strip().lower()
        if fg_lower in ['piseth', 'male', 'ប្រុស']:
            return 'km-KH-PisethNeural'
        if fg_lower in ['sreymom', 'female', 'ស្រី']:
            return 'km-KH-SreynomNeural'

    return 'km-KH-SreynomNeural'


def extract_speaker_tag(text):
    """Extract a speaker tag from subtitle text when present, such as 'Male:' or 'Female:'"""
    if not text:
        return ''

    cleaned = clean_subtitle_text(text)
    match = re.search(r'\b(male|female|boy|girl|man|woman|ប្រុស|ស្រី)\b', cleaned.lower())
    if match:
        return match.group(1)
    return ''


def derive_speaker_hint_from_srt_line(line):
    """Derive a speaker hint from an SRT subtitle line when it contains explicit tags like (female) or (male)."""
    if not line:
        return None

    text = str(line).strip()
    if not text:
        return None

    lower_text = text.lower()
    if '(female)' in lower_text or re.search(r'\bfemale\b', lower_text):
        return 'female'
    if '(male)' in lower_text or re.search(r'\bmale\b', lower_text):
        return 'male'
    return None


def parse_srt(srt_filepath):
    subtitles = []
    if not os.path.exists(srt_filepath):
        return subtitles

    with open(srt_filepath, 'r', encoding='utf-8') as f:
        content = f.read().strip().split('\n\n')

    for block in content:
        lines = [line.strip() for line in block.split('\n') if line.strip()]
        if len(lines) >= 3:
            times = lines[1].split(' --> ')
            start_time = parse_time_str(times[0])
            end_time = parse_time_str(times[1])
            raw_text = " ".join(lines[2:]).strip()
            cleaned_text = clean_subtitle_text(raw_text)

            khmer_text = cleaned_text

            if khmer_text:
                speaker_tag = extract_speaker_tag(raw_text)
                speaker_hint = derive_speaker_hint_from_srt_line(raw_text)
                final_srt_text = clean_subtitle_text(khmer_text)
                subtitles.append({
                    'start': start_time,
                    'end': end_time,
                    'khmer_text': khmer_text,
                    'srt_text': cleaned_text,
                    'final_srt_text': final_srt_text,
                    'speaker_tag': speaker_tag,
                    'speaker_hint': speaker_hint,
                })
    return subtitles


async def generate_srt_audios(subtitles, input_video=None, voice_gender="female", temp_dir="temp_srt_audio", forced_gender=None):
    if isinstance(input_video, str) and input_video.lower() in {"female", "male"}:
        if isinstance(voice_gender, str) and voice_gender.lower() not in {"female", "male"}:
            temp_dir = voice_gender
        voice_gender = input_video.lower()
        input_video = None

    os.makedirs(temp_dir, exist_ok=True)
    default_voice_name = "km-KH-SreynomNeural" if voice_gender == "female" else "km-KH-PisethNeural"
    audio_segments = []

    for idx, sub in enumerate(subtitles):
        text = clean_subtitle_text(sub.get('final_srt_text') or sub.get('khmer_text') or sub.get('srt_text') or '')
        fallback_audio = os.path.join(temp_dir, f"seg_{idx}.wav")
        if input_video and not any(sub.get(key) for key in ['speaker_id', 'speaker', 'speaker_type', 'role', 'speaker_tag']):
            _create_audio_segment_from_video(input_video, fallback_audio, sub['start'], sub['end'])
        voice_name = resolve_speaker_voice(
            sub,
            forced_gender=forced_gender,
            fallback_audio_path=fallback_audio if input_video else None,
            index=idx,
        )

        output_file = os.path.join(temp_dir, f"seg_{idx}.mp3")
        
        clean_text = re.sub(r'[^\w\s\u1780-\u17FF]', '', text).strip()
        if not clean_text:
            clean_text = text

        try:
            communicate = edge_tts.Communicate(clean_text, voice_name)
            await communicate.save(output_file)
        except Exception:
            tts = gTTS(text=clean_text, lang='km')
            tts.save(output_file)

        audio_segments.append({
            'file': output_file,
            'start': sub['start'],
            'end': sub['end']
        })

    return audio_segments


def get_media_duration_seconds(media_path):
    if not media_path or not os.path.exists(media_path):
        return None

    try:
        info = probe(media_path)
        format_duration = info.get('format', {}).get('duration')
        if format_duration:
            return float(format_duration)

        for stream in info.get('streams', []):
            duration = stream.get('duration')
            if duration:
                return float(duration)
    except Exception as e:
        print(f"[WARN] Could not determine media duration for {media_path}: {e}")

    return None


def build_subtitle_filter(srt_path, fonts_dir, font_name=None, font_size=13, primary_color="&H00FFFFFF&", alignment=2):
    if not srt_path:
        return ""

    safe_subtitle_path = escape_ffmpeg_path(srt_path)
    safe_fonts_dir = escape_ffmpeg_path(fonts_dir) if fonts_dir else ''

    return f"subtitles='{safe_subtitle_path}':fontsdir='{safe_fonts_dir}'"


def concat_audio_files(audio_files, output_path, work_dir=None):
    if not audio_files:
        raise ValueError('No audio files provided for concatenation')

    work_dir = work_dir or os.path.dirname(output_path) or os.getcwd()
    os.makedirs(work_dir, exist_ok=True)
    list_path = os.path.join(work_dir, 'concat_list.txt')

    with open(list_path, 'w', encoding='utf-8') as f:
        for p in audio_files:
            abs_p = os.path.abspath(p).replace('\\', '/')
            f.write(f"file '{abs_p}'\n")

    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    cmd = [
        ffmpeg_exe, '-y', '-f', 'concat', '-safe', '0',
        '-i', list_path, '-c', 'copy', output_path
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        err = f"FFmpeg concat failed:\n{result.stderr}\n{result.stdout}"
        print(f"[ERROR] {err}")
        raise RuntimeError(err)

    return output_path


def process_full_dubbing(input_video, srt_filepath, output_video, original_vol=0.0, dub_vol=1.0, voice_gender="female", add_subtitle=True, bgm_audio_path=None, bgm_volume=0.15, forced_gender=None):
    if not srt_filepath or not os.path.exists(srt_filepath):
        raise ValueError("File SRT រកមិនឃើញទេ!")

    subtitles = parse_srt(srt_filepath)
    if not subtitles:
        raise ValueError("File SRT គ្មានទិន្នន័យទេ!")

    temp_dir = os.path.join(os.path.dirname(output_video), "temp_srt_audio")
    os.makedirs(temp_dir, exist_ok=True)

    cleanup_render_cache(temp_dir)
    cleanup_render_cache(os.path.dirname(output_video))

    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

    audio_files = loop.run_until_complete(generate_srt_audios(subtitles, input_video, voice_gender, temp_dir, forced_gender=forced_gender))
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()

    burn_in_srt_path = srt_filepath
    font_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), 'fonts'))
    subtitle_filter = build_subtitle_filter(burn_in_srt_path, font_dir, font_name='Khmer OS Battambang', font_size=22)

    audio_paths = [item['file'] for item in audio_files]
    full_tts_audio = os.path.join(temp_dir, 'full_tts_audio.mp3')
    try:
        concat_audio_files(audio_paths, full_tts_audio, work_dir=temp_dir)
    except Exception as e:
        print(f"[ERROR] Concatenating TTS segments failed: {e}")
        raise

    final_dub_audio = os.path.join(temp_dir, 'final_dub_audio.wav')
    try:
        if bgm_audio_path and os.path.exists(bgm_audio_path):
            video_duration = get_media_duration_seconds(input_video)
            mix_tts_and_bgm(
                full_tts_audio,
                bgm_audio_path,
                final_dub_audio,
                bgm_volume=bgm_volume,
                duration_seconds=video_duration,
            )
        else:
            final_dub_audio = full_tts_audio

        normalized_dub_audio = os.path.join(temp_dir, 'normalized_dub_audio.wav')
        normalize_audio(final_dub_audio, normalized_dub_audio)
        dub_audio_path = normalized_dub_audio
    except Exception as e:
        print(f"[WARN] BGM mix/normalization failed, falling back to TTS-only audio: {e}")
        dub_audio_path = full_tts_audio

    audio_filter = f"[0:a]volume={original_vol}[bg];[1:a]volume={dub_vol}[fg];[bg][fg]amix=inputs=2:duration=first[a]"

    if add_subtitle and burn_in_srt_path and os.path.exists(burn_in_srt_path):
        video_filter = (
            f"[0:v]drawbox=y=ih-140:color=black@0.7:width=iw:height=140:t=fill,"
            f"{subtitle_filter}[v]"
        )
        filter_complex = f"{audio_filter};{video_filter}"
        map_video = '[v]'

        cmd = [ffmpeg_exe, '-y', '-i', input_video, '-i', dub_audio_path, '-filter_complex', filter_complex]
        cmd.extend([
            '-c:v', 'libx264',
            '-pix_fmt', 'yuv420p',
            '-movflags', '+faststart',
            '-c:a', 'aac',
            '-map', map_video,
            '-map', '[a]',
            output_video
        ])
    else:
        cmd = [
            ffmpeg_exe, '-y',
            '-i', input_video,
            '-i', dub_audio_path,
            '-map', '0:v:0',
            '-map', '1:a:0',
            '-c:v', 'copy',
            '-c:a', 'aac',
            '-shortest',
            output_video,
        ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        error_message = f"FFmpeg failed:\n{result.stderr}\n{result.stdout}"
        print(f"[ERROR] {error_message}")
        raise RuntimeError(error_message)

    print(f"[SUCCESS] Dubbing & Subtitling completed: {output_video}")
    return output_video