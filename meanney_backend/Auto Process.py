from flask import Blueprint, request, jsonify
from dubbing_pipeline import parse_and_translate_srt, generate_tts_segments, build_ffmpeg_dubbing
# Import មុខងារបង្កើត SRT ពីអត្ថបទដែលបងមានស្រាប់
# from path_to_your_srt_generator import build_khmer_srt_from_text 

app = Blueprint('auto_process', __name__)

@app.route('/api/process-video', methods=['POST', 'OPTIONS'])
def process_video():
    if request.method == 'OPTIONS':
        return jsonify({"status": "ok"}), 200
        
    try:
        data = request.json
        video_path = data.get('video_path')
        srt_path = data.get('srt_path')
        extracted_text = data.get('text', 'សួស្តី') # អត្ថបទសម្រាប់ពេលអត់មាន SRT
        output_video_path = data.get('outputs/dubbed_output.mp4', 'outputs/dubbed_output.mp4')
        source_lang = data.get('source_lang', 'Chinese')
        target_voice = data.get('target_voice', 'auto')
        
        if not video_path:
            return jsonify({"status": "error", "message": "Missing video_path"}), 400
            
        # បើសិនជាអត់ទាន់មាន srt_path ទេ យើងបង្កើតវាអូតូពី text និង duration វីដេអូ
        if not srt_path or not os.path.exists(srt_path):
            from processor import get_media_duration_seconds
            duration = get_media_duration_seconds(video_path)
            srt_path = build_khmer_srt_from_text(extracted_text, duration, "temp_srt_audio/auto_generated.srt")

        # ១. បកប្រែ និងវិភាគសំឡេង Segment (Auto Detect Pitch)
        subtitles = parse_and_translate_srt(srt_path, target_lang='km', video_path=video_path)
        
        # ២. បង្កើតឯកសារសំឡេង TTS
        audio_segments = generate_tts_segments(subtitles, voice_gender=target_voice)
        
        # ៣. ច្របាច់បញ្ចូលគ្នាតាមរយៈ FFmpeg Dubbing Pipeline
        build_ffmpeg_dubbing(
            video_path=video_path,
            audio_segments=audio_segments,
            srt_path=srt_path,
            output_video_path=output_video_path,
            voice_gender=target_voice
        )
        
        return jsonify({
            "status": "Success",
            "message": "Auto Process and Voice Dubbing completed successfully!",
            "output_video": output_video_path,
            "target_voice": target_voice
        })
    except Exception as e:
        print(f"Error in process-video: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500