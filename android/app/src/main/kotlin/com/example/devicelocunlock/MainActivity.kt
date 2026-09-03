package com.example.devicelocunlock

import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.BatteryManager
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
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
            Log.d("MainActivity", "applyEMIHardLockStatic called: enable=$enable")
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(context, DeviceAdminReceiver::class.java)

            // SharedPreferences-এ স্ট্যাটাস সেভ করা
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

                    // ১. Wake up screen (WakeLock)
                    val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                    @Suppress("DEPRECATION")
                    val wl = pm.newWakeLock(PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE, "Lock:Wake")
                    wl.acquire(10000)
                    if (wl.isHeld) wl.release()

                    // ২. অ্যাপটি সামনে নিয়ে আসা (রিয়েল ফোনে এটি Overlay Permission ছাড়া কাজ করবে না)
                    val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or 
                                   Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or 
                                   Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                   Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    context.startActivity(intent)

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
                Log.e("MainActivity", "Hard lock error: ${e.message}")
                false
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        turnScreenOnAndKeyguardOff()

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        isHardLocked = prefs.getBoolean("flutter.device_locked", false)

        // ১. Native Sync Service স্টার্ট করা
        startNativeSyncService()
        
        // ২. রিয়েল ফোনের জন্য প্রয়োজনীয় পারমিশন রিকোয়েস্ট (Overlay + Battery)
        checkAndRequestPermissions()
    }

    private fun checkAndRequestPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // ১. Battery Optimization পারমিশন
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                }
            }

            // ২. Overlay Permission (রিয়েল ফোনে ব্যাকগ্রাউন্ড লকের জন্য এটি বাধ্যতামূলক)
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                startActivity(intent)
            }
        }
    }

    private fun startNativeSyncService() {
        Log.i("MainActivity", "Starting Native Sync Service...")
        val serviceIntent = Intent(this, SyncForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun turnScreenOnAndKeyguardOff() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                          WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                          WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                          WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    override fun onResume() {
        super.onResume()
        if (isHardLocked) {
            try { startLockTask() } catch (e: Exception) {}
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isHardLocked) {
            turnScreenOnAndKeyguardOff()
            try { startLockTask() } catch (e: Exception) {}
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockDevice" -> result.success(applyEMIHardLockStatic(this, true))
                    "unlockDevice" -> {
                        try { stopLockTask() } catch (e: Exception) {}
                        result.success(applyEMIHardLockStatic(this, false))
                    }
                    "isAdminActive" -> result.success(isDeviceAdminActive())
                    "activateAdmin" -> { activateDeviceAdmin(); result.success(true) }
                    "requestIgnoreBatteryOptimizations" -> { checkAndRequestPermissions(); result.success(true) }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getDeviceInfo") result.success(getDeviceInfo())
                else result.notImplemented()
            }
    }

    override fun onBackPressed() {
        if (isHardLocked) return
        super.onBackPressed()
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
