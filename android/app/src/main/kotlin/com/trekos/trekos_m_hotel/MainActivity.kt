package com.trekos.trekos_m_hotel

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.trekos.hotel/pdf_viewer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openPdfExternal") {
                val filePath = call.argument<String>("filePath")
                if (filePath.isNullOrBlank()) {
                    result.error("INVALID_PATH", "Ruta de archivo vacía", null)
                    return@setMethodCallHandler
                }

                try {
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "El archivo no existe en: $filePath", null)
                        return@setMethodCallHandler
                    }

                    // La autoridad coincide exactamente con AndroidManifest.xml: ${applicationId}.fileprovider
                    val authority = "${applicationContext.packageName}.fileprovider"
                    val contentUri: Uri = FileProvider.getUriForFile(applicationContext, authority, file)

                    // Crear Intent ACTION_VIEW específico para documentos PDF
                    val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(contentUri, "application/pdf")
                        clipData = ClipData.newRawUri("Comprobante PDF", contentUri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }

                    // Envolver en chooser para que el sistema Android despliegue el selector ("Abrir con")
                    val chooserIntent = Intent.createChooser(viewIntent, "Abrir con").apply {
                        clipData = ClipData.newRawUri("Comprobante PDF", contentUri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }

                    // Conceder permisos de lectura a todas las aplicaciones que pueden abrir PDFs
                    val resInfoList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        packageManager.queryIntentActivities(
                            viewIntent,
                            PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.queryIntentActivities(viewIntent, PackageManager.MATCH_DEFAULT_ONLY)
                    }

                    for (resolveInfo in resInfoList) {
                        val targetPackage = resolveInfo.activityInfo.packageName
                        grantUriPermission(targetPackage, contentUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }

                    startActivity(chooserIntent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INTENT_ERROR", e.localizedMessage ?: e.toString(), null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
