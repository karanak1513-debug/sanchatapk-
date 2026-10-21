package com.aistudio.sanchay.savtrkr

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Collections
import java.util.LinkedHashMap
import java.util.regex.Pattern

open class UpiNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "SanchayNotificationListener"
        private const val PREFS_NAME = "sanchay_offline_intercepts"
        private const val PREF_KEY_PENDING_JSON = "pending_transactions_json"
        private const val DEDUPE_WINDOW_MS = 60000L // 60-second window across Bank SMS & UPI

        // Anti-duplication memory cache: hash(amount + direction + (timestamp / 60000))
        private val recentHashes = Collections.synchronizedMap(
            object : LinkedHashMap<String, Long>(50, 0.75f, true) {
                override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Long>?): Boolean {
                    return size > 150
                }
            }
        )

        var listenerCallback: ((Map<String, Any>) -> Unit)? = null
        val queuedTransactions = Collections.synchronizedList(mutableListOf<Map<String, Any>>())

        fun getAndClearPersistedTransactions(context: Context): List<Map<String, Any>> {
            val list = mutableListOf<Map<String, Any>>()
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val rawJson = prefs.getString(PREF_KEY_PENDING_JSON, "[]") ?: "[]"
                val jsonArray = JSONArray(rawJson)
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    val map = mutableMapOf<String, Any>()
                    val keys = obj.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        map[key] = obj.get(key)
                    }
                    list.add(map)
                }
                prefs.edit().remove(PREF_KEY_PENDING_JSON).apply()
            } catch (e: Exception) {
                Log.e(TAG, "Error reading persisted transactions: ${e.message}")
            }
            return list
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Notification listener onStartCommand invoked - START_STICKY active")
        return START_STICKY
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "Sanchay Background Notification Listener connected and active.")
        // Ensure service resilience against battery optimization
        try {
            val component = ComponentName(this, NotificationListener::class.java)
            requestRebind(component)
        } catch (e: Exception) {
            Log.d(TAG, "Auto-restart rebind notice: ${e.message}")
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "Sanchay Notification Listener disconnected. Triggering auto-rebind...")
        try {
            val component = ComponentName(this, NotificationListener::class.java)
            requestRebind(component)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to auto-restart service: ${e.message}")
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // 1. Target Package Listening Scope
        val isGPay = packageName == "com.google.android.apps.nbu.paisa.user"
        val isPhonePe = packageName == "com.phonepe.app"
        val isPaytm = packageName == "net.one97.paytm"
        val isBhim = packageName == "in.org.npci.upiapp"
        val isCred = packageName == "com.dreamplug.androidapp"
        val isAmazonPay = packageName == "in.amazon.mShop.android.shopping"
        val isWhatsApp = packageName == "com.whatsapp"
        val isJupiter = packageName == "money.jupiter"
        val isFi = packageName == "money.epifi"
        val isSlice = packageName == "indwin.c3.shareSpend"
        val isNavi = packageName == "com.naviapp"

        val isGoogleMessages = packageName == "com.google.android.apps.messaging"
        val isSamsungMessages = packageName == "com.samsung.android.messaging"
        val isGenericSms = packageName == "com.android.mms" ||
                packageName.contains("sms", ignoreCase = true) ||
                packageName.contains("mms", ignoreCase = true) ||
                packageName.contains("messaging", ignoreCase = true)

        val isSms = isGoogleMessages || isSamsungMessages || isGenericSms
        val isUpiApp = isGPay || isPhonePe || isPaytm || isBhim || isCred || isAmazonPay || isWhatsApp || isJupiter || isFi || isSlice || isNavi

        if (!isUpiApp && !isSms) {
            return
        }

        val source = when {
            isGPay -> "Google Pay"
            isPhonePe -> "PhonePe"
            isPaytm -> "Paytm"
            isBhim -> "BHIM"
            isCred -> "CRED"
            isAmazonPay -> "Amazon Pay"
            isWhatsApp -> "WhatsApp Pay"
            isJupiter -> "Jupiter"
            isFi -> "Fi Money"
            isSlice -> "Slice"
            isNavi -> "Navi"
            isGoogleMessages -> "Google Messages"
            isSamsungMessages -> "Samsung Messages"
            else -> "Bank SMS"
        }

        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val combinedText = "$title $text $bigText".trim()

        if (combinedText.isEmpty()) return

        // 2. Monetary Amount Detection Engine:
        // (?:(?:rs|inr|₹)\.?\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:inr|rs|₹))
        val amountRegex = Pattern.compile(
            """(?:(?:rs|inr|₹)\.?\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:inr|rs|₹))""",
            Pattern.CASE_INSENSITIVE
        )
        val matcher = amountRegex.matcher(combinedText)

        if (!matcher.find()) {
            return
        }

        val group1 = matcher.group(1)
        val group2 = matcher.group(2)
        val rawAmountStr = (if (!group1.isNullOrEmpty()) group1 else group2) ?: return
        val cleanAmountStr = rawAmountStr.replace(",", "").trim()
        val amount = cleanAmountStr.toDoubleOrNull() ?: return

        if (amount <= 0.0) return

        val lowerText = combinedText.lowercase()

        // 3. Direction Classification (Keyword Classification Engine)
        val isCredit = isCreditTransaction(combinedText)
        val type = if (isCredit) "credit" else "debit"

        // 4. Channel Classification (ATM / CASH vs UPI vs BANK)
        val isAtmCash = lowerText.contains("atm") ||
                lowerText.contains("wdl") ||
                lowerText.contains("cash dispensed") ||
                lowerText.contains("cash withdrawal") ||
                lowerText.contains("withdrawn")

        val channel = when {
            isAtmCash -> "CASH"
            isPhonePe || isGPay || isPaytm || isBhim || isCred || lowerText.contains("upi") -> "UPI"
            else -> "BANK"
        }

        // 5. Merchant / Entity Extraction
        val merchant = extractMerchant(title, combinedText, isAtmCash, type)
        val category = inferCategory(merchant, lowerText, type, channel)

        // 6. Anti-Duplication Hashing: hash(amount + direction + (timestamp / 60000))
        val currentTimestamp = System.currentTimeMillis()
        val minuteSlot = currentTimestamp / 60000L
        val dedupeSignature = "${amount}_${type}_$minuteSlot"

        val lastSeen = recentHashes[dedupeSignature]
        if (lastSeen != null && (currentTimestamp - lastSeen) < DEDUPE_WINDOW_MS) {
            Log.d(TAG, "Cross-channel duplicate alert suppressed: $dedupeSignature (from $source)")
            return
        }
        recentHashes[dedupeSignature] = currentTimestamp

        // 7. Structured Intercepted Payload
        val txId = "tx_${currentTimestamp}_${(100..999).random()}"
        val transactionMap = mapOf(
            "id" to txId,
            "amount" to amount,
            "merchant" to merchant,
            "type" to type,
            "source" to source,
            "channel" to channel,
            "category" to category,
            "tag" to "Auto-Intercepted",
            "isAutoCaptured" to true,
            "timestamp" to currentTimestamp,
            "rawText" to combinedText
        )

        Log.i(TAG, "Intercepted Financial Event: [$channel] $source -> $merchant : ₹$amount ($type)")

        // 8. Stream to Flutter Runtime or Persist to Queue
        val callback = listenerCallback
        if (callback != null) {
            callback(transactionMap)
        } else {
            queuedTransactions.add(transactionMap)
            saveToSharedPreferences(transactionMap)
        }
    }

    private fun extractMerchant(title: String, body: String, isAtmCash: Boolean, type: String): String {
        if (isAtmCash) {
            val atmPattern = Pattern.compile("""(?:at|from)\s+([A-Za-z0-9\s&]{2,30}\s*ATM)""", Pattern.CASE_INSENSITIVE)
            val mAtm = atmPattern.matcher(body)
            if (mAtm.find()) {
                val candidate = mAtm.group(1)?.trim()
                if (!candidate.isNullOrBlank()) return candidate
            }
            return "ATM Cash Withdrawal"
        }

        // Check "[Payer] paid you" or "[Payer] sent you"
        val paidYouPattern = Pattern.compile("""^([A-Za-z0-9\s&]{2,30})\s+(?:paid you|sent you)""", Pattern.CASE_INSENSITIVE)
        val mPaidYou = paidYouPattern.matcher(body.trim())
        if (mPaidYou.find()) {
            val candidate = mPaidYou.group(1)?.trim()
            if (!candidate.isNullOrBlank() && !candidate.contains("rs", ignoreCase = true) && !candidate.contains("inr", ignoreCase = true)) {
                return candidate
            }
        }

        // Check prepositions: "to ([A-Za-z0-9\s]+)", "at ([A-Za-z0-9\s]+)", "from ([A-Za-z0-9\s]+)"
        val prepPattern = Pattern.compile(
            """(?:paid to|transfer to|sent to|purchase at|spent at|to|at|from)\s+([A-Za-z0-9\s&]{2,30})""",
            Pattern.CASE_INSENSITIVE
        )
        val mPrep = prepPattern.matcher(body)
        if (mPrep.find()) {
            val candidate = mPrep.group(1)?.trim()
            if (!candidate.isNullOrBlank() &&
                !candidate.contains("rs", ignoreCase = true) &&
                !candidate.contains("inr", ignoreCase = true) &&
                candidate.length in 2..30
            ) {
                val clean = candidate
                    .split(" on ")[0]
                    .split(" for ")[0]
                    .split(" ref")[0]
                    .split(" txn")[0]
                    .trim()
                if (clean.isNotEmpty()) return clean
            }
        }

        // Top merchant matches
        val knownMerchants = listOf(
            "Swiggy", "Zomato", "Uber", "Ola", "Rapido", "Amazon", "Flipkart", "Myntra",
            "Blinkit", "Zepto", "BigBasket", "Starbucks", "Blue Tokai", "McDonald",
            "Dominos", "KFC", "BookMyShow", "PVR", "Netflix", "Spotify", "Apple",
            "Airtel", "Jio", "Vi", "BESCOM", "DMRC", "Tata Neu"
        )
        for (m in knownMerchants) {
            if (body.contains(m, ignoreCase = true)) {
                return m
            }
        }

        // Fallback to title
        val cleanTitle = title.replace(Regex("""(?i)(alert|bank|upi|sms|notification|payment|update|debited|credited)"""), "").trim()
        if (cleanTitle.isNotEmpty() && cleanTitle.length in 2..30) {
            return cleanTitle
        }

        return if (type == "credit") "Direct Inflow" else "Card / UPI Outflow"
    }

    private fun inferCategory(merchant: String, body: String, type: String, channel: String): String {
        if (channel == "CASH") return "Cash & ATM"

        if (type == "credit") {
            if (body.contains("salary")) return "Salary"
            if (body.contains("cashback")) return "Cashback"
            if (body.contains("refund")) return "Refund"
            return "Received Payment"
        }

        val text = "$merchant $body".lowercase()
        return when {
            text.contains("swiggy") || text.contains("zomato") || text.contains("restaurant") ||
                    text.contains("cafe") || text.contains("food") || text.contains("dining") ||
                    text.contains("mcdonald") || text.contains("burger") || text.contains("pizza") ||
                    text.contains("coffee") || text.contains("blue tokai") || text.contains("starbucks") -> "Food & Dining"

            text.contains("uber") || text.contains("ola") || text.contains("rapido") ||
                    text.contains("metro") || text.contains("dmrc") || text.contains("transit") ||
                    text.contains("petrol") || text.contains("fuel") || text.contains("parking") -> "Transit"

            text.contains("airtel") || text.contains("jio") || text.contains("vi") ||
                    text.contains("electricity") || text.contains("water") || text.contains("broadband") ||
                    text.contains("bescom") || text.contains("bill") || text.contains("recharge") -> "Bills & Utilities"

            text.contains("amazon") || text.contains("flipkart") || text.contains("myntra") ||
                    text.contains("shopping") || text.contains("zara") || text.contains("h&m") ||
                    text.contains("movie") || text.contains("pvr") || text.contains("bookmyshow") -> "Lifestyle"

            text.contains("zerodha") || text.contains("groww") || text.contains("mutual fund") ||
                    text.contains("sip") || text.contains("stock") || text.contains("invest") -> "Investment"

            else -> "General"
        }
    }

    private fun isCreditTransaction(text: String): Boolean {
        val lower = text.lowercase()
        if (lower.contains("paid you") ||
            lower.contains("received") ||
            lower.contains("credited") ||
            lower.contains("cashback") ||
            lower.contains("refund") ||
            lower.contains("added to your account") ||
            lower.contains("money received")) {
            return true
        }

        if (lower.contains("paid to") ||
            lower.contains("debited") ||
            lower.contains("sent to") ||
            lower.contains("spent at") ||
            lower.contains("payment to") ||
            lower.contains("transferred to")) {
            return false
        }

        if (lower.contains("paid") && !lower.contains("paid you")) {
            return false
        }

        return false
    }

    private fun saveToSharedPreferences(tx: Map<String, Any>) {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(PREF_KEY_PENDING_JSON, "[]") ?: "[]"
            val jsonArray = JSONArray(rawJson)
            val jsonObject = JSONObject(tx)
            jsonArray.put(jsonObject)
            prefs.edit().putString(PREF_KEY_PENDING_JSON, jsonArray.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error persisting offline intercepted transaction: ${e.message}")
        }
    }
}
