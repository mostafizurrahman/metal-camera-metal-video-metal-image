# metal-camera-metal-video-metal-image
You are here because you want to know how to 

1. How to upload camera feed direct to metal kernel/fragment functions.
2. Give a start with basic Still Image Texture / Camera Metal Texture loading/processing in iOS graphics using metal API(s).
3. Read a `MTLTexture` buffer, Then use buffer to create a `CVPixelBuffer`/`UIImage` and whatever you like.
4. If you are frustrated to understand the metal kernel functionalities and how it should be calculated; then please give a look to this official document from apple : https://developer.apple.com/documentation/metal/setting_up_a_command_structure
5. If you would like to read more from the following link then it will be more easier to understand the basic of Metal GPU pipeline : https://developer.apple.com/documentation/metal/setting_up_a_command_structure

Special thanks to this repository and its owner :: https://github.com/navoshta/MetalRenderCamera

I grabbed camera session, metal texture cache creation and other setup related code from here. I perform subclassing for `MTLCommandEncoder` class. I subclassed `AVAssetWriter` to generate video from `MTLTexture`. 
Here are some important notes about metal rendering process

1. Metal Texture used for rendering in `MTLView` is not suitable for generating video/still image.
2. `MTLComputeCommandEncoder` is used to process camera feed in metal kernel function. 
3. Output is writen to an internal texture for rendering and later video/image generation.
4. Kernel function subclassing for applying different effect in live iOS camera stream.
5. If you would like to add some custom metal effects you my subclass `BaseKernelPipelineState` and override `processArguments(computeEncode:)` method. 
