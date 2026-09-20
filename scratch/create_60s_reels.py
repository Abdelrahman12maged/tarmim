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

WORK_DIR = r"C:\Users\Abdo\.gemini\antigravity-ide\brain\b650cdaa-3bbe-4c05-b348-7719b43a4803\scratch\reels_60s"
os.makedirs(WORK_DIR, exist_ok=True)

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
RAW_VIDEO = r"C:\Users\Abdo\Desktop\tarmim_raw_recording.mp4"
FINAL_VIDEO = r"C:\Users\Abdo\Desktop\tarmim_showcase_final.mp4"

# Exact cut segments from RAW_VIDEO
# Total video duration targets 58 seconds (perfect for 60s Reels)
SEGMENTS = [
    {
        "id": "reel_01",
        "raw_start": 1.0,
        "raw_end": 5.5,
        "duration": 4.5,
        "title": "نظام تِرميم الذكي",
        "subtitle": "الحل المتكامل لإدارة ورش ومراكز الصيانة",
        "text": "نظام تِرميم، الحل الذكي المتكامل لإدارة ورش ومراكز الصيانة بكل احترافية.",
    },
    {
        "id": "reel_02",
        "raw_start": 9.0,
        "raw_end": 15.0,
        "duration": 6.0,
        "title": "إدارة التذاكر وحالة الأجهزة",
        "subtitle": "متابعة فورية وتواصل مباشر مع العملاء",
        "text": "متابعة فورية لكافة الأجهزة، مع تواصل مباشر مع عملائك عبر واتساب أو اتصال بنقرة زر.",
    },
    {
        "id": "reel_03",
        "raw_start": 23.5,
        "raw_end": 30.0,
        "duration": 6.5,
        "title": "استلام جهاز جديد وفحص العطل",
        "subtitle": "تسجيل سريع لبيانات العميل وموديل الجهاز",
        "text": "استلام الأجهزة بخطوات سريعة: اختيار الماركة، تسجيل العطل، وتحديد التكلفة والعربون.",
    },
    {
        "id": "reel_04",
        "raw_start": 44.0,
        "raw_end": 50.5,
        "duration": 6.5,
        "title": "توثيق صور فحص الجهاز",
        "subtitle": "تصوير حالة الشاشة سحابياً لمنع أي خلاف",
        "text": "توثيق فحص الشاشة وحالة الجهاز بالكاميرا ورفعها سحابياً لضمان الشفافية وحفظ حق الورشة.",
    },
    {
        "id": "reel_05",
        "raw_start": 59.0,
        "raw_end": 65.5,
        "duration": 6.5,
        "title": "إشعار واتساب التلقائي",
        "subtitle": "إرسال إيصال رسمي ورابط تتبع مباشر للعميل",
        "text": "بمجرد الحفظ، يُرسل إيصال استلام رسمي ورابط تتبع مباشر إلى واتساب العميل تلقائياً.",
    },
    {
        "id": "reel_06",
        "raw_start": 122.5,
        "raw_end": 129.5,
        "duration": 7.0,
        "title": "إشعار الجاهزية والتتبع المباشر",
        "subtitle": "العميل يتابع مراحل الصيانة لحظة بلحظة",
        "text": "إشعار فوري عند جاهزية الجهاز، ليفتح العميل رابط التتبع في أي وقت دون تسجيل دخول.",
    },
    {
        "id": "reel_07",
        "raw_start": 134.0,
        "raw_end": 142.0,
        "duration": 8.0,
        "title": "معرض صور الجهاز والفاتورة",
        "subtitle": "صور قبل وبعد الصيانة لتعزيز الثقة والمصداقية",
        "text": "صفحة التتبع تستعرض صور الجهاز قبل وبعد الصيانة والفاتورة لتعزيز ثقة ومصداقية العميل.",
    },
    {
        "id": "reel_08",
        "raw_start": 152.0,
        "raw_end": 158.5,
        "duration": 6.5,
        "title": "الداشبورد والتقارير المالية",
        "subtitle": "أرباح الورشة وحركة الخزينة وأموال الرف",
        "text": "لوحة تحكم مالية ذكية ترصد أرباح ورشتك وحركة الخزينة والمبالغ المعلقة على الرف بدقة.",
    },
    {
        "id": "reel_09",
        "raw_start": 0.5,
        "raw_end": 3.5,
        "duration": 3.0,
        "title": "تِرميم — ورشتك بذكاء",
        "subtitle": "سهولة، أمان، واحترافية متكاملة",
        "text": "تِرميم، ورشتك في جيبك بأعلى احترافية.",
    },
]

