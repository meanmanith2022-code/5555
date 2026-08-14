Gradio demo for MeanNey backend

This folder contains a small Gradio demo that shows a placeholder auto-processing pipeline.

Setup (Windows):

```powershell
cd meanney_backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python gradio_demo.py
```

Setup (Unix/macOS):

```bash
cd meanney_backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python gradio_demo.py
```

The demo launches a local web UI. By default the demo is started without a public share link. To enable a public link, set `share=True` in `gradio_demo.py`.
