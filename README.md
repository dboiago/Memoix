# Memoix 🍳

A beautiful, open-source recipe management app for home cooks. Organize your recipes, import from photos or websites, and share with friends and family.

![Flutter](https://img.shields.io/badge/Flutter-3.2+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Platform](https://img.shields.io/badge/Platform-Android%20|%20iOS%20|%20Windows%20|%20macOS-lightgrey.svg)

## ✨ Features

- 📱 **Cross-platform** - Works on Android, iOS, Windows, and macOS
- 📸 **OCR Import** - Scan recipes from photos of cookbooks or handwritten notes
- 🔗 **URL Import** - Paste a link from popular recipe websites to import
- 🏷️ **Smart Organization** - Organize by course, cuisine, and custom tags
- 🔍 **Powerful Search** - Find recipes by name, ingredients, or tags
- ❤️ **Favorites** - Quick access to your most-loved recipes
- 📤 **Easy Sharing** - Share recipes via QR codes, links, or text
- 🌙 **Dark Mode** - Beautiful light and dark themes
- 📴 **Offline First** - All your recipes available without internet

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      MEMOIX APP                              │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Memoix      │  │ My Recipes  │  │ Shared With Me      │  │
│  │ Collection  │  │ (Personal)  │  │ (Imported)          │  │
│  │ (GitHub)    │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                  Local Database (Isar)                       │
│                  Offline-first, no account                   │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.2+)
- Android Studio / Xcode (for mobile development)
- Visual Studio (for Windows development)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/dboiago/Memoix.git
cd Memoix
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate database schemas:
```bash
dart run build_runner build
```

4. Run the app:
```bash
flutter run
```

### Building for Release

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── app/
│   ├── app.dart             # Main app widget
│   ├── routes/              # Navigation
│   └── theme/               # Colors and theming
├── core/
│   ├── database/            # Isar database setup
│   └── services/            # GitHub sync, etc.
├── features/
│   ├── home/                # Home screen with tabs
│   ├── recipes/             # Recipe list, detail, edit
│   ├── import/              # OCR and URL import
│   ├── sharing/             # QR codes, deep links
│   └── settings/            # App settings
└── shared/
    └── widgets/             # Reusable components

recipes/                      # Official recipe collection (JSON)
├── index.json
├── mains.json
├── sauces.json
└── ...
```

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

### Adding Recipes

1. Edit the appropriate JSON file in `/recipes/`
2. Follow the recipe schema (see [recipes/README.md](recipes/README.md))
3. Increment version in `version.json`
4. Submit a PR

### Code Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Database powered by [Isar](https://isar.dev/)
- OCR by [Google ML Kit](https://developers.google.com/ml-kit)
- Icons by [Material Design](https://material.io/icons)

## ☕ Support

If you find this app useful, consider:
- ⭐ Starring the repository
- 🐛 Reporting bugs
- 💡 Suggesting features
- 📖 Contributing recipes

---

Made with ❤️ for home cooks everywhere
