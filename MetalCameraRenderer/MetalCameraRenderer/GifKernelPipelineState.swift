//
//  GifKernelPipelineState.swift
//  MetalCameraRenderer
//
//  Created by Mostafizur Rahman on 17/3/19.
//  Copyright © 2019 ParadoxSpace. All rights reserved.
//

import UIKit
import Metal
import MetalKit

class GifKernelPipelineState: BaseKernelPipelineState {
    var  startTime:TimeInterval = 0, nowTime:TimeInterval = 0
//    var movieTexture:[MTLTexture] = []
    var images:[UIImage] = []
    var gifIndex = 0
    var textureLoader:MTKTextureLoader!
    
    override init(stateData data: [AnyObject]) {
        super.init(stateData: data)
        self.startTime = super.getTimeOfDay()
        guard  let _mdevice = data[1] as? MTLDevice else {
            assertionFailure("MTLDevice is nil([in _metalData[2]), unable to create function")
            return
        }
        
        if data.count == 4 {
            guard let gifnames = data[3] as? [String],
            let gif = gifnames.last else{
                return
            }
            self.textureLoader = MTKTextureLoader(device: _mdevice)
            guard let url = Bundle.main.url(forResource: "image", withExtension: "gif") else {
                return
                
            }
//            guard let path = Bundle.main.path(forResource: "image", ofType: "gif") else {
//                print("Gif does not exist at that path")
//                return
//            }
//            let url = URL(fileURLWithPath: path)
            guard let gifData = try? Data(contentsOf: url),
                let source =  CGImageSourceCreateWithData(gifData as CFData, nil) else { return }

            
            let imageCount = CGImageSourceGetCount(source)
            for i in 0 ..< imageCount {
                if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    self.images.append(UIImage(cgImage: image))
                }
            }
        }
    }
    
    public override func processArguments(withEncoder computeEncode:MTLComputeCommandEncoder){
        
        //aditional textures starts from index 2
        if self.images.count > 0{
            let image = self.images[self.gifIndex]
            guard let cgImage = image.cgImage else {
                return
            }
            do{
                guard let loader = self.textureLoader else {return}
                let texture = try loader.newTexture(cgImage: cgImage, options: [:])
                computeEncode.setTexture(texture, index: 2)
            }catch{
                print("texture not created")
            }
        }
        self.gifIndex += 1
        if self.gifIndex >= self.images.count {
            self.gifIndex = 0
        }
        self.nowTime = super.getTimeOfDay()
        var deltaTime:Float = Float(self.nowTime - self.startTime)
        computeEncode.setBytes(&deltaTime, length: MemoryLayout<Float>.size, index: 0)
    }
}
