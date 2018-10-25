//
//  BaseKernerPipelineState.swift
//  Metal Camera
//
//  Created by Mostafizur Rahman on 25/10/2016.
//  Copyright © 2018 image-app.com. All rights reserved.
//

import MetalKit
import Metal

class BaseKernelPipelineState {
    

    internal let threadGroupCounts:MTLSize = MTLSizeMake(8, 8, 1)
    internal var threadGroups:MTLSize?
    
    var computeSateArray:[MTLComputePipelineState] = []
    
    init(stateData data:[AnyObject]){
        
        guard  let metal_library = data[0] as? MTLLibrary else {
            assertionFailure("MTLLibrary is nil([in data[1]), unable to locate metal shaders")
            return
        }
        guard  let metal_device = data[1] as? MTLDevice else {
            assertionFailure("MTLDevice is nil([in data[1]), unable to locate metal shaders")
            return
        }
        guard let kernel_function_array = data[2] as? [String] else {
            assertionFailure("Function list is empty([in data[2]), unable to locate metal shaders")
            return
        }
        for functionName in kernel_function_array {
            guard let metalFunction = metal_library.makeFunction(name: functionName) else {
                assertionFailure("MTLLibrary.makeFunction(name:) fail to create a metal function!")
                continue
            }
            do {
                let computeState = try metal_device.makeComputePipelineState(function: metalFunction)
                self.computeSateArray.append(computeState)
            } catch {
                assertionFailure("MTLDevice.makeComputePipelineState(function:) fail to create a compute kernel state!")
            }
        }
        
    }
    
    
    public func compute(inTexutr readTexture:MTLTexture,
                        outTexture writeTexture:MTLTexture,
                        inComputeEncoder computeEncoder:MTLComputeCommandEncoder){
        
        for pipelineState in self.computeSateArray {
            
            computeEncoder.setComputePipelineState(pipelineState)
         
            // readTexture->goes to texture2d<float, access::read> inTexture [[texture(0)]]
            // first texture in kernel must be a camer raw data texture at index 0
            computeEncoder.setTexture(readTexture, index: 0)
            
            // writeTexture->goes to texture2d<float, access::write> inTexture [[texture(1)]]
            // second texture in kernel must be a output texture to be writen at index 1
            computeEncoder.setTexture(writeTexture, index: 1)
            
            // compute and pass other buffer/terxtures if required by the metal effects
            // Buffer data will be available at override method processArguments(withEncoder:)
            self.processArguments(withEncoder:computeEncoder)
            
            
            // finilize MTLComputeCommandEncoder operations
            if let t_group = self.threadGroups {
                self.compute(withEncoder: computeEncoder, threadGroups: t_group)
            } else {
                // create thread group if nil found
                self.threadGroups = MTLSizeMake(readTexture.width / self.threadGroupCounts.width,
                                                readTexture.height / self.threadGroupCounts.height, 1)
                self.compute(withEncoder: computeEncoder, threadGroups: self.threadGroups!)
            }
            
        }
    }
    
    fileprivate func compute(withEncoder computeEncode:MTLComputeCommandEncoder, threadGroups:MTLSize){
        computeEncode.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: self.threadGroupCounts)
        computeEncode.endEncoding()
    }

    public func processArguments(withEncoder computeEncode:MTLComputeCommandEncoder){
        preconditionFailure("processArguments(computeEncode:) must be overridden")
    }
    
    public func getTimeOfDay()->TimeInterval {
        var  t:timeval = timeval()
        gettimeofday(&t, nil)
        return TimeInterval(Double(t.tv_sec) + Double(t.tv_usec) * 1.0e-6)
    }
    
}
