import os
import torch
import subprocess
import imageio_ffmpeg
import whisper

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

from pydub import AudioSegment

# ==========================================
# ១. ពិនិត្យ និងជ្រើសរើស Device (GPU / CPU)
# ==========================================
def get_device():
    if torch.cuda.is_available():
        gpu_name = torch.cuda.get_device_name(0)
        print(f"✅ រកឃើញ NVIDIA GPU: {gpu_name}")
        print(f"   CUDA Version: {torch.version.cuda}")
        return "cuda"
    else:
        print("⚠️ មិនរកឃើញ GPU ទេ! ប្រព័ន្ធនឹងប្រើប្រាស់ CPU Fallback។")
        return "cpu"

DEVICE = get_device()

# ==========================================
# ២. មុខងារ Demucs (ផ្តាច់សំឡេងចម្រៀង និងសំឡេងនិយាយ)
# ==========================================
def separate_vocals(audio_path, output_dir="output_demucs"):
    """
    បំបែក Vocal និង Background Music ចេញពីគ្នាដោយប្រើ Demucs
    """
    print(f"\n🎵 កំពុងផ្តាច់សំឡេង (Demucs) លើ file: {audio_path}...")
    
    cmd = [
        "demucs",
        "--two-stems", "vocals",  # ផ្តាច់ជា ២ ភាគ៖ vocals និង non-vocals (no_vocals)
        "-d", DEVICE,            # cuda ឬ cpu
        "-o", output_dir,
        audio_path
    ]
    
    try:
        subprocess.run(cmd, check=True)
        print(f"✅ ផ្តាច់សំឡេងជោគជ័យ! File រក្សាទុកនៅ៖ {output_dir}")
    except Exception as e:
        print(f"❌ បរាជ័យក្នុងការផ្តាច់សំឡេង៖ {e}")

# ==========================================
# ៣. មុខងារ FunASR (Speech-to-Text)
# ==========================================
def transcribe_audio(audio_path):
    """
    បម្លែងសំឡេងទៅជា អត្ថបទ (Speech-to-Text) ដោយប្រើ FunASR
    """
    print(f"\n🎙️ កំពុងបម្លែងសំឡេងទៅជាអត្ថបទ (FunASR)...")
    try:
        from funasr import AutoModel
        
        # Load Model (Paraformer Speech Recognition)
        model = AutoModel(
            model="paraformer-zh", 
            vad_model="fsmn-vad", 
            punc_model="ct-punc",
            device=DEVICE
        )
        
        res = model.generate(input=audio_path)
        print("✅ បម្លែងជាអត្ថបទជោគជ័យ៖")
        print(res)
        return res
    except Exception as e:
        print(f"❌ បរាជ័យក្នុងការបម្លែង STT៖ {e}")

# ==========================================
# ៤. មុខងារ FFmpeg (កាត់ត/បម្លែងទម្រង់ Media)
# ==========================================
def convert_or_trim_video(input_file, output_file, start_time=None, duration=None):
    """
    កាត់ត ឬបម្លែង Formats វីដេអូ/សំឡេង ដោយប្រើ FFmpeg
    """
    print(f"\n🎬 កំពុងចាត់ការលើ Video/Audio ជាមួយ FFmpeg...")
    cmd = ["ffmpeg", "-y", "-i", input_file]
    
    if start_time:
        cmd.extend(["-ss", str(start_time)])
    if duration:
        cmd.extend(["-t", str(duration)])
        
    cmd.append(output_file)
    
    try:
        subprocess.run(cmd, check=True)
        print(f"✅ ដំណើរការ FFmpeg រួចរាល់៖ {output_file}")
    except Exception as e:
        print(f"❌ បរាជ័យលើ FFmpeg៖ {e}")


def process_dubbing_full(video_input, srt_subtitles, audio_segments, output_video, original_vol=0.1, dub_vol=1.0):
    """
    1. Build combined Khmer TTS audio by overlaying segments at their start times
    2. Merge combined audio with original video and render subtitles
    """

    outputs_dir = os.path.dirname(os.path.abspath(output_video)) or '.'
    os.makedirs(outputs_dir, exist_ok=True)

    total_duration_ms = 180000
    try:
        probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", video_input], capture_output=True, text=True)
        if probe.returncode == 0:
            dur_s = float(probe.stdout.strip() or 0)
            total_duration_ms = int((dur_s + 1) * 1000)
    except Exception:
        pass

    combined_audio = AudioSegment.silent(duration=total_duration_ms)
    for item in audio_segments:
        seg_file = item.get('file')
        start_time_ms = int(item.get('start', 0) * 1000)
        if seg_file and os.path.exists(seg_file):
            segment = AudioSegment.from_file(seg_file)
            combined_audio = combined_audio.overlay(segment, position=start_time_ms)

    combined_audio_path = os.path.join(outputs_dir, 'full_khmer_audio.mp3')
    combined_audio.export(combined_audio_path, format='mp3')

    srt_clean_path = os.path.abspath(srt_subtitles).replace('\\', '/').replace(':', '\\:')
    base_dir = os.path.dirname(os.path.abspath(__file__))
    fonts_dir = os.path.abspath(os.path.join(base_dir, 'fonts')).replace('\\', '/')

    vf_options = (
        "drawbox=y=ih-160:color=black@0.85:width=iw:height=160:t=fill,"
        f"subtitles='{srt_clean_path}':fontsdir='{fonts_dir}':"
        "force_style='Fontname=Khmer OS Battambang,FontSize=13,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=1,Outline=1.5,Shadow=1,Spacing=1.0,Alignment=2,MarginV=15,Encoding=1'"
    )

    ffmpeg_cmd = [
        "ffmpeg", "-y",
        "-i", video_input,
        "-i", combined_audio_path,
        "-filter_complex",
        f"[0:a]volume={original_vol}[bg];[1:a]volume={dub_vol}[fg];[bg][fg]amix=inputs=2:duration=first[a_out];[0:v]{vf_options}[v_out]",
        "-map", "[v_out]",
        "-map", "[a_out]",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-movflags", "+faststart",
        output_video
    ]

    try:
        subprocess.run(ffmpeg_cmd, check=True)
        print("✅ Dubbing Rendered Successfully!")
    except subprocess.CalledProcessError as e:
        print(f"❌ FFmpeg failed: {e}")
        raise

# ==========================================
# TEST RUN (សាកល្បងដំណើរការ)
# ==========================================
if __name__ == "__main__":
    sample_media = "input_video.mp4"
    
    if os.path.exists(sample_media):
        convert_or_trim_video(sample_media, "extracted_audio.wav")
        separate_vocals("extracted_audio.wav")
        
        vocal_file = "output_demucs/htdemucs/extracted_audio/vocals.wav"
        if os.path.exists(vocal_file):
            transcribe_audio(vocal_file)
    else:
        print(f"\n💡 សូមដាក់ file `{sample_media}` ក្នុង Folder ជាមួយគ្នានេះដើម្បីធ្វើការ Test។")