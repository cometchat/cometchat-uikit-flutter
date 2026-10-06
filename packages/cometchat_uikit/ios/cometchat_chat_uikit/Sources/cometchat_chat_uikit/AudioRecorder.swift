//
//  AudioRecorder.swift
//  cometchat
//
//  Created by nabhodipta on 31/07/23.
//

import Foundation
import AVFAudio
import Flutter

public class AudioRecorder: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var audioFilename: URL!
    var lastPlaybackTime: CMTime?
    let dateFormatter = DateFormatter()
    var timer: Timer?
    var binaryMessenger: FlutterBinaryMessenger
    
    
    
    
    private let eventChannelName = "cometchat_uikit_shared_audio_intensity"
    
    var player: AVAudioPlayer?
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        self.binaryMessenger = binaryMessenger
        
        super.init()
        setupEventChannel()
    }
    
    func setupRecorder(result: @escaping FlutterResult) {
        recordingSession = AVAudioSession.sharedInstance()
        
        switch recordingSession.recordPermission {
        case .denied:
            Toast.show(message: "Microphone permission is denied.")
            result(false)
            return

        case .undetermined:
            // 🔄 Ask for permission
            recordingSession.requestRecordPermission { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        do {
                            // .defaultToSpeaker so playback right after recording comes out of the
                            // loudspeaker rather than the earpiece (ENG-39489).
                            try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                            try recordingSession.setActive(true)
                            self.startRecording()
                            result(true)
                        } catch {
                            Toast.show(message: "Failed to activate recording session.")
                            result(false)
                        }
                    } else {
                        Toast.show(message: "Microphone permission is required to record audio.")
                        result(false)
                    }
                }
            }
            
        case .granted:
            do {
                // See above: keep the speaker route for post-record playback.
                try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try recordingSession.setActive(true)
                self.startRecording()
                result(true)
            } catch {
                Toast.show(message: "Failed to activate recording session.")
                result(false)
            }
            
        @unknown default:
            Toast.show(message: "Microphone permission status is unknown.")
            result(false)
        }
    }

    
    func setupEventChannel(){
        let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: binaryMessenger)
        eventChannel.setStreamHandler(self)
        
    }
    
    
    func startRecording() {
        audioFilename = getFileURL()
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
        } catch {
            stopRecording(success: false)
        }
    }
    
    func stopRecording(success: Bool) -> String? {
        if success {
            audioRecorder?.stop()
            audioRecorder = nil
            
            do {
                try recordingSession.setActive(false)
            } catch {
                print("Error stopping recording: \(error.localizedDescription)")
            }
            return audioFilename.path
        } else {
            
            return nil
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    func getFileURL() -> URL {
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let path = getDocumentsDirectory().appendingPathComponent("audio-recording-\(dateFormatter.string(from: Date())).m4a")
        return path as URL
    }
    
    func preparePlayer() {
        // Stop recorder if still active to finalize the file
        if audioRecorder != nil {
            audioRecorder?.stop()
            audioRecorder = nil
            do {
                try recordingSession.setActive(false)
            } catch {
                print("Error stopping recording session: \(error.localizedDescription)")
            }
        }
        
        var error: NSError?
        do {
            player = try AVAudioPlayer(contentsOf: audioFilename)
        } catch let error1 as NSError {
            error = error1
            player = nil
        }
        if let err = error {
            print("AVAudioPlayer error: \(err.localizedDescription)")
        } else {
            player?.delegate = self
            player?.prepareToPlay()
            player?.volume = 10.0
        }
    }
    
    public func startPlaying(){
        preparePlayer()
        player?.play()
    }
    
    public func pausePlaying(){
        player?.pause()
    }
    
    public func resumePlaying() -> Bool {
        guard let player = player else { return false }
        player.play()
        return true
    }
    
    public func seekTo(positionMs: Int) -> Bool {
        let positionSeconds = Double(positionMs) / 1000.0
        
        if let player = player {
            // Player exists, just seek
            player.currentTime = positionSeconds
            // If not playing, start playback
            if !player.isPlaying {
                player.play()
            }
            return true
        } else {
            // Player not initialized, need to create it first
            guard audioFilename != nil else { return false }
            
            preparePlayer()
            guard let player = player else { return false }
            
            player.currentTime = positionSeconds
            player.play()
            return true
        }
    }
    
    public func getPlaybackStatus() -> [String: Any] {
        var status: [String: Any] = [
            "isPlaying": false,
            "currentPosition": 0,
            "duration": 0
        ]
        
        if let player = player {
            status["isPlaying"] = player.isPlaying
            status["currentPosition"] = Int(player.currentTime * 1000) // Convert to milliseconds
            status["duration"] = Int(player.duration * 1000) // Convert to milliseconds
        }
        
        return status
    }
    
    /// Extract waveform data from the recorded audio file
    /// Returns an array of amplitude values (0.0 to 1.0) representing the audio waveform
    public func extractWaveform(sampleCount: Int = 50, completion: @escaping ([Double]) -> Void) {
        guard let fileUrl = audioFilename else {
            print("[AudioRecorder] extractWaveform: No audio filename set")
            completion([])
            return
        }
        
        print("[AudioRecorder] extractWaveform: Extracting from \(fileUrl.path)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let audioFile = try AVAudioFile(forReading: fileUrl)
                let format = audioFile.processingFormat
                let frameCount = UInt32(audioFile.length)
                
                print("[AudioRecorder] extractWaveform: File has \(frameCount) frames")
                
                guard frameCount > 0 else {
                    print("[AudioRecorder] extractWaveform: File has no frames")
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                // Create buffer to read audio data
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    print("[AudioRecorder] extractWaveform: Failed to create buffer")
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                try audioFile.read(into: buffer)
                
                guard let floatData = buffer.floatChannelData else {
                    print("[AudioRecorder] extractWaveform: No float channel data")
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                let channelData = floatData[0]
                let totalSamples = Int(buffer.frameLength)
                
                print("[AudioRecorder] extractWaveform: Processing \(totalSamples) samples")
                
                // Calculate samples per chunk
                let samplesPerChunk = max(1, totalSamples / sampleCount)
                var amplitudes: [Double] = []
                
                for i in 0..<sampleCount {
                    let startSample = i * samplesPerChunk
                    let endSample = min(startSample + samplesPerChunk, totalSamples)
                    
                    if startSample >= totalSamples {
                        break
                    }
                    
                    // Calculate RMS (Root Mean Square) for this chunk
                    var sum: Float = 0
                    for j in startSample..<endSample {
                        let sample = channelData[j]
                        sum += sample * sample
                    }
                    
                    let rms = sqrt(sum / Float(endSample - startSample))
                    
                    // Normalize to 0.0 - 1.0 range with some amplification for visual appeal
                    // RMS values are typically small, so we amplify them
                    var normalizedAmplitude = Double(rms) * 3.0
                    
                    // Apply curve for better visual representation
                    if normalizedAmplitude < 0.1 {
                        normalizedAmplitude = 0.15 + normalizedAmplitude * 2.0
                    } else if normalizedAmplitude < 0.4 {
                        normalizedAmplitude = 0.35 + (normalizedAmplitude - 0.1) * 1.17
                    } else {
                        normalizedAmplitude = 0.7 + (normalizedAmplitude - 0.4) * 0.5
                    }
                    
                    amplitudes.append(min(1.0, max(0.15, normalizedAmplitude)))
                }
                
                print("[AudioRecorder] extractWaveform: Extracted \(amplitudes.count) amplitude samples")
                
                DispatchQueue.main.async {
                    completion(amplitudes)
                }
                
            } catch {
                print("Error extracting waveform: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
    
    private func stopPlaying(){
        player?.stop()
        player = nil
    }
    
    public func releaseMediaResources(){
        if audioRecorder != nil || audioRecorder?.isRecording == true {
            stopRecording(success: true)
        }
        
        if player != nil || player?.isPlaying == true {
            stopPlaying()
        }
    }
    
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if  !flag {
            stopRecording(success: false)
        }
    }
    
    func pauseRecording() {
            if let recorder = audioRecorder, recorder.isRecording {
                recorder.pause()
            }
        }
    
    func resumeRecording(result: @escaping FlutterResult) {
        guard let recorder = audioRecorder else {
            result(false)
            return
        }

        if recorder.isRecording {
            result(true)
            return
        }

        let success = recorder.record()
        if success {
            result(true)
        } else {
            print("Failed to start recording")
            result(false)
        }
    }

}

extension AudioRecorder: FlutterStreamHandler {
    
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        timer?.invalidate()
        timer = nil  // Reset before creating a new one
        // Send events every 100ms for responsive waveform visualization
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            self.audioRecorder?.updateMeters()
            let decibels = self.audioRecorder?.averagePower(forChannel: 0)
            // Convert the decibels to a linear scale (0.0 to 1.0)
            if decibels != nil {
                let linear = pow(10, (decibels!) / 20)
                events(linear)
            }
        }
        
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        timer?.invalidate()
        timer = nil
        return nil
    }
    
}
