//
//  MetalCameraSession.swift
//  MetalShaderCamera
//
//  Created by Mostafizur Rahman on 25/10/2016.
//  Copyright © 2018 image-app.com. All rights reserved.
//


import Metal
import UIKit
import MetalKit
import CoreImage
import AVFoundation
import CoreVideo



/**
 * A convenient hub for accessing camera data as a stream of Metal textures with corresponding timestamps.
 *
 * Keep in mind that frames arrive in a hardware orientation by default, e.g. `.LandscapeRight` for the rear camera. You can set the `frameOrientation` property to override this behavior and apply auto rotation to each frame.
 */
public final class MetalCameraSession: NSObject {
    
    
    // MARK : Session fields
    /// Requested capture device position, e.g. camera
    public let captureDevicePosition: AVCaptureDevice.Position
    
    /// Delegate that will be notified about state changes and new frames
    public var sessionDelegate: CameraSessionDelegate?
    
    /// Pixel format to be used for grabbing camera data and converting textures
    public let pixelFormat: MetalCameraPixelFormat
    
    /// `AVFoundation` capture session object.
    var captureSession = AVCaptureSession()
    
    /// Our internal wrapper for the `AVCaptureDevice`. Making it internal to stub during testing.
    internal var captureDevice = MetalCameraCaptureDevice()
    
    /// Dispatch queue for capture session events.
    let captureSessionQueueVideo = DispatchQueue(label: "MetalCameraVideoSessionQueue", attributes: [])
    let captureSessionQueueAudio = DispatchQueue(label: "MetalCameraAudioSessionQueue", attributes: [])
    

    /// Texture cache we will use for converting frame images to textures
    var textureCache: CVMetalTextureCache?

    
    /// `MTLDevice` we need to initialize texture cache
    fileprivate var metalDevice = MTLCreateSystemDefaultDevice()
    
