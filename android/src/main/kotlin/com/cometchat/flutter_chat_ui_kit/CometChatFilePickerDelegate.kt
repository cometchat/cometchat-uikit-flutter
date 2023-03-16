package com.cometchat.flutter_chat_ui_kit

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Parcelable
import android.os.Message
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.VisibleForTesting
import androidx.core.app.ActivityCompat
import java.io.File
import java.util.ArrayList
import java.util.HashMap
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

 class CometChatFilePickerDelegate (constActivity: Activity): PluginRegistry.ActivityResultListener, PluginRegistry.RequestPermissionsResultListener {

     private val TAG = "FilePickerDelegate"
     private val REQUEST_CODE = FlutterChatUiKitPlugin::class.java.hashCode() + 43 and 0x0000ffff

     private var activity: Activity = constActivity
     private var pendingResult: MethodChannel.Result? = null
     private var isMultipleSelection = false
     private var type: String? = null
     private var loadDataToMemory = false
     private var allowedExtensions: Array<String>? = null;





     override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
         if (type == null) {
             return false
         }

         if (requestCode == REQUEST_CODE && resultCode == Activity.RESULT_OK) {
             this.dispatchEventStatus(true)
             Thread(Runnable {
                 if (data != null) {
                     val files = ArrayList<CometChatFileInfo>()
                     if (data.clipData != null) {
                         val count = data.clipData!!.itemCount
                         var currentItem = 0
                         while (currentItem < count) {
                             val currentUri = data.clipData!!.getItemAt(currentItem).uri
                             val file = CometChatFileUtils.openFileStream(this.activity!!, currentUri, loadDataToMemory)
                             if (file != null) {
                                 files.add(file)
                                 Log.d(TAG, "[MultiFilePick] File #" + currentItem + " - URI: " + currentUri.path)
                             }
                             currentItem++
                         }
                         finishWithSuccess(files)
                     } else if (data.data != null) {
                         var uri = data.data
                         if (type == "dir" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                             uri = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
                             Log.d(TAG, "[SingleFilePick] File URI:$uri")
                             val dirPath = CometChatFileUtils.getFullPathFromTreeUri(uri, this.activity!!)
                             dirPath?.let { finishWithSuccess(it) }
                                     ?: finishWithError("unknown_path", "Failed to retrieve directory path.")
                             return@Runnable
                         }
                         val file = CometChatFileUtils.openFileStream(this.activity!!, uri!!, loadDataToMemory)
                         if (file != null) {
                             files.add(file)
                         }
                         if (!files.isEmpty()) {
                             Log.d(TAG, "File path:$files")
                             finishWithSuccess(files)
                         } else {
                             finishWithError("unknown_path", "Failed to retrieve path.")
                         }
                     } else if (data.extras != null) {
                         val bundle = data.extras
                         if (bundle!!.keySet().contains("selectedItems")) {
                             val fileUris = bundle.getParcelableArrayList<Parcelable>("selectedItems")
                             var currentItem = 0
                             if (fileUris != null) {
                                 for (fileUri in fileUris) {
                                     if (fileUri is Uri) {
                                         val currentUri = fileUri
                                         val file = CometChatFileUtils.openFileStream(this.activity!!, currentUri, loadDataToMemory)
                                         if (file != null) {
                                             files.add(file)
                                             Log.d(TAG, "[MultiFilePick] File #" + currentItem + " - URI: " + currentUri.path)
                                         }
                                     }
                                     currentItem++
                                 }
                             }
                             finishWithSuccess(files)
                         } else {
                             finishWithError("unknown_path", "Failed to retrieve path from bundle.")
                         }
                     } else {
                         finishWithError("unknown_activity", "Unknown activity error, please fill an issue.")
                     }
                 } else {
                     finishWithError("unknown_activity", "Unknown activity error, please fill an issue.")
                 }
             }).start()
             return true
         } else if (requestCode == REQUEST_CODE && resultCode == Activity.RESULT_CANCELED) {
             Log.i(TAG, "User cancelled the picker request")
             finishWithSuccess(null)
             return true
         } else if (requestCode == REQUEST_CODE) {
             finishWithError("unknown_activity", "Unknown activity error, please fill an issue.")
         }
         return false
     }

     override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {

         if (REQUEST_CODE != requestCode) {
             return false
         }

         val permissionGranted = grantResults!!.size > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED

         if (permissionGranted) {
             this.startFileExplorer()
         } else {
             finishWithError("read_external_storage_denied", "User did not allow reading external storage")
         }

         return true
     }


     private fun startFileExplorer() {
         val intent: Intent

         // Temporary fix, remove this null-check after Flutter Engine 1.14 has landed on stable
         if (type == null) {
             return
         }
         if (type == "dir") {
             intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
         } else {
             if (type == "image/*") {
                 intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
             } else {
                 intent = Intent(Intent.ACTION_GET_CONTENT)
                 intent.addCategory(Intent.CATEGORY_OPENABLE)
             }
             val uri = Uri.parse(Environment.getExternalStorageDirectory().path + File.separator)
             Log.d(TAG, "Selected type $type")
             intent.setDataAndType(uri, type)
             intent.type = type
             intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, isMultipleSelection)
             intent.putExtra("multi-pick", isMultipleSelection)
             if (type!!.contains(",")) {
                 allowedExtensions = type!!.split(",").toTypedArray()

             }
             if (allowedExtensions != null) {
                 intent.putExtra(Intent.EXTRA_MIME_TYPES, allowedExtensions)
             }
         }
         if (intent.resolveActivity(activity!!.packageManager) != null) {
             activity!!.startActivityForResult(intent, REQUEST_CODE)
         } else {
             Log.e(TAG, "Can't find a valid activity to handle the request. Make sure you've a file explorer installed.")
             finishWithError("invalid_format_type", "Can't handle the provided file type.")
         }
     }



     private fun finishWithSuccess(data: Any?) {
         var data: Any? = data
         this.dispatchEventStatus(false)

         // Temporary fix, remove this null-check after Flutter Engine 1.14 has landed on stable
         if (pendingResult != null) {
             if (data != null && data !is String) {
                 val files = ArrayList<HashMap<String, Any?>>()
                 for (file in data as ArrayList<CometChatFileInfo>) {
                     files.add(file.toMap())
                 }
                 data = files
             }
             pendingResult!!.success(data)
             this.clearPendingResult()
         }
     }


     private fun finishWithError(errorCode: String, errorMessage: String) {
         if (pendingResult == null) {
             return
         }
         dispatchEventStatus(false)
         pendingResult!!.error(errorCode, errorMessage, null)
         clearPendingResult()
     }

     private fun dispatchEventStatus(status: Boolean) {
//         if (eventSink == null || type == "dir") {
//             return
//         }
//         object : Handler(Looper.getMainLooper()) {
//             override fun handleMessage(message: Message) {
//                 eventSink.success(status)
//             }
//         }.obtainMessage().sendToTarget()
     }


     private fun clearPendingResult() {
         pendingResult = null
     }


     fun startFileExplorer(type: String?, isMultipleSelection: Boolean, withData: Boolean, allowedExtensions : Array<String>? ,result: MethodChannel.Result?) {
         if (!this.setPendingMethodCallAndResult(result!!)) {
             finishWithAlreadyActiveError(result)
             return
         }
         this.type = type
         this.isMultipleSelection = isMultipleSelection
         loadDataToMemory = withData
         this.allowedExtensions = allowedExtensions

         var permissionArray = arrayOf<String >(Manifest.permission.READ_EXTERNAL_STORAGE)


         if ( ActivityCompat.checkSelfPermission(activity!!, Manifest.permission.READ_EXTERNAL_STORAGE)
         != PackageManager.PERMISSION_GRANTED){
             ActivityCompat.requestPermissions(activity!!, permissionArray ,
                     REQUEST_CODE);

         return
         }

//         if (!permissionManager!!.isPermissionGranted(Manifest.permission.READ_EXTERNAL_STORAGE)) {
//             permissionManager.askForPermission(Manifest.permission.READ_EXTERNAL_STORAGE, REQUEST_CODE)
//             return
//         }
         this.startFileExplorer()
     }


     private fun setPendingMethodCallAndResult(result: MethodChannel.Result): Boolean {
         if (pendingResult != null) {
             return false
         }
         pendingResult = result
         return true
     }

     private fun finishWithAlreadyActiveError(result: MethodChannel.Result) {
         result.error("already_active", "File picker is already active", null)
     }

 }