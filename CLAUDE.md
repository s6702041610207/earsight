# EarSight v1 — คู่มือสำหรับ Claude Code

แอป Flutter (Android) ที่ฟังเสียงรอบตัวผ่านไมค์ จำแนกเสียงด้วย YAMNet (TensorFlow Lite) บนเครื่อง
แล้วเตือนด้วยข้อความ + ไอคอน + สี + การสั่น สำหรับผู้ที่มีความบกพร่องทางการได้ยิน
(โครงงานจบ KMUTNB — requirement เก็บจากแบบสอบถามนักเรียนโรงเรียนเศรษฐเสถียรฯ แต่โรงเรียนไม่ใช่กลุ่มเป้าหมายของโปรเจกต์)

APK build บน GitHub Actions (`.github/workflows/build-apk.yml`) ทุกครั้งที่ push — ไม่ต้องใช้ Android Studio ในเครื่อง
ไฟล์ APK อยู่ที่ Releases ของ repo (`build-<เลขรอบ>`)

ผู้ใช้สื่อสารเป็นภาษาไทย ตอบผู้ใช้เป็นภาษาไทย ข้อความใน UI เป็นภาษาไทย

## ติดตั้งครั้งแรก (ทำตามลำดับ)

โฟลเดอร์นี้มีแค่ `lib/`, `test/`, `assets/`, `pubspec.yaml` และ `AndroidManifest.xml` ที่แก้แล้ว
ส่วนที่เหลือของโปรเจกต์ Android ต้องสร้างด้วย `flutter create`

1. ตรวจ Flutter: `flutter --version` ต้องเป็น 3.27 ขึ้นไป และ `flutter doctor` ผ่านส่วน Android
2. สร้างไฟล์แพลตฟอร์มที่ขาด (จะไม่ทับไฟล์ที่มีอยู่แล้ว):
   `flutter create . --platforms=android --org com.earsight --project-name earsight`
   แล้วตรวจว่า `android/app/src/main/AndroidManifest.xml` ยังมี permission RECORD_AUDIO, VIBRATE, WAKE_LOCK
   ถ้าโดนทับ ให้ใส่ 3 บรรทัดนั้นกลับเข้าไป
3. ใน `android/app/build.gradle.kts` (หรือ `build.gradle`) ตั้ง `minSdk = 26` (tflite_flutter ต้องการ)
4. ดาวน์โหลดโมเดลไปไว้ที่ `assets/models/yamnet.tflite`:
   `curl -L -o assets/models/yamnet.tflite https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/audio_classification/android/lite-model_yamnet_classification_tflite_1.tflite`
   ถ้าลิงก์ใช้ไม่ได้ ดาวน์โหลดจาก Kaggle: google/yamnet → TFLite → classification-tflite
   (ไฟล์ .tar.gz ข้างในมี `1.tflite` ให้เปลี่ยนชื่อเป็น `yamnet.tflite`) ไฟล์ควรมีขนาดราว 4 MB
5. `flutter pub get` — ถ้าเวอร์ชัน package ใน pubspec ไม่มีหรือชนกัน ให้ปรับเป็นเวอร์ชันล่าสุดที่เข้ากันได้
   แล้วแก้โค้ดตาม API ใหม่ (package ที่ใช้: tflite_flutter, record, vibration, shared_preferences, wakelock_plus)
6. `flutter analyze` ต้องไม่มี error, `flutter test` ต้องผ่านทั้งหมด
7. รันแอปบน **BlueStacks** (ผู้ใช้ใช้ Windows + BlueStacks เป็นหลัก ไม่ต้องสร้าง Android emulator):
   - BlueStacks ต้องเป็น instance **Android 9 (Pie 64-bit) หรือ Android 11** (แอปต้องการ Android 8.0+ / minSdk 26;
     instance แบบ Nougat ใช้ไม่ได้) — ถ้าไม่ใช่ ให้บอกผู้ใช้สร้างใหม่ใน BlueStacks Multi-instance Manager
   - ผู้ใช้ต้องเปิด ADB ใน BlueStacks เอง: Settings > Advanced > Android Debug Bridge (ADB) แล้วดูพอร์ต (มักเป็น 127.0.0.1:5555)
   - `adb` อยู่ที่ `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` ถ้าไม่อยู่ใน PATH
   - `adb connect 127.0.0.1:<พอร์ต>` → `flutter devices` ต้องเห็นอุปกรณ์ → `flutter run -d <device id>`
   - ถ้า `adb connect` ไม่ติด: ปิด-เปิด ADB ใน BlueStacks ใหม่, ลอง `adb kill-server` แล้ว connect ใหม่
   - ไมค์: บอกผู้ใช้เลือกไมค์ของคอมใน BlueStacks Settings > Audio (Input device) และกด "อนุญาต" ตอนแอปขอสิทธิ์ไมค์
   - BlueStacks สั่นไม่ได้ และบางเครื่องส่งเสียงไมค์เข้าไม่ดี: ถ้าแถบระดับเสียงไม่ขยับเลย ปัญหาอยู่ที่ BlueStacks
     ให้ทดสอบหน้าเตือนด้วยปุ่ม "ดูตัวอย่าง" ในหน้าตั้งค่าแทน หรือเปลี่ยนไปใช้ Android Studio emulator

   ทางเลือกอื่น (ถ้า BlueStacks ใช้ไม่ได้):
   - เครื่องผู้ใช้เป็น **Windows** และยังไม่มีมือถือ Android จึงใช้ **Android Emulator** เป็นหลัก
   - ถ้ายังไม่มี emulator: สร้างด้วย `flutter emulators --create --name earsight_pixel`
     (หรือ Android Studio → Device Manager) ใช้ system image API 33 ขึ้นไป
   - เปิดด้วย `flutter emulators --launch earsight_pixel` แล้ว `flutter run`
   - **บอกผู้ใช้ให้เปิดไมค์ของ emulator เอง**: แถบข้าง emulator → `...` (Extended controls)
     → Microphone → เปิด "Virtual microphone uses host audio input" (ต้องเปิดใหม่ทุกครั้งที่เปิด emulator)
   - emulator ไม่สั่น ฟีเจอร์การสั่นทดสอบได้บนมือถือ Android จริงเท่านั้น
   - ถ้ามีมือถือ Android จริง: เปิด USB debugging เสียบสาย แล้ว `flutter run`
   - iOS (iPhone) ยังไม่รองรับใน v1 เพราะต้อง build บน Mac

