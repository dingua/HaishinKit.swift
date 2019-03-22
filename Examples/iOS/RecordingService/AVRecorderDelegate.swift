//
//  AVRecorderDelegate.swift
//  Example iOS
//
//  Created by Mejdi Lassidi on 3/22/19.
//  Copyright © 2019 Shogo Endo. All rights reserved.
//

import Foundation
import AVFoundation
import HaishinKit


final class AVRecorderDelegate: DefaultAVRecorderDelegate {
    
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


extension AVRecorder {
    var isCameraRecording: Bool {
        return writer?.inputs.count == 2
    }
    
}
