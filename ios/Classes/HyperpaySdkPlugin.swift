import Flutter
import UIKit
import SafariServices
import PassKit
import OPPWAMobile

public class HyperpaySdkPlugin: NSObject, FlutterPlugin {

    private var channel: FlutterMethodChannel?
    private var paymentProvider: OPPPaymentProvider?
    private var checkoutProvider: OPPCheckoutProvider?
    private var pendingResult: FlutterResult?
    private var pendingResourcePath: String?
    private var safariVC: SFSafariViewController?
    private var shopperResultUrl: String?

    // MARK: - FlutterPlugin Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.hyperpay.sdk/channel",
            binaryMessenger: registrar.messenger()
        )
        let instance = HyperpaySdkPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    // MARK: - MethodCallHandler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setup":
            handleSetup(call, result: result)
        case "checkoutReadyUI":
            handleCheckoutReadyUI(call, result: result)
        case "payCustomUI":
            handlePayCustomUI(call, result: result)
        case "payApplePay":
            handlePayApplePay(call, result: result)
        case "getPaymentStatus":
            handleGetPaymentStatus(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Setup

    private func handleSetup(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let mode = args["mode"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "mode is required", details: nil))
            return
        }

        let providerMode: OPPProviderMode = mode == "live" ? .live : .test
        paymentProvider = OPPPaymentProvider(mode: providerMode)
        result(nil)
    }

    // MARK: - ReadyUI Checkout

    private func handleCheckoutReadyUI(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let checkoutId = args["checkoutId"] as? String,
              let brands = args["brands"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGS", message: "checkoutId and brands are required", details: nil))
            return
        }

        guard let provider = paymentProvider else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call setup() before making payments", details: nil))
            return
        }

        let shopperUrl = args["shopperResultUrl"] as? String
        let applePayConfig = args["applePayConfig"] as? [String: Any]

        // Configure checkout settings
        let checkoutSettings = OPPCheckoutSettings()
        checkoutSettings.paymentBrands = brands
        checkoutSettings.storePaymentDetails = .prompt

        if let shopperUrl = shopperUrl {
            checkoutSettings.shopperResultURL = "\(shopperUrl)://callback"
            self.shopperResultUrl = shopperUrl
        }

        // Apple Pay configuration
        if let applePayConfig = applePayConfig {
            let merchantId = applePayConfig["merchantId"] as? String ?? ""
            let countryCode = applePayConfig["countryCode"] as? String ?? ""
            let currencyCode = applePayConfig["currencyCode"] as? String ?? ""
            let amount = applePayConfig["amount"] as? Double ?? 0.0
            let companyName = applePayConfig["companyName"] as? String ?? ""

            let paymentRequest = OPPPaymentProvider.paymentRequest(
                withMerchantIdentifier: merchantId,
                countryCode: countryCode
            )
            paymentRequest.currencyCode = currencyCode
            paymentRequest.paymentSummaryItems = [
                PKPaymentSummaryItem(label: companyName, amount: NSDecimalNumber(value: amount))
            ]
            checkoutSettings.applePayPaymentRequest = paymentRequest
        }

        // Language
        if let lang = args["lang"] as? String {
            checkoutSettings.language = lang
        }

        // Create checkout provider
        checkoutProvider = OPPCheckoutProvider(
            paymentProvider: provider,
            checkoutID: checkoutId,
            settings: checkoutSettings
        )
        checkoutProvider?.delegate = self

        pendingResult = result

        // Present checkout
        DispatchQueue.main.async { [weak self] in
            self?.checkoutProvider?.presentCheckout(
                forSubmittingTransactionCompletionHandler: { [weak self] (transaction, error) in
                    self?.handleCheckoutCompletion(transaction: transaction, error: error)
                },
                cancelHandler: { [weak self] in
                    self?.handleCheckoutCancellation()
                }
            )
        }
    }

    private func handleCheckoutCompletion(transaction: OPPTransaction?, error: Error?) {
        guard let pending = pendingResult else { return }

        if let error = error as NSError? {
            let detail = "domain=\(error.domain), code=\(error.code), userInfo=\(error.userInfo)"
            pending([
                "isSuccess": false,
                "isCanceled": false,
                "errorCode": "\(error.code)",
                "errorMessage": "\(error.localizedDescription) [\(detail)]",
            ] as [String: Any])
            pendingResult = nil
            return
        }

        guard let transaction = transaction else {
            pending([
                "isSuccess": false,
                "isCanceled": false,
                "errorCode": "UNKNOWN",
                "errorMessage": "No transaction returned",
            ] as [String: Any])
            pendingResult = nil
            return
        }

        if transaction.type == .synchronous {
            pending([
                "isSuccess": true,
                "isCanceled": false,
                "resourcePath": transaction.resourcePath ?? "",
                "transactionType": "sync",
            ] as [String: Any])
            pendingResult = nil
        } else {
            // Async — keep pendingResult alive, wait for URL scheme callback
            // OPPCheckoutProvider handles the redirect UI internally
            pendingResourcePath = transaction.resourcePath
        }
    }

    private func handleCheckoutCancellation() {
        guard let pending = pendingResult else { return }
        pending([
            "isSuccess": false,
            "isCanceled": true,
        ] as [String: Any])
        pendingResult = nil
    }

    // MARK: - CustomUI Payment

    private func handlePayCustomUI(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let checkoutId = args["checkoutId"] as? String,
              let brand = args["brand"] as? String,
              let cardNumber = args["cardNumber"] as? String,
              let holder = args["holder"] as? String,
              let expiryMonth = args["expiryMonth"] as? String,
              let expiryYear = args["expiryYear"] as? String,
              let cvv = args["cvv"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "All card fields are required", details: nil))
            return
        }

        guard let provider = paymentProvider else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call setup() before making payments", details: nil))
            return
        }

        let tokenize = args["tokenize"] as? Bool ?? false
        let shopperUrl = args["shopperResultUrl"] as? String

        NSLog("[HyperPay] CustomUI native params: checkoutId=%@, brand=%@, card=%@, holder=%@, expiry=%@/%@, cvv=%@, tokenize=%d, shopperUrl=%@",
              checkoutId, brand, cardNumber, holder, expiryMonth, expiryYear, cvv, tokenize ? 1 : 0, shopperUrl ?? "nil")

        do {
            let paymentParams = try OPPCardPaymentParams(
                checkoutID: checkoutId,
                paymentBrand: brand,
                holder: holder,
                number: cardNumber,
                expiryMonth: expiryMonth,
                expiryYear: expiryYear,
                cvv: cvv
            )
            NSLog("[HyperPay] OPPCardPaymentParams created successfully")

            if tokenize {
                paymentParams.isTokenizationEnabled = true
            }

            if let shopperUrl = shopperUrl {
                paymentParams.shopperResultURL = "\(shopperUrl)://callback"
                self.shopperResultUrl = shopperUrl
            }

            let transaction = OPPTransaction(paymentParams: paymentParams)

            pendingResult = result

            NSLog("[HyperPay] Submitting transaction to provider...")

            provider.submitTransaction(transaction) { [weak self] (transaction, error) in
                guard let self = self, let pending = self.pendingResult else { return }

                if let error = error as NSError? {
                    self.pendingResult = nil
                    let detail = "domain=\(error.domain), code=\(error.code), userInfo=\(error.userInfo)"
                    pending([
                        "isSuccess": false,
                        "isCanceled": false,
                        "errorCode": "\(error.code)",
                        "errorMessage": "\(error.localizedDescription) [\(detail)]",
                    ] as [String: Any])
                    return
                }

                if transaction.type == .synchronous {
                    self.pendingResult = nil
                    pending([
                        "isSuccess": true,
                        "isCanceled": false,
                        "resourcePath": transaction.resourcePath ?? "",
                        "transactionType": "sync",
                    ] as [String: Any])
                } else {
                    // Async — keep pendingResult alive, wait for URL scheme callback
                    self.pendingResourcePath = transaction.resourcePath
                    if let redirectUrl = transaction.redirectURL {
                        DispatchQueue.main.async {
                            self.openSafariVC(url: redirectUrl)
                        }
                    }
                }
            }
        } catch {
            NSLog("[HyperPay] OPPCardPaymentParams creation failed: %@", error.localizedDescription)
            result(FlutterError(
                code: "PAYMENT_ERROR",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }

    // MARK: - Apple Pay

    private func handlePayApplePay(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let checkoutId = args["checkoutId"] as? String,
              let merchantId = args["merchantId"] as? String,
              let countryCode = args["countryCode"] as? String,
              let currencyCode = args["currencyCode"] as? String,
              let amount = args["amount"] as? Double,
              let companyName = args["companyName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "All Apple Pay fields are required", details: nil))
            return
        }

        guard let provider = paymentProvider else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call setup() before making payments", details: nil))
            return
        }

        let paymentRequest = OPPPaymentProvider.paymentRequest(
            withMerchantIdentifier: merchantId,
            countryCode: countryCode
        )
        paymentRequest.currencyCode = currencyCode
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(label: companyName, amount: NSDecimalNumber(value: amount))
        ]

        do {
            let params = try OPPApplePayPaymentParams(
                checkoutID: checkoutId,
                paymentBrand: "APPLEPAY"
            )

            pendingResult = result

            // Present Apple Pay
            if let rootVC = self.rootViewController() {
                let applePayController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
                applePayController?.delegate = self

                rootVC.present(applePayController!, animated: true) {
                    // Store params for submission after Apple Pay authorization
                    self.pendingApplePayParams = params
                    self.pendingApplePayProvider = provider
                }
            } else {
                result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Cannot present Apple Pay", details: nil))
            }
        } catch {
            result(FlutterError(
                code: "APPLE_PAY_ERROR",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }

    private var pendingApplePayParams: OPPApplePayPaymentParams?
    private var pendingApplePayProvider: OPPPaymentProvider?

    // MARK: - Payment Status

    private func handleGetPaymentStatus(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let resourcePath = args?["resourcePath"] as? String

        // Payment status verification should be done server-side.
        result([
            "status": "PENDING_SERVER_VERIFICATION",
            "resourcePath": resourcePath as Any,
        ] as [String: Any])
    }

    // MARK: - Safari VC for Async Payments

    private func openSafariVC(url: URL) {
        guard let rootVC = rootViewController() else { return }

        safariVC = SFSafariViewController(url: url)
        safariVC?.delegate = self
        rootVC.present(safariVC!, animated: true, completion: nil)
    }

    // MARK: - URL Scheme Handling

    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard let shopperUrl = shopperResultUrl,
              url.scheme?.caseInsensitiveCompare(shopperUrl) == .orderedSame else {
            return false
        }

        // Dismiss Safari VC (CustomUI async)
        if let safariVC = safariVC {
            safariVC.dismiss(animated: true, completion: nil)
            self.safariVC = nil
        }

        // Dismiss ReadyUI checkout and resolve pending result
        if let pending = pendingResult {
            let resourcePath = pendingResourcePath ?? ""
            pendingResourcePath = nil

            if let checkoutProvider = checkoutProvider {
                checkoutProvider.dismissCheckout(animated: true) {
                    pending([
                        "isSuccess": true,
                        "isCanceled": false,
                        "resourcePath": resourcePath,
                        "transactionType": "async",
                    ] as [String: Any])
                }
            } else {
                pending([
                    "isSuccess": true,
                    "isCanceled": false,
                    "resourcePath": resourcePath,
                    "transactionType": "async",
                ] as [String: Any])
            }
            pendingResult = nil
        }

        return true
    }

    // MARK: - Helpers

    private func rootViewController() -> UIViewController? {
        if #available(iOS 15.0, *) {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            return windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        } else {
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        }
    }
}

