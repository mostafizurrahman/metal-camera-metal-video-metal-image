//
//  BlackKernelPipelineState.swift
//  Metal Camera
//
//  Created by Mostafizur Rahman on 25/10/2016.
//  Copyright © 2018 image-app.com. All rights reserved.
//

import UIKit
import Metal
import MetalKit

class BlackKernelPipelineState: BaseKernelPipelineState {
    
    
    var  startTime:TimeInterval = 0, nowTime:TimeInterval = 0
    var noiseTexture:MTLTexture?
    
    override init(stateData data: [AnyObject]) {
        super.init(stateData: data)
        self.startTime = super.getTimeOfDay()
        guard  let _mdevice = data[1] as? MTLDevice else {
            assertionFailure("MTLDevice is nil([in _metalData[2]), unable to create function")
            return
        }
        
        if data.count == 4 {
            guard let imageNameArray = data[3] as? [String] else{
                return
            }
            let textureLoader = MTKTextureLoader(device: _mdevice)
            for imageNamed in imageNameArray {
                let image = UIImage(named: imageNamed)
                guard let cgImage = image?.cgImage else {
                    return
                }
                do{
                    self.noiseTexture = try textureLoader.newTexture(cgImage: cgImage, options: [:])
                }catch{
                    print("texture not created")
                }
            }
        }
        
        
        
        
        //self.noiseTexture =
        
        //        let textureLoader = MTKTextureLoader(device: _mdevice)
        //
        //        for imageNamed in imageNameArray {
        //            let image = UIImage(named: "iim.png")
        //            guard let cgImage = image?.cgImage else {
        //                return
        //            }
        //            do{
        //                self.noiseTexture = try textureLoader.newTexture(cgImage: cgImage, options: [:])
        //            }catch{
        //                print("texture not created")
        //            }
        //        }
        
        
        
    }
    
    
    
    
    public override func processArguments(withEncoder computeEncode:MTLComputeCommandEncoder){
        
        //aditional textures starts from index 2
        if let testtexture = noiseTexture{
            computeEncode.setTexture(testtexture, index: 2)
        }
        self.nowTime = super.getTimeOfDay()
        var deltaTime:Float = Float(self.nowTime - self.startTime)
        computeEncode.setBytes(&deltaTime, length: MemoryLayout<Float>.size, index: 0)
    }
    
}
