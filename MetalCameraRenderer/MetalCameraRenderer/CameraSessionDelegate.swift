//
//  CameraSessionDelegate.swift
//  Metal Camera
//
//  Created by Mostafizur Rahman on 25/10/2016.
//  Copyright © 2018 image-app.com. All rights reserved.
//

import CoreImage
import UIKit
import CoreMedia
import AVFoundation

/**
 *  A protocol for a delegate that may be notified about the capture session events.
 */
public protocol CameraSessionDelegate {
    
    /**
     Camera session did receive a new frame and converted it to an array of Metal textures. For instance,
     if the RGB pixel format was selected, the array will have a single texture, whereas if YCbCr was selected,
     then there will be two textures: the Y texture at index 0,
     and CbCr texture at index 1 (following the order in a sample buffer).
     
     - parameter session:       Session that triggered the update
     - parameter textures:      Frame converted to an array of Metal textures
     - parameter sourceTime:    Frame precesentation time as CMTime
     */
    func metalCameraSession(_ session: MetalCameraSession,
                            didReceiveFrameAsTextures textures: [MTLTexture],
                            atTime sourceTime: CMTime)
    
    
    
    
    /**
     Camera session did update capture state
     
     - parameter session:        Session that triggered the update
     - parameter didUpdateState: Capture session state
     - parameter error:          Capture session error or `nil`
     */
    func metalCameraSession(_ session: MetalCameraSession,
                            didUpdateState: MetalCameraSessionState,
                            error: MetalCameraSessionError?)
    
    
    
    /**
     Camera session did receive camera frame as stream aka CMSampleBuffer
     
     - parameter session:        Session that triggered the update
     - parameter didVideoBuffer: Captured camera frame as CMSampleBuffer
     */
    func metalCameraSession(_ session: MetalCameraSession,
                            didVideoBuffer buffer: CMSampleBuffer)
    
    
    
    /**
     Camera session did receive camera frame as stream aka CMSampleBuffer
     
     - parameter session:        Session that triggered the update
     - parameter didAudioBufer:  Captured camera frame as CMSampleBuffer
     */
    func metalCameraSession(_ session: MetalCameraSession,
                            didAudioBufer buffer: CMSampleBuffer)
    
}
