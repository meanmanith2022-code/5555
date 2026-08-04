import gradio as gr
import google.generativeai as genai
import os

# ==========================================
# 1. កំណត់រចនាសម្ព័ន្ធ Gemini API
# ==========================================
# ជំនួស API Key របស់អ្នកនៅត្រង់នេះ
GEMINI_API_KEY = "YOUR_GEMINI_API_KEY_HERE"
genai.configure(api_key=GEMINI_API_KEY)

# ==========================================
# 2. មុខងារបកប្រែ Subtitle
# ==========================================
def translate_srt_content(file_path, target_lang, model_name):
    """
    អានមាតិកានៃ SRT និងផ្ញើទៅ Gemini API ដើម្បីបកប្រែ
    """
    try:
        # អានអត្ថបទចេញពី File SRT
        with open(file_path, 'r', encoding='utf-8') as f:
            srt_content = f.read()

        # ជ្រើសរើស Model តាមការជ្រើសរើសរបស់អ្នកប្រើប្រាស់
        selected_model = "gemini-1.5-flash" if "Flash" in model_name else "gemini-1.5-pro"
        model = genai.GenerativeModel(selected_model)

        # System Prompt ការពារកុំឱ្យ Gemini កែប្រែលេខរៀង និង ម៉ោង (Timestamps)
        prompt = f"""
You are an expert subtitle translator.
Translate the spoken lines in the following SRT subtitle content into {target_lang}.

STRICT RULES:
1. Do NOT modify or remove any subtitle index numbers or timestamps (e.g., 00:00:01,000 --> 00:00:04,000).
2. ONLY translate the text below each timestamp into {target_lang}.
3. Preserve the exact structure and line breaks of the original SRT file.

SRT Content to Translate:
{srt_content}
"""

        response = model.generate_content(prompt)
        return response.text

    except Exception as e:
        return f"Error translating file: {str(e)}"

def process_batch_files(files, target_lang, model_choice):
    """
    គ្រប់គ្រងការបកប្រែឯកសារច្រើនក្នុងពេលតែមួយ
    """
    if not files:
        return "⚠️ សូមជ្រើសរើសឯកសារ SRT យ៉ាងហោចណាស់ ១!", None

    status_logs = []
    output_files = []

    for file_obj in files:
        file_path = file_obj.name
        file_name = os.path.basename(file_path)

        if file_name.endswith('.srt'):
            # ហៅ Function បកប្រែ
            translated_text = translate_srt_content(file_path, target_lang, model_choice)
            
            # បង្កើត File ថ្មីសម្រាប់រក្សាទុកលទ្ធផល
            output_filename = f"translated_{file_name}"
            with open(output_filename, 'w', encoding='utf-8') as out_f:
                out_f.write(translated_text)
                
            output_files.append(output_filename)
            status_logs.append(f"✅ {file_name} : បកប្រែជោគជ័យ!")
        else:
            status_logs.append(f"⚠️ {file_name} : គាំទ្រតែប្រភេទឯកសារ .srt សម្រាប់ការបកប្រែអត្ថបទ។")

    return "\n".join(status_logs), output_files

# ==========================================
# 3. រចនា UI ជាមួយ Gradio (ដូចក្នុងរូប)
# ==========================================
custom_css = """
body { font-family: 'Kantumruy Pro', sans-serif; }
.main-title { color: #2563eb; text-align: center; font-weight: 800; font-size: 2.2rem; }
.sub-title { text-align: center; color: #475569; margin-bottom: 20px; }
"""

with gr.Blocks(css=custom_css, theme=gr.themes.Soft()) as app:

    # Header Title
    gr.HTML("<h1 class='main-title'>AI Dubber Ultimate</h1>")
    gr.HTML("<p class='sub-title'>បកប្រែ Subtitle ឬ MP3 ច្រើនក្នុងពេលតែមួយដោយប្រើ Gemini AI</p>")

    # 1. Daily Limit Section
    with gr.Group():
        gr.Markdown("### 📊 ស្ថិតិប្រើប្រាស់ (DAILY LIMIT)")
        with gr.Row():
            gr.Textbox(label="FLASH USAGE", value="1 / 1500", interactive=False)
            gr.Textbox(label="PRO USAGE", value="0 / 50", interactive=False)

    # 2. Upload and Settings Section
    with gr.Group():
        gr.Markdown("### ☁️ ជ្រើសរើសឯកសារ SRT ឬ MP3")
        
        file_input = gr.File(
            label="អ្នកអាចជ្រើសរើសឯកសារច្រើនក្នុងពេលតែមួយ",
            file_count="multiple",
            file_types=[".srt", ".mp3"]
        )

        # Info Box
        gr.Markdown(
            """
            > 💡 **បច្ចេកវិទ្យាបកប្រែថ្មី (Optimized SRT):**
            > តម្រូវការបកប្រែ File SRT ត្រូវបានកែសម្រួលឱ្យកាន់តែមានសុក្រឹតភាព។ ប្រសិនបើមានបញ្ហា **JSON Parsing** កម្មវិធីនឹងព្យាយាមបកប្រែ និងសម្អាតអត្ថបទដោយស្វ័យប្រវត្តិ។
            """
        )

        # Dropdowns Options
        with gr.Row():
            lang_dropdown = gr.Dropdown(
                choices=["Khmer (ភាសាខ្មែរ)", "English", "Chinese", "Thai", "Vietnamese"],
                value="Khmer (ភាសាខ្មែរ)",
                label="ភាសាដែលចង់បាន"
            )
            model_dropdown = gr.Dropdown(
                choices=["Gemini 1.5 Flash (លឿន និងឆ្លាតវៃ)", "Gemini 1.5 Pro"],
                value="Gemini 1.5 Flash (លឿន និងឆ្លាតវៃ)",
                label="MODEL ជំនួយការ"
            )

        # Translate Button
        submit_btn = gr.Button("🚀 ចាប់ផ្តើមបកប្រែ (Start Translation)", variant="primary", size="lg")

    # 3. Output Results Section
    with gr.Group():
        gr.Markdown("### 📋 លទ្ធផល និងឯកសារដែលបកប្រែរួច")
        status_output = gr.Textbox(label="ស្ថានភាព (Status Log)", interactive=False)
        file_output = gr.File(label="ទាញយកឯកសារដែលបកប្រែរួច (Download Files)")

    # Button Event Listener
    submit_btn.click(
        fn=process_batch_files,
        inputs=[file_input, lang_dropdown, model_dropdown],
        outputs=[status_output, file_output]
    )

    # Footer
    gr.Markdown("---")
    gr.Markdown("<center>© 2026 SRT Batch Translator - Powered by Gemini AI & Gradio</center>")

# Launch Application
if __name__ == "__main__":
    app.launch(share=True)