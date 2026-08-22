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
    private val DEVICE_CHANNEL = "com.example.smartpay/device"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── Control Channel ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockDevice" -> {
                        val success = lockDevice()
                        result.success(success)
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
                    "getDeviceId" -> {
                        val deviceId = getAndroidDeviceId()
                        result.success(deviceId)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // ─── Device Info Channel ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceInfo" -> {
                        val info = getDeviceInfo()
                        result.success(info)
                    }
                    "getIMEI" -> {
                        val imei = getRealDeviceIMEI()
                        result.success(imei)
                    }
                    "getDeviceId" -> {
                        val deviceId = getAndroidDeviceId()
                        result.success(deviceId)
                    }
                    "getBatteryLevel" -> {
                        val battery = getBatteryLevel()
                        result.success(battery)
                    }
                    "getStorageInfo" -> {
                        val storage = getStorageInfo()
                        result.success(storage)
                    }
                    "getAndroidVersion" -> {
                        val version = getAndroidVersion()
                        result.success(version)
                    }
                    "getDeviceModel" -> {
                        val model = getDeviceModel()
                        result.success(model)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    // ─── Get All Device Info ───
    private fun getDeviceInfo(): Map<String, String> {
        return mapOf(
            "model" to getDeviceModel(),
            "imei" to getRealDeviceIMEI(),
            "androidVersion" to getAndroidVersion(),
            "batteryLevel" to getBatteryLevel(),
            "storageUsed" to getStorageInfo(),
            "deviceId" to getAndroidDeviceId(),
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "sdkInt" to Build.VERSION.SDK_INT.toString(),
        )
    }

    private fun getDeviceModel(): String {
        return try {
            "${Build.MANUFACTURER} ${Build.MODEL}"
        } catch (e: Exception) {
            "Unknown Model"
        }
    }

    private fun getAndroidVersion(): String {
        return try {
            "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"
        } catch (e: Exception) {
            "Unknown Version"
        }
    }

    private fun getBatteryLevel(): String {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            "$level%"
        } catch (e: Exception) {
            "N/A"
        }
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
        } catch (e: Exception) {
            "N/A"
        }
    }

    private fun formatSize(size: Long): String {
        return when {
            size < 1024 -> "$size B"
            size < 1024 * 1024 -> "${size / 1024} KB"
            size < 1024 * 1024 * 1024 -> "${size / (1024 * 1024)} MB"
            else -> "${size / (1024 * 1024 * 1024)} GB"
        }
    }

    private fun getRealDeviceIMEI(): String {
        return try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                getDeviceIdentifier()
            } else {
                if (ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_PHONE_STATE
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    telephonyManager.imei ?: getDeviceIdentifier()
                } else {
                    getDeviceIdentifier()
                }
            }
        } catch (e: Exception) {
            getDeviceIdentifier()
        }
    }

    private fun getDeviceIdentifier(): String {
        return try {
            Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ANDROID_ID
            ) ?: "UNKNOWN_DEVICE"
        } catch (e: Exception) {
            "UNKNOWN_DEVICE"
        }
    }

    // ─── Lock Device ───
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
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isDeviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)
        return dpm.isAdminActive(adminComponent)
    }

    // ─── Activate Admin ───
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
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getAndroidDeviceId(): String {
        return try {
            Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ANDROID_ID
            ) ?: "UNKNOWN_DEVICE"
        } catch (e: Exception) {
            "UNKNOWN_DEVICE"
        }
    }
}