## โครงสร้าง

```
lib/
  core/            # ตรรกะล้วน ไม่มี Flutter UI — ทดสอบด้วย unit test
    categories.dart        6 หมวดเสียง, ระดับการเตือน, การจับคู่ label ของ YAMNet
    detection_engine.dart  คะแนน 521 คลาส → การเตือน (threshold, ต่อเนื่อง 2 หน้าต่าง, cooldown)
  services/
    audio_windows.dart     ไมค์ PCM16 16kHz → หน้าต่าง 15600 sample เลื่อนทีละ 7800
    yamnet_classifier.dart โหลด/รัน TFLite รองรับ input [15600] และ [1,15600]
    haptics.dart           รูปแบบการสั่นตามระดับ (Alert Grammar)
    app_store.dart         ตั้งค่า + ประวัติ (SharedPreferences, เก็บในเครื่อง)
    listen_controller.dart ต่อทุกส่วนเข้าด้วยกัน
  ui/              # หน้าหลัก, หน้าเตือนเต็มจอ, ประวัติ, ตั้งค่า
assets/models/     yamnet_class_map.csv (มีแล้ว), yamnet.tflite (ต้องดาวน์โหลด)
server/            เครื่องแม่ข่าย (Python/FastAPI) รับคลิปจากกล่อง IoT → YAMNet → การแจ้งเตือน
  sound_categories.json   รายการเสียง 6 ประเภท (ในบ้าน: ไฟไหม้ ไซเรน เคาะประตู กริ่ง ทารกร้องไห้ ตะโกนเรียก)
  tools/box_simulator.py  จำลองกล่องด้วยไมค์โน้ตบุ๊ก (ตรรกะเดียวกับ firmware ESP32 ที่จะเขียน)
  ดูวิธีรันใน server/README.md
```

**ทิศทางใหม่ (8 ต.ค. 2569 ตามอาจารย์ที่ปรึกษา):** กล่อง IoT (ESP32 + ไมค์) ห้องละ 1 กล่อง วัดความดัง →
เกินเกณฑ์ส่งคลิปไปเครื่องแม่ข่าย → AI จำแนก → แจ้งเตือนมือถือ + นาฬิกา Wear OS; เซนเซอร์สั่นที่ประตูแจ้งตรง
แอป Flutter ใน `lib/` (ฟังด้วยไมค์มือถือเอง) คือ v1 — จะปรับให้รับการแจ้งเตือนจากเครื่องแม่ข่าย

## Requirement ที่มาจากแบบสอบถาม (n = 27)

- เสียงที่ต้องเตือน: เคาะประตู 16, เรียกชื่อ 15, ไฟไหม้ 11, ไซเรน 11, รถ 10, กริ่ง 7
- รูปแบบเตือน: ข้อความชื่อเสียง 17, ไอคอน 13, สีตามประเภท 12, สั่น 9 → ใช้ครบทุกแบบ
- กังวลเรื่องไมค์เปิดตลอด เฉลี่ย 3.3/5, อยากเก็บข้อมูลในเครื่อง 12 คน → ฟังเฉพาะตอนกดเริ่ม ไม่บันทึกเสียง ไม่ใช้เน็ต
- "เรียกชื่อ": YAMNet แยกชื่อคนไม่ได้ v1 จึงเตือนแบบเบาว่า "มีคนพูดใกล้ๆ"

## กติกาที่ต้องรักษา

- ห้ามเขียนเสียงลงไฟล์หรือส่งขึ้นเครือข่าย ประวัติเก็บแค่ชื่อเสียง เวลา และความมั่นใจ
- ห้ามใช้เสียงเป็นช่องทางเตือน (ผู้ใช้ไม่ได้ยิน) ทุกการเตือนต้องเห็นได้และสั่นได้
- เสียงอันตรายต้องเตือนทันที (1 หน้าต่าง) และต้องแตะปิดเอง
- label ใน `categories.dart` ต้องตรงกับ `yamnet_class_map.csv` ทุกตัวอักษร (มี test ตรวจ)

## ข้อจำกัดของ v1 และงาน v2

- ฟังได้เฉพาะตอนเปิดแอปไว้หน้าจอ (เปิดจอค้างด้วย wakelock) — v2: foreground service + notification
- ค่า threshold ใน `categories.dart` ยังไม่ได้จูนกับเสียงจริง ให้ใช้โหมดทดสอบในหน้าตั้งค่าดูคะแนนจริงแล้วปรับ
- "Alarm" (หมวดไฟไหม้) และ "Door" (หมวดเคาะประตู) อาจเตือนผิดบ่อย ถ้าเป็นเช่นนั้นให้ตัดออก
- inference รันบน main isolate — ถ้าหน้าจอกระตุกให้ย้ายไป `IsolateInterpreter`
- v2: นาฬิกา Wear OS, ปุ่มฉุกเฉินแจ้งผู้ปกครอง/ครู, บันทึกเสียงของตัวเอง, จับชื่อเล่น
