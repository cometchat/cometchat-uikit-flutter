package com.cometchat.flutter_chat_ui_kit

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class FileProvider : FileProvider()

class OpenFile{

    companion object {
        fun openFile(call: MethodCall, result: MethodChannel.Result, context: Context, activity: Activity) {
            val filePath: String = call.argument("file_path") ?: ""
            val fileType: String = call.argument("file_type") ?: ""

            val intent = Intent(Intent.ACTION_VIEW)
            intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            intent.addCategory(Intent.CATEGORY_DEFAULT)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                val packageName: String = context.packageName
                val uri: Uri = FileProvider.getUriForFile(context, "$packageName.fileProvider.com.cometchat.flutter_chat_ui_kit", File(filePath))
                intent.setDataAndType(uri, fileType)
            } else {
                intent.setDataAndType(Uri.fromFile(File(filePath)), fileType)
            }

            var message = "Success"
            try {
                activity.startActivity(intent)
            } catch (e: ActivityNotFoundException) {
                message = "No APP found to open this file。"
            } catch (e: Exception) {
                message = "File opened incorrectly。"
            }
            result.success(message)
        }
    }

}