//
//  ScreenAsset.swift
//  Example iOS
//
//  Created by Mejdi Lassidi on 3/22/19.
//  Copyright © 2019 Shogo Endo. All rights reserved.
//

import Foundation
import AVFoundation
import HaishinKit

class ScreenAsset: RecordingAsset {
    
    var mixer = AVMixer()
    var videoMerger: KVVideoManager = KVVideoManager(videoTitle: "screenVideo")
    var outputURL: URL?
    var recorderDelegate: AVRecorderDelegate = AVRecorderDelegate()
    var screenRecorderSession: ScreenCaptureSession = ScreenCaptureSession(shared: .shared)
    var videosURLs: [URL] = [URL]()
    
    func attachScreen() {
        mixer.attachScreen(screenRecorderSession)
    }
    
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
        
        mixer.recorderSettings = [.video: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: 0,
            AVVideoWidthKey: 0
            ]
        ]
    }
    
    func startRecording() {
        self.attachScreen()
        self.mixer.startRunning()
        self.mixer.recorder.startRunning()
    }
}
