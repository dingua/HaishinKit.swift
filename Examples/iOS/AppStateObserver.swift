//
//  AppStateObserver.swift
//  Shortcut
//
//  Created by Mejdi Lassidi on 3/4/19.
//  Copyright © 2019 AHM. All rights reserved.
//

import Foundation
import UIKit

class AppStateObserver {
    
    typealias Callback = () -> Void
    
    private let observerTokens: [NSObjectProtocol]
    
    init(didEnterBackground: @escaping Callback = {},
         willEnterForeground: @escaping Callback = {},
         didBecomeActive: @escaping Callback = {},
         willResignActive: @escaping Callback = {},
         willTerminate: @escaping Callback = {}) {
        
        func registerObserver(name: NSNotification.Name, callback: @escaping Callback) -> NSObjectProtocol {
            return NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { _ in
                callback()
            }
        }
        
        // swiftlint:disable comma
        observerTokens = [
            registerObserver(name: UIApplication.didEnterBackgroundNotification,    callback: didEnterBackground),
            registerObserver(name: UIApplication.willEnterForegroundNotification,   callback: willEnterForeground),
            registerObserver(name: UIApplication.didBecomeActiveNotification,       callback: didBecomeActive),
            registerObserver(name: UIApplication.willResignActiveNotification,      callback: willResignActive),
            registerObserver(name: UIApplication.willTerminateNotification,         callback: willTerminate),
        ]
        // swiftlint:enable comma
    }
    
    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
    }
}
