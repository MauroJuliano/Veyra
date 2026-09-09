# Veyra

[![CI](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml/badge.svg)](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml)

Veyra is a native iOS messaging app built as a portfolio project. It explores what a modern chat experience can feel like when it is designed around a quieter, more atmospheric visual identity — without losing the interactions people already expect from a messaging app.

> **Portfolio notice**
>
> Veyra is an educational and portfolio project. It is not an official commercial product, is not available on the App Store, and is not currently intended for a public launch. Some features and infrastructure are experimental and were created to demonstrate product thinking, native iOS development, architecture, and attention to user experience.

## The idea

This project started from an older chat app I built near the beginning of my career. Instead of simply polishing that code, I chose to rebuild the experience with SwiftUI and a more deliberate structure.

The goal was to turn a familiar idea into a space for practicing the things that matter in a real mobile product: clear navigation, responsive interfaces, realtime behavior, offline continuity, privacy decisions, accessibility, localization, testing, and maintainable code.

The result is a dark, purple-toned interface with glass-inspired surfaces and small neon accents. The visual direction is intentionally different from the more utilitarian appearance of traditional messaging apps, while the interactions remain familiar.

## What you can do in Veyra

- Create an account and maintain a profile with name, username, bio, email, and photo.
- Find people by name or username and keep a list of recent searches.
- Start one-to-one conversations and exchange text, images, stickers, and voice messages.
- Reply to messages, react with emoji, and follow sent and read states.
- See typing, presence, last-seen, unread, and recent activity indicators.
- Browse shared media and open images in a swipeable full-screen gallery.
- Make experimental realtime voice calls and keep call events in the conversation timeline.
- Block, unblock, and report users through privacy-oriented flows.
- Use the interface in English, Brazilian Portuguese, or German.
- Reopen recent conversations from locally stored data when the network is unavailable.

Deletion is intentionally private to each participant. Removing a message or conversation hides it only for the person who requested the deletion; it does not erase the other participant's copy. This decision treats chat history as potentially important context instead of allowing one person to silently remove evidence from both sides.

## Product and design

Veyra was developed screen by screen, with each feature reviewed before moving to the next one. That process helped keep visual and behavioral decisions consistent across authentication, conversations, people, messages, calls, and profiles.

The interface is supported by a small native design system containing semantic colors, typography, spacing, radii, glass backgrounds, buttons, text fields, and avatars. Reusable components include SwiftUI previews so that important states can be reviewed without navigating through the whole app.

The app also includes its own icon, launch experience, dark-first palette, loading and empty states, keyboard handling, and localized copy. These details are part of the product work rather than decoration added at the end.

## How it is built

Veyra is written in **Swift 6** and targets **iOS 17 or later**. The user interface is built with **SwiftUI**, while **SwiftData** provides the local conversation and message cache.

The codebase is organized by feature and follows an MVVM-inspired approach. Views focus on presentation, view models coordinate user actions and state, and repository protocols isolate local and remote data access. This separation also makes it possible to use lightweight in-memory implementations in previews and tests.

Realtime accounts, conversations, messages, presence, media, and privacy rules are backed by **Supabase**. Voice-call media uses **WebRTC**. Both dependencies are managed with Swift Package Manager; the project does not use CocoaPods.

Some of the technical areas explored in the project include:

- Realtime subscriptions and optimistic message updates.
- Local-first loading and reconciliation with remote data.
- Image and audio upload, playback, waveform rendering, and caching.
- Per-user deletion, blocking rules, and Row Level Security.
- Dependency injection through repository contracts.
- String Catalog localization and runtime language selection.
- Unit tests with Swift Testing and automated build checks with GitHub Actions.

## Project structure

The main application is grouped by responsibility:

```text
Veyra/
├── App/                 # Application entry point and navigation
├── Core/                # Backend access, persistence, localization, and design system
├── Features/
│   ├── Authentication/
│   ├── Calls/
│   ├── Contacts/
│   ├── Conversations/
│   ├── Messages/
│   └── Profile/
├── Configuration/       # Build settings and String Catalogs
└── Resources/           # App icon, launch artwork, and assets
```

Supabase migrations, functions, triggers, and security policies are intentionally kept in the separate [Veyra-Supabase repository](https://github.com/MauroJuliano/Veyra-Supabase). This keeps this repository focused on the native iOS work while still making the supporting backend reproducible and reviewable.

## Running locally

You will need Xcode 16.4 or newer and an iOS 17+ simulator or device.

1. Clone this repository.
2. Open `Veyra.xcodeproj`.
3. Select the `Veyra` scheme and an iOS simulator.
4. Run with `Command-R`.

The project can build without private credentials, but features that depend on Supabase will remain unavailable. To connect your own backend:

1. Copy `Veyra/Configuration/Secrets.xcconfig.example` to `Veyra/Configuration/Secrets.xcconfig`.
2. Add your Supabase project URL and publishable key.
3. Apply the migrations from the separate backend repository.

Never place a `service_role` key or database password in the iOS project. The local secrets file is ignored by Git.

Run the test suite with `Command-U`.

## Development approach

The repository history is part of the portfolio. Work was divided into focused branches and pull requests so that design, architecture, data, and realtime behavior could evolve in reviewable steps.

The general workflow was:

- Build one small product outcome at a time.
- Keep features separated and reusable where it makes sense.
- Add tests for important state and data behavior.
- Compile and validate changes before moving forward.
- Keep backend infrastructure outside the native app repository.

## Current status

Veyra is a feature-rich portfolio build, but it should still be treated as a development project rather than a production-ready messenger. A public release would require additional security review, broader device and network testing, production monitoring, moderation operations, legal documentation, accessibility validation, and deployment infrastructure.

Within its intended scope, the project demonstrates the full journey from an early-career idea to a structured, realtime SwiftUI application with a distinct product identity.
