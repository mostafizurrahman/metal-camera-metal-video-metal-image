//
//  ViewController.swift
//  MetalShaderCamera
//
//  Created by Mostafizur Rahman on 25/10/2016.
//  Copyright © 2018 image-app.com. All rights reserved.
//

import UIKit
import Metal
import simd


#if arch(i386) || arch(x86_64)
#else
import MetalKit
#endif

enum ImageScalingMode {
    case AspectFit
    case AspectFill
    case ScaleToFill
    case DontResize
}


/**
 * A `UIViewController` that allows quick and easy rendering of Metal textures. Currently only supports textures from single-plane pixel buffers, e.g. it can only render a single RGB texture and won't be able to render multiple YCbCr textures. Although this functionality can be added by overriding `MTKViewController`'s `willRenderTexture` method.
 */
open class MTKViewController: UIViewController {
    
    var filterHelper:EffectHandler!
    var metalData:[AnyObject] = []
    var videoWriter:MetalVideoWriter!
    
    var lastFrameTime:Float = 0.0
    
    
    // MARK: - Public interface
    
    
    /// Metal texture to be drawn whenever the view controller is asked to render its view. Please note that if you set this `var` too frequently some of the textures may not being drawn, as setting a texture does not force the view controller's view to render its content.
    open var texture: MTLTexture?
    
    
    /// Metal texture to be writen. All the animation and effect will be writen to this texture as output to the scene
    open var internalTexture: MTLTexture?
    
    /// Base pipeline state to be used as compute command encoder.
    var baseKernel:BaseKernelPipelineState?
    
    
    // a texture for gif collection
    open var textureforgif: MTLTexture?
    

    #if arch(i386) || arch(x86_64)
    #else
    /// `UIViewController`'s view
    internal var metalView: MTKView!
    #endif
    
    
    /**
     Create a render pipeline descriptor. metalRenderDescriptor is responsible to render pipeline state
     in the metal encoding system. It displays camera steam to the metalView: MTKView!
     */
    fileprivate let metalRenderDescriptor = MTLRenderPipelineDescriptor()
    
    ///create a pipeline state to render command
    fileprivate var pipelineState:MTLRenderPipelineState?
    
    /// Metal device
    internal var device = MTLCreateSystemDefaultDevice()
    /// Metal Library
    internal var metalLibrary:MTLLibrary!
    
    /// Metal device command queue
    lazy internal var commandQueue: MTLCommandQueue? = {
        return device?.makeCommandQueue()
    }()
    
    
    ///create a base pipeline descriptor?
    //    var renderDescriptor:BasePipelineDescriptor?
    /// A semaphore we use to syncronize drawing code.
    fileprivate let semaphore = DispatchSemaphore(value: 1)
    public let metalWriteQueue =  DispatchQueue(label: "MetalCameraEffectWritingQueue", attributes: [])
    

    
    /// writeTexture(_ _texture:MTLTexture) must be overriden to derived class
    func writeTexture(_ _texture:MTLTexture){
        preconditionFailure("Error : this method should not be called here, call it from derived method")
    }
    
    // MARK: - viewDidLoad() Public overrides
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        #if arch(i386) || arch(x86_64)
        NSLog("Failed creating a default system Metal device, since Metal is not available on iOS Simulator.")
        #else
        assert(device != nil, "Failed creating a default system Metal device. Please, make sure Metal is available on your hardware.")
        #endif
        
