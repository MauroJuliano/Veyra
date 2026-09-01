# Veyra

[![CI](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml/badge.svg)](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml)

A modern SwiftUI chat application built step by step with native Apple frameworks.

## Status

Veyra is being rebuilt incrementally. Every feature is developed in an isolated pull request and must compile and pass its tests before the next feature starts.

The current milestone includes local authentication, remembered sessions, editable profile details, typed navigation, searchable persisted conversations, contact selection, and an in-memory message timeline with a composer.

## Requirements

- Xcode 16.4 or newer
- iOS 17.0 or newer
- Swift 6

## Technology

- SwiftUI
- SwiftData
- Supabase Swift via Swift Package Manager
- Swift Testing
- Repository-based data access with dependency injection
- Apple frameworks only

The project intentionally has no CocoaPods. Its only application dependency is the official Supabase Swift SDK, managed with Swift Package Manager. Conversations remain persisted locally with SwiftData while Supabase is introduced incrementally as the remote backend. Local repositories remain available for previews, tests, and offline-oriented development.

## Supabase configuration

1. Copy `Veyra/Configuration/Secrets.xcconfig.example` to `Veyra/Configuration/Secrets.xcconfig`.
2. Add the project URL and publishable key from the Supabase dashboard.
3. Never add a `service_role` key or database password to the iOS project.

The local secrets file is ignored by Git. Builds without it remain valid, but remote Supabase features stay unavailable.

## Design system

The interface is built from semantic, reusable SwiftUI primitives:

- Adaptive light and dark color roles
- Spacing, corner-radius, and typography scales
- Avatar, primary button, and text-field components
- A preview catalog for visual review in Xcode

Product screens should consume these primitives instead of introducing one-off visual values.

The chat home uses a dark-first visual direction with a purple atmosphere, elevated conversation cards, and native tab navigation.
The message timeline continues this direction with contact context, asymmetric bubbles, delivery status, and a focused composer.
Profile uses the same dark plum palette as the rest of Veyra, with restrained glass surfaces and purple accents for a native settings feel.

## Running the project

1. Clone the repository.
2. Open `Veyra.xcodeproj`.
3. Select the `Veyra` scheme and an iOS simulator.
4. Run the application with `Command-R`.

Run the test suite with `Command-U`.

## Development workflow

- Create one branch per feature using `feature/<number>-<description>`.
- Keep pull requests small and focused on a single outcome.
- Add or update tests alongside production code.
- Merge only after the project builds and all tests pass.
