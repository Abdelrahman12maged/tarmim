import asyncio
import os
import subprocess
import math
import wave
import struct
import edge_tts
from PIL import Image, ImageDraw, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display
import imageio_ffmpeg

WORK_DIR = r"C:\Users\Abdo\.gemini\antigravity-ide\brain\b650cdaa-3bbe-4c05-b348-7719b43a4803\scratch\video_project"
os.makedirs(WORK_DIR, exist_ok=True)

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
RAW_VIDEO = r"C:\Users\Abdo\Desktop\tarmim_raw_recording.mp4"
FINAL_VIDEO = r"C:\Users\Abdo\Desktop\tarmim_showcase_final.mp4"

SEGMENTS = [
    {
        "id": "seg1",
        "start": 0.5,
        "end": 7.5,
        "title": "نظام تِرميم الذكي",
        "subtitle": "الحل المتكامل لإدارة مراكز وورش الصيانة",
        "text": "نظام تِرميم، الحل الذكي المتكامل لإدارة مراكز وورش الصيانة بكل سهولة واحترافية.",
    },
    {
        "id": "seg2",
        "start": 8.0,
        "end": 21.0,
        "title": "إدارة التذاكر وحالة الأجهزة",
        "subtitle": "متابعة فورية وسريعة مع أزرار تواصل مباشرة",
        "text": "لوحة تحكم فورية لمتابعة كافة الأجهزة المستلمة، مع إمكانية البحث السريع والتواصل الفوري مع العملاء عبر واتساب أو اتصال.",
    },
    {
        "id": "seg3",
        "start": 22.0,
        "end": 41.0,
        "title": "استلام جهاز جديد وفحص العطل",
        "subtitle": "تسجيل سريع وتحديد التكاليف والعربون",
        "text": "استلام الأجهزة بخطوات بسيطة: اختيار الماركة، تسجيل وصف العطل، وتحديد التكاليف والعربون.",
    },
    {
        "id": "seg4",
        "start": 42.0,
        "end": 57.0,
        "title": "توثيق صور فحص الجهاز",
        "subtitle": "تصوير حالة الجهاز والشاشة لمنع أي خلاف",
        "text": "وتوثيق حالة الجهاز والشاشة بالصور فوراً عبر الكاميرا ورفعها سحابياً لضمان الشفافية التامة وحفظ حق الورشة.",
    },
    {
        "id": "seg5",
        "start": 58.0,
        "end": 73.0,
        "title": "إشعار واتساب التلقائي",
        "subtitle": "إرسال إيصال رسمي ورابط تتبع مباشر للعميل",
        "text": "بمجرد الحفظ، يُرسل إيصال استلام رسمي ورابط تتبع مباشر إلى واتساب العميل تلقائياً بنقرة زر واحدة وبأمان تام.",
    },
    {
        "id": "seg6",
        "start": 74.0,
        "end": 96.0,
        "title": "بوابة تتبع العميل المباشرة",
        "subtitle": "العميل يتابع مراحل الصيانة والفاتورة لحظياً",
        "text": "يفتح العميل الرابط في أي وقت دون تسجيل دخول، ليتابع مراحل الصيانة لحظة بلحظة وتفاصيل الفاتورة وموقع الورشة.",
    },
    {
        "id": "seg7",
        "start": 97.0,
        "end": 120.0,
        "title": "تحديث الحالة والمصنعية",
        "subtitle": "جاهز للاستلام وتوثيق صور ما بعد الإصلاح",
        "text": "تحديث حالة الجهاز بكل سلاسة إلى جاهز للاستلام، مع تحديد التكلفة وأجرة المصنعية وتوثيق صور الجهاز بعد الصيانة والإصلاح.",
    },
    {
        "id": "seg8",
        "start": 121.0,
        "end": 140.0,
        "title": "معرض صور الجهاز للعميل",
        "subtitle": "صور الاستلام وصور ما بعد الصيانة مع التكبير",
        "text": "صفحة التتبع تتيح للعميل استعراض صور جهازه قبل وبعد الصيانة بدقة عالية مع ميزة التكبير التفاعلي لضمان المصداقية.",
    },
    {
        "id": "seg9",
        "start": 141.0,
        "end": 155.0,
        "title": "الداشبورد والتقارير المالية",
        "subtitle": "أرباح الورشة وحركة الخزينة وأموال الرف المعلقة",
        "text": "لوحة تحكم مالية ذكية ترصد صافي أرباح الورشة، حركة الخزينة، والمبالغ المعلقة على الرف لحظة بلحظة.",
    },
    {
        "id": "seg10",
        "start": 155.5,
        "end": 160.0,
        "title": "تِرميم — إدارة ورشتك بذكاء",
        "subtitle": "سهولة، أمان، واحترافية متكاملة",
        "text": "تِرميم، ورشتك في جيبك بأعلى احترافية وأمان.",
    },
]

