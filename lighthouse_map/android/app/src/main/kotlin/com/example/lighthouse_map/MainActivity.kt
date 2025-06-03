package com.example.lighthouse_map

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createLocationNotificationChannel() // Llama a la función para crear el canal
    }

    private fun createLocationNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "location_tracking_channel_id" // Debe coincidir con el channelId en Flutter
            val channelName = "Rastreo de Ubicación"
            val channelDescription = "Notificaciones para el seguimiento de ubicación en segundo plano"
            val importance = NotificationManager.IMPORTANCE_LOW // O HIGH, para una notificación menos intrusiva

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                setSound(null, null) // Opcional: sin sonido
                enableVibration(false) // Opcional: sin vibración
            }

            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}