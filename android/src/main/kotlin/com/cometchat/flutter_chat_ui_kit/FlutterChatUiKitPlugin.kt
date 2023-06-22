package com.cometchat.flutter_chat_ui_kit

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.AssetManager
import android.media.AudioManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
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
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File
import java.lang.Exception
import java.util.ArrayList
import java.util.HashMap


/** FlutterChatUiKitPlugin */
class FlutterChatUiKitPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener, PluginRegistry.RequestPermissionsResultListener {

  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private var flutterPluginBinding: FlutterPluginBinding? = null
  private lateinit var activity: Activity
  private val locationRequestCheckCode = 111
  private var successCallback: Result? = null
  private var vibrator: Vibrator? = null
  private val VIBRATE_PATTERN = longArrayOf(0, 1000, 1000)

  private var delegate: CometChatFilePickerDelegate? = null
  private var isMultipleSelection = false
  private var withData = false
  private var activityBinding: ActivityPluginBinding? = null
  private var fileType: String? = null


  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding

    this.context = flutterPluginBinding.applicationContext
//    vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_chat_ui_kit")

    channel.setMethodCallHandler(this)
    initAudio()
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "playCustomSound" -> playCustomSound(call, result)
      "open_file" -> openFile(call,result)
      //"stopPlayer" -> stopPlayer(result)
      "getAddress" -> getAddress(call,result)
      "getCurrentLocation" -> getCurrentLocation(result)
      "getLocationPermission" -> getLocationPermission(result)
      "clear" -> clearCache(this.context)
      "pickFile" -> pickFile(call, result)
      else -> result.notImplemented()
    }
  }

  private fun getLocationPermission(result: Result){

    if(hasPermissions(context, Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION))
    {
      result.success(mapOf("status" to true,"message" to "Permission already granted"))
    }
    else{
      successCallback=result
      ActivityCompat.requestPermissions(this.activity,arrayOf(
              Manifest.permission.ACCESS_FINE_LOCATION
      ), 10)
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


  private fun pickFile(call: MethodCall, result: Result) {

    val arguments = call.arguments as HashMap<*, *>
    var allowedExtensions: Array<String>? = null


    isMultipleSelection = arguments["allowMultipleSelection"] as Boolean
    withData = arguments["withData"] as Boolean
    fileType = resolveType(arguments["type"] as String);
    allowedExtensions = CometChatFileUtils.getMimeTypes(arguments["allowedExtensions"] as ArrayList<String>?)

    delegate!!.startFileExplorer(fileType, isMultipleSelection, withData, allowedExtensions , result)


  }


  private fun resolveType(type: String): String? {
    return when (type) {
      "audio" -> "audio/*"
      "image" -> "image/*"
      "video" -> "video/*"
      "media" -> "image/*,video/*"
      "any", "custom" -> "*/*"
      "dir" -> "dir"
      else -> null
    }
  }


  private fun setup(
          activity: Activity,
          registrar: Registrar?,
          activityBinding: ActivityPluginBinding) {
    this.activity = activity
    //this.application = application
    delegate = CometChatFilePickerDelegate(activity)
//    channel = MethodChannel(messenger, FilePickerPlugin.CHANNEL)
//    channel.setMethodCallHandler(this)
//    EventChannel(messenger, FilePickerPlugin.EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
//      override fun onListen(arguments: Any, events: EventSink) {
//        delegate.setEventHandler(events)
//      }
//
//      override fun onCancel(arguments: Any) {
//        delegate.setEventHandler(null)
//      }
//    })
    //this.observer = FilePickerPlugin.LifeCycleObserver(activity)
    if (registrar != null) {
      // V1 embedding setup for activity listeners.
      //application.registerActivityLifecycleCallbacks(this.observer)
      registrar.addActivityResultListener(delegate!!)
      registrar.addRequestPermissionsResultListener(delegate!!)
    } else {
      // V2 embedding setup for activity listeners.
      activityBinding.addActivityResultListener(delegate!!)
      activityBinding.addRequestPermissionsResultListener(delegate!!)
//      this.lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityBinding)
//      this.lifecycle.addObserver(this.observer)
    }
  }


  private fun getCurrentLocation(result: Result){

    successCallback=result
    if(hasPermissions(context, Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION))
    {
      LocationService().getCurrentLocation(context,activity,result)
    }
    else{
      successCallback = null
      result.success(mapOf("status" to false,"message" to "Location Permission denied"))
    }

  }

  private fun openFile(call: MethodCall, result: Result){
    OpenFile.openFile(call,result,context,activity)
  }

  private fun getAddress(call: MethodCall, result: Result) {
    LocationService().getAddressFromLatitudeLongitude(call,result,context)
  }


  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    channel = MethodChannel(flutterPluginBinding?.binaryMessenger!!, "flutter_chat_ui_kit")
    activity = binding.activity
    channel.setMethodCallHandler(this)
    binding.addRequestPermissionsResultListener(this)
    binding.addActivityResultListener(this)

    activityBinding = binding
    setup(
            activity,
            null,
            activityBinding!!

    )







  }

  override fun onDetachedFromActivityForConfigChanges() {
    // TODO("Not yet implemented")
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    // TODO("Not yet implemented")
  }

  override fun onDetachedFromActivity() {
    // TODO("Not yet implemented")
  }

//  private fun playDefaultSound(call: MethodCall, result: Result) {
//    AudioPlayer().playDefaultSound(call,result,context)
//  }


  private fun playCustomSound(call: MethodCall, result: Result) {

    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    vibrator= if (Build.VERSION.SDK_INT >= 31) {
      @SuppressLint("WrongConstant")
      val vibratorManager =
              context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
      vibratorManager.defaultVibrator

    } else {
  @Suppress("DEPRECATION")
      context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    if ((audioManager.ringerMode!=AudioManager.RINGER_MODE_SILENT && audioManager.isMusicActive) || audioManager.ringerMode==AudioManager.RINGER_MODE_VIBRATE) {
      if (Build.VERSION.SDK_INT >= 26) {
        vibrator?.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
      } else {
        vibrator?.vibrate(500)
      }

//      vibrator?.vibrate(com.cometchatworkspace.components.shared.primaryComponents.soundManager.CometChatSoundManager.VIBRATE_PATTERN, 2)
    }else if (audioManager.ringerMode==AudioManager.RINGER_MODE_NORMAL) {
      AudioPlayer().playCustomSound(call,result,context)
    }


  }

//  private fun playURL(call: MethodCall, result: Result) {
//    AudioPlayer().playURL(call,result,context)
//  }
//
//  private fun stopPlayer(result: Result) {
//    AudioPlayer().stopPlayer(result)
//  }

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

  fun getAudioManager(context: Context): AudioManager? {
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
          LocationService().getCurrentLocation(context,activity,successCallback!!)
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