    // MARK: Private properties and methods
    /// Current capture input device.
    internal var videoInputDevice: AVCaptureDeviceInput? {
        didSet {
            if let oldValue = oldValue {
                captureSession.removeInput(oldValue)
            }
            guard let inputDevice = videoInputDevice else { return }
            captureSession.addInput(inputDevice)
        }
    }
    /// Current capture audio input device.
    internal var audioInputDevice: AVCaptureDeviceInput? {
        didSet {
            if let oldValue = oldValue {
                captureSession.removeInput(oldValue)
            }
            guard let inputDevice = audioInputDevice else { return }
            captureSession.addInput(inputDevice)
        }
    }
    /// Current session state.
    fileprivate var state: MetalCameraSessionState = .waiting {
        didSet {
            guard state != .error else { return }
            self.sessionDelegate?.metalCameraSession(self, didUpdateState: self.state, error: nil)
        }
    }
    /// Current capture video output data stream.
    internal var videoOutputData: AVCaptureVideoDataOutput? {
        didSet {
            if let oldValue = oldValue {
                captureSession.removeOutput(oldValue)
            }
            guard let outputData = videoOutputData else { return }
            captureSession.addOutput(outputData)
        }
    }
    /// Current capture audio output data stream.
    internal var audioOutputData: AVCaptureAudioDataOutput? {
        didSet {
            if let oldValue = oldValue {
                captureSession.removeOutput(oldValue)
            }
            guard let outputData = audioOutputData else { return }
            captureSession.addOutput(outputData)
        }
    }
    /// Frame orienation. If you want to receive frames in orientation other than the hardware default one,
    /// set this `var` and this value will be picked up when converting next frame. Although keep in mind that
    /// any rotation comes at a performance cost.
    public var frameOrientation: AVCaptureVideoOrientation? {
        didSet {
            guard let frameOrientation = frameOrientation else {
                print("frame orientation not set")
                return
            }
            guard let outputData = videoOutputData else {
                print("videoOutputData not set")
                return
            }
            guard let videoConnection = outputData.connection(with: .video) else {
                print("videoOutputData contains no connections")
                return
            }
            if !videoConnection.isVideoOrientationSupported {
                print("Video orientation is not supported to the session")
            }
            videoConnection.videoOrientation = frameOrientation
        }
    }

    
    
    
    /**
     initialized a new instance, providing optional values.
     
     - parameter pixelFormat:           Pixel format. Defaults to `.RGB`
     - parameter captureDevicePosition: Camera to be used for capturing. Defaults to `.Back`.
     - parameter delegate:              Delegate. Defaults to `nil`.
     
     */
    public init(pixelFormat: MetalCameraPixelFormat = .rgb,
                captureDevicePosition: AVCaptureDevice.Position = .back,
                delegate: CameraSessionDelegate? = nil) {
        self.pixelFormat = pixelFormat
        self.captureDevicePosition = captureDevicePosition
        self.sessionDelegate = delegate
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(captureSessionRuntimeError),
                                               name: NSNotification.Name.AVCaptureSessionRuntimeError, object: nil)
    }
    
    /**
     Starts the capture session. Call this method to start receiving delegate updates with the sample buffers.
     */
    public func startCamera() {
        
        requestCameraAccess()
//        captureSessionQueueVideo.async(execute: {
            do {
                self.captureSession.beginConfiguration()
                try self.initializeInputDevice()
                try self.initializeVideoOutputData()
                try self.initializeAudioOutputData()
                self.captureSession.commitConfiguration()
                try self.initializeTextureCache()
                self.captureSession.startRunning()
                self.state = .streaming
            }
            catch let error as MetalCameraSessionError {
                self.handleError(error)
            }
            catch {
                /**
                 * We only throw `MetalCameraSessionError` errors.
                 */
            }
//        })
    }

    /**
     Requests access to camera hardware.
     */
    fileprivate func requestCameraAccess() {
        captureDevice.requestAccess(for: .video) {
            (granted: Bool) -> Void in
            guard granted else {
                self.handleError(.noHardwareAccess)
                return
            }
            if self.state != .streaming && self.state != .error {
                self.state = .ready
            }
        }
    }
    
    /**
     Stops the capture session.
     */
    public func stopCamera() {
        captureSessionQueueVideo.async(execute: {
            self.captureSession.stopRunning()
            self.state = .stopped
        })
    }
    
    fileprivate func handleError(_ error: MetalCameraSessionError) {
        if error.isStreamingError() {
            state = .error
        }
        self.sessionDelegate?.metalCameraSession(self, didUpdateState: self.state, error: error)
    }

    /**
     initialized the texture cache. We use it to convert frames into textures.
     */
    fileprivate func initializeTextureCache() throws {

        guard let metalDevice = metalDevice,
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textureCache) == kCVReturnSuccess
        else {
            throw MetalCameraSessionError.failedToCreateTextureCache
        }
    }

    /**
     initializes capture input device with specified media type and device position.
     
     - throws: `MetalCameraSessionError` if we failed to initialize and add input device.
     
     */
    fileprivate func initializeInputDevice() throws {
        
        var videoCaptureInput: AVCaptureDeviceInput?
        var audioCaptureInput: AVCaptureDeviceInput?
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else{
            throw MetalCameraSessionError.requestedHardwareNotFound
        }
        guard let videoDevice = captureDevice.device(for: .video, with: captureDevicePosition) else {
            throw MetalCameraSessionError.requestedHardwareNotFound
        }
        do {
            videoCaptureInput = try AVCaptureDeviceInput(device: videoDevice)
            audioCaptureInput = try AVCaptureDeviceInput(device: audioDevice)
        }
        catch {
            throw MetalCameraSessionError.inputDeviceNotAvailable
        }
        
        if let _videoDevice = videoCaptureInput {
            if self.captureSession.canAddInput(_videoDevice) {
                self.videoInputDevice = videoCaptureInput
            }
        } else {
            throw MetalCameraSessionError.failedToAddCaptureInputDevice
        }
        if let _auidioDevice = audioCaptureInput {
            if self.captureSession.canAddInput(_auidioDevice){
                self.audioInputDevice = audioCaptureInput
            }
        } else {
            throw MetalCameraSessionError.failedToAddCaptureInputDevice
        }
    }
    
    /**
     initializes capture video output data stream.
     
     - throws: `MetalCameraSessionError` if we failed to initialize and add output data stream.
     */
    fileprivate func initializeVideoOutputData() throws {
        let outputData = AVCaptureVideoDataOutput()
        outputData.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(pixelFormat.coreVideoType)]
        outputData.alwaysDiscardsLateVideoFrames = true
        outputData.setSampleBufferDelegate(self, queue: captureSessionQueueVideo)
        guard captureSession.canAddOutput(outputData) else {
            throw MetalCameraSessionError.failedToAddCaptureOutput
        }
        
        self.videoOutputData = outputData
        self.frameOrientation = AVCaptureVideoOrientation.portrait
    }
    /**
     initializes capture audio output data stream.
     
     - throws: `MetalCameraSessionError` if we failed to initialize and add output data stream.
     */
    
    fileprivate func initializeAudioOutputData() throws{
        let audiooutputData = AVCaptureAudioDataOutput()
        audiooutputData.setSampleBufferDelegate(self , queue: captureSessionQueueAudio)
        captureSession.automaticallyConfiguresApplicationAudioSession = true;
        guard captureSession.canAddOutput(audiooutputData) else {
            throw MetalCameraSessionError.failedToAddCaptureOutput
        }
        self.audioOutputData = audiooutputData
    }
    
    
    public func renderMetal(fromBuffer sampleBuffer:CMSampleBuffer){
        do {
            var textures: [MTLTexture] = []
            switch pixelFormat {
            case .rgb:
                let textureRGB = try self.texture(sampleBuffer: sampleBuffer)
                textures = [textureRGB]
            case .yCbCr:
                let textureY = try self.texture(sampleBuffer: sampleBuffer, planeIndex: 0, pixelFormat: .r8Unorm)
                let textureCbCr = try self.texture(sampleBuffer: sampleBuffer, planeIndex: 1, pixelFormat: .rg8Unorm)
                textures = [textureY, textureCbCr]
            }
            
            let displayTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            self.sessionDelegate?.metalCameraSession(self,
                                                     didReceiveFrameAsTextures: textures,
                                                     atTime: displayTime)
        }
        catch let error as MetalCameraSessionError {
            self.handleError(error)
        }
        catch {
            /**
             * We only throw `MetalCameraSessionError` errors.
             */
        }
    }
    
    
    /**
     `AVCaptureSessionRuntimeErrorNotification` callback.
     */
    @objc fileprivate func captureSessionRuntimeError() {
        if state == .streaming {
            handleError(.captureSessionRuntimeError)
        }
    }
    
    
    /**
     Converts a sample buffer received from camera to a Metal texture
     
     - parameter sampleBuffer: Sample buffer
     - parameter textureCache: Texture cache
     - parameter planeIndex:   Index of the plane for planar buffers. Defaults to 0.
     - parameter pixelFormat:  Metal pixel format. Defaults to `.BGRA8Unorm`.
     
     - returns: Metal texture or nil
     */
    func texture(sampleBuffer: CMSampleBuffer?,
                         planeIndex: Int = 0,
                         pixelFormat: MTLPixelFormat = .bgra8Unorm) throws -> MTLTexture {
        
        guard let sampleBuffer = sampleBuffer else {
            throw MetalCameraSessionError.missingSampleBuffer
        }
        guard let textureCache = self.textureCache else {
            throw MetalCameraSessionError.failedToCreateTextureCache
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw MetalCameraSessionError.failedToGetImageBuffer
        }
        let isPlanar = CVPixelBufferIsPlanar(imageBuffer)
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(imageBuffer, planeIndex)
            : CVPixelBufferGetWidth(imageBuffer)
        let height = isPlanar ? CVPixelBufferGetHeightOfPlane(imageBuffer, planeIndex)
            : CVPixelBufferGetHeight(imageBuffer)
        var imageTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache,
                                                               imageBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &imageTexture)
        guard let unwrappedImageTexture = imageTexture,
            let texture = CVMetalTextureGetTexture(unwrappedImageTexture),
            result == kCVReturnSuccess
            else {
                throw MetalCameraSessionError.failedToCreateTextureFromImage
        }
        return texture
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}






// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension MetalCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate,
                              AVCaptureAudioDataOutputSampleBufferDelegate {

#if arch(i386) || arch(x86_64)
#else

    
   
    
    
    /**
     convert a uiimage into metal texture
     
     - parameter
     - returns: Double value for a timestamp in seconds or nil
     */

    func getTexture(from img: UIImage?, _ device:MTLDevice) -> MTLTexture? {
        guard let imageData = img, let image = imageData.cgImage else {
            print(gifLoaderError.failToReturnImageFrame)
            return nil
        }
        let textureLoader = MTKTextureLoader(device: device)
        var texture: MTLTexture? = nil
        let textureLoderOption: [MTKTextureLoader.Option:NSObject]
        if #available(iOS 10.0, *) {
            let origin = NSString(string: MTKTextureLoader.Origin.bottomLeft.rawValue)
            textureLoderOption = [MTKTextureLoader.Option.origin: origin]
        }else{
            textureLoderOption = [:]
        }
        do{
            texture = try textureLoader.newTexture(cgImage: image, options: textureLoderOption)
        }catch{
            print("texture not created")
        }
        guard let texter = texture else {
            print(MetalCameraSessionError.failedToCreateTextureFromImage)
            return nil
        }
        return texter
    }
    
    /**
     Strips out the timestamp value out of the sample buffer received from camera.
     
     - parameter sampleBuffer: Sample buffer with the frame data
     - returns: Double value for a timestamp in seconds or nil
     */
    private func timestamp(sampleBuffer: CMSampleBuffer?) throws -> Double {
        guard let sampleBuffer = sampleBuffer else {
            throw MetalCameraSessionError.missingSampleBuffer
        }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard time != CMTime.invalid else {
            throw MetalCameraSessionError.failedToRetrieveTimestamp
        }
        return (Double)(time.value) / (Double)(time.timescale);
    }
    
    
    /**
     Get audio stream from microphone and get video stream from iOS camera through this method.
     
     - parameter sampleBuffer: Sample buffer with the frame data [Either Audio or video]
     - parameter connection: Connection to the audio video media output
     */
    
    public func captureOutput(_ captureOutput: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        /// Video data output as CMSampleBuffer
        if captureOutput == videoOutputData {
            self.renderMetal(fromBuffer: sampleBuffer)
            self.sessionDelegate?.metalCameraSession(self, didVideoBuffer: sampleBuffer)
        } else {
        /// Audio data output as CMSampleBuffer
            self.sessionDelegate?.metalCameraSession(self, didAudioBufer: sampleBuffer)
        }

    }
    
#endif
}


extension MetalCameraSession {
    
    func pixelBuffer (forImage image:CGImage) -> CVPixelBuffer? {
        
        let frameSize = CGSize(width: image.width, height: image.height)
        var pixelBuffer:CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height),
                                         kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        if status != kCVReturnSuccess {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }
}
