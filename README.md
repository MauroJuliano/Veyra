# Veyra

[![CI](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml/badge.svg)](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml)

Veyra is a native iOS messaging app that combines familiar communication flows with a quieter, more atmospheric visual identity. It was rebuilt in SwiftUI from an early-career project as an exercise in product thinking, architecture, realtime communication, and thoughtful interaction design.

> **Portfolio notice**
>
> Veyra is an educational portfolio project. It is not a commercial product, is not available on the App Store, and is not currently intended for an official public launch. Some features and infrastructure are experimental.

---

## App walkthrough

<!-- Replace this placeholder with the walkthrough thumbnail and video link. -->
<!-- Suggested asset: Docs/Assets/Veyra-Experience.png -->

> 🎬 **Video walkthrough coming soon**
> A complete look at authentication, people discovery, realtime messaging, shared media, voice messages, calls, and profile settings will be added here.

---

## Product preview

### Messaging experience

Find people by name or username, start one-to-one conversations, and exchange text, images, stickers, and voice messages. The timeline supports replies, emoji reactions, delivery and read states, typing presence, last-seen information, unread indicators, and call history. Veyra also explores experimental WebRTC voice calls with incoming, active, timeout, and missed-call states.

<!-- Add one image containing Home, Chat, Voice Message, and Call screens. -->
> 🖼️ **Messaging preview coming soon**

### People, media, and profile

Profiles include a name, unique username, bio, email, and photo. Shared images can be browsed in a dedicated gallery, while privacy flows make it possible to block, unblock, and report users. The interface is available in English, Brazilian Portuguese, and German.

<!-- Add one image containing People, Shared Media, and Profile screens. -->
> 🖼️ **People and profile preview coming soon**

---

## About the project

The original version of this idea was one of the apps I created near the beginning of my career. Rebuilding it offered a useful way to revisit the same product with more experience: moving from isolated screens to a connected experience with authentication, persistent profiles, realtime data, offline continuity, privacy rules, and reusable UI foundations.

The interface uses a dark purple palette, glass-inspired surfaces, and restrained neon accents. These choices give Veyra its own personality while preserving interactions that feel natural in a messaging app.

One deliberate product decision is per-user deletion. Removing a message or conversation hides it only for the person who requested it; the other participant keeps their copy. This avoids allowing one person to silently remove shared context from both sides.

## Under the hood

Veyra is written in **Swift 6**, built with **SwiftUI**, and targets **iOS 17 or later**. The codebase follows an MVVM-inspired approach and is organized by feature, with repository contracts separating presentation, local persistence, and remote services.

- **SwiftUI** for the interface and reusable design system.
- **SwiftData** for locally cached conversations, messages, contacts, and offline continuity.
- **Supabase** for authentication, profiles, realtime messaging, presence, media, and privacy rules.
- **WebRTC** for experimental voice-call media.
- **String Catalogs** for English, Brazilian Portuguese, and German.
- **Swift Testing and GitHub Actions** for automated behavior and build validation.

Message updates are optimistic, recent content is presented from the local cache first, and remote state is reconciled afterward. Images and audio include upload, playback, waveform, and caching behavior. In-memory repository implementations keep previews and tests independent from the live backend.

The native repository is structured around `App`, `Core`, and feature folders for Authentication, Calls, Contacts, Conversations, Messages, and Profile. Supabase migrations, database functions, triggers, and Row Level Security policies live separately in [Veyra-Supabase](https://github.com/MauroJuliano/Veyra-Supabase), keeping this repository focused on the iOS application.

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

## Current status

Veyra should be treated as a portfolio build rather than a production-ready messenger. The repository history reflects an incremental workflow, with features developed in focused pull requests and validated before the next step.

A real public release would require additional security review, broader device and network testing, production monitoring, moderation operations, legal documentation, accessibility validation, and deployment infrastructure. Within its intended scope, Veyra demonstrates the journey from an early-career idea to a structured realtime SwiftUI application with a distinct product identity.
