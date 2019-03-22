//
//  RecordingAsset.swift
//  Example iOS
//
//  Created by Mejdi Lassidi on 3/22/19.
//  Copyright © 2019 Shogo Endo. All rights reserved.
//

import Foundation
import HaishinKit

protocol RecordingAsset {
    var mixer: AVMixer { get }
    var videoMerger: KVVideoManager { get }
    var outputURL: URL? { get }
    var recorderDelegate: AVRecorderDelegate { get }
    var videosURLs: [URL] { get }
    func setupSettings()
    func startRecording()
}
