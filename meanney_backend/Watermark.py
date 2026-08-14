import os
import subprocess

def apply_watermark(input_video_path, watermark_image_path, output_video_path, x, y, scale=1.0):
    """
    Apply watermark/logo to video using ffmpeg based on custom (x, y) coordinates and scale.
    """
    if not os.path.exists(input_video_path):
        raise FileNotFoundError(f"Input video not found: {input_video_path}")
    if not os.path.exists(watermark_image_path):
        raise FileNotFoundError(f"Watermark image not found: {watermark_image_path}")

    # Scale the watermark and overlay it at specific x, y coordinates
    # Using ffmpeg overlay filter: overlay=x=...:y=...
    
    filter_complex = (
        f"[1:v]scale=iw*{scale}:ih*{scale}[wm];"
        f"[0:v][wm]overlay={x}:{y}"
    )

    cmd = [
        "ffmpeg",
        "-y",
        "-i", input_video_path,
        "-i", watermark_image_path,
        "-filter_complex", filter_complex,
        "-codec:a", "copy",
        output_video_path
    ]

    try:
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError as e:
        print(f"FFmpeg error: {e.stderr.decode('utf-8')}")
        return False