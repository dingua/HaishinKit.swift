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

enum RecordingMode {
    case cameraAndScreen
    case camera
    case screen
}

struct RecordingOutput {
    let cameraFileURL: URL?
    let screenFileURL: URL?
}

protocol RecordingServiceProtocol {
    
    var mode: RecordingMode { get }
    func setup()
    func startRecording()
    func stopRecording(_ completion: @escaping (_ recordingOutput: RecordingOutput) -> ())
    func pause(_ completion: @escaping () -> ())
    func resume()
}

enum AssetType {
    case camera
    case screen
}

protocol RecordingAsset {
    var type: AssetType { get }
    var videoMerger: KVVideoManager { get }
    var outputURL: URL? { get }
    var recorderDelegate: ExampleRecorderDelegate { get }
    var videosURLS: [URL] { get }
}

class CameraAsset: RecordingAsset {
    var type: AssetType = .camera
    var videoMerger: KVVideoManager = KVVideoManager(videoTitle: "cameraVideo")
    
    var outputURL: URL?
    
    var recorderDelegate: ExampleRecorderDelegate = ExampleRecorderDelegate()
    
    var videosURLS: [URL] = [URL]()
    
    
}

class ScreenAsset: RecordingAsset {
    var type: AssetType = .screen
    var videoMerger: KVVideoManager = KVVideoManager(videoTitle: "screenVideo")
    var outputURL: URL?
    var recorderDelegate: ExampleRecorderDelegate = ExampleRecorderDelegate()
    var screenRecorderSession: ScreenCaptureSession!
    var videosURLS: [URL] = [URL]()
}

class RecordingService: RecordingServiceProtocol {
    
    public private(set) var cameraMixer = AVMixer()
    public private(set) var recordScreenMixer = AVMixer()
    public let mode: RecordingMode
    
    private let sampleRate: Double = 44_100
    
    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    private let lockQueue = ({ () -> DispatchQueue in
        let queue = DispatchQueue(label: "com.shortcut.ios.app")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    })()
    
    private var cameraOutputURL: URL?
    private var screenOutputURL: URL?
    
    private let recorderDelegate = ExampleRecorderDelegate()
    private let screenRecorderDelegate = ExampleRecorderDelegate()
    
    private var screenRecorderSession: ScreenCaptureSession!
    
    
    private var cameraVideos = [URL]()
    private var screenVideos = [URL]()
    
    private let cameraVideoManager = KVVideoManager(videoTitle: "cameraVideo")
    private let screenVideoManager = KVVideoManager(videoTitle: "screenVideo")
    
    enum Constants {
        static let storageDirectory = "shortcut_videos"
    }
    
    private var isRecording = false
    
    // -MARK: Public
    
    init(mode: RecordingMode) {
        self.mode = mode
    }
    
    func setup() {
        setupSettings()
        setupRecorder()
    }
    
    func startRecording() {
        
        cameraVideos = [URL]()
        screenVideos = [URL]()
        isRecording = true
        
        lockQueue.async {
            
            switch self.mode {
            case .cameraAndScreen:
                self.startCameraRecording()
                self.startScreenRecording()
            case .camera:
                self.startCameraRecording()
            case .screen:
                self.startScreenRecording()
            }
        }
    }
    
    func stopRecording(_ completion: @escaping (_ recordingOutput: RecordingOutput) -> ()) {
        
        lockQueue.async {
            
            self.isRecording = false
            
            switch self.mode {
            case .cameraAndScreen:
                self.stopCameraRecording()
                self.stopScreenRecording()
            case .camera:
                self.stopCameraRecording()
            case .screen:
                self.stopScreenRecording()
            }
            
            self.dispatchGroup.notify(queue: .main) { [unowned self] in
                
                
                if !self.cameraMixer.isRunning && !self.recordScreenMixer.isRunning {
                    
                    let mergeDispatchGroup = DispatchGroup()
                    var cameraURL: URL?
                    var screenURL: URL?
                    print("👀 camera videos \(self.cameraVideos.count)")
                    if self.cameraVideos.isEmpty == false {
                        
                        mergeDispatchGroup.enter()
                        
                        self.cameraVideoManager.merge(arrayVideos: self.cameraVideos.compactMap { AVAsset(url: $0) }) { url, error in
                            
                            guard error == nil else { return }
                            
                            cameraURL = url
                            
                            mergeDispatchGroup.leave()
                            //                            completion(RecordingOutput(cameraFileURL: self.cameraOutputURL, screenFileURL: self.screenOutputURL))
                        }
                    }
                    
                    if self.screenVideos.isEmpty == false  {
                        
                        mergeDispatchGroup.enter()
                        
                        self.screenVideoManager.merge(arrayVideos: self.screenVideos.compactMap { AVAsset(url: $0) }) { url, error in
                            
                            guard error == nil else { return }
                            
                            screenURL = url
                            
                            mergeDispatchGroup.leave()
                            //                            completion(RecordingOutput(cameraFileURL: self.cameraOutputURL, screenFileURL: self.screenOutputURL))
                        }
                    }
                    
                    mergeDispatchGroup.notify(queue: DispatchQueue.main) {
                        
                        self.saveToPhotos(cameraURL)
                        self.saveToPhotos(screenURL)
                        completion(RecordingOutput(cameraFileURL: cameraURL, screenFileURL: screenURL))
                    }
                }
            }
            
        }
        
    }
    
