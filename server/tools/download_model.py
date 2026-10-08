"""ดาวน์โหลดโมเดล YAMNet (ไฟล์เดียวกับแอป) ไปไว้ที่ assets/models/yamnet.tflite

    python tools/download_model.py
"""
from pathlib import Path
from urllib.request import urlretrieve

URLS = [
    "https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/"
    "audio_classification/android/lite-model_yamnet_classification_tflite_1.tflite",
    "https://tfhub.dev/google/lite-model/yamnet/classification/tflite/1?lite-format=tflite",
]
DEST = Path(__file__).resolve().parents[2] / "assets" / "models" / "yamnet.tflite"


def main() -> None:
    if DEST.exists() and DEST.stat().st_size > 1_000_000:
        print(f"มีโมเดลอยู่แล้ว: {DEST}")
        return
    DEST.parent.mkdir(parents=True, exist_ok=True)
    for url in URLS:
        try:
            print(f"กำลังดาวน์โหลด {url[:60]}...")
            urlretrieve(url, DEST)
            if DEST.stat().st_size > 1_000_000:
                print(f"เสร็จแล้ว: {DEST} ({DEST.stat().st_size / 1e6:.1f} MB)")
                return
        except Exception as e:  # noqa: BLE001
            print(f"  ไม่สำเร็จ: {e}")
    raise SystemExit("ดาวน์โหลดไม่ได้ — ดูวิธีอื่นใน CLAUDE.md ข้อ 4")


if __name__ == "__main__":
    main()
