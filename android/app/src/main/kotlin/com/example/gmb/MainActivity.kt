package com.example.gmb

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gijac/energia")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bateriaSinRestriccion" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "pedirSinRestriccion" -> result.success(pedirSinRestriccion())
                    "abrirInicioAutomatico" -> result.success(abrirInicioAutomatico())
                    "fabricante" -> result.success(Build.MANUFACTURER)
                    else -> result.notImplemented()
                }
            }
    }

    /** Diálogo del sistema: "¿Permitir que GIJAC funcione sin restricciones de batería?" */
    private fun pedirSinRestriccion(): Boolean = try {
        startActivity(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
        )
        true
    } catch (e: Exception) {
        false
    }

    /** Pantalla "Inicio automático" de ColorOS (Oppo/Realme/OnePlus); si no existe, abre la ficha de la app */
    private fun abrirInicioAutomatico(): Boolean {
        val pantallas = listOf(
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oplus.battery" to "com.oplus.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
        )
        for ((paquete, clase) in pantallas) {
            try {
                startActivity(Intent().setComponent(ComponentName(paquete, clase)))
                return true
            } catch (e: Exception) {
                // siguiente opción
            }
        }
        return try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
            )
            true
        } catch (e: Exception) {
            false
        }
    }
}