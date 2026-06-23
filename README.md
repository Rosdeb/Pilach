# Pilach - Modern Flutter Messaging Application

Pilach is a feature-rich, high-performance messaging client built with Flutter and Riverpod. It features a modern design system with full light, dark, and system theme adaptation, clean state management, and smooth micro-animations.

<p align="center">
  <img src="docs/Screenshot 2026-06-24 at 2.50.27 AM.png" width="320" alt="Chats Screen (Light Mode)" />
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/Screenshot 2026-06-24 at 2.50.46 AM.png" width="320" alt="Settings Screen (Light Mode)" />
</p>

---

## 🎨 Visual Gallery & Screens

For a full tour of the application user interfaces, see the [Visual Documentation Guide](file:///Users/rosdeb/BuisnessBuild/MessageApp/docs/README.md) inside the `docs` folder. It showcases high-fidelity screenshots and core features for:
* **Chats Screen:** Real-time conversation tracking with unread indicators.
* **Contacts Screen:** Alphabetically-indexed directory.
* **Discover Screen:** Social stories tray and location-based nearby radar scanning.
* **Settings ("Me") Screen:** Accounts configuration, notification preferences, and Theme Mode toggling.
* **Direct Chat Screen:** Rich interactive messaging experience in both Light and Dark modes.

---

## 🚀 Key Features

* **Complete Theme System Support:** Seamless dynamic toggling between Light, Dark, and System modes. Zero static color caching issues.
* **Modern UI/UX Design:** Implements high-quality aesthetic practices including glassmorphism layouts, clean shadows, customized inputs, and responsive flex spacing.
* **State Management:** Powered by Riverpod for highly predictable state container transitions and fast updates.
* **Radar Animation & Stories:** Dynamic, immersive animations for location discovery and social story previews.
* **Modular Code Structure:** Clear separation of concerns (Features, Core, Components, Theme).

---

## 📂 Project Architecture

```
lib/
├── Components/         # Shared UI components (AppText, FloatingErrorBar, etc.)
├── core/               # Shared constants, router settings, and core application configurations
│   ├── constants/      # App asset pathways and global constants
│   ├── router/         # App routing configuration (GoRouter)
│   └── theme/          # ThemeData configs (light_theme.dart, dark_theme.dart)
└── Features/           # Feature-based folder structure
    ├── auth/           # Login, Register, Splash Screens & Auth Provider
    ├── Chat/           # Main Chat list, Inbox, Message tiles & Chat Providers
    ├── Contact/        # Contacts list, Group creation sheet, & Slidable controllers
    ├── Discovers/      # Stories and Nearby Radar scanning feature
    └── Me/             # User settings, Profile editing, & Blocked lists
```

---

## ⚙️ Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version recommended)
* Dart SDK

### Installation

1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd MessageApp
   ```

2. Retrieve dependencies:
   ```bash
   flutter pub get
   ```

3. Run the development server or launch on a simulator/device:
   ```bash
   flutter run
   ```

### Verification & Testing

Verify that your environment contains no compiler or lint issues:
```bash
flutter analyze
```