// MARK: - OPPCheckoutProviderDelegate

extension HyperpaySdkPlugin: OPPCheckoutProviderDelegate {
    public func checkoutProvider(
        _ checkoutProvider: OPPCheckoutProvider,
        continueSubmitting transaction: OPPTransaction,
        completion: @escaping (String, Bool) -> Void
    ) {
        // Continue with the transaction by default
        completion(transaction.resourcePath ?? "", true)
    }
}

// MARK: - SFSafariViewControllerDelegate

extension HyperpaySdkPlugin: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        safariVC = nil
    }
}

// MARK: - PKPaymentAuthorizationViewControllerDelegate

extension HyperpaySdkPlugin: PKPaymentAuthorizationViewControllerDelegate {
    public func paymentAuthorizationViewControllerDidFinish(
        _ controller: PKPaymentAuthorizationViewController
    ) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if self.pendingResult != nil && self.pendingApplePayParams == nil {
                // User cancelled without authorizing
                let pending = self.pendingResult
                self.pendingResult = nil
                pending?([
                    "isSuccess": false,
                    "isCanceled": true,
                ] as [String: Any])
            }
        }
    }

    public func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        guard let params = pendingApplePayParams,
              let provider = pendingApplePayProvider else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            return
        }

        let paramsWithToken = try? OPPApplePayPaymentParams(
            checkoutID: params.checkoutID,
            paymentBrand: "APPLEPAY",
            tokenData: payment.token.paymentData
        )
        guard let finalParams = paramsWithToken else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            return
        }

        let transaction = OPPTransaction(paymentParams: finalParams)
        provider.submitTransaction(transaction) { [weak self] (transaction, error) in
            guard let self = self else { return }
            let pending = self.pendingResult
            self.pendingResult = nil
            self.pendingApplePayParams = nil
            self.pendingApplePayProvider = nil

            if let error = error {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                pending?([
                    "isSuccess": false,
                    "isCanceled": false,
                    "errorCode": "\((error as NSError).code)",
                    "errorMessage": error.localizedDescription,
                ] as [String: Any])
                return
            }

            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            pending?([
                "isSuccess": true,
                "isCanceled": false,
                "resourcePath": transaction.resourcePath ?? "",
                "transactionType": "sync",
            ] as [String: Any])
        }
    }
}
