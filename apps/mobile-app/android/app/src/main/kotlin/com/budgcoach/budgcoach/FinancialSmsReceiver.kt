package com.budgcoach.budgcoach

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

object SmsBridge {
    var events: EventChannel.EventSink? = null
}

object SmsInboxStore {
    private const val preferencesName = "budgcoach_financial_sms"
    private const val pendingKey = "pending_messages"
    private const val maximumPending = 100

    fun append(context: Context, sender: String, body: String): Map<String, String> {
        val entry = mapOf(
            "id" to UUID.randomUUID().toString(),
            "sender" to sender,
            "body" to body,
        )
        val values = read(context)
        values.put(JSONObject(entry))
        while (values.length() > maximumPending) values.remove(0)
        write(context, values)
        return entry
    }

    fun pending(context: Context): List<Map<String, String>> {
        val values = read(context)
        return (0 until values.length()).mapNotNull { index ->
            val value = values.optJSONObject(index) ?: return@mapNotNull null
            mapOf(
                "id" to value.optString("id"),
                "sender" to value.optString("sender"),
                "body" to value.optString("body"),
            )
        }
    }

    fun acknowledge(context: Context, ids: List<String>) {
        if (ids.isEmpty()) return
        val idSet = ids.toSet()
        val current = read(context)
        val retained = JSONArray()
        for (index in 0 until current.length()) {
            val value = current.optJSONObject(index) ?: continue
            if (value.optString("id") !in idSet) retained.put(value)
        }
        write(context, retained)
    }

    private fun read(context: Context): JSONArray {
        val raw = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getString(pendingKey, "[]") ?: "[]"
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun write(context: Context, values: JSONArray) {
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putString(pendingKey, values.toString())
            .apply()
    }
}

class FinancialSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        Telephony.Sms.Intents.getMessagesFromIntent(intent)
            .groupBy { it.originatingAddress.orEmpty() }
            .forEach { (sender, parts) ->
                val body = parts.joinToString(separator = "") { it.messageBody.orEmpty() }.trim()
                if (!isFinancialMessage(sender, body)) return@forEach
                val entry = SmsInboxStore.append(context, sender, body)
                SmsBridge.events?.success(entry)
            }
    }

    private fun isFinancialMessage(sender: String, body: String): Boolean {
        val normalized = "$sender $body".lowercase()
        val institution = listOf(
            "esewa", "khalti", "imepay", "ime pay", "connectips", "fonepay",
            "bank", "wallet", "nabil", "global ime", "nic asia", "prabhu",
            "siddhartha", "sanima", "machhapuchchhre", "kumari",
        ).any(normalized::contains)
        val money = Regex(
            "(?:npr|rs\\.?|रू)\\s*[0-9,]+(?:\\.[0-9]{1,2})?",
            RegexOption.IGNORE_CASE,
        ).containsMatchIn(body)
        val transaction = listOf(
            "debited", "credited", "withdrawn", "deposited", "paid", "sent",
            "received", "purchase", "transaction", "txn",
        ).any(normalized::contains)
        return institution && money && transaction
    }
}
