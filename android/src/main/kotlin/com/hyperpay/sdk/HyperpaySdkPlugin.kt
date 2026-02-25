package com.hyperpay.sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import com.oppwa.mobile.connect.checkout.dialog.CheckoutActivity
import com.oppwa.mobile.connect.checkout.dialog.CheckoutActivityResult
import com.oppwa.mobile.connect.checkout.dialog.CheckoutActivityResultContract
import com.oppwa.mobile.connect.checkout.meta.CheckoutSettings
import com.oppwa.mobile.connect.checkout.meta.CheckoutSkipCVVMode
import com.oppwa.mobile.connect.exception.PaymentError
import com.oppwa.mobile.connect.exception.PaymentException
import com.oppwa.mobile.connect.payment.BrandsValidation
import com.oppwa.mobile.connect.payment.CheckoutInfo
import com.oppwa.mobile.connect.payment.card.CardPaymentParams
import com.oppwa.mobile.connect.payment.token.TokenPaymentParams
import com.oppwa.mobile.connect.provider.Connect
import com.oppwa.mobile.connect.provider.ITransactionListener
import com.oppwa.mobile.connect.provider.OppPaymentProvider
import com.oppwa.mobile.connect.provider.Transaction
import com.oppwa.mobile.connect.provider.TransactionType
import com.oppwa.mobile.connect.provider.ThreeDSWorkflowListener

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import com.google.android.gms.wallet.PaymentDataRequest

class HyperpaySdkPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, ITransactionListener {

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var paymentProvider: OppPaymentProvider? = null
    private var providerMode: Connect.ProviderMode = Connect.ProviderMode.TEST

    private var pendingResult: Result? = null
    private var checkoutLauncher: ActivityResultLauncher<CheckoutSettings>? = null

    companion object {
        private const val CHANNEL_NAME = "com.hyperpay.sdk/channel"
    }

    // region FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    // endregion

