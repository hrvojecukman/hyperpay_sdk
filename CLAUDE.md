# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter plugin wrapping the HyperPay OPPWA Mobile SDK v7.4.0. Provides ReadyUI (pre-built checkout), CustomUI (card form), Apple Pay (iOS), and Google Pay (Android) payment flows. Supports VISA, MasterCard, MADA, STC Pay, 3DS2, and tokenization.

## Build & Development Commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Lint (uses flutter_lints with prefer_single_quotes)
flutter test                 # Run tests
dart format lib/             # Format code

# Example app
cd example && flutter pub get && flutter run

# iOS pods (from example/ios/)
cd example/ios && pod install --repo-update
```

## Architecture

```
Dart API (lib/hyperpay_sdk.dart - HyperpaySdk class)
    │  MethodChannel: "com.hyperpay.sdk/channel"
    ├── iOS: ios/Classes/HyperpaySdkPlugin.swift
    │   └── OPPWAMobile.xcframework + ipworks3ds XCFramework
    └── Android: android/src/main/kotlin/.../HyperpaySdkPlugin.kt
        └── oppwa.mobile AAR + ipworks3ds AAR
```

**5 method channel calls:** `setup`, `checkoutReadyUI`, `payCustomUI`, `payApplePay`, `getPaymentStatus`

**Transaction types:**
- **Sync** — immediate result with resourcePath for server verification
- **Async** — browser redirect (Safari VC on iOS, Intent on Android) for 3DS/gateway, then URL scheme callback returns resourcePath

**Data models** live in `lib/src/models/`: `PaymentMode`, `PaymentResult`, `CheckoutInfo`, `GooglePayConfig`, `ApplePayConfig`.

## Platform Requirements

- **iOS:** min 13.0, Swift 5.0, static framework required (configured in podspec and example Podfile)
- **Android:** minSdk 24, Java 17, Kotlin 2.0.21, Gradle 8.7.3
- **Native SDK binaries** are not bundled — users must place XCFrameworks in `ios/Frameworks/` and AARs in `android/libs/`

## Linting

`analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` with `avoid_print: false` and `prefer_single_quotes: true`.
