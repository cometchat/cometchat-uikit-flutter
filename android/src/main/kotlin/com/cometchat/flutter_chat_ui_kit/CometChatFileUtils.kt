package com.cometchat.flutter_chat_ui_kit

import android.annotation.SuppressLint
import android.annotation.TargetApi
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.annotation.RequiresApi
import java.io.*
import java.lang.Exception
import java.lang.NullPointerException
import java.util.*

class CometChatFileUtils{


    companion object {
        private val TAG = "FilePickerUtils"
        private val PRIMARY_VOLUME_NAME = "primary"
        fun getMimeTypes(allowedExtensions: ArrayList<String>?): Array<String>? {
            if (allowedExtensions == null || allowedExtensions.isEmpty()) {
                return null
            }
            val mimes = ArrayList<String>()
            for (i in allowedExtensions.indices) {
                val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(allowedExtensions[i])
                if (mime == null) {
                    Log.w("FILEUTIL", "Custom file type " + allowedExtensions[i] + " is unsupported and will be ignored.")
                    continue
                }
                mimes.add(mime)
            }
            Log.d("FileUtil", "Allowed file extensions mimes: $mimes")
            return mimes.toTypedArray()
        }


        fun openFileStream(context: Context, uri: Uri, withData: Boolean): CometChatFileInfo? {
            Log.i(TAG, "Caching from URI: $uri")
            var fos: FileOutputStream? = null
            val fileInfo = CometChatFileInfo.Builder()
            val fileName = getFileName(uri, context)
            val path = context.cacheDir.absolutePath + "/file_picker/" + (fileName
                    ?: Random().nextInt(100000))
            val file = File(path)
            if (!file.exists()) {
                file.parentFile.mkdirs()
                try {
                    fos = FileOutputStream(path)
                    try {
                        val out = BufferedOutputStream(fos)
                        val `in` = context.contentResolver.openInputStream(uri)
                        val buffer = ByteArray(8192)
                        var len = 0
                        while (`in`!!.read(buffer).also { len = it } >= 0) {
                            out.write(buffer, 0, len)
                        }
                        out.flush()
                    } finally {
                        fos.fd.sync()
                    }
                } catch (e: Exception) {
                    try {
                        fos!!.close()
                    } catch (ex: IOException) {
                        Log.e(TAG, "Failed to close file streams: " + e.message, null)
                        return null
                    } catch (ex: NullPointerException) {
                        Log.e(TAG, "Failed to close file streams: " + e.message, null)
                        return null
                    }
                    Log.e(TAG, "Failed to retrieve path: " + e.message, null)
                    return null
                }
            }
            Log.d(TAG, "File loaded and cached at:$path")
            if (withData) {
                loadData(file, fileInfo)
            }
            fileInfo
                    .withPath(path)
                    .withName(fileName)
                    .withUri(uri)
                    .withSize(file.length().toString().toLong())
            return fileInfo.build()
        }


        fun loadData(file: File, fileInfo: CometChatFileInfo.Builder) {
            try {
                val size = file.length().toInt()
                val bytes = ByteArray(size)
                try {
                    val buf = BufferedInputStream(FileInputStream(file))
                    buf.read(bytes, 0, bytes.size)
                    buf.close()
                } catch (e: FileNotFoundException) {
                    Log.e(TAG, "File not found: " + e.message, null)
                } catch (e: IOException) {
                    Log.e(TAG, "Failed to close file streams: " + e.message, null)
                }
                fileInfo.withData(bytes)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load bytes into memory with error $e. Probably the file is too big to fit device memory. Bytes won't be added to the file this time.")
            }
        }



        @RequiresApi(api = Build.VERSION_CODES.KITKAT)
        fun getFullPathFromTreeUri(treeUri: Uri?, con: Context): String? {
            if (treeUri == null) {
                return null
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                if (isDownloadsDocument(treeUri)) {
                    val docId = DocumentsContract.getDocumentId(treeUri)
                    val extPath = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).path
                    if (docId == "downloads") {
                        return extPath
                    } else if (docId.matches(Regex("^ms[df]\\:.*"))) {
                        val fileName = getFileName(treeUri, con)
                        return "$extPath/$fileName"
                    } else if (docId.startsWith("raw:")) {
                        return docId.split(":").toTypedArray()[1]
                    }
                    return null
                }
            }
            var volumePath = getVolumePath(getVolumeIdFromTreeUri(treeUri), con)
            val fileInfo = CometChatFileInfo.Builder()
            if (volumePath == null) {
                return File.separator
            }
            if (volumePath.endsWith(File.separator)) volumePath = volumePath.substring(0, volumePath.length - 1)
            var documentPath = getDocumentPathFromTreeUri(treeUri)
            if (documentPath!!.endsWith(File.separator)) documentPath = documentPath.substring(0, documentPath.length - 1)
            return if (documentPath.length > 0) {
                if (documentPath.startsWith(File.separator)) {
                    volumePath + documentPath
                } else {
                    volumePath + File.separator + documentPath
                }
            } else {
                volumePath
            }
        }

