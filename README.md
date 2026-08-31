# Veyra

[![CI](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml/badge.svg)](https://github.com/MauroJuliano/Veyra/actions/workflows/ci.yml)

A modern SwiftUI chat application built step by step with native Apple frameworks.

## Status

Veyra is being rebuilt incrementally. Every feature is developed in an isolated pull request and must compile and pass its tests before the next feature starts.

The current milestone contains only the application bootstrap. Product screens and data persistence will be introduced in later pull requests.

## Requirements

- Xcode 16.4 or newer
- iOS 17.0 or newer
- Swift 6

## Technology

- SwiftUI
- Swift Testing
- Apple frameworks only

The project intentionally has no CocoaPods, third-party packages, or backend dependency.

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
