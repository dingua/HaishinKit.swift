//
//  RecordingServiceProtocol.swift
//  Example iOS
//
//  Created by Mejdi Lassidi on 3/22/19.
//  Copyright © 2019 Shogo Endo. All rights reserved.
//

import Foundation

protocol RecordingServiceProtocol {
    
    var mode: RecordingMode { get }
    func setup()
    func startRecording()
    func stopRecording(_ completion: @escaping (_ recordingOutput: RecordingOutput) -> ())
    func pause(_ completion: @escaping () -> ())
    func resume()
}