    // region ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        registerCheckoutLauncher()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        registerCheckoutLauncher()
    }

    override fun onDetachedFromActivity() {
        activity = null
        activityBinding = null
        checkoutLauncher = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        activityBinding = null
        checkoutLauncher = null
    }

    // endregion

    // region CheckoutActivityResultContract

    private fun registerCheckoutLauncher() {
        val componentActivity = activity as? ComponentActivity ?: return
        checkoutLauncher = componentActivity.registerForActivityResult(
            CheckoutActivityResultContract()
        ) { result: CheckoutActivityResult ->
            handleCheckoutResult(result)
        }
    }

    private fun handleCheckoutResult(result: CheckoutActivityResult) {
        val pending = pendingResult ?: return
        pendingResult = null

        when {
            result.isCanceled -> {
                pending.success(mapOf(
                    "isSuccess" to false,
                    "isCanceled" to true,
                ))
            }
            result.paymentError != null -> {
                val error = result.paymentError!!
                pending.success(mapOf(
                    "isSuccess" to false,
                    "isCanceled" to false,
                    "errorCode" to error.errorCode,
                    "errorMessage" to error.errorInfo,
                ))
            }
            result.resourcePath != null -> {
                pending.success(mapOf(
                    "isSuccess" to true,
                    "isCanceled" to false,
                    "resourcePath" to result.resourcePath,
                    "transactionType" to "sync",
                ))
            }
            else -> {
                pending.success(mapOf(
                    "isSuccess" to false,
                    "isCanceled" to false,
                    "errorCode" to "UNKNOWN",
                    "errorMessage" to "Unknown checkout result",
                ))
            }
        }
    }

    // endregion

    // region MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setup" -> handleSetup(call, result)
            "checkoutReadyUI" -> handleCheckoutReadyUI(call, result)
            "payCustomUI" -> handlePayCustomUI(call, result)
            "payApplePay" -> handlePayApplePay(result)
            "getPaymentStatus" -> handleGetPaymentStatus(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleSetup(call: MethodCall, result: Result) {
        val mode = call.argument<String>("mode")
        providerMode = if (mode == "live") {
            Connect.ProviderMode.LIVE
        } else {
            Connect.ProviderMode.TEST
        }
        paymentProvider = OppPaymentProvider(context!!, providerMode)
        paymentProvider?.setThreeDSWorkflowListener(object : ThreeDSWorkflowListener {
            override fun onThreeDSChallengeRequired(): Activity? {
                return activity
            }
        })
        result.success(null)
    }

    private fun handleCheckoutReadyUI(call: MethodCall, result: Result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Plugin is not attached to an Activity", null)
            return
        }
        if (checkoutLauncher == null) {
            result.error("NO_LAUNCHER", "Checkout launcher not registered. Ensure your Activity extends ComponentActivity.", null)
            return
        }

        val checkoutId = call.argument<String>("checkoutId") ?: run {
            result.error("INVALID_ARGS", "checkoutId is required", null)
            return
        }
        val brands = call.argument<List<String>>("brands") ?: run {
            result.error("INVALID_ARGS", "brands is required", null)
            return
        }
        val shopperResultUrl = call.argument<String>("shopperResultUrl")
        val googlePayConfig = call.argument<Map<String, Any>>("googlePayConfig")
        val lang = call.argument<String>("lang")

        try {
            val paymentBrands = HashSet(brands)
            val checkoutSettings = CheckoutSettings(checkoutId, paymentBrands, providerMode)
            checkoutSettings.setSkipCVVMode(CheckoutSkipCVVMode.FOR_STORED_CARDS)

            if (shopperResultUrl != null) {
                checkoutSettings.shopperResultUrl = "${shopperResultUrl}://callback"
            }

            if (lang != null) {
                checkoutSettings.locale = lang
            }

            // Configure Google Pay if provided
            if (googlePayConfig != null) {
                val merchantId = googlePayConfig["gatewayMerchantId"] as? String ?: ""
                val merchantName = googlePayConfig["merchantName"] as? String ?: ""
                val countryCode = googlePayConfig["countryCode"] as? String ?: ""
                val totalPrice = (googlePayConfig["totalPrice"] as? Number)?.toDouble() ?: 0.0
                val currencyCode = googlePayConfig["currencyCode"] as? String ?: ""

                val googlePayJsonBuilder = com.oppwa.mobile.connect.checkout.googlepay.PaymentDataRequestJsonBuilder()
                    .setGatewayMerchantId(merchantId)
                    .setMerchantName(merchantName)
                    .setTransactionInfo(
                        com.oppwa.mobile.connect.checkout.googlepay.TransactionInfoJsonBuilder()
                            .setTotalPrice(totalPrice)
                            .setTotalPriceStatus("FINAL")
                            .setCountryCode(countryCode)
                            .setCurrencyCode(currencyCode)
                    )
                    .setCardPaymentMethod(
                        com.oppwa.mobile.connect.checkout.googlepay.CardPaymentMethodJsonBuilder()
                    )

                checkoutSettings.setGooglePayPaymentDataRequestJson(googlePayJsonBuilder)
            }

            pendingResult = result
            checkoutLauncher!!.launch(checkoutSettings)
        } catch (e: Exception) {
            result.error("CHECKOUT_ERROR", e.message, null)
        }
    }

    private fun handlePayCustomUI(call: MethodCall, result: Result) {
        if (paymentProvider == null) {
            result.error("NOT_INITIALIZED", "Call setup() before making payments", null)
            return
        }

        val checkoutId = call.argument<String>("checkoutId") ?: run {
            result.error("INVALID_ARGS", "checkoutId is required", null)
            return
        }
        val brand = call.argument<String>("brand") ?: run {
            result.error("INVALID_ARGS", "brand is required", null)
            return
        }
        val cardNumber = call.argument<String>("cardNumber") ?: run {
            result.error("INVALID_ARGS", "cardNumber is required", null)
            return
        }
        val holder = call.argument<String>("holder") ?: run {
            result.error("INVALID_ARGS", "holder is required", null)
            return
        }
        val expiryMonth = call.argument<String>("expiryMonth") ?: run {
            result.error("INVALID_ARGS", "expiryMonth is required", null)
            return
        }
        val expiryYear = call.argument<String>("expiryYear") ?: run {
            result.error("INVALID_ARGS", "expiryYear is required", null)
            return
        }
        val cvv = call.argument<String>("cvv") ?: run {
            result.error("INVALID_ARGS", "cvv is required", null)
            return
        }
        val tokenize = call.argument<Boolean>("tokenize") ?: false
        val shopperResultUrl = call.argument<String>("shopperResultUrl")

        try {
            val paymentParams = CardPaymentParams(
                checkoutId,
                brand,
                cardNumber,
                holder,
                expiryMonth,
                expiryYear,
                cvv
            )

            if (tokenize) {
                paymentParams.tokenizationEnabled = true
            }

            if (shopperResultUrl != null) {
                paymentParams.shopperResultUrl = "${shopperResultUrl}://callback"
            }

            paymentProvider!!.setTransactionListener(this)
            pendingResult = result

            val transaction = Transaction(paymentParams)
            paymentProvider!!.submitTransaction(transaction)
        } catch (e: PaymentException) {
            result.error(
                e.error?.errorCode ?: "PAYMENT_ERROR",
                e.error?.errorInfo ?: e.message ?: "Unknown payment error",
                null
            )
        } catch (e: Exception) {
            result.error("PAYMENT_ERROR", e.message, null)
        }
    }

    private fun handlePayApplePay(result: Result) {
        result.error("UNSUPPORTED", "Apple Pay is not available on Android", null)
    }

    private fun handleGetPaymentStatus(call: MethodCall, result: Result) {
        val resourcePath = call.argument<String>("resourcePath")

        // Payment status verification should be done server-side.
        // This method provides the resource path to the Dart layer so
        // the app can call its backend to verify.
        result.success(mapOf(
            "status" to "PENDING_SERVER_VERIFICATION",
            "resourcePath" to resourcePath,
        ))
    }

    // endregion

    // region ITransactionListener

    override fun transactionCompleted(transaction: Transaction) {
        val pending = pendingResult ?: return
        pendingResult = null

        val resourcePath = transaction.transactionParams?.get("resourcePath") as? String

        if (transaction.transactionType == TransactionType.SYNC) {
            pending.success(mapOf(
                "isSuccess" to true,
                "isCanceled" to false,
                "resourcePath" to resourcePath,
                "transactionType" to "sync",
            ))
        } else {
            // Async transaction — need to redirect
            val redirectUrl = transaction.redirectUrl
            if (redirectUrl != null && activity != null) {
                try {
                    val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(redirectUrl))
                    activity!!.startActivity(browserIntent)
                } catch (_: Exception) {
                    // Browser open failed, still return the result
                }
            }
            pending.success(mapOf(
                "isSuccess" to true,
                "isCanceled" to false,
                "resourcePath" to resourcePath,
                "transactionType" to "async",
            ))
        }
    }

    override fun transactionFailed(transaction: Transaction, paymentError: PaymentError) {
        val pending = pendingResult ?: return
        pendingResult = null

        pending.success(mapOf(
            "isSuccess" to false,
            "isCanceled" to false,
            "errorCode" to paymentError.errorCode,
            "errorMessage" to paymentError.errorInfo,
        ))
    }

    // endregion
}
