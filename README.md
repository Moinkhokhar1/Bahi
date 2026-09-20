# 🏢 ERP System

> A modern, cross-platform **Enterprise Resource Planning (ERP) application built with Flutter** for managing bills, inventory, deliveries, and day-to-day shop-to-shop business operations from a single system.

ERP System is designed to simplify common business workflows by bringing billing, stock management, delivery operations, and business records into one application. The project focuses on providing a clean, practical, and maintainable ERP experience while taking advantage of Flutter's cross-platform capabilities.

---

## ✨ Overview

Small and medium businesses often manage inventory, invoices, customer records, deliveries, and other operations using separate applications or manual records.

**ERP System** brings these workflows together into one application.

The system is designed around three core areas:

* 📦 **Stock Management** — Organize and manage inventory information.
* 🧾 **Billing** — Create and maintain business billing records.
* 🚚 **Deliveries** — Manage shop-to-shop delivery-related operations.

The application is built with **Flutter and Dart**, allowing the same project to target Android, iOS, Web, Windows, macOS, and Linux.

---

## 🚀 Key Features

### 📊 Business Dashboard

A centralized interface for accessing important ERP operations and business information.

### 📦 Inventory & Stock Management

Manage product and stock information required for everyday business operations.

### 🧾 Billing Management

Maintain billing-related information digitally and simplify business record management.

### 🚚 Delivery Management

Manage delivery workflows for shop-to-shop business operations.

### ✍️ Digital Signatures

Capture signatures digitally where acknowledgement or authorization is required.

### 📄 PDF Support

Generate documents in PDF format for business records and printable documents.

### 🖨️ Printing

Print generated documents directly from supported devices.

### 📤 Sharing

Share generated business documents using applications available on the user's device.

### 💾 Local Data Storage

SQLite-based local persistence allows application data to be maintained directly on the device.

### 🌐 Cross-Platform

The project contains Flutter platform targets for:

`Android` • `iOS` • `Web` • `Windows` • `macOS` • `Linux`

---

## 🛠️ Tech Stack

| Technology           | Purpose                                |
| -------------------- | -------------------------------------- |
| **Flutter**          | Cross-platform application development |
| **Dart**             | Primary programming language           |
| **Provider**         | Application state management           |
| **SQLite / sqflite** | Local database and persistence         |
| **Path Provider**    | Application filesystem access          |
| **Google Fonts**     | Application typography                 |
| **Signature**        | Digital signature capture              |
| **PDF**              | PDF document generation                |
| **Printing**         | Printing and PDF preview               |
| **Share Plus**       | Native document/content sharing        |
| **Intl**             | Date, number, and locale formatting    |
| **UUID**             | Unique identifier generation           |
| **URL Launcher**     | Opening external links and resources   |

---

## 🏗️ Project Structure

```text
ERP_System/
│
├── android/              # Android platform configuration
├── ios/                  # iOS platform configuration
├── lib/                  # Main Flutter/Dart application
├── linux/                # Linux desktop configuration
├── macos/                # macOS configuration
├── test/                 # Flutter tests
├── web/                  # Web configuration
├── windows/              # Windows desktop configuration
│
├── pubspec.yaml          # Dependencies and project configuration
├── pubspec.lock          # Locked dependency versions
├── analysis_options.yaml # Dart/Flutter lint configuration
└── README.md
```

---

## ⚙️ Getting Started

### Prerequisites

Make sure the following are installed:

* Flutter SDK
* Dart SDK
* Android Studio and/or VS Code
* Android SDK for Android development
* Xcode for iOS development on macOS
* Git

Verify your Flutter environment:

```bash
flutter doctor
```

---

## 📥 Installation

### 1. Clone the repository

```bash
git clone https://github.com/Moinkhokhar1/ERP_System.git
```

### 2. Enter the project directory

