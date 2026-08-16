# Shelf

A native macOS utility for the space between the clipboard and the filesystem.

> **Finder is where you keep things. Clipboard is what you're using right now. Shelf is everything in between.**

Throw text, links, images, files, PDFs, colours and code snippets onto a floating Shelf, then drag them back out into any other app later.

## Requirements

- macOS 26
- Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Building

```bash
xcodegen generate
open Shelf.xcodeproj
# or, headless:
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build build
```

The project uses ad-hoc code signing locally. For App Store distribution, set your team in Xcode (`Support/Shelf.entitlements` is already sandboxed).

## Usage

- **⌥ Space** — summon / dismiss the floating Shelf (global, configurable)
- **⌥ ⇧ Space** — capture the clipboard onto the active shelf (configurable)
- Drag files / images / text / URLs / colours from any app onto the shelf
- Drag to the left or right screen edge to summon Shelf mid-drag
- Drag items back out into any other app
- Snap the panel left or right from the header
- **⌘-click** to multi-select (Pro), then drag as a stack
- **Space** — Quick Look · **Return** — open · **⌫** — delete · **↑↓←→** — move selection
- **⌘C** copy · **⌘P** pin · **⌘N** new shelf · **⌘[ ⌘]** or **⌘1–9** switch shelves
- **⌘F** — focus search
- Menu bar icon for shelves, capture, manage, preferences, quit
- Duplicates are detected and brought forward instead of copied again
- Links fetch a title and favicon on this Mac
- Inbox can suggest archiving things unused for two weeks
- Settings can write a backup into an iCloud Drive folder

## Free vs Shelf Pro

**Free:** Inbox (Quick Shelf), core drag-and-drop, basic search, 100 items.

**Pro:** unlimited shelves, unlimited items, OCR search inside screenshots, multi-item drag, custom shortcuts.

Purchases are managed with RevenueCat. Entitlement state is never hard-coded. Paste your Apple platform API key into `Sources/App/AppConfig.swift` to enable the store; without a key the app still runs fully locally.

## Privacy

Everything stays on this Mac. SwiftData stores metadata, imported binaries are copied into Application Support, and OCR runs on-device with Vision. Clipboard history is never recorded.

## Architecture

```
Sources/
  App/          App entry, shared state, actions, windows, settings
  Models/       SwiftData models + deterministic ItemClassifier
  Persistence/  SwiftData container + binary storage
  Import/       NSItemProvider → ShelfItem pipeline
  DragDrop/     Transferable for dragging items out and reordering
  Panel/        NSPanel, snap/edge-drop, keyboard nav
  Services/     Shortcuts, clipboard, Vision OCR, Quick Look, haptics
  Store/        RevenueCat StoreManager + feature gates
  Theme/        Visual tokens, shelf rail, toast
  Views/        Cards, switcher, onboarding, paywall, prefs, management
```
