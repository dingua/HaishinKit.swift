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
    
    private var appStateObserver: AppStateObserver!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        appStateObserver = AppStateObserver.init(didEnterBackground: {
            if self.isRecording {
                print("🙃 yalla stop")
                var task: UIBackgroundTaskIdentifier!
                
                DispatchQueue.global().async {
                    print("🇹🇳")
                    task = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                        print("😎")
                        
                        UIApplication.shared.endBackgroundTask(task)
                        task = .invalid
                    })
                    self.pause() {
                        print("❤️")
                        UIApplication.shared.endBackgroundTask(task)
                        task = .invalid
                    }

                }
                
            }
            
        }, willEnterForeground: {
            if self.isRecording {
                self.resume()
            }
        })
        
        recordingService = RecordingService()
        recordingService.setupSettings()
        recordingService.setupRecorder()

//        webView.load(URLRequest(url: URL(string: "https://www.figma.com/proto/ZK9FcB96Hpqb4RBdowER8Z7U/unified-wallet?node-id=723%3A187&scaling=min-zoom&redirected=1")!))
        let urlString = "https://www.figma.com/proto/ZK9FcB96Hpqb4RBdowER8Z7U/unified-wallet?node-id=723%3A187&scaling=contain&redirected=1"
        webView.loadRequest(URLRequest(url: URL(string: urlString)!))

        configureTouchVisualizer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
//        recordingService.startRunning(lfView)
    }
    
    @IBAction func toggleRecord(_ sender: Any) {
        
        isRecording = !isRecording
        isRecording ? recordingService.startRunning() : recordingService.stopRunning()
        recordButton.setTitle(isRecording ? "Recording.." : "Record", for: .normal)
        
    }
    
    func stopRecording() {
        
        recordingService.stopRunning()
//        recordButton.setTitle("Record", for: .normal)
    }
    
    func pause(_ completion: @escaping () -> ()) {
        
        recordingService.pause() {
            completion()
        }
        //        recordButton.setTitle("Record", for: .normal)
    }
    
    func startRecording() {
        recordingService.startRunning()
        recordButton.setTitle("Recording..", for: .normal)
    }
    
    func resume() {
        recordingService.resume()
    }
    private func configureTouchVisualizer() {
//        var config = Configuration()
//        config.color = .red
////        config.image = UIImage(named: "YOUR-IMAGE")
//        config.showsTimer = false
//        config.showsTouchRadius = true
//        config.showsLog = false
//        Visualizer.start(config)
    }
}




