package com.example.flutter_application_1

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Abre otras apps del celular (Yape, apps de bancos) directamente, sin pasar por Play Store.
        // getLaunchIntentForPackage es la forma correcta: un Intent MAIN/LAUNCHER implícito no se
        // resuelve con startActivity ni con resolveActivity(MATCH_DEFAULT_ONLY), por eso antes
        // la app creía que Yape no estaba instalado y abría la Play Store.
        // Los paquetes deben estar declarados en <queries> del AndroidManifest (Android 11+).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "credisol/apps")
            .setMethodCallHandler { call, result ->
                val paquete = call.argument<String>("paquete")
                val intent = paquete?.let { packageManager.getLaunchIntentForPackage(it) }
                when (call.method) {
                    "instalada" -> result.success(intent != null)
                    "abrir" -> {
                        if (intent == null) {
                            result.success(false)
                        } else {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
