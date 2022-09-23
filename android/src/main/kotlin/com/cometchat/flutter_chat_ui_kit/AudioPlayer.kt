package com.cometchat.flutter_chat_ui_kit

import android.content.Context
import android.content.res.AssetManager
import android.media.AudioAttributes
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.os.Vibrator
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


class AudioPlayer {

    private var mMediaPlayer = MediaPlayer()

//     fun playDefaultSound(call: MethodCall, result: MethodChannel.Result,context: Context) {
//
//         val ringId: Int = when (call.argument("ringId") ?: "") {
//             "incomingMessage" -> {
//                 R.raw.incoming_message
//             }
//             "outgoingMessage" -> {
//                 R.raw.outgoing_message
//             }
//             "incomingMessageFromOther" -> {
//                 R.raw.record_start
//             }
//             "beep" -> {
//                 R.raw.beep2
//             }
//             else -> { // Note the block
//                 R.raw.record_error
//             }
//         }
//        val mMediaPlayer = MediaPlayer.create(context, ringId)
//       // mMediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC)
//
//         mMediaPlayer.setAudioAttributes(
//                 AudioAttributes.Builder()
//                         .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
//                         .build())
//
//        mMediaPlayer.start()
//        mMediaPlayer.setOnCompletionListener { mediaPlayer ->
//            val mediaPlayer: MediaPlayer? = mediaPlayer
//            if (mediaPlayer != null) {
//                mediaPlayer.stop()
//                mediaPlayer.release()
//            }
//            result.success("Sound Played" )
//        }
//
//
//    }

     fun playCustomSound(call: MethodCall, result: MethodChannel.Result, context: Context ) {
        val assetAudioPath: String = call.argument("assetAudioPath") ?: ""


        val mMediaPlayer = MediaPlayer()

         //This code can be helpful for vibration issue
        //val mmr = MediaMetadataRetriever()
         // mmr.setDataSource(afd.fileDescriptor, afd.startOffset, afd.declaredLength)
        //      mmr.release()
         val afd = context.assets.openFd("flutter_assets/$assetAudioPath")
        mMediaPlayer.setDataSource(afd.fileDescriptor, afd.startOffset, afd.declaredLength)

        afd.close()


         mMediaPlayer.setAudioAttributes(
                 AudioAttributes.Builder()
                         .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                         .build())


        mMediaPlayer.setOnPreparedListener {
            mMediaPlayer.start()
            mMediaPlayer.setOnCompletionListener { mediaPlayer ->
                val mediaPlayer = mediaPlayer
                if (mediaPlayer != null) {
                    mediaPlayer.stop()
                    mediaPlayer.release()
                } }
        }
        mMediaPlayer.prepare()
        result.success("Sound Played" )
    }

//     fun playURL(call: MethodCall, result: MethodChannel.Result,context: Context) {
//        val audioURL: String = call.argument("audioURL") ?: ""
//        val messageId: Int = call.argument<Int>("messageId") ?: 0
//
//        try {
//            if(mMediaPlayer.isPlaying){
//                this.mMediaPlayer.stop()
//
//            }
//        } catch (e: Exception) {
//            // handler
//        }
//
//        this.mMediaPlayer = MediaPlayer.create(context, Uri.parse(audioURL))
//
//        mMediaPlayer.setOnCompletionListener { mediaPlayer ->
//            val mediaPlayer = mediaPlayer
//
//            if (mediaPlayer != null) {
//                mediaPlayer.stop()
//                mediaPlayer.release()
//            }
//            val res =  hashMapOf(
//                    "messageId" to messageId,
//                    "status" to "Stopped"
//            )
//            result.success(res)
//        }
//        mMediaPlayer.start()
//    }
//
//     fun stopPlayer(result: MethodChannel.Result) {
//        try {
//            if(mMediaPlayer.isPlaying){
//                this.mMediaPlayer.stop()
//
//            }
//        } catch (e: Exception) {
//            // handler
//        }
//        result.success("Player Stopped")
//    }
}