        initializeMetalView()
        initializeRenderPipelineState()
    }
    
    // MARK: - Private Metal-related properties and methods
    
    /**
     initializes and configures the `MTKView` we use as `UIViewController`'s view.
     
     */
    fileprivate func initializeMetalView() {
        #if arch(i386) || arch(x86_64)
        #else
        
        let rect = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 1920 / 1080)
        metalView = MTKView(frame: rect, device: device)
        metalView.delegate = self
        metalView.framebufferOnly = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.contentScaleFactor = UIScreen.main.scale
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(metalView, at: 0)
//        metalView.center = self.view.center
        #endif
    }
    
    /**
     initializes render pipeline state with a default vertex function, mapping texture to the view's frame and a simple fragment function returning texture pixel's value.
     */
    fileprivate func initializeRenderPipelineState() {
        guard
            let device = device,
            let library = device.makeDefaultLibrary()
            else {
                return
        }
        self.metalLibrary = library
        self.metalRenderDescriptor.sampleCount = 1
        self.metalRenderDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.metalRenderDescriptor.colorAttachments[0].isBlendingEnabled = true
        self.metalRenderDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperation.add;
        self.metalRenderDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperation.add;
        self.metalRenderDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactor.one;
        self.metalRenderDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactor.one;
        self.metalRenderDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
        self.metalRenderDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
        
        let _vname = "VertexFunction"
        let _fname = "FragmentFunction"
        self.metalRenderDescriptor.vertexFunction = library.makeFunction(name: _vname )
        self.metalRenderDescriptor.fragmentFunction = library.makeFunction(name: _fname )
        do{
            self.pipelineState = try device.makeRenderPipelineState(descriptor: self.metalRenderDescriptor)
        } catch  {
            assertionFailure("failed to create state")
        }
        self.metalData.append(self.metalLibrary)
        self.metalData.append(device)
        self.filterHelper = EffectHandler()
        self.baseKernel = self.filterHelper.getKernel(At: 0, Deivce: self.metalData)
//        let data = [ self.metalLibrary, device, ["NormalEffect"]] as [AnyObject]
//        self.baseKernel = EffectKernelPipelineState(stateData: data)
//        self.baseKernel = MaskKernelPipelineState(stateData: data)
        
//        let data = [ self.metalLibrary, device, ["GifmovieEffect"], ["image"]] as [AnyObject]
//      self.baseKernel = GifKernelPipelineState(stateData: data)
    }
    
    
    /// This method render camera stream in metal and applies effects the write output data in out texture
    /// Uses compute command encoding system to invoke a kernel in metal described by effect_data.
    public func createMetalEffect(_ texture:MTLTexture,
                                  inputCommandBuffer commandBuffer:MTLCommandBuffer){
        //self.internalTexture must be set to nil to switch camera
        if self.internalTexture == nil {
            
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat,
                                                                             width: texture.width,
                                                                             height: texture.height,
                                                                             mipmapped: false)
            textureDescriptor.usage = [.shaderWrite, .shaderRead]
            if  let device = self.device {
                self.internalTexture = device.makeTexture(descriptor: textureDescriptor)
            } else {
                assertionFailure("Metal device nil!")
            }
        }
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Error : compute encoder fail to create")
            return
        }
        
        guard let kernel = self.baseKernel else  {
            print("Error : base kernel object is nil")
            return
        }
        guard let intTexture = self.internalTexture else {
            print("Error : Internal texture is nil")
            return
        }
        
        kernel.compute(inTexutr: texture,
                       outTexture: intTexture,
                       inComputeEncoder: commandEncoder)
        if self.shouldWritetexture {
            self.writeVideo(Texture: intTexture)
        }
            
    }
    var shouldWritetexture = false
    
    func writeVideo(Texture intexture:MTLTexture){
        
    }
}

#if arch(i386) || arch(x86_64)
#else

// MARK: - MTKViewDelegate and rendering
extension MTKViewController: MTKViewDelegate {
    
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        NSLog("MTKView drawable size will change to \(size)")
    }
    
    public func draw(in: MTKView) {
        
        autoreleasepool {
            guard let texture = texture else {
                print("Error : camera stream failed to create texture")
                return
            }
            guard let device = self.device else {
                print("Error : Metal Device is nil")
                return
            }
            guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
                print("Error : Command encoder is nil")
                return
            }
            // resposible to create metal camera effect in camera raw image and output will be written to
            // internalTexture, if success, internal texture will be present to the screen using encoder
            self.createMetalEffect(texture, inputCommandBuffer: commandBuffer)
            // rendering the effect output texture (writen to internalTexture via kernel) on screen
            // so the self.internalTexture must not be nil!
            render(texture: self.internalTexture!, withCommandBuffer: commandBuffer, device: device)
        }
    }
    
    /**
     Renders texture into the `UIViewController`'s view.
     
     - parameter texture:       Texture to be rendered
     - parameter commandBuffer: Command buffer we will use for drawing
     */
    private func render(texture: MTLTexture,
                        withCommandBuffer commandBuffer: MTLCommandBuffer,
                        device: MTLDevice) {
        
        
        guard let renderPassDescriptor = metalView.currentRenderPassDescriptor else {
            print("Error : Render pass descriptor is nil")
            return
        }
        guard let drawable = metalView.currentDrawable else {
            print("Error : drawable from metal view is nil")
            return
        }
        guard let pipelineState = self.pipelineState else {
            print("Error : pipelineState is nil")
            return
        }
//        guard let animation = self.animationDescriptor else {
//            print("Error : animation is nil")
//            return
//        }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("Error : Fail to create screen render encoder from command buffer!")
                return
        }
        encoder.pushDebugGroup("RenderFrame")
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0,
                                vertexCount: 4, instanceCount: 1)
        
        encoder.popDebugGroup()
        encoder.endEncoding()

        commandBuffer.present(drawable)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
       
//        self.metalWriteQueue.async {
//            self.writeTexture(texture)
//        }
        
    }
}


#endif
