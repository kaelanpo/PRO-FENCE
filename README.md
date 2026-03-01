# PRO-FENCE

Fencing app for people who need help.

iOS-first fence estimating app with a single-screen, scroll-based flow and iOS 26–style liquid glass UI. Built with **React Native (Expo SDK 52)**.

## Features

- **Deterministic calculation engine** — Post spacing, materials (posts, rails, pickets, panels, concrete, hardware, gates), labor with terrain multipliers, markup, and waste. No AI/LLM.
- **Live estimate panel** — Animated totals as you type.
- **Fence types** — Wood Privacy, Wood Picket, Chain Link, Vinyl, Aluminum, Split Rail.
- **Persistent pricing** — Contractor costs and labor rates saved via AsyncStorage.
- **Copy quote / Share** — Formatted estimate text; copy to clipboard or share sheet.
- **Material list** — Expandable line items and “Copy Supplier Order” for ordering.

## Quick start

```bash
npm install --legacy-peer-deps
npx expo start
```

Then press **i** for iOS simulator or scan the QR code with Expo Go.

For a native iOS build:

```bash
npx expo run:ios
```

## Project structure

- **`App.tsx`** — Single screen: header, fence type pills, measurements, live estimate, material accordion, pricing config, action bar.
- **`src/engine/calculations.ts`** — Pure calculation engine (no React): `runEstimate()`, `calculateMaterials()`, `calculateCosts()`, `generateLineItems()`, `generateQuoteText()`, `generateSupplierList()`.
- **`app.json`** — Expo config (bundle ID `com.fencequote.app`).

## Design

- Dark theme, deep space gradient background, frosted glass cards (`expo-blur`).
- SF Pro (iOS), 8pt grid, 20pt card radius, accent green for total price.
- Haptics on fence type, gates, terrain, and actions.

## Requirements

- Node 18+ (Node 20+ recommended for latest Expo tooling).
- iOS 18+ simulator or device for best visual match.
- For a clean install, use `npm install --legacy-peer-deps` if you hit peer dependency conflicts.

Replace `assets/icon.png` and `assets/adaptive-icon.png` with your own app icon when publishing.
