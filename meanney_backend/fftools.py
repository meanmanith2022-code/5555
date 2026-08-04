import os
import shutil
import subprocess
import json
import argparse
from typing import Any, Dict, Optional


def _resolve_ffmpeg_binary(cmd: str) -> str:
    if shutil.which(cmd):
        return cmd

    try:
        import imageio_ffmpeg
        bundled = imageio_ffmpeg.get_ffmpeg_exe()
        if bundled and os.path.exists(bundled):
            return bundled
    except Exception:
        pass

    raise RuntimeError(f"{cmd} binary not found in PATH or via imageio_ffmpeg. Install FFmpeg and ensure '{cmd}' is available.")


def _ensure_available(cmd: str) -> None:
    _resolve_ffmpeg_binary(cmd)


def escape_ffmpeg_path(path: str) -> str:
    """Normalize a file path for FFmpeg filter syntax on Windows."""
    if not path:
        return path
    return os.path.abspath(path).replace('\\', '/').replace(':', '\\:')


def probe(path: str) -> Dict[str, Any]:
    """Run ffprobe on `path` and return parsed JSON metadata."""
    _ensure_available("ffprobe")
    ffprobe_bin = _resolve_ffmpeg_binary("ffprobe")
    cmd = [ffprobe_bin, "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", path]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"ffprobe failed: {res.stderr}")
    return json.loads(res.stdout or "{}")


def run_ffmpeg(args: list[str], cwd: Optional[str] = None) -> str:
    """Run ffmpeg with the provided argument list and return stdout.

    Example: run_ffmpeg(["-i", "in.mp4", "-c:v", "copy", "out.mp4"])"""
    _ensure_available("ffmpeg")
    ffmpeg_bin = _resolve_ffmpeg_binary("ffmpeg")
    cmd = [ffmpeg_bin, "-y"] + args
    proc = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    if proc.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {proc.stderr}")
    return proc.stdout


def _pick_audio_codec(output_path: str):
    """Choose a safe codec for the target audio container."""
    lower = output_path.lower()
    if lower.endswith('.mp3'):
        return 'libmp3lame', '192k'
    if lower.endswith(('.m4a', '.mp4', '.aac')):
        return 'aac', '192k'
    return 'pcm_s16le', '192k'


def mix_tts_and_bgm(tts_audio_path: str, bgm_audio_path: str, output_audio_path: str, bgm_volume: float = 0.15, duration_seconds: Optional[float] = None):
    """Mix TTS audio with background music using FFmpeg and a resolved ffmpeg binary."""
    _ensure_available("ffmpeg")
    ffmpeg_bin = _resolve_ffmpeg_binary("ffmpeg")
    codec_name, bitrate = _pick_audio_codec(output_audio_path)
    cmd = [
        ffmpeg_bin, '-y',
        '-i', tts_audio_path,
        '-stream_loop', '-1',
        '-i', bgm_audio_path,
        '-filter_complex',
        f"[1:a]volume={bgm_volume}[bgm];[0:a][bgm]amix=inputs=2:duration=first:dropout_transition=2[aout]",
        '-map', '[aout]',
        '-c:a', codec_name,
        '-b:a', bitrate,
    ]
    if duration_seconds is not None:
        cmd.extend(['-t', str(duration_seconds)])
    cmd.append(output_audio_path)
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"ffmpeg mixing failed: {proc.stderr}")
    return output_audio_path


def normalize_audio(input_path: str, output_path: str):
    """Normalize the input audio to a consistent loudness level using FFmpeg."""
    _ensure_available("ffmpeg")
    ffmpeg_bin = _resolve_ffmpeg_binary("ffmpeg")
    codec_name, bitrate = _pick_audio_codec(output_path)
    cmd = [
        ffmpeg_bin, '-y',
        '-i', input_path,
        '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11',
        '-c:a', codec_name,
        '-b:a', bitrate,
        output_path,
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"ffmpeg normalization failed: {proc.stderr}")
    return output_path


def play_video(path: str) -> subprocess.Popen:
    """Launch ffplay to play a media file. Returns the Popen object."""
    _ensure_available("ffplay")
    ffplay_bin = _resolve_ffmpeg_binary("ffplay")
    cmd = [ffplay_bin, "-autoexit", path]
    return subprocess.Popen(cmd)


def _cli_probe(args: argparse.Namespace) -> int:
    try:
        info = probe(args.path)
        print(json.dumps(info, indent=2, ensure_ascii=False))
        return 0
    except Exception as e:
        print(str(e))
        return 2


def _cli_ffmpeg(args: argparse.Namespace) -> int:
    try:
        out = run_ffmpeg(args.ff_args, cwd=args.cwd)
        if out:
            print(out)
        return 0
    except Exception as e:
        print(str(e))
        return 2


def _cli_play(args: argparse.Namespace) -> int:
    try:
        proc = play_video(args.path)
        proc.wait()
        return proc.returncode or 0
    except Exception as e:
        print(str(e))
        return 2


def main() -> int:
    parser = argparse.ArgumentParser(prog="fftools", description="Lightweight FFmpeg helpers for MeanNey backend")
    sub = parser.add_subparsers(dest="cmd")

    p_probe = sub.add_parser("probe", help="Run ffprobe and print metadata as JSON")
    p_probe.add_argument("path", help="Path to media file")
    p_probe.set_defaults(func=_cli_probe)

    p_play = sub.add_parser("play", help="Play media using ffplay")
    p_play.add_argument("path", help="Path to media file")
    p_play.set_defaults(func=_cli_play)

    p_ff = sub.add_parser("ffmpeg", help="Run ffmpeg with provided args")
    p_ff.add_argument("ff_args", nargs=argparse.REMAINDER, help="Arguments for ffmpeg (e.g. -i in.mp4 out.mp4)")
    p_ff.add_argument("--cwd", dest="cwd", help="Working directory for the ffmpeg command", default=None)
    p_ff.set_defaults(func=_cli_ffmpeg)

    parsed = parser.parse_args()
    if not hasattr(parsed, "func"):
        parser.print_help()
        return 1
    return parsed.func(parsed)


if __name__ == "__main__":
    raise SystemExit(main())
