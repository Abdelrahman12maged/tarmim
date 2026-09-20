package com.tarmim.fixly

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.tarmim.fixly/sms"
    private val PERMISSION_REQUEST_CODE = 9988
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermissions" -> {
                    val smsPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
                    val phoneStatePermission = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
                    result.success(mapOf(
                        "hasSmsPermission" to smsPermission,
                        "hasPhoneStatePermission" to phoneStatePermission
                    ))
                }
                "requestPermissions" -> {
                    val permissions = mutableListOf(Manifest.permission.SEND_SMS)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                        permissions.add(Manifest.permission.READ_PHONE_STATE)
                    }

                    val missing = permissions.filter {
                        ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                    }

                    if (missing.isEmpty()) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(this, missing.toTypedArray(), PERMISSION_REQUEST_CODE)
                    }
                }
                "getSimCards" -> {
                    try {
                        val simList = getAvailableSimCards()
                        result.success(simList)
                    } catch (e: Exception) {
                        result.error("SIM_ERROR", e.message, null)
                    }
                }
                "sendDirectSms" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    val subId = call.argument<Int>("subscriptionId")

                    if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                        result.success(mapOf(
                            "success" to false,
                            "code" to "invalid_arguments",
                            "message" to "رقم الهاتف أو نص الرسالة فارغ"
                        ))
                        return@setMethodCallHandler
                    }

                    // Check SMS permission first
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                        result.success(mapOf(
                            "success" to false,
                            "code" to "permission_denied",
                            "message" to "إذن إرسال الرسائل (SEND_SMS) غير مفعل"
                        ))
                        return@setMethodCallHandler
                    }

                    sendSmsDirect(phone, message, subId, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getAvailableSimCards(): List<Map<String, Any>> {
        val resultList = mutableListOf<Map<String, Any>>()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
            resultList.add(mapOf(
                "subscriptionId" to -1,
                "slotIndex" to 0,
                "displayName" to "شريحة الهاتف الافتراضية",
                "carrierName" to "الشبكة الافتراضية",
                "countryIso" to "",
                "isDefault" to true
            ))
            return resultList
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            resultList.add(mapOf(
                "subscriptionId" to -1,
                "slotIndex" to 0,
                "displayName" to "الشريحة الافتراضية (بدون إذن قراءة الشرائح)",
                "carrierName" to "غير محدد",
                "countryIso" to "",
                "isDefault" to true
            ))
            return resultList
        }

        val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
        val activeSubscriptions: List<SubscriptionInfo>? = subscriptionManager?.activeSubscriptionInfoList

        if (activeSubscriptions.isNullOrEmpty()) {
            return emptyList()
        }

        val defaultSubId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            SubscriptionManager.getDefaultSubscriptionId()
        } else {
            -1
        }

        for (info in activeSubscriptions) {
            val carrier = info.carrierName?.toString()?.trim() ?: "شبكة غير معروفة"
            val display = info.displayName?.toString()?.trim() ?: "شريحة ${info.simSlotIndex + 1}"
            val country = info.countryIso?.uppercase() ?: ""

            val title = if (carrier.isNotEmpty() && carrier.lowercase() != "unknown") {
                "شريحة ${info.simSlotIndex + 1} ($carrier)"
            } else {
                "شريحة ${info.simSlotIndex + 1} ($display)"
            }

            resultList.add(mapOf(
                "subscriptionId" to info.subscriptionId,
                "slotIndex" to info.simSlotIndex,
                "displayName" to title,
                "carrierName" to carrier,
                "countryIso" to country,
                "isDefault" to (info.subscriptionId == defaultSubId || (defaultSubId == -1 && info.simSlotIndex == 0))
            ))
        }

        return resultList
    }

    private fun sendSmsDirect(phone: String, message: String, subscriptionId: Int?, result: MethodChannel.Result) {
        val cleanPhone = phone.replace(Regex("[^0-9+]"), "")
        if (cleanPhone.isEmpty()) {
            result.success(mapOf(
                "success" to false,
                "code" to "invalid_phone",
                "message" to "رقم الهاتف غير صالح"
            ))
            return
        }

        val smsManager: SmsManager = try {
            if (subscriptionId != null && subscriptionId != -1 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    getSystemService(SmsManager::class.java).createForSubscriptionId(subscriptionId)
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
                }
            } else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }
            }
        } catch (e: Exception) {
            result.success(mapOf(
                "success" to false,
                "code" to "sms_manager_error",
                "message" to "تعذر تهيئة مدير الرسائل للشريحة: ${e.localizedMessage}"
            ))
            return
        }

        val actionId = "com.tarmim.fixly.SMS_SENT_${System.currentTimeMillis()}_${(1000..9999).random()}"
        val sentIntent = Intent(actionId)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val sentPI = PendingIntent.getBroadcast(this, 0, sentIntent, flags)

        val parts = smsManager.divideMessage(message)
        val totalParts = parts.size
        val partsReceived = AtomicInteger(0)
        val isCompleted = AtomicBoolean(false)
        val mainHandler = Handler(Looper.getMainLooper())

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val currentCode = resultCode
                val count = partsReceived.incrementAndGet()

                if (isCompleted.get()) return

                if (currentCode != Activity.RESULT_OK) {
                    if (isCompleted.compareAndSet(false, true)) {
                        safeUnregisterReceiver(this)
                        val errorInfo = mapResultCodeToError(currentCode)
                        mainHandler.post {
                            result.success(mapOf(
                                "success" to false,
                                "code" to errorInfo.first,
                                "message" to errorInfo.second
                            ))
                        }
                    }
                    return
                }

                if (count >= totalParts) {
                    if (isCompleted.compareAndSet(false, true)) {
                        safeUnregisterReceiver(this)
                        mainHandler.post {
                            result.success(mapOf(
                                "success" to true,
                                "code" to "sent",
                                "message" to "تم إرسال الرسالة بنجاح"
                            ))
                        }
                    }
                }
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, IntentFilter(actionId), Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, IntentFilter(actionId))
            }
        } catch (e: Exception) {
            result.success(mapOf(
                "success" to false,
                "code" to "receiver_error",
                "message" to "تعذر تسجيل مستقبل تقرير الإرسال: ${e.localizedMessage}"
            ))
            return
        }

        mainHandler.postDelayed({
            if (isCompleted.compareAndSet(false, true)) {
                safeUnregisterReceiver(receiver)
                result.success(mapOf(
                    "success" to false,
                    "code" to "timeout",
                    "message" to "انتهت مهلة انتظار تأكيد الشبكة، يرجى فحص التغطية والرصيد"
                ))
            }
        }, 12000)

        try {
            if (totalParts > 1) {
                val sentIntents = ArrayList<PendingIntent>()
                for (i in 0 until totalParts) {
                    sentIntents.add(sentPI)
                }
                smsManager.sendMultipartTextMessage(cleanPhone, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(cleanPhone, null, message, sentPI, null)
            }
        } catch (e: Exception) {
            if (isCompleted.compareAndSet(false, true)) {
                safeUnregisterReceiver(receiver)
                result.success(mapOf(
                    "success" to false,
                    "code" to "send_exception",
                    "message" to "فشل إرسال الرسالة من الشريحة: ${e.localizedMessage}"
                ))
            }
        }
    }

    private fun safeUnregisterReceiver(receiver: BroadcastReceiver) {
        try {
            unregisterReceiver(receiver)
        } catch (_: Exception) {}
    }

    private fun mapResultCodeToError(resultCode: Int): Pair<String, String> {
        return when (resultCode) {
            SmsManager.RESULT_ERROR_GENERIC_FAILURE ->
                Pair("no_credit_or_generic", "فشل الإرسال: تأكد من شحن رصيد الشريحة أو توفر باقة رسائل صالحة.")
            SmsManager.RESULT_ERROR_NO_SERVICE ->
                Pair("no_service", "فشل الإرسال: لا توجد تغطية شبكة محمول في موقعك حالياً.")
            SmsManager.RESULT_ERROR_RADIO_OFF ->
                Pair("radio_off", "فشل الإرسال: وضع الطيران مفعّل أو إرسال الشبكة متوقف.")
            SmsManager.RESULT_ERROR_NULL_PDU ->
                Pair("null_pdu", "خطأ في حزمة الرسالة (PDU)، يرجى مراجعة مشغل الخدمة.")
            10 ->
                Pair("limit_exceeded", "تم تجاوز الحد الأقصى المسموح لعدد الرسائل في الدقيقة.")
            else ->
                Pair("failed_$resultCode", "فشل إرسال الرسالة، رمز الخطأ من الشبكة: $resultCode")
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(allGranted)
            pendingPermissionResult = null
        }
    }
}
