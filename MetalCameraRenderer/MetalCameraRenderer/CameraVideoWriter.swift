//
//  CameraVideoWriter.swift
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

class CameraVideoWriter: BaseVideoWriter {
    
    override init(withMetalTexture metalTexture: MTLTexture, atSourceTime sessionTime: CMTime) {
        fatalError("Should not call init(withMetalTexture:atSourceTime) for camera stream writing")
    }

    override init(withSampleBuffer sampleBuffer: CMSampleBuffer) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let _width = CVPixelBufferGetWidth(pixelBuffer)
            let _height = CVPixelBufferGetHeight(pixelBuffer)
            let videoSize = CGSize(width: _width, height: _height)
            super.init(videoName: "camera_video.mov", withSize: videoSize)
        } else {
            let videoSize = CGSize(width: 720, height: 1280)
            super.init(videoName: "camera_video.mov", withSize: videoSize)
        }
        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        super.startSession(atSourceTime: sourceTime)
        self.appendVideoSample(sampleBuffer)
    }
}
