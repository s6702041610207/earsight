"""รันโมเดล YAMNet (ไฟล์ .tflite ตัวเดียวกับแอป v1) บนเครื่องแม่ข่าย."""
from __future__ import annotations

from typing import Protocol

import numpy as np

from .audio import WINDOW


class Classifier(Protocol):
    def scores(self, window: np.ndarray) -> np.ndarray:
        """คะแนน 521 คลาส (0–1) ของเสียง 1 ช่วง (15600 sample)."""
        ...


def _interpreter_class():
    try:  # Linux / macOS
        from ai_edge_litert.interpreter import Interpreter
        return Interpreter
    except ImportError:
        pass
    try:
        from tflite_runtime.interpreter import Interpreter
        return Interpreter
    except ImportError:
        pass
    try:  # Windows
        import tensorflow as tf
        return tf.lite.Interpreter
    except ImportError as e:
        raise ImportError(
            "ไม่พบตัวรันโมเดล ติดตั้งด้วย: pip install -r requirements.txt"
        ) from e


class YamnetClassifier:
    def __init__(self, model_path: str):
        self._it = _interpreter_class()(model_path=str(model_path))
        inp = self._it.get_input_details()[0]
        if list(inp["shape"]) not in ([WINDOW], [1, WINDOW]):
            self._it.resize_tensor_input(inp["index"], [WINDOW])
        self._it.allocate_tensors()
        self._in = self._it.get_input_details()[0]
        self._out = self._it.get_output_details()[0]

    @property
    def shape_info(self) -> str:
        return f"input {list(self._in['shape'])} → output {list(self._out['shape'])}"

    def scores(self, window: np.ndarray) -> np.ndarray:
        x = window.astype(np.float32).reshape(self._in["shape"])
        self._it.set_tensor(self._in["index"], x)
        self._it.invoke()
        y = np.asarray(self._it.get_tensor(self._out["index"]), dtype=np.float32)
        return y.reshape(-1, y.shape[-1]).max(axis=0)
