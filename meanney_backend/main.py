import os
import re
import json
import asyncio
import importlib.util
import sys
import requests
import subprocess
from pathlib import Path
import pysrt
import edge_tts
from flask import Flask, request, jsonify, send_from_directory
import google.generativeai as genai
import gradio as gr
from typing import Tuple, Optional
import whisper
from googletrans import Translator
from copy import deepcopy
import time  # <--- បន្ថែមការ import នេះចូលទីនេះ
from dotenv import load_dotenv

load_dotenv()

# ដាក់ API Key របស់អ្នកបញ្ចូលផ្ទាល់នៅទីនេះតែម្តង ដើម្បីធានាថាមិនបាត់
os.environ["GEMINI_API_KEY"] = "AQ.Ab8RN6IOGrzro4XrNt3kKAO7DLejc1FqjAcjYMLBd-Ms19poA"

try:
    genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
    print('Configured google.generativeai successfully.')
except Exception as e:
    print(f'Warning: failed to configure google.generativeai: {e}')

import setup_and_process
import llm_service
from processor import get_media_duration_seconds, process_full_dubbing
from flask_cors import CORS
from srt_parser import build_khmer_srt_from_text

# Load Gemini API key from environment or from a JSON file one level above meanney_backend.
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
if not GEMINI_API_KEY:
    base_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(base_dir, '..', '.runtime_api_keys.json')
    if os.path.exists(json_path):
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                keys_data = json.load(f)
                if isinstance(keys_data, list) and len(keys_data) > 0:
                    GEMINI_API_KEY = keys_data[0]
                elif isinstance(keys_data, dict):
                    GEMINI_API_KEY = keys_data.get("gemini_api_key") or keys_data.get("api_key", "")
        except Exception as e:
            print(f"Error reading JSON key: {e}")

if GEMINI_API_KEY:
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        print('Configured google.generativeai from GEMINI_API_KEY or .runtime_api_keys.json')
    except Exception as e:
        print(f'Warning: failed to configure google.generativeai: {e}')
else:
    print('Warning: GEMINI_API_KEY is not set; generative features may be disabled.')

app = Flask(__name__)
CORS(app)

BASE_DIR = Path(__file__).resolve().parent
os.makedirs("outputs/temp_video", exist_ok=True)
AUTO_PROCESS_MODULE_PATH = BASE_DIR / "Auto Process.py"
auto_process_module = None

if AUTO_PROCESS_MODULE_PATH.exists():
    try:
        spec = importlib.util.spec_from_file_location("auto_process_module", AUTO_PROCESS_MODULE_PATH)
        auto_process_module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = auto_process_module
        spec.loader.exec_module(auto_process_module)
    except Exception as exc:
        print(f"Warning: could not load auto process module: {exc}")

@app.route('/api/status', methods=['GET'])
def api_status():
    return jsonify({"status": "running"}), 200


@app.route('/api/dubbing-status', methods=['GET'])
def dubbing_status():
    step_value = DUBBING_STATUS.get("step", "0/0")
    try:
        current_step = int(str(step_value).split('/')[0])
    except (TypeError, ValueError):
        current_step = 0

    return jsonify({
        "status": DUBBING_STATUS.get("status", "idle"),
        "progress": DUBBING_STATUS.get("progress", 0),
        "current_step": current_step,
        "percent": float(DUBBING_STATUS.get("progress", 0)),
        "step": step_value,
        "speaker": DUBBING_STATUS.get("speaker", "unknown"),
        "message": DUBBING_STATUS.get("message", "Ready to dub."),
    }), 200

OUTPUTS_DIR = BASE_DIR / "outputs"
TEMP_AUDIO_DIR = OUTPUTS_DIR / "temp_audio"
TEMP_SRT_DIR = OUTPUTS_DIR / "temp_srt_audio"
TEMP_VIDEO_DIR = OUTPUTS_DIR / "temp_video"
CLONE_VOICES_DIR = OUTPUTS_DIR / "clone_voices"

DUBBING_STATUS = {
    "status": "idle",
    "progress": 0,
    "step": "0/0",
    "speaker": "unknown",
    "message": "Ready to dub."
}


def update_dubbing_status(
    status: str,
    progress: int = 0,
    step: Optional[str] = None,
    speaker: Optional[str] = None,
    message: Optional[str] = None,
):
    DUBBING_STATUS["status"] = status
    DUBBING_STATUS["progress"] = progress
    if step is not None:
        DUBBING_STATUS["step"] = step
    if speaker is not None:
        DUBBING_STATUS["speaker"] = speaker
    if message is not None:
        DUBBING_STATUS["message"] = message

