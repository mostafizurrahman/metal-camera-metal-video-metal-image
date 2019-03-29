//
//  EffectKernelPipelineState.swift
//  MetalCameraRenderer
//
//  Created by Mostafizur Rahman on 29/3/19.
//  Copyright © 2019 ParadoxSpace. All rights reserved.
//

import UIKit

class EffectKernelPipelineState: BaseKernelPipelineState {
    var  startTime:TimeInterval = 0, nowTime:TimeInterval = 0
    
    
    override init(stateData data: [AnyObject]) {
        super.init(stateData: data)
        self.startTime = super.getTimeOfDay()
        
    }
    
    public override func processArguments(withEncoder computeEncode:MTLComputeCommandEncoder){
        
        
        self.nowTime = super.getTimeOfDay()
        var deltaTime:Float = Float(self.nowTime - self.startTime)
        computeEncode.setBytes(&deltaTime, length: MemoryLayout<Float>.size, index: 0)
    }
}
