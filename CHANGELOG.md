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
