//
//  MetalVideoWriter.swift
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


class MetalVideoWriter: BaseVideoWriter {

    var cvpixelBuffer:CVPixelBuffer?
    var pixelBytesPerRow:Int = 0
    var pixelRegion:MTLRegion!
    override init(withMetalTexture metalTexture: MTLTexture,
                  atSourceTime sessionTime: CMTime) {
        
        let _size = CGSize(width: metalTexture.width, height: metalTexture.height)
        super.init(videoName: "effect_video.mov", withSize: _size)
        self.createPixelBuffer(fromTexture:metalTexture)
        super.setPixelBufferAdapter()
        super.startSession(atSourceTime: sessionTime)
        self.append(metalTexture: metalTexture, atTime:sessionTime)
    }
    
    public override func append(metalTexture effectTexture:MTLTexture,
                                atTime displayTime:CMTime ){
        guard let pixelBuffer = self.cvpixelBuffer else {
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.init(rawValue: 0))
        guard let memoryPointer = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.init(rawValue: 0))
            return
        }
        effectTexture.getBytes(memoryPointer, bytesPerRow: self.pixelBytesPerRow,
                               from: self.pixelRegion, mipmapLevel: 0)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.init(rawValue: 0))
        super.append(pixelBuffer: pixelBuffer, atTime: displayTime)
    }
    
    override init(withSampleBuffer sampleBuffer: CMSampleBuffer) {
        fatalError("Should not call init(withSampleBuffer:) for metal effect stream writing")
    }
    
    fileprivate func createPixelBuffer(fromTexture metalTexture:MTLTexture){
        
        var keyCallBack: CFDictionaryKeyCallBacks = CFDictionaryKeyCallBacks.init()
        var valueCallBacks: CFDictionaryValueCallBacks = CFDictionaryValueCallBacks.init()
        
        var empty: CFDictionary = CFDictionaryCreate(kCFAllocatorDefault, nil, nil,
                                                     0, &keyCallBack, &valueCallBacks)
        
        let attributes = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                   1, &keyCallBack,
                                                   &valueCallBacks)
        var iOSurfacePropertiesKey = kCVPixelBufferIOSurfacePropertiesKey
        CFDictionarySetValue(attributes, &iOSurfacePropertiesKey, &empty)
        let cvreturn = CVPixelBufferCreate(kCFAllocatorDefault,
                                           metalTexture.width,
                                           metalTexture.height,
                                           kCVPixelFormatType_32BGRA,
                                           attributes,
                                           &cvpixelBuffer)
        self.pixelRegion = MTLRegionMake2D(0, 0, metalTexture.width, metalTexture.height)
        assert(cvreturn == kCVReturnSuccess, "Erorr : Unable to create effect video buffer")
        self.pixelBytesPerRow = CVPixelBufferGetBytesPerRow(self.cvpixelBuffer!)
    }
    
    deinit {
        print("deleted")
        
//            release  self.cvpixelBuffer.deallocate()
    }
}
