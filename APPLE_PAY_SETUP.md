# Apple Pay Merchant ID Configuration Guide

This guide walks through setting up Apple Pay for use with the HyperPay SDK.

## Overview

There are 4 steps to configure Apple Pay:

1. Create Merchant ID identifier
2. Create Apple Payment Processing Certificate
3. Create Merchant Certificate
4. Verify website domain (for web payments)

Plus iOS project setup in Xcode.

---

## 1. Create Merchant ID Identifier

- Go to [developer.apple.com](https://developer.apple.com)
- Log in using your Apple ID
- Click **Account** > **Certificates, IDs & Profiles**

<img src="screenshots/apple_pay_setup/01_certificates_ids_profiles.png" height="300">

- In **Certificates, Identifiers & Profiles**, click **Identifiers** in the sidebar
- Click the add button **(+)** on the top left
- Create a **Merchant IDs** identifier for your business

<img src="screenshots/apple_pay_setup/02_create_merchant_id.png" height="300">

- Select **Merchant IDs**, press **Continue**
- Enter a description and identifier (e.g. `merchant.com.your.app`), press **Continue** then **Register**

---

## 2. Create Apple Payment Processing Certificate

After registering the Merchant ID identifier, create a payment processing certificate to encrypt payment information.

<img src="screenshots/apple_pay_setup/03_payment_processing_cert.png" height="300">

- Select your **Merchant ID**
- Select **No** and continue
- Select the processing file from your computer

<img src="screenshots/apple_pay_setup/04_upload_processing_file.png" height="300">

- Apple Pay payment processing certificate is created
- **Download** the certificate

---

## 3. Create Merchant Certificate

Create an Apple Pay merchant identity certificate.

- Select your **Merchant ID**

<img src="screenshots/apple_pay_setup/05_merchant_cert.png" height="300">

- Add the merchant file from your computer
- Select **Continue**, then **Download** the certificate

<img src="screenshots/apple_pay_setup/06_upload_merchant_file.png" height="300">

---

## 4. Verify Domain (for Web Payments)

- Add your website URL domain (e.g. `www.example.com`)

<img src="screenshots/apple_pay_setup/07_verify_domain.png" height="300">

- Click **Download** to download the verification text file
- Upload this file to a `/.well-known/` folder in the HTTP root of your server
- Once it is in place, click the **Verify** button to confirm

<img src="screenshots/apple_pay_setup/08_verify_button.png" height="300">

---

## 5. iOS Project Setup in Xcode

- Open your Xcode project (**Runner**)
- Go to **Signing & Capabilities**
- Click **(+) Capability**
- Select **Apple Pay**
- Check your **Merchant ID**

<img src="screenshots/apple_pay_setup/09_xcode_capability.png" height="300">

---

## Using Apple Pay with HyperPay SDK

Once configured, use the `merchantId` in your Flutter code:

```dart
final result = await HyperpaySdk.payApplePay(
  checkoutId: checkoutId,
  merchantId: 'merchant.com.your.app', // the ID you registered above
  countryCode: 'SA',
  currencyCode: 'SAR',
  amount: 100.0,
  companyName: 'Your Company',
);
```

Or pass it via `ApplePayConfig` in ReadyUI:

```dart
final result = await HyperpaySdk.checkoutReadyUI(
  checkoutId: checkoutId,
  brands: ['VISA', 'MASTER', 'MADA'],
  shopperResultUrl: 'com.your.app.payments',
  applePayConfig: ApplePayConfig(
    merchantId: 'merchant.com.your.app',
    countryCode: 'SA',
    currencyCode: 'SAR',
    amount: 100.0,
    companyName: 'Your Company',
  ),
);
```

---

_Based on the guide by [Ahmad Elkhyary](https://github.com/ahmedelkhyary/applepay_merchantId_config)._
