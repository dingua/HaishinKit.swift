//
//  ViewController.swift
//  TestHaishinKitVideoRecording
//
//  Created by Mejdi Lassidi on 2/25/19.
//  Copyright © 2019 Mejdi Lassidi. All rights reserved.
//

import UIKit
import AVFoundation
import HaishinKit
import Photos
//import TouchVisualizer

class ViewController: UIViewController {
    
    @IBOutlet weak var webView: UIWebView!
    
    @IBOutlet weak var recordButton: UIButton!
    
    private var isRecording = false
    
    private var recordingService: RecordingService!
    
    var url = "https://www.figma.com/proto/ZK9FcB96Hpqb4RBdowER8Z7U/unified-wallet?node-id=723%3A187&scaling=contain&redirected=1"
    
    private var appStateObserver: AppStateObserver!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        handleAppStates()
        
        recordingService = RecordingService(mode: .cameraAndScreen)
        
        webView.loadRequest(URLRequest(url: URL(string: url)!))
        
        configureTouchVisualizer()
    }
    
    @IBAction func toggleRecord(_ sender: Any) {
        
        isRecording = !isRecording
        isRecording ? start() : stop()
        recordButton.setTitle(isRecording ? "Recording.." : "Record", for: .normal)
    }
    
    // MARK: - Private
    
    private func start() {
        recordingService.setup()
        recordingService.startRecording()
    }
    
    private func stop() {
        recordingService.stopRecording { output in
            print("---------------Yalllaaaaa")
            print(output.cameraFileURL)
            print(output.screenFileURL)
        }
    }
    
    private func handleAppStates() {
        appStateObserver = AppStateObserver(didEnterBackground: {
            if self.isRecording {
                
                var task: UIBackgroundTaskIdentifier!
                DispatchQueue.global().async {
                    task = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                        UIApplication.shared.endBackgroundTask(task)
                        task = .invalid
                    })
                }
            }
            
        }, willEnterForeground: {})
    }
    
    private func configureTouchVisualizer() {
        
//        var config = Configuration()
//        config.color = .red
//        config.showsTimer = false
//        config.showsTouchRadius = true
//        config.showsLog = false
//        Visualizer.start(config)
    }
}




