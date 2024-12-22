package com.pinciat.external_path

import android.content.Context
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Environment
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File

/** ExternalPathPlugin */
class ExternalPathPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "external_path")
        channel.setMethodCallHandler(this)
    }

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "external_path")
            channel.setMethodCallHandler(ExternalPathPlugin())
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getExternalStorageDirectories" -> result.success(getExternalStorageDirectories())
            "getExternalStoragePublicDirectory" -> result.success(
                getExternalStoragePublicDirectory(
                    call.argument<String>("type")
                )
            )
            "getSDCardStorageDirectory" -> result.success(getSDCardPath())
            "getUSBStorageDirectories" -> result.success(getUSBPaths())
            else -> result.notImplemented()
        }
    }

    private fun getExternalStorageDirectories(): ArrayList<String> {
        val appsDir = context.getExternalFilesDirs(null)
        return appsDir.map { it.absolutePath }.toCollection(ArrayList())
    }

    private fun getExternalStoragePublicDirectory(type: String?): String {
        return Environment.getExternalStoragePublicDirectory(type).toString()
    }

    private fun getSDCardPath(): String? {
        val externalStorageVolumes = context.getExternalFilesDirs(null)
        return externalStorageVolumes.firstOrNull { isSDCard(it) }?.let {
            it.path.substringBefore("/Android/data")
        }
    }

    private fun isSDCard(file: File): Boolean {
        val state = Environment.getExternalStorageState(file)
        return Environment.MEDIA_MOUNTED == state &&
                Environment.isExternalStorageRemovable(file) &&
                !Environment.isExternalStorageEmulated(file)
    }

    private fun getUSBPaths(): ArrayList<String> {
        val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        val usbDevices = usbManager.deviceList
        return usbDevices.values.mapNotNull { device ->
            val usbPath = "/storage/${device.deviceName}"
            if (isDirectoryExists(usbPath)) usbPath else null
        }.toCollection(ArrayList())
    }

    private fun isDirectoryExists(path: String): Boolean {
        val directory = File(path)
        return directory.exists() && directory.isDirectory
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}