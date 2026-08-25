package com.example.devicelocunlock

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.BatteryManager
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.telephony.TelephonyManager
import android.widget.Toast
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.devicelocunlock/controls"
    private val DEVICE_CHANNEL = "com.example.devicelocunlock/device"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockDevice" -> {
                        val success = lockDevice()
                        result.success(success)
                    }
                    "unlockDevice" -> {
                        // Native তে আনলক করার জন্য কোনো নির্দিষ্ট কাজ নেই, তবে UI আপডেট হবে
                        result.success(true)
                    }
                    "isAdminActive" -> {
                        val active = isDeviceAdminActive()
                        result.success(active)
                    }
                    "activateAdmin" -> {
                        activateDeviceAdmin()
                        result.success(true)
                    }
                    "blockUninstall" -> {
                        val block = call.argument<Boolean>("block") ?: false
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            blockUninstall(packageName, block)
                            result.success(true)
                        } else {
                            result.error("ERROR", "Package name not provided", null)
                        }
                    }
                    "getDeviceId" -> result.success(getAndroidDeviceId())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceInfo" -> {
                        val info = getDeviceInfo()
                        result.success(info)
                    }
                    "getIMEI" -> {
                        result.success(getGeneratedIMEI())
                    }
                    "getDeviceId" -> result.success(getAndroidDeviceId())
                    "getSerialNumber" -> result.success(getGeneratedSerial())
                    "getBatteryLevel" -> result.success(getBatteryLevel())
                    "getStorageInfo" -> result.success(getStorageInfo())
                    "getAndroidVersion" -> result.success(getAndroidVersion())
                    "getDeviceModel" -> result.success(getDeviceModel())
                    else -> result.notImplemented()
                }
            }
    }

    // Android ID থেকে Serial Number তৈরি
    private fun getGeneratedSerial(): String {
        val androidId = getAndroidDeviceId()
        val digits = androidId.filter { it.isDigit() }
        val base = if (digits.length >= 15) digits.substring(0, 15) else digits.padEnd(15, '0')
        return "9$base".take(15)
    }

    // Android ID থেকে imei2 তৈরি
    private fun getGeneratedIMEI2(): String {
        val androidId = getAndroidDeviceId()
        val digits = androidId.filter { it.isDigit() }
        val base = if (digits.length >= 15) digits.substring(0, 15) else digits.padEnd(15, '0')
        return base.dropLast(1) + "1"
    }

    private fun getGeneratedIMEI(): String {
        val androidId = getAndroidDeviceId()
        val digits = androidId.filter { it.isDigit() }
        return if (digits.length >= 15) digits.substring(0, 15) else digits.padEnd(15, '0')
    }

    private fun getDeviceInfo(): Map<String, String> {
        return mapOf(
            "model" to getDeviceModel(),
            "imei" to getGeneratedIMEI(),
            "imei2" to getGeneratedIMEI2(),
            "androidVersion" to getAndroidVersion(),
            "batteryLevel" to getBatteryLevel(),
            "storageUsed" to getStorageInfo(),
            "deviceId" to getAndroidDeviceId(),
            "serialNumber" to getGeneratedSerial(),
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "sdkInt" to Build.VERSION.SDK_INT.toString(),
        )
    }

    private fun getAndroidDeviceId(): String {
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "UNKNOWN_DEVICE"
        } catch (e: Exception) { "UNKNOWN_DEVICE" }
    }

    private fun getDeviceModel(): String {
        return try { "${Build.MANUFACTURER} ${Build.MODEL}" } catch (e: Exception) { "Unknown Model" }
    }

    private fun getAndroidVersion(): String {
        return try { "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})" } catch (e: Exception) { "Unknown Version" }
    }

    private fun getBatteryLevel(): String {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            "$level%"
        } catch (e: Exception) { "N/A" }
    }

    private fun getStorageInfo(): String {
        return try {
            val stat = StatFs(Environment.getDataDirectory().path)
            val blockSize = stat.blockSizeLong
            val totalBlocks = stat.blockCountLong
            val availableBlocks = stat.availableBlocksLong
            val totalSize = totalBlocks * blockSize
            val availableSize = availableBlocks * blockSize
            val usedSize = totalSize - availableSize
            "${formatSize(usedSize)} / ${formatSize(totalSize)}"
        } catch (e: Exception) { "N/A" }
    }

    private fun formatSize(size: Long): String {
        return when {
            size < 1024 -> "$size B"
            size < 1024 * 1024 -> "${size / 1024} KB"
            size < 1024 * 1024 * 1024 -> "${size / (1024 * 1024)} MB"
            else -> "${size / (1024 * 1024 * 1024)} GB"
        }
    }

    private fun lockDevice(): Boolean {
        return try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)
            if (dpm.isAdminActive(adminComponent)) {
                dpm.lockNow()
                Toast.makeText(this, "🔒 Device Locked!", Toast.LENGTH_SHORT).show()
                true
            } else {
                Toast.makeText(this, "⚠️ Admin not active! Please activate first.", Toast.LENGTH_LONG).show()
                false
            }
        } catch (e: Exception) { e.printStackTrace(); false }
    }

    private fun isDeviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)
        return dpm.isAdminActive(adminComponent)
    }

    private fun activateDeviceAdmin() {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)
        if (!dpm.isAdminActive(adminComponent)) {
            val intent = android.content.Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
            intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            startActivity(intent)
        } else {
            Toast.makeText(this, "✅ Admin already active", Toast.LENGTH_SHORT).show()
        }
    }

    private fun blockUninstall(packageName: String, block: Boolean) {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)
            if (dpm.isAdminActive(adminComponent)) {
                dpm.setUninstallBlocked(adminComponent, packageName, block)
                val message = if (block) "Uninstall blocked" else "Uninstall allowed"
                Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) { e.printStackTrace() }
    }
}