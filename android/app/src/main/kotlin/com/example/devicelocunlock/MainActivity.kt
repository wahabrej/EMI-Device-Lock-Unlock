package com.example.devicelocunlock

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.BatteryManager
import android.provider.Settings
import android.view.WindowManager
import android.widget.Toast
import androidx.annotation.NonNull
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
                        val success = applyEMIHardLock(true)
                        result.success(success)
                    }
                    "unlockDevice" -> {
                        applyEMIHardLock(false)
                        result.success(true)
                    }
                    "isAdminActive" -> result.success(isDeviceAdminActive())
                    "activateAdmin" -> {
                        activateDeviceAdmin()
                        result.success(true)
                    }
                    "getDeviceId" -> result.success(getAndroidDeviceId())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceInfo" -> result.success(getDeviceInfo())
                    "getIMEI" -> result.success(getGeneratedIMEI())
                    else -> result.notImplemented()
                }
            }
    }

    private fun applyEMIHardLock(enable: Boolean): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)

        return try {
            if (enable) {
                if (!dpm.isAdminActive(adminComponent)) {
                    Toast.makeText(this, "⚠️ Please activate Admin first!", Toast.LENGTH_LONG).show()
                    return false
                }

                if (dpm.isDeviceOwnerApp(packageName)) {
                    dpm.setLockTaskPackages(adminComponent, arrayOf(packageName))
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        dpm.setStatusBarDisabled(adminComponent, true)
                        dpm.setKeyguardDisabled(adminComponent, true)
                    }
                }
                
                startLockTask()
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
                window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
                window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
                
                // স্ক্রিন অফ করবে, কিন্তু ডিভাইস ওনার থাকায় খোলার সাথে সাথে আমাদের অ্যাপই থাকবে
                dpm.lockNow()
                true
            } else {
                stopLockTask()
                if (dpm.isDeviceOwnerApp(packageName)) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        dpm.setStatusBarDisabled(adminComponent, false)
                        dpm.setKeyguardDisabled(adminComponent, false)
                    }
                }
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                window.clearFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
                window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
                window.clearFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // ক্রাশ রোধ করার জন্য problematic ব্রডকাস্ট সরানো হয়েছে
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
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
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
            intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            startActivity(intent)
        }
    }

    private fun getAndroidDeviceId(): String = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "UNKNOWN"

    private fun getGeneratedIMEI(): String {
        val androidId = getAndroidDeviceId().filter { it.isDigit() }
        return if (androidId.length >= 15) androidId.substring(0, 15) else androidId.padEnd(15, '0')
    }

    private fun getDeviceInfo(): Map<String, String> {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        return mapOf(
            "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "imei" to getGeneratedIMEI(),
            "androidVersion" to Build.VERSION.RELEASE,
            "batteryLevel" to "$level%",
            "deviceId" to getAndroidDeviceId()
        )
    }
}
