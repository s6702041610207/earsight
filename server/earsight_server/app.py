"""เครื่องแม่ข่าย EarSight: รับคลิปเสียงจากกล่อง → AI จำแนก → สร้างการแจ้งเตือน.

กติกาความเป็นส่วนตัว: เสียงอยู่ในหน่วยความจำระหว่างประมวลผลเท่านั้น ไม่บันทึกลงดิสก์
ประวัติเก็บแค่ ชื่อเสียง ห้อง เวลา และความมั่นใจ
"""
from __future__ import annotations

import json
import time
from collections import deque
from dataclasses import asdict, dataclass
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import HTMLResponse

from .audio import BadAudio, decode_wav, split_windows
from .categories import SoundCategory, missing_labels
from .classifier import Classifier
from .detector import Detector, Hit

MAX_CLIP_BYTES = 2_000_000  # ~60 วินาทีที่ 16 kHz 16 บิต — กันไฟล์ใหญ่ผิดปกติ
DOOR_SENSOR_ID = "knock"  # หมวดที่เซนเซอร์สั่นที่ประตูแจ้งตรง ไม่ผ่าน AI


@dataclass
class Event:
    id: int
    time: float
    device: str
    room: str
    category_id: str
    name_th: str
    level: str
    confidence: float
    source: str  # "ai" หรือ "door_sensor"
    top_label: str = ""


class EventStore:
    def __init__(self, log_path: Path | None, keep: int = 200):
        self._events: deque[Event] = deque(maxlen=keep)
        self._next = 1
        self._log = log_path

    def add(self, **kw) -> Event:
        e = Event(id=self._next, time=time.time(), **kw)
        self._next += 1
        self._events.append(e)
        if self._log:
            with open(self._log, "a", encoding="utf-8") as f:
                f.write(json.dumps(asdict(e), ensure_ascii=False) + "\n")
        return e

    def after(self, last_id: int) -> list[Event]:
        return [e for e in self._events if e.id > last_id]


def create_app(
    classifier: Classifier,
    categories: list[SoundCategory],
    labels: list[str],
    log_path: Path | None = None,
) -> FastAPI:
    bad = missing_labels(categories, labels)
    if bad:
        raise ValueError("label ไม่ตรงกับ yamnet_class_map.csv: " + ", ".join(bad))

    app = FastAPI(title="EarSight server")
    detector = Detector(categories, labels)
    store = EventStore(log_path)
    devices: dict[str, dict] = {}
    by_id = {c.id: c for c in categories}

    def seen(device: str, room: str, **extra):
        devices[device] = {"device": device, "room": room, "last_seen": time.time(), **extra}

    def record(device: str, room: str, hit: Hit, source: str) -> Event:
        c = hit.category
        return store.add(device=device, room=room, category_id=c.id, name_th=c.name_th,
                         level=c.level, confidence=round(hit.confidence, 3),
                         source=source, top_label=hit.top_label)

    @app.post("/api/clip")
    async def clip(request: Request, device: str = Query("box1"), room: str = Query("ห้อง 1")):
        """กล่องส่งคลิป WAV มาใน body (Content-Type อะไรก็ได้)."""
        body = await request.body()
        if len(body) > MAX_CLIP_BYTES:
            raise HTTPException(413, "คลิปใหญ่เกินไป")
        t0 = time.perf_counter()
        try:
            wave = decode_wav(body)
        except BadAudio as e:
            raise HTTPException(400, str(e))
        del body
        windows = split_windows(wave)
        del wave
        scores = [classifier.scores(w) for w in windows]
        del windows  # เสียงหายไปจากหน่วยความจำตรงนี้ เหลือแค่คะแนน
        hits = detector.apply_cooldown(device, detector.analyze(scores))
        events = [record(device, room, h, "ai") for h in hits]
        seen(device, room)
        return {
            "events": [asdict(e) for e in events],
            "top": detector.top(scores),
            "windows": len(scores),
            "ms": round((time.perf_counter() - t0) * 1000),
        }

    @app.post("/api/door")
    def door(device: str = Query("box1"), room: str = Query("ห้อง 1")):
        """เซนเซอร์สั่นที่ประตูจับการเคาะได้ → เตือนทันทีโดยไม่ต้องผ่าน AI."""
        c = by_id.get(DOOR_SENSOR_ID)
        if c is None:
            raise HTTPException(404, f"ไม่มีหมวด '{DOOR_SENSOR_ID}' ใน sound_categories.json")
        hits = detector.apply_cooldown(device, [Hit(c, 1.0, "")])
        seen(device, room)
        return {"events": [asdict(record(device, room, h, "door_sensor")) for h in hits]}

    @app.post("/api/heartbeat")
    def heartbeat(device: str = Query("box1"), room: str = Query("ห้อง 1"), level_db: float | None = None):
        seen(device, room, level_db=level_db)
        return {"ok": True}

    @app.get("/api/events")
    def events(after: int = 0):
        return [asdict(e) for e in store.after(after)]

    @app.get("/api/devices")
    def list_devices():
        now = time.time()
        return [{**d, "online": now - d["last_seen"] < 30} for d in devices.values()]

    @app.get("/api/categories")
    def list_categories():
        return [asdict(c) for c in categories]

    @app.get("/", response_class=HTMLResponse)
    def dashboard():
        return (Path(__file__).parent / "dashboard.html").read_text(encoding="utf-8")

    return app
