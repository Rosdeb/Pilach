# Performance Analysis & Optimization Plan
**Project:** Pilach Community Chat App
**Date:** June 2026

This document details the performance analysis of the app, specifically addressing the JANK logs reported, and outlines actionable strategies for optimizing frame rates and overall UI smoothness.

---

## 1. Analysis of the Jank Log
The logs provided previously indicated significant frame drops specifically during keyboard interactions:
`CUJ=J<IME_INSETS_SHOW_ANIMATION::0@1@com.example.messageapp>`
`Missed App frame: totalDuration: 284552216` (approx. 284ms to render a frame)

**Root Cause:**
When the device's on-screen keyboard (IME) appears, the available screen height shrinks. By default, Flutter's `Scaffold` has `resizeToAvoidBottomInset: true`. This causes the entire widget tree inside the `Scaffold` (especially inside the Chat Screen) to violently recalculate its layout, rebuild all visible widgets, and execute a sliding animation to move the content up. If the UI contains heavy elements (like long lists or unoptimized image widgets), the 16ms window to render a 60fps frame is severely missed, resulting in visible "jank" or stuttering.

---

## 2. Identified Performance Bottlenecks

### A. Heavy Layout Recalculation on Keyboard Toggle
As analyzed above, the chat screen drops frames when the keyboard slides up because the `ListView` of messages must rapidly redraw.

### B. Uncached Network Images
The app currently uses standard `NetworkImage` (e.g., for avatars and story previews). Every time a user scrolls, these images are downloaded/decoded repeatedly. Image decoding is a highly CPU-intensive task on the main thread.

### C. Inefficient Widget Rebuilds
Watching Riverpod providers (`ref.watch`) at the top of large widget trees (like `Scaffold` body) causes the entire screen to rebuild when the state changes.

### D. Third-Party Animation Glitches
Using heavy or buggy third-party packages for simple UI elements (like `flutter_advanced_switch`) caused unnecessary state lifecycles and layout passes. We already solved one instance of this by migrating to the highly optimized native `CupertinoSwitch`.

---

## 3. Actionable Optimization Plan

### Step 1: Fix Keyboard Animation Jank (IME Insets)
- **Implement `ListView.builder` strictly:** Ensure all message lists and story lists use lazy-loading builders rather than rendering all children at once.
- **Cache Extents:** If message heights are predictable, consider using `prototypeItem` or `itemExtent` in `ListView` to drastically reduce layout calculation time.
- **Defer Heavy Builds:** If a screen has complex UI, consider wrapping the main body in `const` widgets wherever possible to prevent them from rebuilding during the keyboard animation.

### Step 2: Implement Image Caching
- **Package Integration:** Add `cached_network_image` to `pubspec.yaml`.
- **Action:** Replace all instances of `NetworkImage` and `Image.network` with `CachedNetworkImage`. This will store decoded images in memory and disk caches, making scrolling through avatars and stories silky smooth at 120Hz.

### Step 3: Optimize Riverpod State Management
- **Targeted Rebuilds:** Instead of placing `ref.watch` at the very top of the `build` method, extract components that rely on that state into their own smaller `ConsumerWidget`. This localizes rebuilds only to the widgets that actually changed.
- **Use `select`:** If a widget only cares about a specific property of a provider, use `.select((value) => value.property)` so the widget ignores irrelevant state changes.

### Step 4: Font and Icon Pre-loading
- Ensure any custom fonts are fully loaded before rendering the main UI. Missing or lazily-loaded fonts can cause a layout jump (Jank) upon their first appearance.

### Step 5: Profile Mode Validation
- Always test animations on a physical device in **Profile Mode** (`flutter run --profile`). Debug mode includes heavy assertions and timeline overheads that artificially induce jank. The 284ms frame drop might only be 20ms in a release build, but optimizations will still make it visually seamless.
