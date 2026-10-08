from pathlib import Path

import numpy as np
import pytest
from fastapi.testclient import TestClient

from earsight_server.app import create_app
from earsight_server.audio import HOP, SAMPLE_RATE, WINDOW, BadAudio, decode_wav, split_windows, to_wav
from earsight_server.categories import load_categories, load_class_map, missing_labels
from earsight_server.detector import Detector

SERVER = Path(__file__).resolve().parents[1]
MODELS = SERVER.parent / "assets" / "models"
CATS = load_categories(SERVER / "sound_categories.json")
LABELS = load_class_map(MODELS / "yamnet_class_map.csv")
IDX = {n: i for i, n in enumerate(LABELS)}


def scores(**named: float) -> np.ndarray:
    s = np.zeros(len(LABELS), np.float32)
    for name, p in named.items():
        s[IDX[name.replace("_", " ")]] = p
    return s


class FakeClassifier:
    """แทนโมเดลจริง: คืนคะแนนตามลำดับที่กำหนดไว้ ทีละช่วง."""

    def __init__(self, seq):
        self.seq, self.i = seq, 0

    def scores(self, window):
        s = self.seq[min(self.i, len(self.seq) - 1)]
        self.i += 1
        return s


# ---- หมวดเสียง

def test_class_map_has_521_labels():
    assert len(LABELS) == 521


def test_all_category_labels_exist_in_yamnet():
    assert missing_labels(CATS, LABELS) == []


# ---- เสียง

def test_decode_resamples_stereo_44k_to_mono_16k():
    import io, wave
    n = 44100
    pcm = (np.sin(np.arange(n) / 10) * 10000).astype("<i2")
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(44100)
        w.writeframes(np.repeat(pcm, 2).tobytes())
    x = decode_wav(buf.getvalue())
    assert abs(len(x) - SAMPLE_RATE) <= 1
    assert x.dtype == np.float32 and np.abs(x).max() <= 1


def test_decode_rejects_garbage():
    with pytest.raises(BadAudio):
        decode_wav(b"not a wav file")


def test_split_windows():
    assert len(split_windows(np.zeros(8000, np.float32))) == 1  # สั้น → เติมศูนย์
    three_s = split_windows(np.zeros(3 * SAMPLE_RATE, np.float32))
    assert all(len(w) == WINDOW for w in three_s)
    assert len(three_s) == (3 * SAMPLE_RATE - WINDOW) // HOP + 1


# ---- กติกาการเตือน

def test_danger_fires_on_single_window():
    d = Detector(CATS, LABELS)
    hits = d.analyze([scores(Siren=0.5), scores()])
    assert [h.category.id for h in hits] == ["siren"]


def test_attention_needs_consecutive_windows():
    d = Detector(CATS, LABELS)
    assert d.analyze([scores(Knock=0.6), scores(), scores(Knock=0.6)]) == []
    assert [h.category.id for h in d.analyze([scores(Knock=0.6), scores(Knock=0.5)])] == ["knock"]


def test_below_threshold_is_ignored():
    d = Detector(CATS, LABELS)
    assert d.analyze([scores(Siren=0.1)] * 5) == []


def test_danger_sorted_first():
    d = Detector(CATS, LABELS)
    hits = d.analyze([scores(Knock=0.9, Siren=0.4)] * 2)
    assert [h.category.id for h in hits] == ["siren", "knock"]


def test_cooldown_is_per_device():
    d = Detector(CATS, LABELS)
    hits = d.analyze([scores(Siren=0.5)])
    assert d.apply_cooldown("box1", hits, now=100)
    assert not d.apply_cooldown("box1", hits, now=102)
    assert d.apply_cooldown("box2", hits, now=102)
    assert d.apply_cooldown("box1", hits, now=106)


# ---- API

def client(seq):
    return TestClient(create_app(FakeClassifier(seq), CATS, LABELS))


def test_clip_creates_event_with_room():
    c = client([scores(Doorbell=0.8)])
    r = c.post("/api/clip", params={"device": "b1", "room": "ห้องนอน"},
               content=to_wav(np.zeros(3 * SAMPLE_RATE, np.float32)))
    assert r.status_code == 200
    ev = r.json()["events"]
    assert [(e["category_id"], e["room"], e["source"]) for e in ev] == [("doorbell", "ห้องนอน", "ai")]
    assert c.get("/api/events", params={"after": 0}).json()[0]["name_th"] == "กริ่ง / ออด"
    assert c.get("/api/events", params={"after": ev[0]["id"]}).json() == []
    dev = c.get("/api/devices").json()
    assert dev[0]["room"] == "ห้องนอน" and dev[0]["online"]


def test_quiet_clip_gives_no_event():
    c = client([scores(Silence=0.9)])
    r = c.post("/api/clip", content=to_wav(np.zeros(SAMPLE_RATE, np.float32)))
    assert r.json()["events"] == [] and r.json()["top"][0][0] == "Silence"


def test_bad_clip_is_rejected():
    assert client([scores()]).post("/api/clip", content=b"xx").status_code == 400


def test_door_sensor_bypasses_ai_and_respects_cooldown():
    c = client([scores()])
    first = c.post("/api/door", params={"room": "ประตูหน้า"}).json()["events"]
    assert first[0]["category_id"] == "knock" and first[0]["source"] == "door_sensor"
    assert c.post("/api/door", params={"room": "ประตูหน้า"}).json()["events"] == []


def test_event_log_has_no_audio(tmp_path):
    log = tmp_path / "events.jsonl"
    c = TestClient(create_app(FakeClassifier([scores(Siren=0.9)]), CATS, LABELS, log))
    c.post("/api/clip", content=to_wav(np.random.uniform(-.5, .5, SAMPLE_RATE).astype(np.float32)))
    line = log.read_text(encoding="utf-8").strip()
    assert '"siren"' in line and len(line) < 400  # มีแค่ข้อมูลการแจ้งเตือน


def test_dashboard_served():
    r = client([scores()]).get("/")
    assert r.status_code == 200 and "EarSight" in r.text


# ---- โมเดลจริง (รันเมื่อมีไฟล์ yamnet.tflite เช่นบน GitHub Actions)

@pytest.mark.skipif(not (MODELS / "yamnet.tflite").exists(), reason="ยังไม่ได้ดาวน์โหลดโมเดล")
def test_real_model_runs():
    from earsight_server.classifier import YamnetClassifier
    clf = YamnetClassifier(str(MODELS / "yamnet.tflite"))
    s = clf.scores(np.zeros(WINDOW, np.float32))
    assert s.shape == (521,) and np.isfinite(s).all()
    print("silence →", LABELS[int(np.argmax(s))], clf.shape_info)
    t = np.arange(WINDOW) / SAMPLE_RATE
    siren = 0.5 * np.sin(2 * np.pi * (700 + 400 * np.sin(2 * np.pi * 0.8 * t)) * t)
    s2 = clf.scores(siren.astype(np.float32))
    print("siren-like tone →", [(LABELS[i], round(float(s2[i]), 2)) for i in np.argsort(s2)[::-1][:3]])