    func saveToPhotos(_ cameraURL: URL?) {
        
        guard let cameraURL = cameraURL else { return }
        print("😎 saved to photos \(cameraURL.absoluteURL.absoluteString)")
        PHPhotoLibrary.shared().performChanges({() -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: cameraURL)
        }, completionHandler: { _, error -> Void in
            do {
                try FileManager.default.removeItem(at: cameraURL)
            } catch {
                print(error)
            }
        })
    }
    
    // HACK: Due to limitation for now pausing just save the recorded input to disk
    // When it comes to uploading we have to upload the multiple session videos created between
    // the start and the end of recording
    func pause(_ completion: @escaping () -> ()) {
        
        let dispatchGroup = DispatchGroup()
        
        switch mode {
        case .cameraAndScreen:
            dispatchGroup.enter()
            self.cameraMixer.recorder.stopRunning() { url in
                if let url = url {
                    print("👀 video url \(url)")
                    self.cameraVideos.append(url)
                }
                dispatchGroup.leave()
            }
            
            dispatchGroup.enter()
            self.recordScreenMixer.recorder.stopRunning() { url in
                if let url = url {
                    print("👀 screen url \(url)")
                    self.screenVideos.append(url)
                }
                dispatchGroup.leave()
            }
            
        case .camera:
            dispatchGroup.enter()
            self.cameraMixer.recorder.stopRunning() { url in
                if let url = url {
                    self.cameraVideos.append(url)
                }
                dispatchGroup.leave()
            }
            
        case .screen:
            dispatchGroup.enter()
            self.recordScreenMixer.recorder.stopRunning() { url in
                if let url = url {
                    print("👀 screen url \(url)")
                    self.screenVideos.append(url)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            completion()
        }
    }
    
    func resume() {
        
        switch self.mode {
        case .cameraAndScreen:
            self.cameraMixer.recorder.startRunning()
            self.recordScreenMixer.recorder.startRunning()
        case .camera:
            self.cameraMixer.recorder.startRunning()
        case .screen:
            self.recordScreenMixer.recorder.startRunning()
        }
    }
    
    
    // - MARK: Private
    
    private func setupSettings() {
        
        ensureLockQueue {
            
            switch self.mode {
            case .cameraAndScreen:
                self.setupCameraRecording()
                self.setupScreenRecording()
            case .camera:
                self.setupCameraRecording()
            case .screen:
                self.setupScreenRecording()
            }
        }
    }
    
    private func setupCameraRecording() {
        
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
    }
    
    private func setupScreenRecording() {
        
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
    
    private func startCameraRecording() {
        self.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            print("\(error.description)")
        }
        let camera = DeviceUtil.device(withPosition: .front)
        self.attachCamera(camera) { error in
            print("\(error.description)")
        }
        
        self.cameraMixer.startRunning()
        self.cameraMixer.recorder.startRunning()
    }
    
    private func startScreenRecording() {
        
        self.attachScreen()
        self.recordScreenMixer.startRunning()
        self.recordScreenMixer.recorder.startRunning()
    }
    
    var dispatchGroup = DispatchGroup()
    private func setupRecorder() {
        
        switch self.mode {
        case .cameraAndScreen:
            recordScreenMixer.recorder.delegate = screenRecorderDelegate
            cameraMixer.recorder.delegate = recorderDelegate
        case .camera:
            cameraMixer.recorder.delegate = recorderDelegate
        case .screen:
            recordScreenMixer.recorder.delegate = screenRecorderDelegate
        }
    }
    
    private func stopCameraRecording() {
        dispatchGroup.enter()
        cameraMixer.stopRunning()
        cameraMixer.recorder.stopRunning()
        
        recorderDelegate.completionHandler = { [weak self] url in
            guard let url = url, self?.isRecording == false else { return }
            self?.cameraVideos.append(url)
            self?.cameraOutputURL = url
            self?.dispatchGroup.leave()
        }
    }
    
    private func stopScreenRecording() {
        dispatchGroup.enter()
        print("❤️ dispatchGroup.enter")
        self.recordScreenMixer.stopRunning()
        self.recordScreenMixer.recorder.stopRunning()
        
        screenRecorderDelegate.completionHandler = { [weak self] url in
            guard let url = url, self?.isRecording == false else { return }
            print("❤️ dispatchGroup.leave")
            self?.screenVideos.append(url)
            self?.screenOutputURL = url
            self?.dispatchGroup.leave()
        }
    }
    
    private func attachCamera(_ camera: AVCaptureDevice?, onError: ((_ error: NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.cameraMixer.attachCamera(camera)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }
    
    private func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = false, onError: ((_ error: NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.cameraMixer.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }
    
    
    private func attachScreen() {
        if screenRecorderSession == nil {
            screenRecorderSession = ScreenCaptureSession(shared: .shared)
        }
        
        recordScreenMixer.attachScreen(screenRecorderSession)
    }
    
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

enum VideoType {
    case camera
    case screen
}

extension AVRecorder {
    var isCameraRecording: Bool {
        return writer?.inputs.count == 2
    }
    
}

class ExampleRecorderDelegate: DefaultAVRecorderDelegate {
    
    var completionHandler: ((URL?) -> ())?
    
    override func didFinishWriting(_ recorder: AVRecorder) {
        
        print("SCREEN 💚")
        
        guard let writer: AVAssetWriter = recorder.writer else {
            completionHandler?(nil)
            return
            
        }
        print("🎉 didFinishWriting writer url \(writer.outputURL)")
        
        self.completionHandler?(writer.outputURL)
    }
}
