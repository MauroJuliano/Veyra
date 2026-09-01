# Veyra

[![CI](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml/badge.svg)](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml)

A modern SwiftUI chat application built step by step with native Apple frameworks.

## Status

Veyra is being rebuilt incrementally. Every feature is developed in an isolated pull request and must compile and pass its tests before the next feature starts.

The current milestone includes local login, registration, remembered sessions and logout, typed navigation, searchable persisted conversations, contact selection, and an in-memory message timeline with a composer.

## Requirements

- Xcode 16.4 or newer
- iOS 17.0 or newer
- Swift 6

## Technology

- SwiftUI
- SwiftData
- Swift Testing
- Repository-based data access with dependency injection
- Apple frameworks only

The project intentionally has no CocoaPods, third-party packages, or backend dependency. Conversations are persisted locally with SwiftData.

## Design system

The interface is built from semantic, reusable SwiftUI primitives:

- Adaptive light and dark color roles
- Spacing, corner-radius, and typography scales
- Avatar, primary button, and text-field components
- A preview catalog for visual review in Xcode

Product screens should consume these primitives instead of introducing one-off visual values.

The chat home uses a dark-first visual direction with a purple atmosphere, elevated conversation cards, and native tab navigation.
The message timeline continues this direction with contact context, asymmetric bubbles, delivery status, and a focused composer.

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
