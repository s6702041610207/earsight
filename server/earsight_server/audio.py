"""แปลงไฟล์ WAV ที่กล่องส่งมาเป็นคลื่นเสียง 16 kHz แล้วตัดเป็นช่วงตามที่ YAMNet ต้องการ.

ทำงานในหน่วยความจำเท่านั้น ไม่เขียนเสียงลงดิสก์
"""
from __future__ import annotations

import io
import wave

import numpy as np

SAMPLE_RATE = 16000
WINDOW = 15600  # 0.975 วินาที = ขนาด input ของ YAMNet
HOP = 7800  # เลื่อนครั้งละครึ่งช่วง (~0.49 วินาที)


class BadAudio(ValueError):
    pass


def decode_wav(data: bytes) -> np.ndarray:
    """WAV (PCM 8/16/32 บิต, กี่ช่องก็ได้, sample rate ใดก็ได้) → float32 โมโน 16 kHz ช่วง [-1, 1]."""
    try:
        with wave.open(io.BytesIO(data)) as w:
            ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
            raw = w.readframes(n)
    except (wave.Error, EOFError) as e:
        raise BadAudio(f"ไม่ใช่ไฟล์ WAV ที่อ่านได้: {e}") from e

    if width == 1:
        x = (np.frombuffer(raw, np.uint8).astype(np.float32) - 128) / 128
    elif width == 2:
        x = np.frombuffer(raw, "<i2").astype(np.float32) / 32768
    elif width == 4:
        x = np.frombuffer(raw, "<i4").astype(np.float32) / 2147483648
    else:
        raise BadAudio(f"ไม่รองรับ PCM {width * 8} บิต")
    if ch > 1:
        x = x[: len(x) // ch * ch].reshape(-1, ch).mean(axis=1)
    if rate != SAMPLE_RATE and len(x):
        n_out = int(round(len(x) * SAMPLE_RATE / rate))
        x = np.interp(np.linspace(0, len(x) - 1, n_out), np.arange(len(x)), x).astype(np.float32)
    if len(x) == 0:
        raise BadAudio("ไฟล์เสียงว่าง")
    return x.astype(np.float32)


def split_windows(x: np.ndarray) -> list[np.ndarray]:
    """ตัดเป็นช่วงละ 15600 sample เลื่อนทีละ 7800 (คลิปสั้นกว่า 1 ช่วงจะเติมศูนย์)."""
    if len(x) < WINDOW:
        x = np.pad(x, (0, WINDOW - len(x)))
    return [x[i:i + WINDOW] for i in range(0, len(x) - WINDOW + 1, HOP)]


def to_wav(x: np.ndarray, rate: int = SAMPLE_RATE) -> bytes:
    """float32 [-1, 1] → WAV PCM16 ในหน่วยความจำ (ใช้ในเทสต์และโปรแกรมจำลองกล่อง)."""
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())
    return buf.getvalue()
