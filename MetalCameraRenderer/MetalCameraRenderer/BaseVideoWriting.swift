//
//  MetalCameraSessionForVideoWriting.swift
//  Metal Camera
//
//  Created by Mostafizur Rahman on 25/10/2016.
//  Copyright © 2018 image-app.com. All rights reserved.
//

import Foundation
import AVFoundation
import CoreMedia
import CoreFoundation
import UIKit

public protocol VideoCaptureDelegate: AnyObject{
    func onVideoCaptureStarted()
    func onVideoCaptureEnded(videoUrl url:URL)
}

//must init for each video writing session
public class BaseVideoWriter {
    
    var videoInput:AVAssetWriterInput!
    private var audioInput:AVAssetWriterInput!
    var pixelAdapter:AVAssetWriterInputPixelBufferAdaptor!
    public var videoWriter:AVAssetWriter!
    
    public weak var captureDelegate:VideoCaptureDelegate?
    public var videoUrl:URL!
    
    private var skipVideoCapture:Bool = true
    public init(videoName name:String, withSize videoSize:CGSize ) {
        self.generateVideoUrl(videoName:name)
        self.setVideoWriterInput(withSize:videoSize)
        self.setAudioWriterInput()
        self.initializeAssetWriter()
    }
    
    
    public init(withSampleBuffer sampleBuffer:CMSampleBuffer){
        preconditionFailure("'init(withSampleBuffer:)' must be override in derived class")
    }
    
    public init(withMetalTexture metalTexture:MTLTexture, atSourceTime sessionTime:CMTime){
        preconditionFailure("'init(withMetalTexture:)' must be override in derived class")
    }
    
    //generate video url
    fileprivate func generateVideoUrl(videoName name:String){
        guard let documentsPathString = FileManager.default.urls(for: .documentDirectory,
                                                                 in: .userDomainMask).first else {
            assertionFailure("Document Directory must not empty!")
            return
        }
        self.videoUrl = documentsPathString.appendingPathComponent(name)
        //remove previously created video (if any)
        self.removeVideo(videoUrl: self.videoUrl)
    }
    
    deinit {
        if videoWriter.status ==  AVAssetWriter.Status.writing {
            self.videoInput.markAsFinished()
            self.audioInput.markAsFinished()
            videoWriter.finishWriting {
                self.removeVideo(videoUrl:self.videoUrl)
            }
        }
        self.videoInput = nil
        self.audioInput = nil
        self.videoWriter = nil
    }
    
