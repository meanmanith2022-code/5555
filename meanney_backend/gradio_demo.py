import gradio as gr
import os
from typing import Tuple, Optional


def auto_process_video(video_file, source_lang, voice_option) -> Tuple[Optional[str], str]:
    """
    Placeholder demo pipeline:
    - Accepts an uploaded video (Gradio returns either a filepath or a dict with a "name" key)
    - Returns the (unchanged) output video path and a sample translated subtitle string
    """
    # Resolve gradio-provided value to a filesystem path when possible
    video_path = None
    try:
        if isinstance(video_file, dict):
            # Newer gradio may provide {'name': '/path/to/file'} or {"name": ..., "orig_name": ...}
            video_path = video_file.get("name") or video_file.get("orig_name")
        elif isinstance(video_file, str):
            video_path = video_file
    except Exception:
        video_path = None

    # Log inputs for debugging
    print(f"Auto-process invoked. source_lang={source_lang}, voice_option={voice_option}, video_path={video_path}")

    # Placeholder translated subtitle and output path
    translated_subtitle = "អត្ថបទបកប្រែជាភាសាខ្មែរ (ឧទាហរណ៍)"
    output_video_path = video_path if video_path else ""

    return output_video_path, translated_subtitle


# Gradio UI

demo = gr.Interface(
    fn=auto_process_video,
    inputs=[
        gr.Video(label="ជ្រើសរើសវីដេអូ (Pick Video)"),
        gr.Dropdown(choices=["Chinese (ចិន)", "English"], value="Chinese (ចិន)", label="Video Source Language"),
        gr.Radio(choices=["Auto Detect", "Male Only", "Female Only"], value="Auto Detect", label="Auto Process Voice Option"),
    ],
    outputs=[
        gr.Video(label="វីដេអូលទ្ធផល (Output Video)"),
        gr.Textbox(label="ចំណងជើងរងភាសាខ្មែរ (Khmer Subtitles)"),
    ],
    title="Auto Process Video Translation",
    allow_flagging=False,
)


if __name__ == "__main__":
    # Use local server; set share=True to create a public link if desired
    demo.launch(share=False)
