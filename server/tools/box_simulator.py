"""จำลองกล่อง EarSight ด้วยไมค์ของโน้ตบุ๊ก (ใช้ระหว่างรอบอร์ด ESP32)

ตรรกะเดียวกับที่จะใส่ในบอร์ดจริง:
  1. วัดความดังทุก 0.1 วินาที — ไม่อัด ไม่ส่งอะไร
  2. จำเสียงย้อนหลังไว้สั้นๆ ในหน่วยความจำ (ไม่ลงดิสก์) เพื่อไม่ให้หัวเสียงขาด
  3. ดังเกินเสียงพื้นหลัง + ค่าเผื่อ → รวมเป็นคลิปแล้วส่งไปเครื่องแม่ข่าย

วิธีใช้ (เปิดเครื่องแม่ข่ายไว้ก่อน):
    python tools/box_simulator.py                         ฟังไมค์โน้ตบุ๊ก
    python tools/box_simulator.py --room "ห้องนั่งเล่น"
    python tools/box_simulator.py --file เสียงทดสอบ.wav   ส่งไฟล์เสียงแทนไมค์
    python tools/box_simulator.py --door                  จำลองเซนเซอร์ประตูจับการเคาะ
"""
from __future__ import annotations

import argparse
import json
import math
import queue
import sys
import threading
import time
from collections import deque
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from earsight_server.audio import SAMPLE_RATE, to_wav  # noqa: E402

import numpy as np  # noqa: E402

BLOCK = SAMPLE_RATE // 10  # 0.1 วินาที


def post(server: str, path: str, params: dict, body: bytes = b"") -> dict:
    req = Request(f"{server}{path}?{urlencode(params)}", data=body, method="POST",
                  headers={"Content-Type": "audio/wav"})
    with urlopen(req, timeout=15) as r:
        return json.loads(r.read())


def show_result(res: dict) -> None:
    ev = ", ".join(f"{e['name_th']} {e['confidence']:.0%}" for e in res.get("events", []))
    top = ", ".join(f"{n} {p:.0%}" for n, p in res.get("top", []))
    print(f"\n  → AI ได้ยิน: {top}  ({res.get('ms', '?')} ms)")
    print(f"  → แจ้งเตือน: {ev or '-'}")


def db_of(x: np.ndarray) -> float:
    rms = float(np.sqrt(np.mean(x.astype(np.float64) ** 2)))
    return 20 * math.log10(rms + 1e-9)


def run_mic(a: argparse.Namespace, params: dict) -> None:
    try:
        import sounddevice as sd
    except ImportError:
        raise SystemExit("ติดตั้งก่อน: pip install sounddevice")

    blocks: queue.Queue[np.ndarray] = queue.Queue()
    sender: queue.Queue[np.ndarray] = queue.Queue()

    def send_loop():
        while True:
            clip = sender.get()
            try:
                show_result(post(a.server, "/api/clip", params, to_wav(clip)))
            except Exception as e:  # noqa: BLE001
                print(f"\n  ส่งไม่สำเร็จ: {e}")

    threading.Thread(target=send_loop, daemon=True).start()

    pre = deque(maxlen=int(a.pre * 10))
    post_blocks = int(round((a.clip - a.pre) * 10))
    baseline = -60.0
    recording: list[np.ndarray] | None = None
    last_beat = 0.0

    def cb(indata, frames, t, status):
        blocks.put(indata[:, 0].copy())

    print(f"กำลังฟังไมค์... ส่งไปที่ {a.server} ห้อง '{a.room}'  (Ctrl+C เพื่อหยุด)")
    with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype="float32", blocksize=BLOCK, callback=cb):
        while True:
            x = blocks.get()
            db = db_of(x)
            if recording is not None:
                recording.append(x)
                if len(recording) >= len(pre) + post_blocks:
                    sender.put(np.concatenate(recording))
                    recording = None
                    pre.clear()
                continue
            trigger_at = max(baseline + a.margin, a.floor)
            if db > trigger_at:
                print(f"\n  ดัง {db:.0f} dB (เกณฑ์ {trigger_at:.0f}) → อัดคลิป {a.clip:.0f} วินาที")
                recording = list(pre) + [x]
            else:
                baseline = 0.97 * baseline + 0.03 * db  # เรียนรู้เสียงพื้นหลังเฉพาะตอนเงียบ
                pre.append(x)
            bar = "#" * max(0, min(40, int((db + 70) / 70 * 40)))
            print(f"\r  ระดับเสียง {db:6.1f} dB |{bar:<40}| พื้นหลัง {baseline:5.1f}", end="", flush=True)
            if time.time() - last_beat > 10:
                last_beat = time.time()
                try:
                    post(a.server, "/api/heartbeat", {**params, "level_db": round(db, 1)})
                except Exception:  # noqa: BLE001
                    pass


def main() -> None:
    p = argparse.ArgumentParser(description="จำลองกล่อง EarSight")
    p.add_argument("--server", default="http://localhost:8000")
    p.add_argument("--device", default="sim1")
    p.add_argument("--room", default="ห้องทดสอบ")
    p.add_argument("--file", type=Path, help="ส่งไฟล์ WAV แทนการฟังไมค์")
    p.add_argument("--door", action="store_true", help="จำลองเซนเซอร์ประตู")
    p.add_argument("--clip", type=float, default=3.0, help="ความยาวคลิป (วินาที)")
    p.add_argument("--pre", type=float, default=1.0, help="เสียงย้อนหลังก่อนจุดที่ดัง (วินาที)")
    p.add_argument("--margin", type=float, default=15.0, help="ต้องดังกว่าเสียงพื้นหลังกี่ dB")
    p.add_argument("--floor", type=float, default=-45.0, help="ความดังขั้นต่ำ (dBFS) ที่จะเริ่มอัด")
    a = p.parse_args()
    params = {"device": a.device, "room": a.room}

    if a.door:
        res = post(a.server, "/api/door", params)
        print("ส่งแล้ว:", ", ".join(e["name_th"] for e in res["events"]) or "อยู่ในช่วง cooldown")
    elif a.file:
        show_result(post(a.server, "/api/clip", params, a.file.read_bytes()))
    else:
        try:
            run_mic(a, params)
        except KeyboardInterrupt:
            print("\nหยุดแล้ว")


if __name__ == "__main__":
    main()
