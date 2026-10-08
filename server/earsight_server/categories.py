"""หมวดเสียงที่ระบบเตือน (อ่านจาก sound_categories.json) และรายชื่อ label ของ YAMNet."""
from __future__ import annotations

import csv
import json
from dataclasses import dataclass
from pathlib import Path

LEVEL_ORDER = {"danger": 0, "attention": 1, "info": 2}


@dataclass(frozen=True)
class SoundCategory:
    id: str
    name_th: str
    level: str  # danger | attention | info
    labels: tuple[str, ...]
    threshold: float
    min_windows: int
    cooldown_s: float


def load_categories(path: str | Path) -> list[SoundCategory]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    cats = []
    for c in data["categories"]:
        if c["level"] not in LEVEL_ORDER:
            raise ValueError(f"{c['id']}: level ต้องเป็น danger/attention/info")
        cats.append(SoundCategory(
            id=c["id"],
            name_th=c["name_th"],
            level=c["level"],
            labels=tuple(c["labels"]),
            threshold=float(c["threshold"]),
            min_windows=int(c.get("min_windows", 1 if c["level"] == "danger" else 2)),
            cooldown_s=float(c.get("cooldown_s", 5)),
        ))
    return cats


def load_class_map(path: str | Path) -> list[str]:
    """display_name ทั้ง 521 คลาส เรียงตาม index ของผลลัพธ์โมเดล."""
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    rows.sort(key=lambda r: int(r["index"]))
    return [r["display_name"] for r in rows]


def missing_labels(categories: list[SoundCategory], labels: list[str]) -> list[str]:
    known = set(labels)
    return [f"{c.id}: {l}" for c in categories for l in c.labels if l not in known]
