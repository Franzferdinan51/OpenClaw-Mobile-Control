package com.duckbot.go

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val termuxChannel = "duckbot/termux_bridge"
    private val termuxPrefixPath = "/data/data/com.termux/files/usr"
    private val termuxHomePath = "/data/data/com.termux/files/home"

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

                    "runCommand" -> handleRunCommand(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleRunCommand(call: MethodCall, result: MethodChannel.Result) {
        if (!isPackageInstalled("com.termux")) {
            result.error("termux_missing", "Termux is not installed", null)
            return
        }

        if (ContextCompat.checkSelfPermission(
                this,
                "com.termux.permission.RUN_COMMAND"
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "permission_denied",
                "RUN_COMMAND permission has not been granted to this app",
                null
            )
            return
        }

        val script = call.argument<String>("script")?.trim()
        val label = call.argument<String>("label")?.trim().orEmpty()
        val description = call.argument<String>("description")?.trim().orEmpty()
        val background = call.argument<Boolean>("background") ?: false

        if (script.isNullOrEmpty()) {
            result.error("invalid_args", "Script is required", null)
            return
        }

        try {
            val intent = Intent("com.termux.RUN_COMMAND").apply {
                setClassName("com.termux", "com.termux.app.RunCommandService")
                putExtra("com.termux.RUN_COMMAND_PATH", "$termuxPrefixPath/bin/bash")
                putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-lc", script))
                putExtra("com.termux.RUN_COMMAND_WORKDIR", termuxHomePath)
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", background)
                if (label.isNotEmpty()) {
                    putExtra("com.termux.RUN_COMMAND_COMMAND_LABEL", label)
                }
                if (description.isNotEmpty()) {
                    putExtra("com.termux.RUN_COMMAND_COMMAND_DESCRIPTION", description)
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && background) {
                applicationContext.startForegroundService(intent)
            } else {
                applicationContext.startService(intent)
            }

            result.success(true)
        } catch (securityException: SecurityException) {
            result.error(
                "permission_denied",
                securityException.message ?: "RUN_COMMAND permission denied",
                null
            )
        } catch (exception: Exception) {
            result.error("run_command_failed", exception.message, null)
        }
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
