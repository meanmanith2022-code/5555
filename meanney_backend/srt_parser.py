from pathlib import Path
import pysrt
import re

def build_khmer_srt_from_text(text, duration_seconds, output_path):
    """Create a simple SRT subtitle file from Khmer text using the video duration."""
    text_value = str(text or '').strip()
    if not text_value:
        text_value = 'Subtitle'

    duration_ms = 0
    if duration_seconds is not None:
        try:
            duration_ms = max(1, int(round(float(duration_seconds) * 1000)))
        except (TypeError, ValueError):
            duration_ms = 5000

    if duration_ms <= 0:
        duration_ms = 5000

    def format_timestamp(ms):
        hours, remainder = divmod(ms, 3_600_000)
        minutes, remainder = divmod(remainder, 60_000)
        seconds, millis = divmod(remainder, 1000)
        return f"{hours:02d}:{minutes:02d}:{seconds:02d},{millis:03d}"

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    content = (
        "1\n"
        f"{format_timestamp(0)} --> {format_timestamp(duration_ms)}\n"
        f"{text_value}\n\n"
    )
    output.write_text(content, encoding='utf-8')
    return str(output)