//
//  EffectHandler.swift
//  MetalCameraRenderer
//
//  Created by Mostafizur Rahman on 30/3/19.
//  Copyright © 2019 ParadoxSpace. All rights reserved.
//

import UIKit

enum EffectType:String {
    case mask = "mask"
    case movie = "movie"
    case base = "base"
    case gif = "gif"
    case normal = "normal"
}
struct FilterData {
    let filterID:String
    let title:String
    let imagesArray:[String]
    let functionName:String
    let type:EffectType
    init(data:[String : AnyObject]){
        self.filterID = data["id"] as! String
        self.imagesArray = data["images"] as! [String]
        self.functionName = data["fn"] as! String
        self.title = data["title"] as! String
        self.type = EffectType.init(rawValue: data["type"] as! String)!
    }
}

class EffectHandler: NSObject {

    var effectArray:[FilterData]
    override init() {
        self.effectArray = []
        let dicPath = Bundle.main.path(forResource: "EffectList", ofType: "plist")!
        let array = NSArray.init(contentsOfFile: dicPath)!
        for data in array {
            if let _data = data as? [String:AnyObject]{
                let filter = FilterData(data: _data)
                self.effectArray.append(filter)
            }
        }
        super.init()
    }

    
    func getFilter(At index:Int)->FilterData{
        return self.effectArray[index]
    }
    
    func getKernel(At index:Int, Deivce devices:[AnyObject])->BaseKernelPipelineState? {
        var data = devices
        let filter = self.getFilter(At: index)
        let functions = [filter.functionName]
        data.append(functions as AnyObject)
        var kernel:BaseKernelPipelineState? = nil
        if filter.type == .base {
             kernel = EffectKernelPipelineState(stateData: data)
        } else if filter.type == .mask {
            data.append(filter.imagesArray as AnyObject)
            kernel = MaskKernelPipelineState(stateData: data)
        } else if filter.type == .movie {
            data.append(filter.imagesArray as AnyObject)
            kernel = OldMoviePipelineState(stateData: data)
        }
        return kernel
    }
}
