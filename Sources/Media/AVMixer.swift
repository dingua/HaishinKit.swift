import AVFoundation

#if os(iOS) || os(macOS)
    extension AVCaptureSession.Preset {
        static var `default`: AVCaptureSession.Preset = .medium
    }
#endif

public class AVMixer: NSObject {
    public static let defaultFPS: Float64 = 30
    public static let defaultVideoSettings: [NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA)
    ]

    static let supportedSettingsKeys: [String] = [
        "fps",
        "sessionPreset",
        "continuousAutofocus",
        "continuousExposure"
    ]
    
    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    public let lockQueue = ({ () -> DispatchQueue in
        let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.AVMixer.lock")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    })()
    
    
    open var context: CIContext? {
        get {
            return videoIO.context
        }
        set {
            videoIO.context = newValue
        }
    }
    
    open var audioSettings: [String: Any] {
        get {
            var audioSettings: [String: Any]!
            ensureLockQueue {
                audioSettings = self.audioIO.encoder.dictionaryWithValues(forKeys: AudioConverter.supportedSettingsKeys)
            }
            return  audioSettings
        }
        set {
            ensureLockQueue {
                self.audioIO.encoder.setValuesForKeys(newValue)
            }
        }
    }
    
    open var videoSettings: [String: Any] {
        get {
            var videoSettings: [String: Any]!
            ensureLockQueue {
                videoSettings = self.videoIO.encoder.dictionaryWithValues(forKeys: H264Encoder.supportedSettingsKeys)
            }
            return videoSettings
        }
        set {
            if DispatchQueue.getSpecific(key: AVMixer.queueKey) == AVMixer.queueValue {
                self.videoIO.encoder.setValuesForKeys(newValue)
            } else {
                ensureLockQueue {
                    self.videoIO.encoder.setValuesForKeys(newValue)
                }
            }
        }
    }
    
    open var captureSettings: [String: Any] {
        get {
            var captureSettings: [String: Any]!
            ensureLockQueue {
                captureSettings = self.dictionaryWithValues(forKeys: AVMixer.supportedSettingsKeys)
            }
            return captureSettings
        }
        set {
            ensureLockQueue {
                self.setValuesForKeys(newValue)
            }
        }
    }
    
    open var recorderSettings: [AVMediaType: [String: Any]] {
        get {
            var recorderSettings: [AVMediaType: [String: Any]]!
            ensureLockQueue {
                recorderSettings = self.recorder.outputSettings
            }
            return recorderSettings
        }
        set {
            ensureLockQueue {
                self.recorder.outputSettings = newValue
            }
        }
    }
    #if os(iOS) || os(macOS)
    
    @objc var fps: Float64 {
        get { return videoIO.fps }
        set { videoIO.fps = newValue }
    }

    @objc var continuousExposure: Bool {
        get { return videoIO.continuousExposure }
        set { videoIO.continuousExposure = newValue }
    }

    @objc var continuousAutofocus: Bool {
        get { return videoIO.continuousAutofocus }
        set { videoIO.continuousAutofocus = newValue }
    }

    @objc var sessionPreset: AVCaptureSession.Preset = .default {
        didSet {
            guard sessionPreset != oldValue else {
                return
            }
            session.beginConfiguration()
            session.sessionPreset = sessionPreset
            session.commitConfiguration()
        }
    }

    private var _session: AVCaptureSession?
    public var session: AVCaptureSession {
        get {
            if _session == nil {
                _session = AVCaptureSession()
                _session!.sessionPreset = .default
            }
            return _session!
        }
        set {
            _session = newValue
        }
    }
#endif
    private var _recorder: AVRecorder?
    /// The recorder instance.
    public var recorder: AVRecorder! {
        if _recorder == nil {
            _recorder = AVRecorder()
        }
        return _recorder
    }

    private var _audioIO: AudioIOComponent?
    var audioIO: AudioIOComponent! {
        if _audioIO == nil {
            _audioIO = AudioIOComponent(mixer: self)
        }
        return _audioIO!
    }

    private var _videoIO: VideoIOComponent?
    var videoIO: VideoIOComponent! {
        if _videoIO == nil {
            _videoIO = VideoIOComponent(mixer: self)
        }
        return _videoIO!
    }

    deinit {
        dispose()
    }

    public func dispose() {
#if os(iOS) || os(macOS)
        if let session = _session, session.isRunning {
            session.stopRunning()
        }
#endif
        _audioIO?.dispose()
        _audioIO = nil
        _videoIO?.dispose()
        _videoIO = nil
    }
    
    func ensureLockQueue(callback: () -> Void) {
        if DispatchQueue.getSpecific(key: AVMixer.queueKey) == AVMixer.queueValue {
            callback()
        } else {
            lockQueue.sync {
                callback()
            }
        }
    }
    
    open func attachCamera(_ camera: AVCaptureDevice?, onError: ((_ error: NSError) -> Void)? = nil) throws {
        lockQueue.async {
            do {
                try self.videoIO.attachCamera(camera)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }
    
    open func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = false, onError: ((_ error: NSError) -> Void)? = nil) throws {
        lockQueue.async {
            do {
                try self.audioIO.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }
    
    open func attachScreen(_ screen: ScreenCaptureSession?, useScreenSize: Bool = true) {
        lockQueue.async {
            self.videoIO.attachScreen(screen, useScreenSize: useScreenSize)
            screen?.startRunning()
        }
    }
    
    open func deattachScreen() {
        videoIO.screen?.stopRunning()
    }
    
    open func setPointOfInterest(_ focus: CGPoint, exposure: CGPoint) {
        videoIO.focusPointOfInterest = focus
        videoIO.exposurePointOfInterest = exposure
    }
}

extension AVMixer {
    public func startEncoding(delegate: Any) {
        videoIO.encoder.delegate = delegate as? VideoEncoderDelegate
        videoIO.encoder.startRunning()
        audioIO.encoder.delegate = delegate as? AudioConverterDelegate
        audioIO.encoder.startRunning()
    }

    public func stopEncoding() {
        videoIO.encoder.delegate = nil
        videoIO.encoder.stopRunning()
        audioIO.encoder.delegate = nil
        audioIO.encoder.stopRunning()
    }
}

extension AVMixer {
    public func startPlaying(_ audioEngine: AVAudioEngine?) {
        audioIO.audioEngine = audioEngine
        audioIO.encoder.delegate = audioIO
        videoIO.queue.startRunning()
    }

    public func stopPlaying() {
        audioIO.audioEngine = nil
        audioIO.encoder.delegate = nil
        videoIO.queue.stopRunning()
    }
}

#if os(iOS) || os(macOS)
extension AVMixer: Running {
    // MARK: Running
    public var isRunning: Bool {
        return session.isRunning
    }

    public func startRunning() {
        guard !isRunning else {
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            self.session.startRunning()
        }
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        session.stopRunning()
    }
}
#else
extension AVMixer: Running {
    // MARK: Running
    public var isRunning: Bool {
        return false
    }

    public func startRunning() {
    }

    public func stopRunning() {
    }
}
#endif
