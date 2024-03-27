package com.cometchat.cometchat_chat_uikit

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.lang.Exception


/** CometchatChatUikitPlugin */
class CometchatChatUikitPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener, PluginRegistry.RequestPermissionsResultListener {

  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private var flutterPluginBinding: FlutterPluginBinding? = null
  private lateinit var activity: Activity
  private val locationRequestCheckCode = 111
  private var successCallback: Result? = null
  private var activityBinding: ActivityPluginBinding? = null



  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding

    this.context = flutterPluginBinding.applicationContext

    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cometchat_chat_uikit")

    channel.setMethodCallHandler(this)
    initAudio()
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "clear" -> clearCache(this.context)
      else -> result.notImplemented()
    }
  }




  private fun clearCache(context: Context): Boolean {
    try {
      val cacheDir = File(context.cacheDir.toString() + "/file_picker/")
      val files = cacheDir.listFiles()
      if (files != null) {
        for (file in files) {
          file.delete()
        }
      }
    } catch (ex: Exception) {
      Log.e("FileUtil", "There was an error while clearing cached files: $ex")
      return false
    }
    return true
  }



  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    channel = MethodChannel(flutterPluginBinding?.binaryMessenger!!, "cometchat_chat_uikit")
    activity = binding.activity
    channel.setMethodCallHandler(this)
    binding.addRequestPermissionsResultListener(this)
    binding.addActivityResultListener(this)

    activityBinding = binding
  }

  override fun onDetachedFromActivityForConfigChanges() {
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
  }

  override fun onDetachedFromActivity() {
  }


  override fun onDetachedFromEngine(@NonNull binding: FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }


  private fun initAudio(){
    val audioManager: AudioManager? = this.getAudioManager(context)
    if(audioManager!=null){
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
        audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
      } else {
        audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
      }

    }

  }

  private fun getAudioManager(context: Context): AudioManager? {
    return context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
  }

  private fun hasPermissions(context: Context?, vararg permissions: String): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && context != null) {
      for (permission in permissions) {
        if (ActivityCompat.checkSelfPermission(context, permission) !=
                PackageManager.PERMISSION_GRANTED) {

          return false
        }
      }
    }
    return true
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {

    when (requestCode) {
      locationRequestCheckCode -> when (resultCode) {
        Activity.RESULT_OK ->                        {
        }
        Activity.RESULT_CANCELED ->                         {
          successCallback!!.success(mapOf("status" to false,"message" to "gps not turned on"))
        }
        else -> {
        }
      }
    }
    return true
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {

    when (requestCode) {
      10 -> {
        if (grantResults!=null && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {

          if(hasPermissions(context, Manifest.permission.ACCESS_FINE_LOCATION,
                          Manifest.permission.ACCESS_COARSE_LOCATION)){
            successCallback!!.success( mapOf("status" to true,"message" to "location permission granted"))
          }
          else {
            successCallback!!.success( mapOf("status" to false,"message" to "location permission denied"))
          }
        } else {
          successCallback!!.success( mapOf("status" to false,"message" to "permission denied"))
        }
      }
    }
    successCallback = null
    return true
  }
}