```bash
cd ERP_System
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Check connected devices

```bash
flutter devices
```

### 5. Run the application

```bash
flutter run
```

---

## 🤖 Run on Android

Start an Android emulator or connect a physical Android device with USB debugging enabled.

Then run:

```bash
flutter run
```

To create a release APK:

```bash
flutter build apk --release
```

The generated APK will normally be available under:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🌐 Run on Web

```bash
flutter run -d chrome
```

Create a production web build with:

```bash
flutter build web
```

---

## 🖥️ Run on Desktop

### macOS

```bash
flutter run -d macos
```

### Windows

```bash
flutter run -d windows
```

### Linux

```bash
flutter run -d linux
```

Platform-specific Flutter desktop requirements must be installed before running the corresponding target.

---

## 📦 Core Dependencies

```yaml
provider:
sqflite:
path:
path_provider:
google_fonts:
signature:
pdf:
printing:
share_plus:
intl:
uuid:
url_launcher:
```

These packages provide the application's state management, local persistence, filesystem access, typography, signature capture, document generation, printing, sharing, formatting, identifier generation, and external-link functionality.

---

## 🔄 Application Workflow

```text
                     ┌─────────────────────┐
                     │     ERP SYSTEM      │
                     └──────────┬──────────┘
                                │
             ┌──────────────────┼──────────────────┐
             │                  │                  │
             ▼                  ▼                  ▼
      ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
      │    STOCK    │    │   BILLING   │    │ DELIVERIES  │
      └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
             │                  │                  │
             └──────────────────┼──────────────────┘
                                ▼
                       ┌─────────────────┐
                       │ BUSINESS DATA   │
                       └────────┬────────┘
                                │
                     ┌──────────┴──────────┐
                     ▼                     ▼
              ┌────────────┐        ┌────────────┐
              │ PDF/PRINT  │        │   SHARE    │
              └────────────┘        └────────────┘
```

---

## 📸 Screenshots

> Add application screenshots here to make the repository easier to understand.

```markdown
![Dashboard](screenshots/home_screen.png)
![Inventory](screenshots/inventory_screen.png)
![Billing](screenshots/bills_screen.png)
![Delivery](screenshots/shop_list_screen.png)
```

Recommended repository structure:

```text
screenshots/
├── dashboard.png
├── inventory.png
├── billing.png
└── delivery.png
```

---

## 🗺️ Roadmap

Potential areas for continued development include:

* [ ] Advanced inventory reporting
* [ ] Sales analytics and visualization
* [ ] Customer and supplier management improvements
* [ ] Search and filtering
* [ ] Exportable business reports
* [ ] Backup and restore
* [ ] Cloud synchronization
* [ ] Authentication and role-based access
* [ ] Improved responsive UI
* [ ] Automated testing
* [ ] Production deployment

---

## 🧪 Testing

Run Flutter tests using:

```bash
flutter test
```

Run static analysis using:

```bash
flutter analyze
```

Format the Dart source code using:

```bash
dart format .
```

---

## 🤝 Contributing

Contributions, suggestions, and improvements are welcome.

1. Fork the repository.
2. Create a new branch.

```bash
git checkout -b feature/your-feature
```

3. Make your changes.
4. Commit them.

```bash
git commit -m "Add your feature"
```

5. Push the branch.

```bash
git push origin feature/your-feature
```

6. Open a Pull Request.

---

## 👨‍💻 Developer

**Moin Khokhar**

Backend + Full Stack Developer

Interested in building practical applications involving **Flutter, Node.js, REST APIs, PostgreSQL, Prisma, offline-first systems, and full-stack development**.

---

## ⭐ Support

If you find this project useful or interesting, consider giving the repository a **⭐ star**.

It helps support continued development and makes the project easier for other developers to discover.

---

## 📄 License

© 2026 moinworksonlocalhost. All rights reserved.

This project is **not open source**. No part of this codebase may be copied, modified, distributed, or used without explicit written permission from the author.

---

<div align="center">

**Built with ❤️ by [Moinworksonlocalhost](https://moinworksonlocalhost.onrender.com/)**
<p align="center">
  <b>ERP System</b><br>
  Simplifying bills, stock and deliveries for modern businesses.
</p>
