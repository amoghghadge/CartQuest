package com.amoghghadge.cartquestandroid.data.remote

import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject

class KrogerAuthManager(
    private val clientId: String,
    private val clientSecret: String
) {
    private var token: String? = null
    private var expiresAt: Long = 0
    private val mutex = Mutex()
    private val client = OkHttpClient()

    suspend fun getToken(): String {
        mutex.withLock {
            if (token != null && System.currentTimeMillis() < expiresAt) return token!!
            val credentials = Base64.encodeToString(
                "$clientId:$clientSecret".toByteArray(), Base64.NO_WRAP
            )
            val request = Request.Builder()
                .url("https://api.kroger.com/v1/connect/oauth2/token")
                .post("grant_type=client_credentials&scope=product.compact".toRequestBody("application/x-www-form-urlencoded".toMediaType()))
                .header("Authorization", "Basic $credentials")
                .build()
            val response = withContext(Dispatchers.IO) {
                client.newCall(request).execute()
            }
            val json = JSONObject(response.body!!.string())
            token = json.getString("access_token")
            expiresAt = System.currentTimeMillis() + (json.getInt("expires_in") * 1000L) - 60_000
            return token!!
        }
    }
}
