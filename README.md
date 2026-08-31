# Veyra

[![CI](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml/badge.svg)](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml)

A modern SwiftUI chat application built step by step with native Apple frameworks.

## Status

Veyra is being rebuilt incrementally. Every feature is developed in an isolated pull request and must compile and pass its tests before the next feature starts.

The current milestone includes the visual foundation, typed navigation, a local conversation list, and an in-memory message timeline with a composer. Message persistence will be introduced in later pull requests.

## Requirements

- Xcode 16.4 or newer
- iOS 17.0 or newer
- Swift 6

## Technology

- SwiftUI
- Swift Testing
- Apple frameworks only

The project intentionally has no CocoaPods, third-party packages, or backend dependency.

## Design system

The interface is built from semantic, reusable SwiftUI primitives:

- Adaptive light and dark color roles
- Spacing, corner-radius, and typography scales
- Avatar, primary button, and text-field components
- A preview catalog for visual review in Xcode

Product screens should consume these primitives instead of introducing one-off visual values.

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