TEMP_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
TEMP_SRT_DIR.mkdir(parents=True, exist_ok=True)
TEMP_VIDEO_DIR.mkdir(parents=True, exist_ok=True)
CLONE_VOICES_DIR.mkdir(parents=True, exist_ok=True)

VOICE_MAPPING = {
    "Sreymom": "km-KH-SreymomNeural",
    "Piseth": "km-KH-PisethNeural",
}


def clean_srt_text(raw_text: str) -> str:
    cleaned = re.sub(r'\s*\([^)]*\)', '', raw_text)
    return cleaned.strip()


def save_file_to_temp(uploaded_file, target_dir, filename=None):
    if uploaded_file is None:
        return None
    target_dir.mkdir(parents=True, exist_ok=True)
    final_name = filename or uploaded_file.filename
    target_path = target_dir / final_name
    uploaded_file.save(str(target_path))
    return target_path


def save_srt_content(srt_content: str, target_path):
    target = Path(target_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(srt_content or '', encoding='utf-8')
    return str(target)


def normalize_voice_option(voice_option):
    if not isinstance(voice_option, str):
        return 'auto'
    value = voice_option.strip().lower()
    if value in ['auto', 'auto detect', 'autodetect', 'detect', 'default', '']: 
        return 'auto'
    if value in ['female', 'female only', 'female-only', 'sreymom', 'sreymom only', 'sreymom-only']:
        return 'female'
    if value in ['male', 'male only', 'male-only', 'piseth', 'piseth only', 'piseth-only']:
        return 'male'
    return 'auto'


@app.route('/api/generate-dub', methods=['POST'])
def generate_dub():
    video_path = None
    srt_path = None

    video_file = request.files.get('video')
    srt_file = request.files.get('srt')

    if request.is_json:
        data = request.json or {}
    else:
        data = request.form or {}

    # ទាញយកតម្លៃ forced_gender ឬ voice_option ពីសំណើរបស់ UI
    forced_gender = data.get('forced_gender', data.get('voice_gender', data.get('selected_voice', 'auto')))
    voice_option = normalize_voice_option(forced_gender)
    target_voice = data.get('target_voice', forced_gender)
    if target_voice:
        voice_option = normalize_voice_option(target_voice)

    video_mode = data.get('voice_mode', 'Standard')
    source_lang = data.get('source_lang', 'English')

    if video_file:
        video_path = TEMP_VIDEO_DIR / video_file.filename
        video_file.save(str(video_path))
    elif data.get('video_path'):
        candidate_video = Path(data['video_path'])
        resolved_video = None
        lookup_paths = []
        if candidate_video.is_absolute():
            lookup_paths.append(candidate_video)
        else:
            lookup_paths.extend([
                BASE_DIR / candidate_video,
                BASE_DIR.parent / candidate_video,
                candidate_video,
                Path(candidate_video.as_posix().lstrip('/')),
            ])
        for path in lookup_paths:
            if path.exists():
                resolved_video = path
                break
        if resolved_video is None:
            return jsonify({"status": "error", "message": "Video path not found."}), 400
        video_path = resolved_video

    if srt_file:
        srt_path = TEMP_SRT_DIR / srt_file.filename
        srt_file.save(str(srt_path))
    elif data.get('srt_path'):
        candidate_srt = Path(data['srt_path'])
        resolved_srt = None
        lookup_paths = []
        if candidate_srt.is_absolute():
            lookup_paths.append(candidate_srt)
        else:
            lookup_paths.extend([
                BASE_DIR / candidate_srt,
                BASE_DIR.parent / candidate_srt,
                candidate_srt,
                Path(candidate_srt.as_posix().lstrip('/')),
            ])
        for path in lookup_paths:
            if path.exists():
                resolved_srt = path
                break
        if resolved_srt is None:
            return jsonify({"status": "error", "message": "SRT path not found."}), 400
        srt_path = resolved_srt
    elif video_file:
        if not video_path:
            return jsonify({"status": "error", "message": "Video file processing failed."}), 500

        _, translated_subtitle = auto_process_video(str(video_path), source_lang, voice_option)
        srt_path = TEMP_SRT_DIR / f"{Path(video_path).stem}_auto.srt"
        try:
            duration = get_media_duration_seconds(str(video_path))
        except Exception:
            duration = None
        build_khmer_srt_from_text(translated_subtitle, duration, srt_path)
    else:
        return jsonify({"status": "error", "message": "Missing srt file and video file"}), 400

    if not srt_path.exists():
        return jsonify({"status": "error", "message": "រកមិនឃើឃើញឯកសារ SRT ទេ។"}), 400

    output_video_path = OUTPUTS_DIR / f"dubbed_output_{int(time.time())}.mp4"

    try:
        process_full_dubbing(
            input_video=str(video_path) if video_path else None,
            srt_filepath=str(srt_path),
            output_video=str(output_video_path),
            original_vol=0.0,
            dub_vol=1.0,
            voice_gender=voice_option,
            add_subtitle=True,
            bgm_audio_path=None,
            bgm_volume=0.15,
            forced_gender=forced_gender,
        )
    except Exception as e:
        update_dubbing_status(
            status='error',
            progress=0,
            message=str(e),
        )
        return jsonify({"status": "error", "message": str(e)}), 500

    update_dubbing_status(
        status="completed",
        progress=100,
        step="Completed",
        message="Dubbing completed successfully.",
    )

    return jsonify({
        "status": "completed",
        "video_url": f"http://127.0.0.1:5000/outputs/{Path(output_video_path).name}",
        "message": "Dubbing បានជោគជ័យ!"
    })


@app.route('/api/process-video', methods=['POST', 'OPTIONS'])
def process_video():
    if request.method == 'OPTIONS':
        return jsonify({"status": "ok"}), 200

    try:
        data = request.get_json(silent=True) or {}

        if auto_process_module and hasattr(auto_process_module, 'process_video'):
            if data.get('source_lang') or data.get('target_voice') or data.get('video_path'):
                return auto_process_module.process_video()


        def resolve_existing_path(candidate: Optional[str]) -> Optional[str]:
            if not candidate:
                return None
            candidate_path = Path(candidate)
            lookup_paths = []
            if candidate_path.is_absolute():
                lookup_paths.append(candidate_path)
            else:
                lookup_paths.extend([
                    BASE_DIR / candidate_path,
                    BASE_DIR.parent / candidate_path,
                    candidate_path,
                ])
            for path in lookup_paths:
                if path.exists():
                    return str(path)
            return None

        video_path_input = data.get('video_path')

        if video_path_input:
            input_video = str(BASE_DIR / video_path_input)
        else:
            input_video = str(BASE_DIR / 'outputs' / 'dubbed_output.mp4')

        if not Path(input_video).exists():
            upload_dir = BASE_DIR / 'uploads'
            upload_candidates = [
                p for p in upload_dir.iterdir()
                if p.is_file() and p.suffix.lower() in {'.mp4', '.mov', '.avi'}
            ]
            if upload_candidates:
                input_video = str(max(upload_candidates, key=lambda p: p.stat().st_mtime))
            else:
                input_video = str(BASE_DIR / 'outputs' / 'dubbed_output.mp4')

        logo_path = resolve_existing_path(data.get('logo_path'))
        if logo_path is None:
            candidate_logo_paths = [
                BASE_DIR / 'assets' / 'logo.png',
                BASE_DIR / 'uploads' / 'logo.png',
                BASE_DIR / 'uploads' / 'Mean_logo.png',
                BASE_DIR.parent / 'assets' / 'logo.png',
            ]
            logo_path = next((str(p) for p in candidate_logo_paths if p.exists()), None)
            if logo_path is None:
                raise FileNotFoundError('No valid logo image found for watermarking.')

        output_filename = f"watermarked_{int(time.time())}.mp4"
        output_path = str(OUTPUTS_DIR / output_filename)
        OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)

        cmd = [
            'ffmpeg', '-y', 
            '-i', input_video, 
            '-i', logo_path,
            '-filter_complex', '[0:v][1:v]overlay=30:30[outv]',
            '-map', '[outv]',
            '-map', '0:a?',
            '-c:v', 'libx264',
            '-crf', '23',
            '-preset', 'fast',
            '-c:a', 'copy',
            output_path
        ]
        
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode != 0:
            print("FFmpeg Error:", result.stderr)
            return jsonify({"status": "error", "message": result.stderr}), 500

        return jsonify({
            "status": "success",
            "message": "Watermark applied successfully!",
            "video_url": f"http://127.0.0.1:5000/outputs/{output_filename}"
        }), 200
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route('/api/translate-srt', methods=['POST'])
def translate_srt():
    srt_file = request.files.get('srt')
    srt_content = None
    if not srt_file:
        srt_content = request.form.get('srt_content')
    if not srt_file and not srt_content:
        return jsonify({"status": "error", "message": "Missing SRT file or SRT content."}), 400

    data = request.json or request.form or {}
    voice_option = normalize_voice_option(data.get('voice_option', data.get('selected_voice', data.get('voice_gender', 'auto'))))

    srt_path = None
    if srt_file:
        srt_path = save_file_to_temp(srt_file, TEMP_SRT_DIR)
    else:
        srt_path = TEMP_SRT_DIR / 'translated_input.srt'
        srt_path.write_text(srt_content or '', encoding='utf-8')

    try:
        subs = pysrt.open(str(srt_path), encoding='utf-8')
        translated_items = []
        for sub in subs:
            text = clean_srt_text(sub.text).strip()
            translated_items.append(llm_service.translate_to_khmer(text, voice_option=voice_option) if text else text)

        output_filename = f"{Path(srt_path).stem}_khmer.srt"
        output_path = OUTPUTS_DIR / output_filename
        translated_subs = pysrt.SubRipFile()
        for index, sub in enumerate(subs, start=1):
            translated_text = translated_items[index - 1] if index - 1 < len(translated_items) else ''
            translated_subs.append(pysrt.SubRipItem(index=index, start=sub.start, end=sub.end, text=translated_text))
        translated_subs.save(str(output_path), encoding='utf-8')

        return jsonify({
            "status": "completed",
            "message": "SRT translated to Khmer.",
            "srt_url": f"http://127.0.0.1:5000/outputs/{output_filename}",
        })
    except Exception as exc:
        return jsonify({"status": "error", "message": str(exc)}), 500


