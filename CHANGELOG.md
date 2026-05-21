## 2.1.0

- Add `HyperpaySdk.requestBinInfo(checkoutId, bin)` — wraps the OPPWA SDK's BIN service so callers can use HyperPay's authoritative BIN database to detect MADA (and other brands) instead of maintaining their own hardcoded BIN list. Returns `HyperpayBinInfo { brands, binType, type }` with a convenience `isMada` getter. Use this on add-card to route MADA cards through the DB flow and avoid PA-rail declines on Saudi-issued co-branded cards.

## 2.0.1

- Fix example app failing to build after the 2.0.0 breaking change — the example's Apple Pay screen still called `payApplePay` without the now-required `shopperResultUrl`, causing a compile error. No library changes.

## 2.0.0

**Breaking change**: `HyperpaySdk.payApplePay()` now requires `shopperResultUrl`.

The earlier 1.0.5 fix added `shopperResultURL` assignment on the iOS Apple Pay params, but the value was never plumbed through from Dart — the `payApplePay` Dart method didn't accept a `shopperResultUrl` argument, so the iOS plugin always saw a nil value and submitted Apple Pay payments to HyperPay with no `shopperResultURL`, causing `200.300.404 invalid or missing parameter`. Now mirrors the Ready UI flow: callers must pass `shopperResultUrl`, the Dart→iOS bridge forwards it, the iOS handler captures it, and the submission delegate assigns it on `OPPApplePayPaymentParams` before `submitTransaction`.

## 1.0.5

- Fix Apple Pay on iOS rejected by HyperPay with `200.300.404 invalid or missing parameter` — `shopperResultURL` was set on the card path but not on `OPPApplePayPaymentParams` before submission, so wallet payments reached HyperPay without it. Now mirrors the card flow and assigns `shopperResultURL` on the Apple Pay params before submitting the transaction. (Incomplete: see 2.0.0.)

## 1.0.4

- Fix Apple Pay cancel hanging forever on iOS — `pendingResult` was never called when user dismissed the payment sheet

## 1.0.3

- Added Apple Pay Merchant ID configuration guide with screenshots
- Fixed README links to use absolute URLs for pub.dev compatibility

## 1.0.2

- Fix package description length for pub.dev validation

## 1.0.1

- Redesigned example app with multi-screen layout (splash, home, saved cards)
- Added "Add Card" flow — tokenize cards without making a payment (PA + createRegistration)
- Extracted shared business logic into PaymentService
- Custom card form now opens in a modal bottom sheet
- Added .env.example for easier example app setup
- Added screenshots to README
- Added production integration guide with backend flow diagram
- Added UI color customization documentation

## 1.0.0

- Initial release wrapping HyperPay OPPWA Mobile SDK v7.4.0
- ReadyUI and CustomUI payment flows
- Support for VISA, MasterCard, MADA, Apple Pay, Google Pay, STC Pay
- Tokenization / stored cards
- 3DS2 authentication
- Test and Live payment modes
- Shopper result URL / callback scheme handling
- Payment status checking
