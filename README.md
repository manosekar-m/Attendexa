# Attendexa 📡
> Smart NFC Attendance — Mark. Track. Export.

**Attendexa** is a modern, Flutter-based mobile attendance management application that utilizes NFC/RFID tags to mark student attendance instantly. Designed with a premium glassmorphic User Interface (Material 3), it allows educators and institutions to manage student records efficiently, entirely offline.

## ✨ Features

- **NFC/RFID Attendance Marking:** Tap a student's NFC card/tag to instantly mark them as present.
- **Premium Glassmorphism UI:** A sleek, modern, and vibrant interface featuring dynamic gradients, smooth animations, and interactive cards.
- **Offline First:** Powered by [Hive](https://pub.dev/packages/hive), all student data and attendance records are stored locally and securely on the device.
- **Excel Import & Export:** 
  - Easily bulk-import students using an `.xlsx` file.
  - Export daily or monthly attendance records to Excel sheets with a single tap.
- **Dynamic History & Tracking:** View detailed attendance history by date. Quickly identify who is Present (🟢) and who is Absent (🔴).
- **Secure Authentication:** Built-in PIN protection ensures that only authorized personnel can access or modify attendance data.
- **Quick Edit Flow:** Intuitive swipe gestures (swipe right to edit, swipe left to delete) make managing the student roster effortless.

## 🛠️ Technology Stack

- **Framework:** Flutter (Dart)
- **Local Storage:** Hive (NoSQL database)
- **NFC Integration:** `nfc_manager`
- **File Handling:** `file_picker`, `excel`, `path_provider`
- **UI & Icons:** Custom Glassmorphism, `font_awesome_flutter`

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed on your machine.
- An Android device with NFC capabilities (for testing NFC features).

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/manosekar-m/Attendexa.git
   cd Attendexa
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## 📂 Project Structure

- `lib/models/` - Hive data models (`Student`, `Attendance`).
- `lib/screens/` - UI screens (`AttendanceMarkingScreen`, `HistoryScreen`, `ImportStudentsScreen`, etc.).
- `lib/services/` - Core logic (`DatabaseService`, `ExcelService`, `NfcService`, `AuthService`).
- `lib/widgets/` - Reusable UI components (e.g., `GlassCard`).

## 💡 Usage Guide

1. **Setup PIN:** On the first launch, set up a secure 4-digit PIN.
2. **Import Students:** Go to the "Students" tab and import an Excel file containing `NFC ID`, `Name`, and `Std-Sec`.
3. **Mark Attendance:** Navigate to the "Mark Attendance" tab and tap an NFC card to the back of your device.
4. **View History:** Check the "History" tab to see attendance logs for any specific date.
5. **Export Data:** Export attendance records as an Excel file directly to your device's downloads folder.

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/manosekar-m/Attendexa/issues).

## 📄 License
This project is licensed under the MIT License.