    /// remove old video from url
    func removeVideo(videoUrl url:URL){
        let path = url.path
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
                print("file removed")
            } catch let error as NSError {
                print("error occure to remove file",error.debugDescription)
            }
        }
    }
    
    /// setting up the video input with source frame size for asset writer
    fileprivate func setVideoWriterInput(withSize videoSize:CGSize){
//        if{
        
            let videoSettings:[String : Any] = [ AVVideoCodecKey: AVVideoCodecH264,
                                                AVVideoWidthKey: videoSize.width,
                                                AVVideoHeightKey: videoSize.height,
                                                AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                                AVVideoCompressionPropertiesKey:
                                                    [AVVideoAverageBitRateKey : 10 * 1024 * 1024,
                                                     AVVideoExpectedSourceFrameRateKey : NSNumber.init(value:120)]]
//        } else {
//            // Fallback on earlier versions
//        }
        
        self.videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        self.videoInput.expectsMediaDataInRealTime = true
    }
    
    
    /// setting up the audio input for asset writer
    fileprivate func setAudioWriterInput(){
        var acl: AudioChannelLayout = AudioChannelLayout()
        bzero(&acl, MemoryLayout.size(ofValue: acl))
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        
        let audioSettings:[String:Any] = [AVFormatIDKey: Int(kAudioFormatAppleLossless),
                                          AVEncoderBitDepthHintKey:Int(16),
                                          AVSampleRateKey: Float(44100.0),
                                          AVNumberOfChannelsKey:1,
                                          AVChannelLayoutKey:NSData(bytes: &acl, length: MemoryLayout.size(ofValue: acl))]
        self.audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        self.audioInput.expectsMediaDataInRealTime = true
    }
    
    /// setting up the video asset writer with video input and audio input
    fileprivate func initializeAssetWriter() {
        do {
            self.videoWriter = try AVAssetWriter(outputURL: self.videoUrl, fileType: AVFileType.mov)
        } catch {
            assertionFailure("Error : unable to create asset writer")
        }
        assert(self.videoInput != nil, "Error : Video writer input is nil!")
        if self.videoWriter.canAdd(self.videoInput){
            self.videoWriter.add(self.videoInput)
        }
        assert(self.audioInput != nil, "Error : Audio writer input is nil!")
        if self.videoWriter.canAdd(self.audioInput){
            self.videoWriter.add(self.audioInput)
        }
    }
    
    public func append(metalTexture effectTexture:MTLTexture,
                       atTime displayTime:CMTime){
        preconditionFailure("'init(withSampleBuffer:)' must be override in derived class")
    }
    
    public func appendVideoSample(_ buffer:CMSampleBuffer){
        if self.videoInput.isReadyForMoreMediaData &&
            self.skipVideoCapture == false {
            self.videoInput.append(buffer)
        }
    }
    
    public func appendAudioSample(_ buffer:CMSampleBuffer){
        if self.audioInput.isReadyForMoreMediaData &&
            self.skipVideoCapture == false {
            self.audioInput.append(buffer)
        }
    }
    
    public func startSession(atSourceTime sourceTime:CMTime){
        if sourceTime == CMTime.invalid {
            fatalError("startSession fail to initiate video writing at invalid time : \(sourceTime)")
        }
        if let __delegate = self.captureDelegate {
            __delegate.onVideoCaptureStarted()
        }
        self.videoWriter.startWriting()
        self.videoWriter.startSession(atSourceTime: sourceTime)
        self.skipVideoCapture = false
    }
    
    public func endVideoCapture(){
        self.skipVideoCapture = true
        while !self.videoInput.isReadyForMoreMediaData {
            print("slepping for a while")
            usleep(100)
        }
        self.videoInput.markAsFinished()
        self.audioInput.markAsFinished()
        self.videoWriter.finishWriting {
            if let __delegate = self.captureDelegate {
                __delegate.onVideoCaptureEnded(videoUrl: self.videoUrl)
            }
        }
    }
    
    //this will create pixel buffer adapter which will append cvpixel buffer to video input
    //metal texture buffer is converted to cvpixelbuffer and append to adapter.
    public func setPixelBufferAdapter(){
        let bufferAttributes:[String:Any] = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA]
        self.pixelAdapter = AVAssetWriterInputPixelBufferAdaptor.init(assetWriterInput: self.videoInput,
                                                                      sourcePixelBufferAttributes: bufferAttributes)
    }
    var count = 0
    var skipFrame = false
    public func append(pixelBuffer buffer:CVPixelBuffer,
                       atTime displayTime:CMTime){
        if UIDevice.current.hasNotch {
            if self.pixelAdapter.assetWriterInput.isReadyForMoreMediaData &&
                self.skipVideoCapture == false {
                if count == 0 {
                    if !self.pixelAdapter.append(buffer, withPresentationTime: displayTime){
                        
                    }
                    count += 1
                } else {
                    if count >= 2 {
                        count = 0
                    } else {
                        count += 1
                    }
                }
            }
        } else {
            if self.pixelAdapter.assetWriterInput.isReadyForMoreMediaData &&
                self.skipVideoCapture == false {
                if !self.pixelAdapter.append(buffer, withPresentationTime: displayTime){
                    
                }
            }
        }
        
    }
}
extension UIDevice {
    var hasNotch: Bool {
        if #available(iOS 11.0, *) {
            let bottom = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
            return bottom > 0
        }
        return false
    }
}
