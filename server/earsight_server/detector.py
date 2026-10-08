"""คะแนนจาก AI → การเตือน (กติกาเดียวกับ detection_engine.dart ของแอป v1).

- เสียงอันตราย: เจอ 1 ช่วงก็เตือน
- เสียงอื่น: ต้องเจอติดกันตาม min_windows (กันเตือนผิด)
- เตือนเสียงเดิมจากกล่องเดิมซ้ำไม่ได้จนกว่าจะพ้น cooldown
"""
from __future__ import annotations

import time
from dataclasses import dataclass

import numpy as np

from .categories import LEVEL_ORDER, SoundCategory


@dataclass(frozen=True)
class Hit:
    category: SoundCategory
    confidence: float
    top_label: str


class Detector:
    def __init__(self, categories: list[SoundCategory], labels: list[str]):
        self.categories = categories
        self.labels = labels
        index = {name: i for i, name in enumerate(labels)}
        self._idx = {c.id: [index[l] for l in c.labels if l in index] for c in categories}
        self._last: dict[tuple[str, str], float] = {}

    def analyze(self, window_scores: list[np.ndarray]) -> list[Hit]:
        """หาเสียงที่ผ่านเกณฑ์ในคลิปหนึ่ง (ยังไม่คิด cooldown)."""
        hits = []
        for c in self.categories:
            idx = self._idx[c.id]
            if not idx:
                continue
            streak, best, best_label = 0, 0.0, ""
            fired = False
            for s in window_scores:
                j = max(idx, key=lambda k: s[k])
                p = float(s[j])
                if p >= c.threshold:
                    streak += 1
                    if p > best:
                        best, best_label = p, self.labels[j]
                    if streak >= c.min_windows:
                        fired = True
                else:
                    streak = 0
            if fired:
                hits.append(Hit(c, best, best_label))
        hits.sort(key=lambda h: (LEVEL_ORDER[h.category.level], -h.confidence))
        return hits

    def apply_cooldown(self, device: str, hits: list[Hit], now: float | None = None) -> list[Hit]:
        now = time.time() if now is None else now
        out = []
        for h in hits:
            key = (device, h.category.id)
            if now - self._last.get(key, -1e18) >= h.category.cooldown_s:
                self._last[key] = now
                out.append(h)
        return out

    def top(self, window_scores: list[np.ndarray], k: int = 3) -> list[tuple[str, float]]:
        """เสียงที่ AI คิดว่าใช่มากที่สุด k อันดับ (ไว้ดูตอนจูนเกณฑ์)."""
        m = np.max(np.stack(window_scores), axis=0)
        order = np.argsort(m)[::-1][:k]
        return [(self.labels[i], round(float(m[i]), 3)) for i in order]
