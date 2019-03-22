//
//  CameraAsset.swift
//  Example iOS
//
//  Created by Mejdi Lassidi on 3/22/19.
//  Copyright © 2019 Shogo Endo. All rights reserved.
//

import Foundation
import AVFoundation
import HaishinKit


final class CameraAsset: RecordingAsset {
    
    var mixer = AVMixer()
    var videoMerger: KVVideoManager = KVVideoManager(videoTitle: "cameraVideo")
    
    var outputURL: URL?
    
    var recorderDelegate: AVRecorderDelegate = AVRecorderDelegate()
    
    var videosURLs: [URL] = [URL]()
    
    private let sampleRate: Double = 44_100
    
    func setupSettings() {
        
        mixer.captureSettings = [
            "sessionPreset": AVCaptureSession.Preset.hd1280x720.rawValue,
            "continuousAutofocus": true,
            "continuousExposure": true
        ]
        
        mixer.videoSettings = [
            "width": 720,
            "height": 1280
        ]
        
        mixer.audioSettings = [
            "sampleRate": sampleRate
        ]
    }
    
    func startRecording() {
        
        attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            print("\(error.description)")
        }
        let camera = DeviceUtil.device(withPosition: .front)
        attachCamera(camera) { error in
            print("\(error.description)")
        }
        
        self.mixer.startRunning()
        self.mixer.recorder.startRunning()
    }
    
    private func attachCamera(_ camera: AVCaptureDevice?, onError: ((_ error: NSError) -> Void)? = nil) {
        do {
            try self.mixer.attachCamera(camera)
        } catch let error as NSError {
            onError?(error)
        }
    }
    
    private func attachAudio(_ audio: AVCaptureDevice?,
                             automaticallyConfiguresApplicationAudioSession: Bool = false,
                             onError: ((_ error: NSError) -> Void)? = nil) {
        
        do {
            try self.mixer.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
        } catch let error as NSError {
            onError?(error)
        }
    }
}