async def generate_voice_clips():
    print("--- 1. Generating Fast & Dynamic Arabic Voiceover ---")
    for seg in SEGMENTS:
        mp3_path = os.path.join(WORK_DIR, f"{seg['id']}.mp3")
        wav_path = os.path.join(WORK_DIR, f"{seg['id']}.wav")
        print(f"Generating voice for {seg['id']}...")
        # Rate +6% gives a punchy energetic promo tone without rushing
        communicate = edge_tts.Communicate(seg["text"], "ar-EG-ShakirNeural", rate="+6%")
        await communicate.save(mp3_path)
        # Convert to 44.1kHz wav
        subprocess.run([FFMPEG, "-y", "-i", mp3_path, "-ar", "44100", "-ac", "1", wav_path], capture_output=True, check=True)
    print("All voiceover clips ready!")

def generate_banners():
    print("--- 2. Generating High-Res Clean Banners (Pure Arabic Fonts) ---")
    font_title = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 25)
    font_sub = ImageFont.truetype("C:/Windows/Fonts/tahoma.ttf", 17)

    for seg in SEGMENTS:
        img = Image.new("RGBA", (720, 1600), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # Card box placed below Android notification bar
        card_box = [18, 52, 702, 156]
        # Premium dark slate with emerald glowing border
        draw.rounded_rectangle(card_box, radius=22, fill=(15, 23, 42, 255), outline=(20, 184, 166, 255), width=2)

        # Title in luminous teal/emerald
        t1 = get_display(arabic_reshaper.reshape(seg["title"]))
        draw.text((360, 88), t1, font=font_title, fill=(45, 212, 191, 255), anchor="mm")

        # Subtitle in bright soft white
        t2 = get_display(arabic_reshaper.reshape(seg["subtitle"]))
        draw.text((360, 124), t2, font=font_sub, fill=(241, 245, 249, 255), anchor="mm")

        banner_path = os.path.join(WORK_DIR, f"banner_{seg['id']}.png")
        img.save(banner_path)
    print("All banners generated successfully!")

def cut_and_assemble_video_segments():
    print("--- 3. Cutting Video Segments and Overlaying Banners ---")
    concat_list_path = os.path.join(WORK_DIR, "concat_list.txt")
    with open(concat_list_path, "w", encoding="utf-8") as f:
        for idx, seg in enumerate(SEGMENTS):
            seg_out = os.path.join(WORK_DIR, f"seg_{seg['id']}.mp4")
            banner = os.path.join(WORK_DIR, f"banner_{seg['id']}.png")
            
            # Cut segment and overlay banner
            # Re-encoding ensures exact frame cutting and perfect synchronization
            filter_str = f"[0:v][1:v]overlay=0:0[v]"
            cmd = [
                FFMPEG, "-y",
                "-ss", str(seg["raw_start"]),
                "-to", str(seg["raw_end"]),
                "-i", RAW_VIDEO,
                "-i", banner,
                "-filter_complex", filter_str,
                "-map", "[v]",
                "-c:v", "libx264",
                "-preset", "faster",
                "-crf", "20",
                "-r", "30",
                "-pix_fmt", "yuv420p",
                "-an",
                seg_out
            ]
            print(f"Encoding segment {idx+1}/{len(SEGMENTS)}: {seg['id']} ({seg['duration']}s)...")
            subprocess.run(cmd, check=True)
            f.write(f"file '{seg_out.replace(chr(92), '/')}'\n")

    # Concat all segments into seamless montage video
    print("Concatenating all segments into montage video...")
    montage_video = os.path.join(WORK_DIR, "montage_video.mp4")
    cmd_concat = [
        FFMPEG, "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", concat_list_path,
        "-c", "copy",
        montage_video
    ]
    subprocess.run(cmd_concat, check=True)
    print(f"Montage video completed: {montage_video}")
    return montage_video

def build_master_audio(total_duration):
    print("--- 4. Mixing Master Voiceover Audio Track ---")
    inputs = []
    filter_delays = []
    
    current_time = 0.0
    for i, seg in enumerate(SEGMENTS):
        wav_path = os.path.join(WORK_DIR, f"{seg['id']}.wav")
        inputs.extend(["-i", wav_path])
        # Add slight 0.2s pause at start of each segment
        delay_ms = int((current_time + 0.2) * 1000)
        filter_delays.append(f"[{i}]adelay={delay_ms}|{delay_ms}[a{i}]")
        current_time += seg["duration"]
    
    mix_inputs = "".join([f"[a{i}]" for i in range(len(SEGMENTS))])
    filter_complex = f"{';'.join(filter_delays)};{mix_inputs}amix=inputs={len(SEGMENTS)}:dropout_transition=0:normalize=0[vo]"

    master_vo = os.path.join(WORK_DIR, "master_voiceover.wav")
    cmd = [FFMPEG, "-y"] + inputs + ["-filter_complex", filter_complex, "-map", "[vo]", master_vo]
    subprocess.run(cmd, check=True)
    print("Master voiceover mixed successfully!")
    return master_vo

def generate_ambient_music(duration_sec, sample_rate=44100):
    print(f"--- 5. Generating Dynamic Ambient Music ({duration_sec:.1f}s) ---")
    wav_path = os.path.join(WORK_DIR, "ambient_music.wav")
    total_samples = int(duration_sec * sample_rate)
    
    # Modern uplifting chords progression (Em -> G -> D -> C)
    chords = [
        [164.81, 196.00, 246.94, 329.63], # Em
        [196.00, 246.94, 293.66, 392.00], # G
        [146.83, 220.00, 293.66, 369.99], # D
        [130.81, 196.00, 261.63, 329.63], # C
    ]
    chord_len = int(sample_rate * 3.5) # slightly faster chord shifts for 60s reel

    with wave.open(wav_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)

        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            chord_idx = (i // chord_len) % len(chords)
            chord = chords[chord_idx]

            # Harmonious sine blend
            val = 0.0
            for f in chord:
                val += math.sin(2.0 * math.pi * f * t)
            val /= len(chord)

            # Tremolo
            tremolo = 0.8 + 0.2 * math.sin(2.0 * math.pi * 2.0 * t)
            val *= tremolo

            # Soft background level
            val *= 0.06

            # Fade in 1.5s, fade out 2.5s
            if t < 1.5:
                val *= (t / 1.5)
            elif t > duration_sec - 2.5:
                val *= ((duration_sec - t) / 2.5)

            sample_int = int(max(-32767, min(32767, val * 32767)))
            samples.append(struct.pack("<h", sample_int))

        wf.writeframes(b"".join(samples))
    print("Ambient music generated!")
    return wav_path

def render_final_master(montage_video, master_vo, ambient_music):
    print("--- 6. Rendering Final Reels Master Video ---")
    # Audio filter: boost voiceover, keep subtle ambient music behind
    audio_filter = "[1:a]volume=1.35[vo];[2:a]volume=0.22[bg];[vo][bg]amix=inputs=2:duration=first:dropout_transition=2[a_final]"

    cmd = [
        FFMPEG, "-y",
        "-i", montage_video,
        "-i", master_vo,
        "-i", ambient_music,
        "-filter_complex", audio_filter,
        "-map", "0:v",
        "-map", "[a_final]",
        "-c:v", "libx264",
        "-preset", "faster",
        "-crf", "21",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        "-shortest",
        FINAL_VIDEO
    ]
    subprocess.run(cmd, check=True)
    print("==================================================")
    print("SUCCESS: 60-SECOND REELS VIDEO RENDERED!")
    print(f"Master Video Path: {FINAL_VIDEO}")
    print("==================================================")

async def main():
    total_dur = sum(s["duration"] for s in SEGMENTS)
    print(f"Total planned duration: {total_dur} seconds (~1 minute Reels format)")
    await generate_voice_clips()
    generate_banners()
    montage_video = cut_and_assemble_video_segments()
    master_vo = build_master_audio(total_dur)
    ambient_music = generate_ambient_music(total_dur)
    render_final_master(montage_video, master_vo, ambient_music)

if __name__ == "__main__":
    asyncio.run(main())
