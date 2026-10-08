"""เริ่มเครื่องแม่ข่าย:  python -m earsight_server"""
from __future__ import annotations

import argparse
import socket
from pathlib import Path

import uvicorn

from .app import create_app
from .categories import load_categories, load_class_map
from .classifier import YamnetClassifier

SERVER_DIR = Path(__file__).resolve().parent.parent
MODELS = SERVER_DIR.parent / "assets" / "models"


def lan_ip() -> str:
    """IP ของเครื่องนี้ในวง Wi-Fi บ้าน (เอาไปตั้งในกล่อง)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def main() -> None:
    p = argparse.ArgumentParser(description="EarSight server")
    p.add_argument("--model", default=MODELS / "yamnet.tflite", type=Path)
    p.add_argument("--class-map", default=MODELS / "yamnet_class_map.csv", type=Path)
    p.add_argument("--categories", default=SERVER_DIR / "sound_categories.json", type=Path)
    p.add_argument("--log", default=SERVER_DIR / "events.jsonl", type=Path,
                   help="ไฟล์ประวัติการแจ้งเตือน (ไม่มีเสียง)")
    p.add_argument("--host", default="0.0.0.0")
    p.add_argument("--port", default=8000, type=int)
    a = p.parse_args()

    if not a.model.exists():
        raise SystemExit(f"ไม่พบโมเดล {a.model}\nดาวน์โหลดก่อน: python tools/download_model.py")
    clf = YamnetClassifier(str(a.model))
    app = create_app(clf, load_categories(a.categories), load_class_map(a.class_map), a.log)
    ip = lan_ip()
    print(f"\nโมเดล: {clf.shape_info}")
    print(f"หน้าดูผล:       http://localhost:{a.port}/")
    print(f"ที่อยู่สำหรับกล่อง: http://{ip}:{a.port}/api/clip\n")
    uvicorn.run(app, host=a.host, port=a.port, log_level="warning")


if __name__ == "__main__":
    main()
