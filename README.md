# Archer POS v2 — Flutter Mobile App

A full-featured Point of Sale (POS) system for Android phones and tablets, converted from the original Python/PySide6 desktop application.

## 📱 Overview

Archer POS v2 is a mobile-first POS system built with Flutter, targeting Android phones and tablets. It maintains the same business logic and system flow as the original desktop version.

## ✨ Features

- **Dashboard** — Real-time stats: today's sales, transactions, total products, outstanding balances
- **Point of Sale (POS)** — Barcode scanning, cart management, retail/wholesale pricing, bundle pricing, park/recall sales, quick-add items, checkout with change calculation
- **Product Manager** — Full CRUD for products, bundle management, price list viewing
- **Balance Manager** — View and resolve customer outstanding balances
- **Data Logs** — Audit trail, receipt reprinting, sale voiding
- **Account Settings** — Password change, logout
- **Payment Notes** — Log and track expenses/payouts

## 🏗️ Architecture

- **Framework**: Flutter (Dart)
- **Database**: SQLite via `sqflite`
- **State Management**: Provider
- **Navigation**: Bottom Navigation Bar (phones) / Navigation Rail (tablets)

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── database/
│   │   └── database_helper.dart       # SQLite database layer
│   ├── models/
│   │   ├── product.dart
│   │   ├── sale.dart
│   │   ├── customer.dart
│   │   └── bundle.dart
│   ├── providers/
│   │   ├── auth_provider.dart         # Authentication state
│   │   ├── cart_provider.dart         # Shopping cart state
│   │   └── theme_provider.dart
│   └── utils/
│       ├── constants.dart             # App-wide constants & colors
│       └── formatters.dart            # Currency, date formatting
└── screens/
    ├── login/
    │   └── login_screen.dart
    ├── main/
    │   └── main_screen.dart           # Navigation shell
    ├── dashboard/
    │   └── dashboard_screen.dart
    ├── pos/
    │   ├── pos_screen.dart
    │   └── widgets/
    │       ├── cart_item_tile.dart
    │       ├── checkout_dialog.dart
    │       ├── quick_add_dialog.dart
    │       ├── park_recall_dialog.dart
    │       └── add_product_dialog.dart
    ├── inventory/
    │   ├── inventory_screen.dart
    │   └── widgets/
    │       ├── product_form_dialog.dart
    │       └── bundle_dialog.dart
    ├── balance/
    │   └── balance_screen.dart
    ├── logs/
    │   └── logs_screen.dart
    ├── account/
    │   └── account_screen.dart
    └── payment_notes/
        └── payment_notes_screen.dart
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0.0+
- Android Studio or VS Code with Flutter extension
- Android device or emulator (API 21+)

### Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run on device/emulator:
   ```bash
   flutter run
   ```

3. Build APK:
   ```bash
   flutter build apk --release
   ```

4. Build for tablet (same APK, adapts automatically):
   ```bash
   flutter build apk --release
   ```

## 🔐 Default Login

- **Username**: `admin`
- **Password**: `admin`

> ⚠️ Change the default password after first login!

## 👥 User Roles

| Feature | Admin | Staff |
|---------|-------|-------|
| View all screens | ✅ | ✅ |
| POS - add items | ✅ | ✅ |
| POS - delete items | ✅ | ✅ (admin password) |
| POS - apply discount | ✅ | ✅ (admin password) |
| POS - void cart | ✅ | ✅ (admin password) |
| Products - add/edit/delete | ✅ | ❌ |
| Products - manage bundles | ✅ | ❌ |
| Delete payment notes | ✅ | ✅ (admin password) |
| Void sale in logs | ✅ | ✅ (admin password) |

## 📦 Key Dependencies

- `sqflite` - SQLite database
- `provider` - State management
- `google_fonts` - Inter font family
- `intl` - Currency and date formatting
- `crypto` - Password hashing
- `pdf` + `printing` - Receipt export
- `share_plus` - Share functionality

## 🌏 Notes

- All timestamps stored at UTC+8 (Philippines Standard Time)
- Audit logs automatically purged after 90 days
- Stock management is disabled by design (no inventory deduction on sale)
- Password minimum length: 6 characters
- Master recovery code for admin: Contact developer