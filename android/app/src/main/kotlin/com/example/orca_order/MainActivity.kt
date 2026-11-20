package com.orcallc.orca_order

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "orca_order/apk_updates"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canRequestInstallPackages" -> {
                        result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                packageManager.canRequestPackageInstalls()
                        )
                    }
                    "availableUpdateSpaceBytes" -> {
                        result.success(StatFs(cacheDir.absolutePath).availableBytes)
                    }
                    "openInstallPermissionSettings" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            result.success(true)
                        } else {
                            try {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:$packageName")
                                    )
                                )
                                result.success(true)
                            } catch (error: Exception) {
                                result.error(
                                    "INSTALL_SETTINGS_UNAVAILABLE",
                                    "تعذر فتح إعداد السماح بتثبيت التطبيقات",
                                    error.message
                                )
                            }
                        }
                    }
                    "validateApk" -> {
                        val filePath = call.argument<String>("path")
                        val expectedPackage =
                            call.argument<String>("packageName")
                        val expectedBuild =
                            call.argument<Number>("buildNumber")?.toLong()
                        if (filePath == null ||
                            expectedPackage != packageName ||
                            expectedBuild == null
                        ) {
                            result.error(
                                "INVALID_APK_REQUEST",
                                "بيانات التحقق من التطبيق غير صالحة",
                                null
                            )
                        } else {
                            try {
                                result.success(
                                    validateApk(
                                        File(filePath),
                                        expectedPackage,
                                        expectedBuild
                                    )
                                )
                            } catch (error: Exception) {
                                result.error(
                                    "APK_VALIDATION_FAILED",
                                    error.message ?: "تعذر التحقق من حزمة APK",
                                    null
                                )
                            }
                        }
                    }
                    "installApk" -> {
                        val filePath = call.argument<String>("path")
                        if (filePath == null) {
                            result.error(
                                "APK_PATH_REQUIRED",
                                "ملف التثبيت غير محدد",
                                null
                            )
                        } else {
                            try {
                                val apk = File(filePath)
                                require(apk.isFile && apk.length() > 0) {
                                    "ملف APK غير موجود أو فارغ"
                                }
                                check(
                                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                        packageManager.canRequestPackageInstalls()
                                ) {
                                    "يجب السماح لهذا التطبيق بتثبيت الحزم أولاً"
                                }
                                val contentUri = FileProvider.getUriForFile(
                                    this,
                                    "$packageName.fileprovider",
                                    apk
                                )
                                val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(
                                        contentUri,
                                        "application/vnd.android.package-archive"
                                    )
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(installIntent)
                                result.success(true)
                            } catch (error: Exception) {
                                result.error(
                                    "APK_INSTALLER_UNAVAILABLE",
                                    error.message ?: "تعذر فتح مثبت Android",
                                    null
                                )
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun validateApk(
        apk: File,
        expectedPackage: String,
        expectedBuild: Long
    ): Map<String, Any> {
        require(apk.isFile && apk.length() > 0) {
            "ملف APK غير موجود أو فارغ"
        }
        val archiveInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                apk.absolutePath,
                android.content.pm.PackageManager.PackageInfoFlags.of(
                    android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES.toLong()
                )
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageArchiveInfo(
                apk.absolutePath,
                android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES
            )
        } ?: error("الملف ليس حزمة APK صالحة")

        val actualBuild = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archiveInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            archiveInfo.versionCode.toLong()
        }
        require(archiveInfo.packageName == expectedPackage) {
            "معرّف الحزمة لا يطابق التطبيق المثبت"
        }
        require(actualBuild == expectedBuild) {
            "رقم بناء APK لا يطابق بيانات التحديث"
        }

        val installedInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                android.content.pm.PackageManager.PackageInfoFlags.of(
                    android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES.toLong()
                )
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(
                packageName,
                android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES
            )
        }
        val archiveSigners = signerDigests(archiveInfo)
        val installedSigners = signerDigests(installedInfo)
        require(archiveSigners.isNotEmpty() &&
            installedSigners.isNotEmpty() &&
            archiveSigners.intersect(installedSigners).isNotEmpty()
        ) {
            "توقيع APK لا يطابق توقيع التطبيق المثبت"
        }
        return mapOf(
            "packageName" to archiveInfo.packageName,
            "buildNumber" to actualBuild,
            "versionName" to (archiveInfo.versionName ?: "")
        )
    }

    private fun signerDigests(
        packageInfo: android.content.pm.PackageInfo
    ): Set<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            @Suppress("DEPRECATION")
            val signatures = packageInfo.signatures ?: return emptySet()
            return signatures.map { digest(it.toByteArray()) }.toSet()
        }
        val signingInfo = packageInfo.signingInfo ?: return emptySet()
        val signatures = signingInfo.signingCertificateHistory
        return signatures.map { digest(it.toByteArray()) }.toSet()
    }

    private fun digest(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { byte -> "%02x".format(byte) }
}
