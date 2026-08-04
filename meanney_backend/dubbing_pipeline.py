import os
import re
import asyncio
import subprocess
from deep_translator import GoogleTranslator
from processor import parse_srt as processor_parse_srt, generate_srt_audios, process_full_dubbing
from speaker_detection import detect_speaker_gender

def parse_srt(srt_path):
    return processor_parse_srt(srt_path)

def resolve_segment_voice(audio_path, seg, forced_gender=None):
    """Resolve a voice for one subtitle segment using its speaker hint if available, or pitch detection."""
    return detect_speaker_gender(
        audio_segment_path=audio_path,
        forced_gender=forced_gender,
        speaker_hint=seg.get('speaker_hint') if isinstance(seg, dict) else None,
    )

def generate_tts_segments(subtitles, temp_dir="temp_audio", voice_gender="female", forced_gender=None):
    os.makedirs(temp_dir, exist_ok=True)
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

    return loop.run_until_complete(
        generate_srt_audios(
            subtitles, 
            input_video=None, 
            voice_gender=voice_gender, 
            temp_dir=temp_dir, 
            forced_gender=forced_gender
        )
    )

def build_ffmpeg_dubbing(
    video_path, 
    audio_segments, 
    srt_path, 
    output_video_path, 
    voice_gender="auto", 
    original_vol=0.0, 
    dub_vol=1.0, 
    add_subtitle=True, 
    bgm_audio_path=None, 
    bgm_volume=0.15,
    forced_gender=None
):
    return process_full_dubbing(
        input_video=video_path,
        srt_filepath=srt_path,
        output_video=output_video_path,
        original_vol=original_vol,
        dub_vol=dub_vol,
        voice_gender=voice_gender,
        add_subtitle=add_subtitle,
        bgm_audio_path=bgm_audio_path,
        bgm_volume=bgm_volume,
        forced_gender=forced_gender,
    )

def parse_and_translate_srt(srt_path, target_lang='km', video_path=None, temp_dir="temp_audio"):
    subtitles = []
    translator = GoogleTranslator(source='auto', target=target_lang)
    os.makedirs(temp_dir, exist_ok=True)

    if not os.path.exists(srt_path):
        print(f"❌ រកមិនឃើញ File SRT នៅត្រង់ Path: {srt_path}")
        return subtitles

    with open(srt_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read().strip()

    if not content:
        print("⚠️ File SRT ទទេរ គ្មានទិន្នន័យទេ!")
        return subtitles

    blocks = re.split(r'\n\s*\n', content)
    print(f"🌐 ស្វែងរកឃើញ {len(blocks)} បន្ទាត់។ កំពុងចាប់ផ្តើមបកប្រែ និងវិភាគសំឡេង Segment...")

    for idx, block in enumerate(blocks):
        lines = [line.strip() for line in block.strip().split('\n') if line.strip()]
        if len(lines) >= 2:
            time_line = None
            text_lines = []
            
            for line in lines:
                if '-->' in line:
                    time_line = line
                elif not line.isdigit():
                    text_lines.append(line)
            
            if time_line:
                time_match = re.search(r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})', time_line)
                if time_match:
                    h1, m1, s1, ms1, h2, m2, s2, ms2 = map(int, time_match.groups())
                    start_sec = h1 * 3600 + m1 * 60 + s1 + ms1 / 1000.0
                    end_sec = h2 * 3600 + m2 * 60 + s2 + ms2 / 1000.0
                    
                    original_text = " ".join(text_lines).strip()
                    
                    if original_text:
                        try:
                            translated_text = translator.translate(original_text)
                        except Exception as e:
                            print(f"⚠️ Error បកប្រែបន្ទាត់ទី {idx+1}: {e}")
                            translated_text = original_text 
                    else:
                        continue

                    # 1. កាត់យក File សំឡេងតូច (Segment Audio) ពីវីដេអូដើមសម្រាប់ Auto Detect Pitch
                    segment_audio_path = os.path.join(temp_dir, f"seg_{idx}_{start_sec:.2f}.wav")
                    if video_path and os.path.exists(video_path):
                        duration = max(0.5, end_sec - start_sec)
                        cmd = [
                            "ffmpeg", "-y", "-ss", str(start_sec), "-i", video_path,
                            "-t", str(duration), "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1", segment_audio_path
                        ]
                        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

                    # 2. ហៅមុខងារ detect_speaker_gender ដើម្បីកំណត់រកប្រុស (Piseth) ឬស្រី (Sreymom)
                    detected_gender = 'Sreymom'
                    if os.path.exists(segment_audio_path):
                        detected_gender = detect_speaker_gender(audio_segment_path=segment_audio_path)

                    speaker_voice = 'km-KH-PisethNeural' if detected_gender == 'Piseth' else 'km-KH-SreymomNeural'

                    subtitles.append({
                        'start': start_sec,
                        'end': end_sec,
                        'text': translated_text,
                        'fallback_audio_path': segment_audio_path if os.path.exists(segment_audio_path) else None,
                        'speaker': speaker_voice
                    })

    print(f"✅ បកប្រែ និងបែងចែកសំឡេងប្រុសស្រីអូតូបានសរុប៖ {len(subtitles)} បន្ទាត់!")
    return subtitles