async def generate_voice_clips():
    print("--- 1. Generating Arabic Voiceover Clips ---")
    for seg in SEGMENTS:
        wav_path = os.path.join(WORK_DIR, f"{seg['id']}.mp3")
        if os.path.exists(wav_path):
            continue
        print(f"Generating voice for {seg['id']}...")
        communicate = edge_tts.Communicate(seg["text"], "ar-EG-ShakirNeural", rate="+3%")
        await communicate.save(wav_path)
    print("Voice clips generated successfully!")

def generate_banners():
    print("--- 2. Generating Glassmorphism Overlay Banners ---")
    font_title = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 25)
    font_sub = ImageFont.truetype("C:/Windows/Fonts/tahoma.ttf", 17)

    for seg in SEGMENTS:
        img = Image.new("RGBA", (720, 1600), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # Draw modern solid floating card below status bar: x=18, y=52, w=684, h=104
        card_box = [18, 52, 702, 156]
        # Fully opaque dark slate with emerald glowing border
        draw.rounded_rectangle(card_box, radius=22, fill=(15, 23, 42, 255), outline=(20, 184, 166, 255), width=2)

        # Title (emerald/teal)
        t1 = get_display(arabic_reshaper.reshape(seg["title"]))
        draw.text((360, 88), t1, font=font_title, fill=(45, 212, 191, 255), anchor="mm")

        # Subtitle (crisp white)
        t2 = get_display(arabic_reshaper.reshape(seg["subtitle"]))
        draw.text((360, 124), t2, font=font_sub, fill=(241, 245, 249, 255), anchor="mm")

        out_path = os.path.join(WORK_DIR, f"banner_{seg['id']}.png")
        img.save(out_path)
    print("All banners generated!")

def generate_ambient_music(duration_sec=161, sample_rate=44100):
    print("--- 3. Generating Ambient Background Music Track ---")
    wav_path = os.path.join(WORK_DIR, "ambient_music.wav")
    total_samples = int(duration_sec * sample_rate)
    
    # Warm chords progression: E minor -> G major -> D major -> C major
    chords = [
        [164.81, 196.00, 246.94, 329.63], # Em
        [196.00, 246.94, 293.66, 392.00], # G
        [146.83, 220.00, 293.66, 369.99], # D
        [130.81, 196.00, 261.63, 329.63], # C
    ]
    chord_len = int(sample_rate * 4.0)

    with wave.open(wav_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)

        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            chord_idx = (i // chord_len) % len(chords)
            chord = chords[chord_idx]

            # Soft sine waves with gentle tremolo & fade in/out
            val = 0.0
            for f in chord:
                val += math.sin(2.0 * math.pi * f * t)
            val /= len(chord)

            # Soft lfo tremolo (2 Hz)
            tremolo = 0.8 + 0.2 * math.sin(2.0 * math.pi * 1.5 * t)
            val *= tremolo

            # Master volume: very soft (-24dB, around 0.06 amplitude)
            val *= 0.06

            # Fade in first 2s, fade out last 3s
            if t < 2.0:
                val *= (t / 2.0)
            elif t > duration_sec - 3.0:
                val *= ((duration_sec - t) / 3.0)

            sample_int = int(max(-32767, min(32767, val * 32767)))
            samples.append(struct.pack("<h", sample_int))

        wf.writeframes(b"".join(samples))
    print("Ambient music generated!")
    return wav_path

def build_master_audio():
    print("--- 4. Mixing Master Voiceover Audio Track ---")
    # Use ffmpeg adelay and amix to place each clip at its exact start timestamp
    inputs = []
    filter_delays = []
    
    for i, seg in enumerate(SEGMENTS):
        clip_path = os.path.join(WORK_DIR, f"{seg['id']}.mp3")
        inputs.extend(["-i", clip_path])
        delay_ms = int(seg["start"] * 1000)
        filter_delays.append(f"[{i}]adelay={delay_ms}|{delay_ms}[a{i}]")
    
    mix_inputs = "".join([f"[a{i}]" for i in range(len(SEGMENTS))])
    filter_complex = f"{';'.join(filter_delays)};{mix_inputs}amix=inputs={len(SEGMENTS)}:dropout_transition=0:normalize=0[vo]"

    master_vo = os.path.join(WORK_DIR, "master_voiceover.wav")
    cmd = [FFMPEG, "-y"] + inputs + ["-filter_complex", filter_complex, "-map", "[vo]", master_vo]
    subprocess.run(cmd, check=True)
    print("Master voiceover mixed successfully!")
    return master_vo

def render_final_video():
    print("--- 5. Rendering Final Master Video ---")
    music_wav = generate_ambient_music(duration_sec=160.5)
    master_vo = build_master_audio()

    # Build FFmpeg filter complex for overlays:
    # Inputs:
    # [0:v] raw video
    # [1:a] master voiceover
    # [2:a] ambient music
    # [3..12] banner images
    cmd = [
        FFMPEG, "-y",
        "-t", "160.0", # Trim last 2 seconds of status bar pull
        "-i", RAW_VIDEO,
        "-i", master_vo,
        "-i", music_wav,
    ]

    for seg in SEGMENTS:
        cmd.extend(["-i", os.path.join(WORK_DIR, f"banner_{seg['id']}.png")])

    # Construct overlay filter graph:
    # [0:v] -> overlay 1 -> overlay 2 -> ... -> [v_out]
    overlay_filters = []
    current_stream = "0:v"
    
    for idx, seg in enumerate(SEGMENTS):
        input_idx = 3 + idx
        next_stream = f"v_ov_{idx}" if idx < len(SEGMENTS) - 1 else "v_final"
        # Enable banner between seg['start'] and seg['end']
        cond = f"between(t,{seg['start']},{seg['end']})"
        overlay_filters.append(f"[{current_stream}][{input_idx}:v]overlay=0:0:enable='{cond}'[{next_stream}]")
        current_stream = next_stream

    # Audio mix filter: voiceover (1.3x) + background music (0.25x)
    audio_filter = "[1:a]volume=1.3[vo];[2:a]volume=0.22[bg];[vo][bg]amix=inputs=2:duration=first:dropout_transition=2[a_final]"

    full_filter = ";".join(overlay_filters) + ";" + audio_filter

    cmd.extend([
        "-filter_complex", full_filter,
        "-map", f"[{current_stream}]",
        "-map", "[a_final]",
        "-c:v", "libx264",
        "-preset", "faster",
        "-crf", "22",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        FINAL_VIDEO,
    ])

    print("Running master render encode...")
    subprocess.run(cmd, check=True)
    print("FINAL VIDEO RENDERED SUCCESSFULLY!")
    print(f"Output Path: {FINAL_VIDEO}")

if __name__ == "__main__":
    asyncio.run(generate_voice_clips())
    generate_banners()
    render_final_video()
