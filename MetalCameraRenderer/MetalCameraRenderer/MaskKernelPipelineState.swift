//
//  MaskKernelPipelineState.swift
//  MetalCameraRenderer
//
//  Created by Mostafizur Rahman on 30/3/19.
//  Copyright © 2019 ParadoxSpace. All rights reserved.
//

import UIKit
import Metal
import MetalKit

class MaskKernelPipelineState: BaseKernelPipelineState {
    var  startTime:TimeInterval = 0, nowTime:TimeInterval = 0
    var movieTexture:[MTLTexture] = []
    
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
                guard let path = Bundle.main.path(forResource: imageNamed, ofType: "") else {
                    continue
                }
                let image = UIImage(contentsOfFile: path)
                guard let cgImage = image?.cgImage else {
                    return
                }
                do{
                    let texture = try textureLoader.newTexture(cgImage: cgImage, options: [:])
                    self.movieTexture.append(texture)
                }catch{
                    print("texture not created")
                }
            }
        }
    }
    
    public override func processArguments(withEncoder computeEncode:MTLComputeCommandEncoder){
        
        //aditional textures starts from index 2
        if self.movieTexture.count > 0{
            let testtexture = self.movieTexture[0]
            computeEncode.setTexture(testtexture, index: 2)
        }
        self.nowTime = super.getTimeOfDay()
        var deltaTime:Float = Float(self.nowTime - self.startTime)
        computeEncode.setBytes(&deltaTime, length: MemoryLayout<Float>.size, index: 0)
    }
}
