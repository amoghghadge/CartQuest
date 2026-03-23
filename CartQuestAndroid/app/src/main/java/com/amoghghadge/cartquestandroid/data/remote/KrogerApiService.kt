package com.amoghghadge.cartquestandroid.data.remote

import com.amoghghadge.cartquestandroid.data.model.KrogerProduct
import com.amoghghadge.cartquestandroid.data.model.KrogerStore
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.Query

interface KrogerApiService {
    @GET("v1/products")
    suspend fun searchProducts(
        @Header("Authorization") auth: String,
        @Query("filter.term") term: String,
        @Query("filter.locationId") locationId: String? = null,
        @Query("filter.limit") limit: Int = 20
    ): KrogerProductResponse

    @GET("v1/locations")
    suspend fun searchLocations(
        @Header("Authorization") auth: String,
        @Query("filter.lat.near") lat: Double,
        @Query("filter.lon.near") lon: Double,
        @Query("filter.radiusInMiles") radius: Int = 10,
        @Query("filter.limit") limit: Int = 10
    ): KrogerLocationResponse

    companion object {
        fun create(): KrogerApiService {
            val logging = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            val client = OkHttpClient.Builder()
                .addInterceptor(logging)
                .build()
            return Retrofit.Builder()
                .baseUrl("https://api.kroger.com/")
                .client(client)
                .addConverterFactory(GsonConverterFactory.create())
                .build()
                .create(KrogerApiService::class.java)
        }
    }
}

data class KrogerProductResponse(val data: List<KrogerProduct>)
data class KrogerLocationResponse(val data: List<KrogerStore>)
