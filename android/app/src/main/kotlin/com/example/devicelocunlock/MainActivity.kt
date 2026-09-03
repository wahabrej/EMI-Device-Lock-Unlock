package com.example.devicelocunlock

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.BatteryManager
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.devicelocunlock/controls"
    private val DEVICE_CHANNEL = "com.example.devicelocunlock/device"

    companion object {
        var isHardLocked = false

        fun applyEMIHardLockStatic(context: Context, enable: Boolean): Boolean {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(context, DeviceAdminReceiver::class.java)

            // স্ট্যাটাসটি SharedPreferences এ সেভ করা যাতে অ্যাপ বন্ধ থাকলেও মনে থাকে
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.device_locked", enable).apply()
            isHardLocked = enable

            return try {
                if (enable) {
                    if (dpm.isDeviceOwnerApp(context.packageName)) {
                        dpm.setLockTaskPackages(adminComponent, arrayOf(context.packageName))
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            dpm.setStatusBarDisabled(adminComponent, true)
                            dpm.setKeyguardDisabled(adminComponent, true)
                        }
                    }

                    // অ্যাপটি সামনে নিয়ে আসা
                    val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    context.startActivity(intent)

                    // স্ক্রিন সাথে সাথে বন্ধ করে দেওয়া (লক করা)
                    dpm.lockNow()
                } else {
                    if (dpm.isDeviceOwnerApp(context.packageName)) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            dpm.setStatusBarDisabled(adminComponent, false)
                            dpm.setKeyguardDisabled(adminComponent, false)
                        }
                    }
                }
                true
            } catch (e: Exception) {
                false
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // অ্যাপ ওপেন হওয়ার সময় আগের লক স্ট্যাটাস চেক করা
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        isHardLocked = prefs.getBoolean("flutter.device_locked", false)
    }

    override fun onResume() {
        super.onResume()
        // যদি ডিভাইস হার্ড লক মোডে থাকে তবে কিয়স্ক মোড শুরু হবে
        if (isHardLocked) {
            try {
                startLockTask()
            } catch (e: Exception) {
                // Device Owner না হলে এটি এরর দিতে পারে
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockDevice" -> result.success(applyEMIHardLockStatic(this, true))
                    "unlockDevice" -> {
                        // আনলক করার সময় কিয়স্ক মোড বন্ধ করা
                        try { stopLockTask() } catch (e: Exception) {}
                        result.success(applyEMIHardLockStatic(this, false))
                    }
                    "isAdminActive" -> result.success(isDeviceAdminActive())
                    "activateAdmin" -> {
                        activateDeviceAdmin()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getDeviceInfo") {
                    result.success(getDeviceInfo())
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onBackPressed() {
        // হার্ড লক থাকলে ব্যাক বাটন কাজ করবে না
        if (isHardLocked) return
        super.onBackPressed()
    }

    override fun onPause() {
        super.onPause()
        // moveTaskToFront এখান থেকে সরিয়ে দেওয়া হয়েছে কারণ এটি ক্রাশের মূল কারণ ছিল।
        // কিয়স্ক মোড (LockTask) সচল থাকলে এটি ছাড়াই ফোন সুরক্ষিত থাকবে।
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
