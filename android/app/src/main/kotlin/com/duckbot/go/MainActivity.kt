package com.duckbot.go

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val termuxChannel = "duckbot/termux_bridge"
    private val termuxPrefixPath = "/data/data/com.termux/files/usr"
    private val termuxHomePath = "/data/data/com.termux/files/home"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val callbackCounter = AtomicInteger(1)

    private val termuxPackageName = "com.termux"
    private val termuxRunCommandAction = "com.termux.RUN_COMMAND"
    private val termuxRunCommandService = "com.termux.app.RunCommandService"
    private val extraCommandPath = "com.termux.RUN_COMMAND_PATH"
    private val extraArguments = "com.termux.RUN_COMMAND_ARGUMENTS"
    private val extraWorkdir = "com.termux.RUN_COMMAND_WORKDIR"
    private val extraBackground = "com.termux.RUN_COMMAND_BACKGROUND"
    private val extraCommandLabel = "com.termux.RUN_COMMAND_COMMAND_LABEL"
    private val extraCommandDescription = "com.termux.RUN_COMMAND_COMMAND_DESCRIPTION"
    private val extraPendingIntent = "com.termux.RUN_COMMAND_PENDING_INTENT"
    private val pluginResultBundle = "result"
    private val pluginResultStdout = "stdout"
    private val pluginResultStderr = "stderr"
    private val pluginResultExitCode = "exitCode"
    private val pluginResultErr = "err"
    private val pluginResultErrmsg = "errmsg"
    private val callbackActionPrefix = "com.duckbot.go.TERMUX_COMMAND_RESULT"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, termuxChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTermuxInstalled" -> {
                        result.success(isPackageInstalled("com.termux"))
                    }

                    "hasRunCommandPermission" -> {
                        result.success(
                            ContextCompat.checkSelfPermission(
                                this,
                                "com.termux.permission.RUN_COMMAND"
                            ) == PackageManager.PERMISSION_GRANTED
                        )
                    }

                    "launchTermux" -> {
                        result.success(launchPackage("com.termux"))
                    }

                    "openAppSettings" -> {
                        val packageName =
                            call.argument<String>("packageName") ?: packageName
                        openAppSettings(packageName)
                        result.success(true)
                    }

                    "runCommand" -> handleRunCommand(call, result, detailed = false)
                    "runCommandDetailed" -> handleRunCommand(call, result, detailed = true)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleRunCommand(
        call: MethodCall,
        result: MethodChannel.Result,
        detailed: Boolean,
    ) {
        if (!isPackageInstalled(termuxPackageName)) {
            finishRunCommandResult(
                result,
                detailed,
                failureResult(
                    message = "Termux is not installed",
                ),
            )
            return
        }

        if (ContextCompat.checkSelfPermission(
                this,
                "com.termux.permission.RUN_COMMAND"
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            finishRunCommandResult(
                result,
                detailed,
                failureResult(
                    message = "RUN_COMMAND permission has not been granted to this app",
                ),
            )
            return
        }

        val script = call.argument<String>("script")?.trim()
        val label = call.argument<String>("label")?.trim().orEmpty()
        val description = call.argument<String>("description")?.trim().orEmpty()
        val background = call.argument<Boolean>("background") ?: false
        val waitForResultMs = (call.argument<Int>("waitForResultMs") ?: 1800)
            .coerceIn(250, 10_000)

        if (script.isNullOrEmpty()) {
            finishRunCommandResult(
                result,
                detailed,
                failureResult(
                    message = "Script is required",
                ),
            )
            return
        }

        val requestCode = callbackCounter.getAndIncrement()
        val callbackAction = "$callbackActionPrefix.$requestCode"
        val callbackIntent = Intent(callbackAction).setPackage(packageName)
        val pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            callbackIntent,
            pendingIntentFlags,
        )

        var receiverRegistered = false
        var replied = false
        lateinit var timeoutRunnable: Runnable
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (replied) {
                    return
                }

                replied = true
                mainHandler.removeCallbacks(timeoutRunnable)
                if (receiverRegistered) {
                    unregisterReceiver(this)
                    receiverRegistered = false
                }
                pendingIntent.cancel()

                finishRunCommandResult(
                    result,
                    detailed,
                    buildCommandResult(intent),
                )
            }
        }

        try {
            registerCallbackReceiver(receiver, callbackAction)
            receiverRegistered = true

            val intent = Intent(termuxRunCommandAction).apply {
                setClassName(termuxPackageName, termuxRunCommandService)
                putExtra(extraCommandPath, "$termuxPrefixPath/bin/bash")
                putExtra(extraArguments, arrayOf("-lc", script))
                putExtra(extraWorkdir, termuxHomePath)
                putExtra(extraBackground, background)
                putExtra(extraPendingIntent, pendingIntent)
                if (label.isNotEmpty()) {
                    putExtra(extraCommandLabel, label)
                }
                if (description.isNotEmpty()) {
                    putExtra(extraCommandDescription, description)
                }
            }

            timeoutRunnable = Runnable {
                if (replied) {
                    return@Runnable
                }

                replied = true
                if (receiverRegistered) {
                    unregisterReceiver(receiver)
                    receiverRegistered = false
                }
                pendingIntent.cancel()

                finishRunCommandResult(
                    result,
                    detailed,
                    hashMapOf(
                        "accepted" to true,
                        "completed" to false,
                        "pending" to true,
                        "stdout" to null,
                        "stderr" to null,
                        "exitCode" to null,
                        "errorCode" to null,
                        "errorMessage" to null,
                        "requiresAllowExternalApps" to false,
                    ),
                )
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && background) {
                applicationContext.startForegroundService(intent)
            } else {
                applicationContext.startService(intent)
            }

            mainHandler.postDelayed(timeoutRunnable, waitForResultMs.toLong())
        } catch (securityException: SecurityException) {
            if (receiverRegistered) {
                unregisterReceiver(receiver)
            }
            pendingIntent.cancel()
            finishRunCommandResult(
                result,
                detailed,
                failureResult(
                    message = securityException.message ?: "RUN_COMMAND permission denied",
                ),
            )
        } catch (exception: Exception) {
            if (receiverRegistered) {
                unregisterReceiver(receiver)
            }
            pendingIntent.cancel()
            finishRunCommandResult(
                result,
                detailed,
                failureResult(
                    message = exception.message ?: "Failed to send command to Termux",
                ),
            )
        }
    }

    private fun registerCallbackReceiver(receiver: BroadcastReceiver, action: String) {
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
    }

    private fun finishRunCommandResult(
        result: MethodChannel.Result,
        detailed: Boolean,
        payload: HashMap<String, Any?>,
    ) {
        if (detailed) {
            result.success(payload)
        } else {
            result.success(payload["accepted"] == true)
        }
    }

    private fun failureResult(message: String): HashMap<String, Any?> {
        val requiresAllowExternalApps = message.contains("allow-external-apps", ignoreCase = true)
        return hashMapOf(
            "accepted" to false,
            "completed" to true,
            "pending" to false,
            "stdout" to null,
            "stderr" to null,
            "exitCode" to null,
            "errorCode" to null,
            "errorMessage" to message,
            "requiresAllowExternalApps" to requiresAllowExternalApps,
        )
    }

    private fun buildCommandResult(intent: Intent?): HashMap<String, Any?> {
        val resultBundle = intent?.getBundleExtra(pluginResultBundle)
        val stdout = resultBundle?.getString(pluginResultStdout)
            ?: intent?.getStringExtra(pluginResultStdout)
        val stderr = resultBundle?.getString(pluginResultStderr)
            ?: intent?.getStringExtra(pluginResultStderr)
        val exitCode = getOptionalInt(
            bundle = resultBundle,
            intent = intent,
            key = pluginResultExitCode,
        )
        val errorCode = getOptionalInt(
            bundle = resultBundle,
            intent = intent,
            key = pluginResultErr,
        )
        val errorMessage = resultBundle?.getString(pluginResultErrmsg)
            ?: intent?.getStringExtra(pluginResultErrmsg)
        val requiresAllowExternalApps =
            errorMessage?.contains("allow-external-apps", ignoreCase = true) == true

        return hashMapOf(
            "accepted" to (errorCode == null || errorCode == 0),
            "completed" to true,
            "pending" to false,
            "stdout" to stdout,
            "stderr" to stderr,
            "exitCode" to exitCode,
            "errorCode" to errorCode,
            "errorMessage" to errorMessage,
            "requiresAllowExternalApps" to requiresAllowExternalApps,
        )
    }

    private fun getOptionalInt(bundle: Bundle?, intent: Intent?, key: String): Int? {
        if (bundle != null && bundle.containsKey(key)) {
            return bundle.getInt(key)
        }
        if (intent != null && intent.hasExtra(key)) {
            return intent.getIntExtra(key, 0)
        }
        return null
    }

    private fun isPackageInstalled(targetPackage: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    targetPackage,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(targetPackage, 0)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun launchPackage(targetPackage: String): Boolean {
        val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage) ?: return false
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launchIntent)
        return true
    }

    private fun openAppSettings(targetPackage: String) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$targetPackage")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
