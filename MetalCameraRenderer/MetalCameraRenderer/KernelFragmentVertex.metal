//
//  KernelFragmentVertex.metal
//  MetalCameraRenderer
//
//  Created by Mostafizur Rahman on 25/10/18.
//  Copyright © 2018 image-app.com. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


typedef struct {
    float4 renderedCoordinate [[position]];
    float2 textureCoordinate;
} TextureMappingVertex;

vertex TextureMappingVertex VertexFunction(const device float *vertexDiff [[ buffer(0) ]],
                                       unsigned int vertex_id [[ vertex_id ]]) {
    
    float4x4 renderedCoordinates = float4x4(float4( -1.0 , -1.0, 0.0, 1.0 ),
                                            float4(  1.0, -1.0, 0.0, 1.0 ),
                                            float4( -1.0,  1.0, 0.0, 1.0 ),
                                            float4(  1.0,  1.0, 0.0, 1.0 ));
    
    float4x2 textureCoordinates = float4x2(float2( 0.0, 1.0), float2(1.0, 1.0),
                                           float2( 0.0, 0.0), float2(1.0, 0.0));
    TextureMappingVertex outVertex;
    outVertex.renderedCoordinate = renderedCoordinates[vertex_id];
    outVertex.textureCoordinate = textureCoordinates[vertex_id];
    return outVertex;
}

fragment half4 FragmentFunction(TextureMappingVertex mappingVertex [[ stage_in ]],
                             texture2d<float, access::sample> texture [[ texture(0) ]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    //    float4 alpha = float4(alphaDiff,alphaDiff,alphaDiff,alphaDiff);
    return half4(texture.sample(s, mappingVertex.textureCoordinate)) ;
    
}


kernel void WaveColorEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           const device float *timeDelta [[ buffer(0) ]],
                           uint2 gid [[thread_position_in_grid]],
                           uint2 tpg [[threads_per_grid]]){
    
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    float wave = sin(timeDelta[0]);
    float circle = uv.x * uv.x + uv.y * uv.y;
    float4 color = inTexture.sample(s, uv);
    float4 newColor = float4(circle * color.r / wave  , color.g * wave,
                             color.b * wave , wave ) + color * (1.0 - wave);
    outTexture.write(newColor,gid);
}