@app.route('/api/clone-voices', methods=['GET'])
def clone_voices():
    voices = [
        {'id': 'Malyn.wav', 'name': 'Malyn', 'gender': 'female'},
        {'id': 'Mean.wav', 'name': 'Mean', 'gender': 'male'},
    ]

    if CLONE_VOICES_DIR.exists():
        for voice_file in sorted(CLONE_VOICES_DIR.iterdir()):
            if not voice_file.is_file():
                continue
            voices.append({
                'id': voice_file.name,
                'name': Path(voice_file.stem).stem.replace('_', ' '),
                'gender': 'unknown',
            })

    return jsonify({'status': 'completed', 'voices': voices})


@app.route('/api/upload-clone-voice', methods=['POST'])
def upload_clone_voice():
    voice_file = request.files.get('file')
    if not voice_file:
        return jsonify({'status': 'error', 'message': 'Missing voice file'}), 400

    voice_name = (request.form.get('voice_name') or 'clone_voice').strip()
    voice_gender = (request.form.get('voice_gender') or 'auto').strip()
    original_name = Path(voice_file.filename or 'clone_voice.wav').name
    ext = Path(original_name).suffix or '.wav'
    safe_name = re.sub(r'[^A-Za-z0-9._-]+', '_', voice_name) or 'clone_voice'
    voice_id = f'{safe_name}{ext}'
    saved_path = CLONE_VOICES_DIR / voice_id
    voice_file.save(str(saved_path))

    return jsonify({
        'status': 'completed',
        'voice_id': voice_id,
        'name': voice_name,
        'gender': voice_gender,
    })


