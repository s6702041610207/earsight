# EarSight — เครื่องแม่ข่าย (ต้นแบบ)

รับคลิปเสียงจากกล่อง IoT → AI (YAMNet) จำแนกเสียง → สร้างการแจ้งเตือน
ตอนนี้แสดงผลบนหน้าเว็บก่อน ขั้นต่อไปจะส่งไปแอปมือถือและนาฬิกา

```
กล่อง (หรือโปรแกรมจำลองกล่อง) ──คลิป WAV──▶ เครื่องแม่ข่าย ──▶ หน้าเว็บ / (ต่อไป) แอปมือถือ → นาฬิกา
เซนเซอร์ประตู ──────────────────สัญญาณเคาะ──▶ เครื่องแม่ข่าย (ไม่ผ่าน AI)
```

ความเป็นส่วนตัว: เสียงอยู่ในหน่วยความจำระหว่างประมวลผลเท่านั้น ไม่บันทึกลงดิสก์
ประวัติ (`events.jsonl`) มีแค่ ชื่อเสียง ห้อง เวลา ความมั่นใจ

## ติดตั้งบน Windows (ครั้งแรก)

1. ติดตั้ง **Python 3.12** จาก python.org (ติ๊ก "Add python.exe to PATH" ตอนติดตั้ง)
2. เปิด PowerShell ในโฟลเดอร์ `server` ของ repo แล้วรัน

   ```powershell
   py -3.12 -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt sounddevice
   python tools/download_model.py
   ```

## ใช้งาน

หน้าต่างที่ 1 — เปิดเครื่องแม่ข่าย:

```powershell
.venv\Scripts\activate
python -m earsight_server
```

เปิดเบราว์เซอร์ที่ http://localhost:8000 (ถ้า Windows ถามเรื่อง Firewall ให้กด Allow บน Private network
เพื่อให้กล่องในวง Wi-Fi เดียวกันส่งเข้ามาได้)

หน้าต่างที่ 2 — จำลองกล่องด้วยไมค์โน้ตบุ๊ก:

```powershell
.venv\Scripts\activate
python tools/box_simulator.py --room "ห้องนอน"
```

ลองเปิดคลิปเสียงกริ่ง ไซเรน หรือเคาะโต๊ะใกล้ๆ ไมค์ แล้วดูผลบนหน้าเว็บ

คำสั่งอื่น:

| คำสั่ง | ทำอะไร |
|---|---|
| `python tools/box_simulator.py --file ไฟล์.wav` | ส่งไฟล์เสียงแทนไมค์ |
| `python tools/box_simulator.py --door` | จำลองเซนเซอร์ประตูจับการเคาะ |
| `python tools/box_simulator.py --margin 10` | ให้ไวขึ้น (ค่าเริ่มต้น 15 dB เหนือเสียงพื้นหลัง) |
| `python -m pytest` | รันเทสต์ |

## ปรับรายการเสียง

แก้ `sound_categories.json` ได้โดยไม่ต้องแก้โค้ด (รายการตอนนี้เป็นของชั่วคราวจากแอป v1 รอสรุป 6 เสียง)
ชื่อใน `labels` ต้องตรงกับ `assets/models/yamnet_class_map.csv` ทุกตัวอักษร (มีเทสต์ตรวจ)
ช่อง "ที่มา" บนหน้าเว็บบอกว่า AI ได้ยินอะไร — ใช้ดูคะแนนจริงแล้วปรับ `threshold`

## API สำหรับกล่อง

| Method | Path | ใช้ทำอะไร |
|---|---|---|
| POST | `/api/clip?device=box1&room=ห้องนอน` | body = ไฟล์ WAV (PCM 16 บิต แนะนำ 16 kHz โมโน) |
| POST | `/api/door?device=box1&room=ประตูหน้า` | เซนเซอร์ประตูจับการเคาะ |
| POST | `/api/heartbeat?device=box1&room=ห้องนอน` | กล่องบอกว่ายังออนไลน์ (ทุก 10 วินาที) |
| GET | `/api/events?after=<id>` | การแจ้งเตือนใหม่ (แอปมือถือจะใช้) |
| GET | `/api/devices` | สถานะกล่องทั้งหมด |
