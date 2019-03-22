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

enum AssetType {
    case camera
    case screen
}

final class RecordingService: RecordingServiceProtocol {
    
    public let cameraAsset = CameraAsset()
    public let screenAsset = ScreenAsset()
    
    public let mode: RecordingMode
    
    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    private let lockQueue = ({ () -> DispatchQueue in
        let queue = DispatchQueue(label: "com.shortcut.ios.app")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    })()
    
    private let dispatchGroup = DispatchGroup()
    
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
        
        cameraAsset.videosURLs = [URL]()
        screenAsset.videosURLs = [URL]()
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
                
                
                if !self.cameraAsset.mixer.isRunning && !self.screenAsset.mixer.isRunning {
                    
                    let mergeDispatchGroup = DispatchGroup()
                    var cameraURL: URL?
                    var screenURL: URL?
                    if self.cameraAsset.videosURLs.isEmpty == false {
                        
                        mergeDispatchGroup.enter()
                        
                        self.cameraAsset.videoMerger.merge(arrayVideos: self.cameraAsset.videosURLs.compactMap { AVAsset(url: $0) }) { url, error in
                            
                            guard error == nil else { return }
                            
                            cameraURL = url
                            
                            mergeDispatchGroup.leave()
                        }
                    }
                    
                    if self.screenAsset.videosURLs.isEmpty == false  {
                        
                        mergeDispatchGroup.enter()
                        
                        self.screenAsset.videoMerger.merge(arrayVideos: self.screenAsset.videosURLs.compactMap { AVAsset(url: $0) }) { url, error in
                            
                            guard error == nil else { return }
                            
                            screenURL = url
                            
                            mergeDispatchGroup.leave()
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
            self.cameraAsset.mixer.recorder.stopRunning() { url in
                if let url = url {
                    self.cameraAsset.videosURLs.append(url)
                }
                dispatchGroup.leave()
            }
            
            dispatchGroup.enter()
            self.screenAsset.mixer.recorder.stopRunning() { url in
                if let url = url {
                    self.screenAsset.videosURLs.append(url)
                }
                dispatchGroup.leave()
            }
            
        case .camera:
            dispatchGroup.enter()
            self.cameraAsset.mixer.recorder.stopRunning() { url in
                if let url = url {
                    self.cameraAsset.videosURLs.append(url)
                }
                dispatchGroup.leave()
            }
            
        case .screen:
            dispatchGroup.enter()
            self.screenAsset.mixer.recorder.stopRunning() { url in
                if let url = url {
                    self.screenAsset.videosURLs.append(url)
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
            self.cameraAsset.mixer.recorder.startRunning()
            self.screenAsset.mixer.recorder.startRunning()
        case .camera:
            self.cameraAsset.mixer.recorder.startRunning()
        case .screen:
            self.screenAsset.mixer.recorder.startRunning()
        }
    }
    
    
    // - MARK: Private
    
    private func setupSettings() {
        
        ensureLockQueue {
            self.cameraAsset.setupSettings()
            self.screenAsset.setupSettings()
        }
    }
    
    private func startCameraRecording() {
        self.cameraAsset.startRecording()
    }
    
    private func startScreenRecording() {
        self.screenAsset.startRecording()
    }
    
    private func setupRecorder() {
        
        switch self.mode {
        case .cameraAndScreen:
            screenAsset.mixer.recorder.delegate = screenAsset.recorderDelegate
            cameraAsset.mixer.recorder.delegate = cameraAsset.recorderDelegate
        case .camera:
            cameraAsset.mixer.recorder.delegate = cameraAsset.recorderDelegate
        case .screen:
            screenAsset.mixer.recorder.delegate = screenAsset.recorderDelegate
        }
    }
    
    private func stopCameraRecording() {
        dispatchGroup.enter()
        cameraAsset.mixer.stopRunning()
        cameraAsset.mixer.recorder.stopRunning()
        
        cameraAsset.recorderDelegate.completionHandler = { [weak self] url in
            guard let url = url, self?.isRecording == false else { return }
            self?.cameraAsset.videosURLs.append(url)
            self?.cameraAsset.outputURL = url
            self?.dispatchGroup.leave()
        }
    }
    
    private func stopScreenRecording() {
        dispatchGroup.enter()
        self.screenAsset.mixer.stopRunning()
        self.screenAsset.mixer.recorder.stopRunning()
        
        screenAsset.recorderDelegate.completionHandler = { [weak self] url in
            guard let url = url, self?.isRecording == false else { return }
            self?.screenAsset.videosURLs.append(url)
            self?.screenAsset.outputURL = url
            self?.dispatchGroup.leave()
        }
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
