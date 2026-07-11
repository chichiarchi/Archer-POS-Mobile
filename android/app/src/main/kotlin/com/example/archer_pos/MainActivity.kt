package com.example.archer_pos

import android.content.ContentValues
import android.net.Uri
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val BEEP_CHANNEL = "com.example.archer_pos/beep"
    private val PRINTER_CHANNEL = "com.example.archer_pos/printer"
    private val ACTION_USB_PERMISSION = "com.example.archer_pos.USB_PERMISSION"
    
    private var toneGen: ToneGenerator? = null
    private var pendingPrintBytes: ByteArray? = null
    private var pendingPrintResult: MethodChannel.Result? = null

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            if (ACTION_USB_PERMISSION == action) {
                synchronized(this) {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        device?.let {
                            printToDevice(it)
                        }
                    } else {
                        pendingPrintResult?.error("ERR_USB_PERMISSION", "Permission denied for USB device", null)
                        clearPendingPrint()
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            toneGen?.release()
            toneGen = null
        } catch (e: Exception) {}
        try {
            unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            // ignore
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            toneGen = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (e: Exception) {
            // ignore
        }

        val FILE_CHANNEL = "com.example.archer_pos/file_export"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "exportToDownloads") {
                val sourceFilePath = call.argument<String>("sourcePath")
                val fileName = call.argument<String>("fileName")
                if (sourceFilePath == null || fileName == null) {
                    result.error("ERR_INVALID_ARGS", "Missing sourcePath or fileName", null)
                    return@setMethodCallHandler
                }

                val sourceFile = File(sourceFilePath)
                if (!sourceFile.exists()) {
                    result.error("ERR_FILE_NOT_FOUND", "Source file does not exist", null)
                    return@setMethodCallHandler
                }

                try {
                    val resolver = contentResolver
                    val contentValues = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                        put(MediaStore.MediaColumns.MIME_TYPE, "application/x-sqlite3")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/")
                        }
                    }

                    val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                    } else {
                        @Suppress("DEPRECATION")
                        val downloadsDir = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS)
                        val targetFile = File(downloadsDir, fileName)
                        val targetUri = Uri.fromFile(targetFile)
                        downloadsDir.mkdirs()
                        targetUri
                    }

                    if (uri == null) {
                        result.error("ERR_URI_CREATION", "Failed to create destination uri", null)
                        return@setMethodCallHandler
                    }

                    val outputStream: OutputStream? = resolver.openOutputStream(uri)
                    if (outputStream == null) {
                        result.error("ERR_STREAM_OPEN", "Failed to open output stream", null)
                        return@setMethodCallHandler
                    }

                    val inputStream = FileInputStream(sourceFile)
                    val buf = ByteArray(1024)
                    var len: Int
                    while (inputStream.read(buf).also { len = it } > 0) {
                        outputStream.write(buf, 0, len)
                    }
                    inputStream.close()
                    outputStream.flush()
                    outputStream.close()

                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERR_EXPORT_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BEEP_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playBeep") {
                try {
                    if (toneGen == null) {
                        toneGen = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
                    }
                    toneGen?.startTone(ToneGenerator.TONE_PROP_BEEP, 150)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("ERR_PLAY_BEEP", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "printRaw") {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("ERR_INVALID_ARGS", "Bytes argument is null", null)
                    return@setMethodCallHandler
                }
                
                val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
                val printerDevice = findPrinterDevice(usbManager)
                
                if (printerDevice == null) {
                    result.error("ERR_PRINTER_NOT_FOUND", "No USB printer found. Make sure the printer is connected via OTG and powered on.", null)
                    return@setMethodCallHandler
                }

                if (usbManager.hasPermission(printerDevice)) {
                    pendingPrintBytes = bytes
                    pendingPrintResult = result
                    printToDevice(printerDevice)
                } else {
                    pendingPrintBytes = bytes
                    pendingPrintResult = result
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val permissionIntent = PendingIntent.getBroadcast(
                        this, 
                        0, 
                        Intent(ACTION_USB_PERMISSION), 
                        flags
                    )
                    usbManager.requestPermission(printerDevice, permissionIntent)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun findPrinterDevice(usbManager: UsbManager): UsbDevice? {
        val deviceList = usbManager.deviceList
        for (device in deviceList.values) {
            for (i in 0 until device.interfaceCount) {
                val intf = device.getInterface(i)
                if (intf.interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                    return device
                }
            }
            val name = (device.deviceName ?: "").lowercase()
            val prod = (device.productName ?: "").lowercase()
            if (name.contains("printer") || prod.contains("printer") || prod.contains("xprinter") || prod.contains("xp-58")) {
                return device
            }
        }
        if (deviceList.size == 1) {
            return deviceList.values.first()
        }
        return null
    }

    private fun printToDevice(device: UsbDevice) {
        val bytes = pendingPrintBytes
        val result = pendingPrintResult
        if (bytes == null || result == null) return

        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        var printerInterface: UsbInterface? = null
        var endpointOut: UsbEndpoint? = null

        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                printerInterface = intf
                break
            }
        }

        if (printerInterface == null && device.interfaceCount > 0) {
            printerInterface = device.getInterface(0)
        }

        if (printerInterface == null) {
            result.error("ERR_INTERFACE_NOT_FOUND", "USB printer interface not found", null)
            clearPendingPrint()
            return
        }

        for (i in 0 until printerInterface.endpointCount) {
            val ep = printerInterface.getEndpoint(i)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK && ep.direction == UsbConstants.USB_DIR_OUT) {
                endpointOut = ep
                break
            }
        }

        if (endpointOut == null) {
            result.error("ERR_ENDPOINT_NOT_FOUND", "USB printer bulk out endpoint not found", null)
            clearPendingPrint()
            return
        }

        Thread {
            var connection: UsbDeviceConnection? = null
            try {
                connection = usbManager.openDevice(device)
                if (connection == null) {
                    runOnUiThread {
                        result.error("ERR_OPEN_FAILED", "Failed to open USB device connection", null)
                    }
                    return@Thread
                }

                val claimed = connection.claimInterface(printerInterface, true)
                if (!claimed) {
                    runOnUiThread {
                        result.error("ERR_CLAIM_FAILED", "Failed to claim USB interface", null)
                    }
                    return@Thread
                }

                val transferResult = connection.bulkTransfer(endpointOut, bytes, bytes.size, 10000)
                connection.releaseInterface(printerInterface)
                
                runOnUiThread {
                    if (transferResult >= 0) {
                        result.success(true)
                    } else {
                        result.error("ERR_TRANSFER_FAILED", "USB transfer failed (code: $transferResult)", null)
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("ERR_PRINT_EXCEPTION", e.message, null)
                }
            } finally {
                connection?.close()
                runOnUiThread {
                    clearPendingPrint()
                }
            }
        }.start()
    }

    private fun clearPendingPrint() {
        pendingPrintBytes = null
        pendingPrintResult = null
    }
}