@app.route('/outputs/<path:filename>')
def serve_output(filename):
    return send_from_directory(str(OUTPUTS_DIR), filename)


print("Loading Whisper model for Gradio...")
whisper_model = whisper.load_model("base")
translator_obj = Translator()

def auto_process_video(video_file, source_lang, voice_option) -> Tuple[Optional[str], str]:
    video_path = None
    try:
        if isinstance(video_file, dict):
            video_path = video_file.get("name") or video_file.get("orig_name")
        elif isinstance(video_file, str):
            video_path = video_file
    except Exception:
        video_path = None

    if not video_path:
        return "", "រកមិនឃើញឯកសារវីដេអូឡើយ!"

    try:
        result = whisper_model.transcribe(video_path)
        extracted_text = result.get("text", "")
        translated = translator_obj.translate(extracted_text, dest='km')
        translated_subtitle = translated.text
    except Exception as e:
        translated_subtitle = f"មានកំហុសឆ្គងក្នុងការដំណើរការ: {str(e)}"

    return video_path, translated_subtitle


demo = gr.Interface(
    fn=auto_process_video,
    inputs=[
        gr.Video(label="ជ្រើសរើសវីដេអូ (Pick Video)"),
        gr.Dropdown(choices=["Chinese", "English"], value="English", label="Video Source Language"),
        gr.Radio(choices=["Auto Detect", "Male Only", "Female Only"], value="Auto Detect", label="Auto Process Voice Option"),
    ],
    outputs=[
        gr.Video(label="វីដេអូលទ្ធផល (Output Video)"),
        gr.Textbox(label="ចំណងជើងរងភាសាខ្មែរ (Khmer Subtitles)"),
    ],
    title="Auto Process Video Translation with AI"
)


if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)