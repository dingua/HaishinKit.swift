//
//  RecordingService.swift
//  Example iOS
//
//  Created by Mejdi Lassidi on 2/26/19.
//  Copyright © 2019 Shogo Endo. All rights reserved.
//

import UIKit
import AVFoundation
import HaishinKit
import Photos

class RecordingService {
    
    public private(set) var cameraMixer = AVMixer()
    public private(set) var recordScreenMixer = AVMixer()
    let sampleRate: Double = 44_100
    
    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    public let lockQueue = ({ () -> DispatchQueue in
        let queue = DispatchQueue(label: "com.shortcut.ios.app")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    })()
    
    let recorderDelegate = ExampleRecorderDelegate()
    let screenRecorderDelegate = ExampleRecorderDelegate()
    
    var screenRecorderSession: ScreenCaptureSession!
    
    // -MARK: Public
    
    func attachCamera(_ camera: AVCaptureDevice?, onError: ((_ error: NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.cameraMixer.attachCamera(camera)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }
    
    func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = false, onError: ((_ error: NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.cameraMixer.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }
    
    func setPointOfInterest(_ focus: CGPoint, exposure: CGPoint) {
        cameraMixer.setPointOfInterest(focus, exposure: exposure)
        recordScreenMixer.setPointOfInterest(focus, exposure: exposure)
    }
    
    func setupSettings() {
        
        ensureLockQueue {
            
            self.cameraMixer.captureSettings = [
                "sessionPreset": AVCaptureSession.Preset.hd1280x720.rawValue,
                "continuousAutofocus": true,
                "continuousExposure": true
            ]
            
            self.cameraMixer.videoSettings = [
                "width": 720,
                "height": 1280
            ]
            
            self.cameraMixer.audioSettings = [
                "sampleRate": self.sampleRate
            ]
            
            self.recordScreenMixer.captureSettings = [
                "sessionPreset": AVCaptureSession.Preset.hd1280x720.rawValue,
                "continuousAutofocus": true,
                "continuousExposure": true
            ]
            
            self.recordScreenMixer.videoSettings = [
                "width": 720,
                "height": 1280
            ]
            
            self.recordScreenMixer.recorderSettings = [.video: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoHeightKey: 0,
                AVVideoWidthKey: 0
                ]
            ]
        }
    }
    
    func setupRecorder() {
        
        cameraMixer.recorder.delegate = recorderDelegate
        recordScreenMixer.recorder.delegate = screenRecorderDelegate
    }
    
    func startRunning() {
        
        lockQueue.async {
            
            self.recordScreen()
            self.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
                print("\(error.description)")
            }
            let camera = DeviceUtil.device(withPosition: .front)
            self.attachCamera(camera) { error in
                print("\(error.description)")
            }
            
            self.cameraMixer.startRunning()
            self.cameraMixer.recorder.startRunning()
            
            self.recordScreenMixer.startRunning()
            self.recordScreenMixer.recorder.startRunning()
            self.recordScreen()
        }
    }
    
    func stopRunning() {
        lockQueue.async {
        
            self.cameraMixer.stopRunning()
            self.cameraMixer.recorder.stopRunning()
            
            self.recordScreenMixer.stopRunning()
            self.recordScreenMixer.recorder.stopRunning()
        }
    }
    
    func pause(_ completion: @escaping () -> ()) {
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        self.cameraMixer.recorder.stopRunning() {
            print("💣")
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        self.recordScreenMixer.recorder.stopRunning() {
            print("💣")
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            completion()
        }
    }
    
    func resume() {

        self.cameraMixer.recorder.startRunning()
        self.recordScreenMixer.recorder.startRunning()
    }
    
    
    func recordScreen() {
        if screenRecorderSession == nil {
            screenRecorderSession = ScreenCaptureSession(shared: .shared)
        }
        
        recordScreenMixer.attachScreen(screenRecorderSession)
    }
    
    // - MARK: Private
    
    private func ensureLockQueue(callback: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: RecordingService.queueKey) == RecordingService.queueValue {
            callback()
        } else {
            lockQueue.sync {
                callback()
            }
        }
    }
}

class ExampleRecorderDelegate: DefaultAVRecorderDelegate {
    override func didFinishWriting(_ recorder: AVRecorder) {
        print("👏 didFinishWriting (RecordingService)")
        guard let writer: AVAssetWriter = recorder.writer else { return }
        PHPhotoLibrary.shared().performChanges({() -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { _, error -> Void in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch {
                print(error)
            }
        })
    }
}