        private fun getDirectoryPath(storageVolumeClazz: Class<*>, storageVolumeElement: Any): String? {
            try {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                    val getPath = storageVolumeClazz.getMethod("getPath")
                    return getPath.invoke(storageVolumeElement) as String
                }
                val getDirectory = storageVolumeClazz.getMethod("getDirectory")
                val f = getDirectory.invoke(storageVolumeElement) as File
                if (f != null) return f.path
            } catch (ex: Exception) {
                return null
            }
            return null
        }

        @SuppressLint("ObsoleteSdkInt")
        private fun getVolumePath(volumeId: String?, context: Context): String? {
            return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) null else try {
                val mStorageManager = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
                val storageVolumeClazz = Class.forName("android.os.storage.StorageVolume")
                val getVolumeList = mStorageManager.javaClass.getMethod("getVolumeList")
                val getUuid = storageVolumeClazz.getMethod("getUuid")
                val isPrimary = storageVolumeClazz.getMethod("isPrimary")
                val result = getVolumeList.invoke(mStorageManager) ?: return null
                val length = java.lang.reflect.Array.getLength(result)
                for (i in 0 until length) {
                    val storageVolumeElement = java.lang.reflect.Array.get(result, i)
                    val uuid = getUuid.invoke(storageVolumeElement) as String
                    val primary = isPrimary.invoke(storageVolumeElement) as Boolean

                    // primary volume?
                    if (primary != null && PRIMARY_VOLUME_NAME == volumeId) {
                        return getDirectoryPath(storageVolumeClazz, storageVolumeElement)
                    }

                    // other volumes?
                    if (uuid != null && uuid == volumeId) {
                        return getDirectoryPath(storageVolumeClazz, storageVolumeElement)
                    }
                }
                // not found.
                null
            } catch (ex: Exception) {
                null
            }
        }

        private fun isDownloadsDocument(uri: Uri): Boolean {
            return "com.android.providers.downloads.documents" == uri.authority
        }

        @TargetApi(Build.VERSION_CODES.LOLLIPOP)
        private fun getVolumeIdFromTreeUri(treeUri: Uri): String? {
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            val split = docId.split(":").toTypedArray()
            return if (split.size > 0) split[0] else null
        }


        @TargetApi(Build.VERSION_CODES.LOLLIPOP)
        private fun getDocumentPathFromTreeUri(treeUri: Uri): String? {
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            val split: Array<String?> = docId.split(":").toTypedArray()
            return if (split.size >= 2 && split[1] != null) split[1] else File.separator
        }


        fun getFileName(uri: Uri, context: Context): String? {
            var result: String? = null
            try {
                if (uri.scheme == "content") {
                    val cursor = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    try {
                        if (cursor != null && cursor.moveToFirst()) {
                            result = cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
                        }
                    } finally {
                        cursor!!.close()
                    }
                }
                if (result == null) {
                    result = uri.path
                    val cut = result!!.lastIndexOf('/')
                    if (cut != -1) {
                        result = result.substring(cut + 1)
                    }
                }
            } catch (ex: Exception) {
                Log.e(TAG, "Failed to handle file name: $ex")
            }
            return result
        }


    }






}