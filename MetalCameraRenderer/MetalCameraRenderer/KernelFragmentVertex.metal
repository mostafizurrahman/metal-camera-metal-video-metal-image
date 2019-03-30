//
//  KernelFragmentVertex.metal
//  MetalCameraRenderer
//
//  Created by Mostafizur Rahman on 25/10/18.
//  Copyright © 2018 image-app.com. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
float3 blendMultiply(float3 base, float3 blend) {
    return base*blend;
}
float3 blendMultiply(float3 base, float3 blend, float opacity) {
    return (blendMultiply(base, blend) * opacity + base * (1.0 - opacity));
}

float3 blendPhoenix(float3 base, float3 blend) {
    return min(base,blend)-max(base,blend)+float3(1.0);
}

float3 blendPhoenix(float3 base, float3 blend, float opacity) {
    return (blendPhoenix(base, blend) * opacity + base * (1.0 - opacity));
}

float blendReflect(float base, float blend) {
    return (blend==1.0)?blend:min(base*base/(1.0-blend),1.0);
}

float3 blendReflect(float3 base, float3 blend) {
    return float3(blendReflect(base.r,blend.r),blendReflect(base.g,blend.g),blendReflect(base.b,blend.b));
}

float3 blendReflect(float3 base, float3 blend, float opacity) {
    return (blendReflect(base, blend) * opacity + base * (1.0 - opacity));
}


float blendOverlay(float base, float blend) {
    return base<0.5?(2.0*base*blend):(1.0-2.0*(1.0-base)*(1.0-blend));
}

float3 blendOverlay(float3 base, float3 blend) {
    return float3(blendOverlay(base.r,blend.r),blendOverlay(base.g,blend.g),blendOverlay(base.b,blend.b));
}

float3 blendOverlay(float3 base, float3 blend, float opacity) {
    return (blendOverlay(base, blend) * opacity + base * (1.0 - opacity));
}





float3 mod289(float3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float4 mod289(float4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float4 permute(float4 x) {
    return mod289(((x*34.0)+1.0)*x);
}

float4 taylorInvSqrt(float4 r)
{
    return 1.79284291400159 - 0.85373472095314 * r;
}
float snoise3(float3 v)
{
    const float2  C = float2(1.0/6.0, 1.0/3.0) ;
    const float4  D = float4(0.0, 0.5, 1.0, 2.0);
    
    // First corner
    float3 i  = floor(v + dot(v, C.yyy) );
    float3 x0 =   v - i + dot(i, C.xxx) ;
    
    // Other corners
    float3 g = step(x0.yzx, x0.xyz);
    float3 l = 1.0 - g;
    float3 i1 = min( g.xyz, l.zxy );
    float3 i2 = max( g.xyz, l.zxy );
    
    //   x0 = x0 - 0.0 + 0.0 * C.xxx;
    //   x1 = x0 - i1  + 1.0 * C.xxx;
    //   x2 = x0 - i2  + 2.0 * C.xxx;
    //   x3 = x0 - 1.0 + 3.0 * C.xxx;
    float3 x1 = x0 - i1 + C.xxx;
    float3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
    float3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y
    
    // Permutations
    i = mod289(i);
    float4 p = permute( permute( permute(
                                         i.z + float4(0.0, i1.z, i2.z, 1.0 ))
                                + i.y + float4(0.0, i1.y, i2.y, 1.0 ))
                       + i.x + float4(0.0, i1.x, i2.x, 1.0 ));
    
    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
    float n_ = 0.142857142857; // 1.0/7.0
    float3  ns = n_ * D.wyz - D.xzx;
    
    float4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)
    
    float4 x_ = floor(j * ns.z);
    float4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)
    
    float4 x = x_ *ns.x + ns.yyyy;
    float4 y = y_ *ns.x + ns.yyyy;
    float4 h = 1.0 - abs(x) - abs(y);
    
    float4 b0 = float4( x.xy, y.xy );
    float4 b1 = float4( x.zw, y.zw );
    
    //float4 s0 = float4(lessThan(b0,0.0))*2.0 - 1.0;
    //float4 s1 = float4(lessThan(b1,0.0))*2.0 - 1.0;
    float4 s0 = floor(b0)*2.0 + 1.0;
    float4 s1 = floor(b1)*2.0 + 1.0;
    float4 sh = -step(h, float4(0.0));
    
    float4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
    float4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;
    
    float3 p0 = float3(a0.xy,h.x);
    float3 p1 = float3(a0.zw,h.y);
    float3 p2 = float3(a1.xy,h.z);
    float3 p3 = float3(a1.zw,h.w);
    
    //Normalise gradients
    float4 norm = taylorInvSqrt(float4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    
    // Mix final noise value
    float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot( m*m, float4( dot(p0,x0), dot(p1,x1),
                                   dot(p2,x2), dot(p3,x3) ) );
}

float2 mod(float2 xx, float2 yy){
    float __x = xx.x - yy.x * floor(xx.x/yy.x);
    float __y = xx.y - yy.y * floor(xx.y/yy.y);
    return float2(__x, __y);
}
float _mod(float f1, float f2){
    return f1 - f2 * floor(f1/f2);
}
float3 rgb2hsb(  float3 c ){
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz),
                   float4(c.gb, K.xy),
                   step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r),
                   float4(c.r, p.yzx),
                   step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
                  d / (q.x + e),
                  q.x);
}

float2 barrelDistortion(float2 _coord, float amt) {
    float2 cc = _coord - 0.5;
    float dist = dot(cc, cc);
    return _coord + cc * dist * amt;
}

float sat( float t )
{
    return clamp( t, 0.0, 1.0 );
}

float linterp( float t ) {
    return sat( 1.0 - abs( 2.0*t - 1.0 ) );
}

float remap( float t, float a, float b ) {
    return sat( (t - a) / (b - a) );
}

float3 spectrum_offset( float t ) {
    float3 ret;
    float lo = step(t,0.5);
    float hi = 1.0-lo;
    float w = linterp( remap( t, 1.0/6.0, 5.0/6.0 ) );
    ret = float3(lo,1.0,hi) * float3(1.0-w, w, 1.0-w);
    
    return pow( ret, float3(1.0/2.2) );
}



float max(float _f1, float _f2){
    if (_f1 > _f2) {
        return _f1;
    }
    return _f2;
}

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

kernel void GifmovieEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           texture2d<float, access::sample> movieTexture [[texture(2)]],
                           const device float *timeDelta [[ buffer(0) ]],
                           uint2 gid [[thread_position_in_grid]],
                           uint2 tpg [[threads_per_grid]]){
    
    float2 ngid = float2(gid);
    ngid.x /= inTexture.get_width();
    ngid.y /= inTexture.get_height();
    float4 orig = inTexture.read(gid);
    float4 mov = movieTexture.read(gid);
    float val = mov.r*255.0;
    if (val > 18.0 && val < 25.0){
        outTexture.write(orig, gid);
    } else {
        float iGlobalTime = sin(*timeDelta);
        float4 colorAtPixel = float4(orig*iGlobalTime+mov*(1.0-iGlobalTime));
        outTexture.write(colorAtPixel, gid);
    }
    
}

kernel void OldmovieEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                            texture2d<float, access::write> outTexture [[texture(1)]],
                           texture2d<float, access::sample> movieTexture [[texture(2)]],
                            const device float *timeDelta [[ buffer(0) ]],
                            uint2 gid [[thread_position_in_grid]],
                            uint2 tpg [[threads_per_grid]]){
    float2 ngid = float2(gid);
    ngid.x /= inTexture.get_width();
    ngid.y /= inTexture.get_height();
    float4 orig = inTexture.read(gid);
    float4 mov = movieTexture.read(gid);
    
    float iGlobalTime = 1.5 ;//+ sin(*timeDelta);
    float4 colorAtPixel = float4(orig*iGlobalTime+mov*(1.0-iGlobalTime));
    outTexture.write(colorAtPixel, gid);
}

kernel void ColoredEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           const device float *timeDelta [[ buffer(0) ]],
                           uint2 gid [[thread_position_in_grid]],
                           uint2 tpg [[threads_per_grid]]){
    
//    constexpr sampler s(address::clamp_to_edge, filter::linear);
//    float2 uv = float2(gid)/float2(tpg);
//    float wave = sin(timeDelta[0]);
//    float circle = uv.x * uv.x + uv.y * uv.y;
//    float4 color = inTexture.sample(s, uv);
//    float4 newColor = float4(circle * color.r / wave  , color.g * wave,
//                             color.b * wave , wave ) + color * (1.0 - wave);
//    outTexture.write(newColor,gid);
    
    //metal shader is taken from here :: https://www.invasifloatode.com/weblog/metal-video-processing-ios-tvos/
    float2 ngid = float2(gid);
    ngid.x /= inTexture.get_width();
    ngid.y /= inTexture.get_height();

    float4 orig = inTexture.read(gid);

    float2 p = -1.0 + 2.0 * orig.xy;
    
    float iGlobalTime = *timeDelta;

    float x = p.x;
    float y = p.y;

    float mov0 = x + y + 1.0 * cos( 2.0*sin(iGlobalTime)) + 11.0 * sin(x/1.);
    float mov1 = y / 0.9 + iGlobalTime;
    float mov2 = x / 0.2;

    float c1 = abs( 0.5 * sin(mov1 + iGlobalTime) + 0.5 * mov2 - mov1 - mov2 + iGlobalTime );
    float c2 = abs( sin(c1 + sin(mov0/2. + iGlobalTime) + sin(y/1.0 + iGlobalTime) + 3.0 * sin((x+y)/1.)) );
    float c3 = abs( sin(c2 + cos(mov1 + mov2 + c2) + cos(mov2) + sin(x/1.)) );

    float4 colorAtPixel = float4(c1, c2, c3, 1.0);
    outTexture.write(colorAtPixel, gid);
}

kernel void waterEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                        texture2d<float, access::write> outTexture [[texture(1)]],
                        const device float *timeDelta [[ buffer(0) ]],
                        uint2 gid [[thread_position_in_grid]],
                        uint2 tpg [[threads_per_grid]]){
    
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    
    const float2 tc = float2(gid) / float2(tpg);
    float2 p = float2(-1.0) + 2.0 * tc;
    float len = length(p);
    float2 uv = tc + (p/len)*cos(len*12.0-timeDelta[0]*4.0)*0.03;
    float4 color = inTexture.sample(textureSampler,uv).rgba;
    outTexture.write(color, gid);
}

kernel void waterMirrorEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                              texture2d<float, access::write> outTexture [[texture(1)]],
                              const device float *timeDelta [[ buffer(0) ]],
                              uint2 gid [[thread_position_in_grid]],
                              uint2 tpg [[threads_per_grid]]){
    
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    
    const float2 tc = float2(gid) / float2(tpg);
    if (tc.y < 0.5){
        float4 color = inTexture.sample(textureSampler,tc).rgba;
        outTexture.write(color, gid);
    } else{
        tc.y = 1.0 - tc.y ;
        float2 p = float2(-1.0) + 2.0 * tc;
        float len = length(p);
        float2 uv = tc + (p/len)*cos(len*12.0-timeDelta[0]*4.0)*0.03;
        float4 color = inTexture.sample(textureSampler,uv).rgba;
        outTexture.write(color, gid);
    }
    
}


kernel void wavColorEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           const device float *timeDelta [[ buffer(0) ]],
                           uint2 gid [[thread_position_in_grid]],
                           uint2 tpg [[threads_per_grid]]){
    
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    float wave = sin(timeDelta[0]);
    float circle = uv.x * uv.x + uv.y * uv.y;
    float4 color = inTexture.sample(s, uv);
    float4 newColor = float4(circle * color.r / wave  , color.g * wave,  color.b * wave , wave ) + color * (1.0 - wave);
    outTexture.write(newColor,gid);
}




kernel void HSBEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                      texture2d<float, access::write> outTexture [[texture(1)]],
                      const device float *timeDelta [[ buffer(0) ]],
                      uint2 gid [[thread_position_in_grid]],
                      uint2 tpg [[threads_per_grid]]){
    
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    float wave = sin(timeDelta[0]);
    float circle = uv.x * uv.y + uv.y * uv.x;
    const float4 conv =  inTexture.sample(s, uv);
    float4 color = float4(rgb2hsb(conv.rgb),1.0);
    
    // Put it all together
    //    gl_FragColor = float4(float3(circle + wave),1.0);
    float4 generatedcolor = float4(circle * color.r / wave  , color.g * wave,  color.b * wave , wave ) + conv * (1.0 - wave);
    outTexture.write(generatedcolor,gid);
}


kernel void spectrumColor(texture2d<float, access::sample> inTexture [[texture(0)]],
                          texture2d<float, access::write> outTexture [[texture(1)]],
                          const device float *timeDelta [[ buffer(0) ]],
                          uint2 gid [[thread_position_in_grid]],
                          uint2 tpg [[threads_per_grid]]) {
    
    constexpr sampler s(address::clamp_to_edge, filter::linear);
//    float2 resolution = float2(gid.xy);
    float2 err =  float2(cos(timeDelta[0]), sin(timeDelta[0]));
 
    
    
    float2 uv = float2(gid) / float2(tpg);
    float4 color = inTexture.sample(s, uv);
    
    float4 color1 = inTexture.sample(s, uv + mod(uv, err));
    
    outTexture.write(color1.gbra * color.agrb, gid);
    
}


//kernel void noiseEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
//                        texture2d<float, access::write> outTexture [[texture(1)]],
//                        texture2d<float, access::sample> sampleTexture [[texture(2)]],
//                        const device float *timeDelta [[ buffer(0) ]],
//                        uint2 gid [[thread_position_in_grid]],
//                        uint2 tpg [[threads_per_grid]]){
//
//    constexpr sampler source(address::clamp_to_edge, filter::linear);
//    constexpr sampler noise(address::clamp_to_edge, filter::linear);
//    float2 uv = float2(gid)/float2(tpg);
//    //    uv.y = uv.y;
//    half trheshold =  sin(timeDelta[0]);
//    float2 n_uv = float2(gid)/float2(tpg);
//    float4 sourcePixel = inTexture.sample(source, uv);
//    float4 ditherPixel = sampleTexture.sample(noise, n_uv);
//
//
//    float4 color = (ditherPixel - trheshold) * trheshold * 0.5  + sourcePixel * 0.5;
//    if (color.r < 0 || color.a <= 0) {
//        float4 colorOne = sourcePixel * 0.75 + (ditherPixel) * 0.25;
//        outTexture.write(colorOne,gid);
//    }
//    outTexture.write(color,gid);
//    // return color;
//
//
//}


kernel void colorTransferEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                                texture2d<float, access::write> outTexture [[texture(1)]],
                                const device float *timeDelta [[ buffer(0) ]],
                                uint2 gid [[thread_position_in_grid]],
                                uint2 tpg [[threads_per_grid]]){
    
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    
    float trheshold =  sin(timeDelta[0]);
    float square_T = trheshold *= trheshold;
    
    float width = 1080;
    float height = 1920;
    float w = 1.0 / width;
    float h = 1.0 / height;
    float2 wh = float2(w,h);
    float4 color = inTexture.sample(source, uv);
    float4 color1 = inTexture.sample(source, uv+wh) * color / square_T;
    float4 color2 = inTexture.sample(source, uv-wh) ;
    color2.a = 1.0;
    color2.r = color1.r;
    color2.gb = color2.gb * color1.gb;
    outTexture.write(color2,gid);
}


kernel void gradientEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           const device float *timeDelta [[ buffer(0) ]],
                           uint2 gid [[thread_position_in_grid]],
                           uint2 tpg [[threads_per_grid]]){
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    
    float trheshold =  sin(timeDelta[0]);
    float square_T = trheshold *= trheshold;
    
    float4 pixcol = inTexture.sample(source, uv);
    
    
    float4 finalColor = pixcol * float4(uv.x, uv.y, square_T, 1.0);
    outTexture.write(finalColor,gid);
}

kernel void NormalEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                        texture2d<float, access::write> outTexture [[texture(1)]],
                        uint2 gid [[thread_position_in_grid]],
                        uint2 tpg [[threads_per_grid]]){
    float2 uv = float2(gid) / float2(tpg);
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float4 color = inTexture.sample(s, uv);
    outTexture.write(color,gid);
}


kernel void barrelffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                        texture2d<float, access::write> outTexture [[texture(1)]],
                        uint2 gid [[thread_position_in_grid]],
                        uint2 tpg [[threads_per_grid]]){
    
    float barrelPower = 1.5;
    
    const int num_iter = 12;
    const float reci_num_iter_f = 1.0 / float(num_iter);
    float2 uv = float2(gid) / float2(tpg);
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float3 sumcol = float3(0.0);
    float3 sumw = float3(0.0);
    for ( int i=0; i<num_iter;++i )
    {
        float t = float(i) * reci_num_iter_f;
        float3 w = spectrum_offset( t );
        sumw += w;
        float4 color = inTexture.sample(s, barrelDistortion(uv, barrelPower*t ));
        sumcol += w * color.rgb;
    }
    float4 color = float4(float3(float3(sumcol.rgb) / float3(sumw.rgb)), 1.0);
    outTexture.write(color,gid);
}

float random(float2 c){
    return fract(sin(dot(c.xy ,float2(12.9898,78.233))) * 43758.5453);
}

kernel void glitchEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                         texture2d<float, access::write> outTexture [[texture(1)]],
                         const device float *timeDelta [[ buffer(0) ]],
                         uint2 gid [[thread_position_in_grid]],
                         uint2 tpg [[threads_per_grid]]){
    
    
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 vUv = float2(gid)/float2(tpg);
    
    float interval = 3.0;
    
    float time = timeDelta[0];
    float2 resolution = float2(inTexture.get_width(),inTexture.get_height());
    
    float strength = smoothstep(interval * 0.5, interval, interval - _mod(time, interval));
    float2 shake = float2(strength * 8.0 + 0.5) * float2(
                                                         random(float2(time)) * 2.0 - 1.0,
                                                         random(float2(time * 2.0)) * 2.0 - 1.0
                                                         ) / resolution;
    
    float y = vUv.y * resolution.y;
    float rgbWave = (
                     snoise3(float3(0.0, y * 0.01, time * 400.0)) * (2.0 + strength * 32.0)
                     * snoise3(float3(0.0, y * 0.02, time * 200.0)) * (1.0 + strength * 4.0)
                     + step(0.9995, sin(y * 0.005 + time * 1.6)) * 12.0
                     + step(0.9999, sin(y * 0.005 + time * 2.0)) * -18.0
                     ) / resolution.x;
    float rgbDiff = (6.0 + sin(time * 500.0 + vUv.y * 40.0) * (20.0 * strength + 1.0)) / resolution.x;
    float rgbUvX = vUv.x + rgbWave;
    float r = inTexture.sample(source, float2(rgbUvX + rgbDiff, vUv.y) + shake).r;
    float g = inTexture.sample(source, float2(rgbUvX, vUv.y) + shake).g;
    float b = inTexture.sample(source, float2(rgbUvX - rgbDiff, vUv.y) + shake).b;
    
    float whiteNoise = (random(vUv + _mod(time, 10.0)) * 2.0 - 1.0) * (0.15 + strength * 0.15);
    
    float bnTime = floor(time * 20.0) * 200.0;
    float noiseX = step((snoise3(float3(0.0, vUv.x * 3.0, bnTime)) + 1.0) / 2.0, 0.12 + strength * 0.3);
    float noiseY = step((snoise3(float3(0.0, vUv.y * 3.0, bnTime)) + 1.0) / 2.0, 0.12 + strength * 0.3);
    float bnMask = noiseX * noiseY;
    float bnUvX = vUv.x + sin(bnTime) * 0.2 + rgbWave;
    float bnR = inTexture.sample(source, float2(bnUvX + rgbDiff, vUv.y)).r * bnMask;
    float bnG = inTexture.sample(source, float2(bnUvX, vUv.y)).g * bnMask;
    float bnB = inTexture.sample(source, float2(bnUvX - rgbDiff, vUv.y)).b * bnMask;
    float4 blockNoise = float4(bnR, bnG, bnB, 1.0);
    
    float bnTime2 = floor(time * 25.0) * 300.0;
    float noiseX2 = step((snoise3(float3(0.0, vUv.x * 2.0, bnTime2)) + 1.0) / 2.0, 0.12 + strength * 0.5);
    float noiseY2 = step((snoise3(float3(0.0, vUv.y * 8.0, bnTime2)) + 1.0) / 2.0, 0.12 + strength * 0.3);
    float bnMask2 = noiseX2 * noiseY2;
    float bnR2 = inTexture.sample(source, float2(bnUvX + rgbDiff, vUv.y)).r * bnMask2;
    float bnG2 = inTexture.sample(source, float2(bnUvX, vUv.y)).g * bnMask2;
    float bnB2 = inTexture.sample(source, float2(bnUvX - rgbDiff, vUv.y)).b * bnMask2;
    float4 blockNoise2 = float4(bnR2, bnG2, bnB2, 1.0);
    
    float waveNoise = (sin(vUv.y * 1200.0) + 1.0) / 2.0 * (0.15 + strength * 0.2);
    
    float4 finalColor = float4(r, g, b, 1.0) * float4(1.0 - bnMask - bnMask2) + float4(whiteNoise + blockNoise + blockNoise2 - waveNoise);
    
    outTexture.write(finalColor,gid);
}


kernel void DodgeEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                         texture2d<float, access::write> outTexture [[texture(1)]],
                         const device float *timeDelta [[ buffer(0) ]],
                         uint2 gid [[thread_position_in_grid]],
                         uint2 tpg [[threads_per_grid]]){
    
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
//    if (uv.y > 0.5)
//    {
    
        
    
        float rt_w = inTexture.get_width();
        float rt_h = inTexture.get_height();
        
        
        float4 c = float4(0.0);
    float size = 1.5  * sin(*timeDelta);
        float2 cPos = uv * float2(rt_w, rt_h);
        float2 tlPos = floor(cPos / float2(size, size));
        tlPos *= size;
        int invert = 0;
        int remX = int(_mod(cPos.x, size));
        int remY = int(_mod(cPos.y, size));
        if (remX == 0 && remY == 0)
            tlPos = cPos;
        float2 blPos = tlPos;
        blPos.y += (size - 1.0);
        if ((remX == remY) ||
            (((int(cPos.x) - int(blPos.x)) == (int(blPos.y) - int(cPos.y)))))
        {
            if (invert == 1)
                c = float4(0.2, 0.15, 0.05, 1.0);
            else
                c = inTexture.sample(source, tlPos * float2(1.0/rt_w, 1.0/rt_h)) * 1.4;
        }
        else
        {
            if (invert == 1)
                c = inTexture.sample(source, tlPos * float2(1.0/rt_w, 1.0/rt_h)) * 1.4;
            else
                c = float4(0.0, 0.0, 0.0, 1.0);
        }
        outTexture.write(c,gid);
//    }
//    else
//    {
//        uv.y += 0.5;
//
//        float4 c =  inTexture.sample(source, uv);
//        outTexture.write(c,gid);
//    }
    
}


kernel void Shockwave(texture2d<float, access::sample> inTexture [[texture(0)]],
                        texture2d<float, access::write> outTexture [[texture(1)]],
                        const device float *timeDelta [[ buffer(0) ]],
                        uint2 gid [[thread_position_in_grid]],
                        uint2 tpg [[threads_per_grid]]){
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    
    
    
    float2 center = float2(0.25, 0.25); // Mouse position
    float time = *timeDelta; // effect elapsed time
    time = (sin(time) + cos(time) ) / tan(time);
    if (time < 0 ){
        time = -time;
    }
    float3 shockParams = float3(10.0, 0.8, 0.1);
    
    
    float2 texCoord = uv;
    float dist = distance(uv, center);
    if ( (dist <= (time + shockParams.z)) &&
        (dist >= (time - shockParams.z)) )
    {
        float diff = (dist - time);
        float powDiff = 1.0 - pow(abs(diff*shockParams.x),
                                  shockParams.y);
        float diffTime = diff  * powDiff;
        float2 diffUV = normalize(uv - center);
        texCoord = uv + (diffUV * diffTime);
    }
    float4 c  = inTexture.sample(source, texCoord);
    outTexture.write(c,gid);
}


kernel void Posterize(texture2d<float, access::sample> inTexture [[texture(0)]],
                      texture2d<float, access::write> outTexture [[texture(1)]],
                      const device float *timeDelta [[ buffer(0) ]],
                      uint2 gid [[thread_position_in_grid]],
                      uint2 tpg [[threads_per_grid]]){
    
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    float gamma =  1.2 - cos(*timeDelta);
    float numColors = 10.0;
    float3 c  = inTexture.sample(source, uv).rgb;
    
        c = pow(c, float3(gamma, gamma, gamma));
        c = c * numColors;
        c = floor(c);
        c = c / numColors;
        c = pow(c, float3(1.0/gamma));
    outTexture.write(float4(c, 1.0),gid);
    
}

kernel void BlackEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                      texture2d<float, access::write> outTexture [[texture(1)]],
                      const device float *timeDelta [[ buffer(0) ]],
                      uint2 gid [[thread_position_in_grid]],
                      uint2 tpg [[threads_per_grid]]){
    
    
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    
    float4 c = inTexture.sample(source, uv);
    
    c +=  inTexture.sample(source, uv+0.001);
    c +=  inTexture.sample(source, uv+0.003);
    c +=  inTexture.sample(source, uv+0.005);
    c += inTexture.sample(source, uv+0.007);
    c += inTexture.sample(source, uv+0.009);
    c += inTexture.sample(source, uv+0.011);
    
    c += inTexture.sample(source, uv-0.001);
    c += inTexture.sample(source, uv-0.003);
    c += inTexture.sample(source, uv-0.005);
    c += inTexture.sample(source, uv-0.007);
    c += inTexture.sample(source, uv-0.009);
    c += inTexture.sample(source, uv-0.011);
    
    c.rgb = float3((c.r+c.g+c.b)/3.0);
    c = c / 9.5;
    
    outTexture.write(c,gid);
}


kernel void Pixelate(texture2d<float, access::sample> inTexture [[texture(0)]],
                      texture2d<float, access::write> outTexture [[texture(1)]],
                      const device float *timeDelta [[ buffer(0) ]],
                      uint2 gid [[thread_position_in_grid]],
                      uint2 tpg [[threads_per_grid]]){
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    
    
    float rt_w = inTexture.get_height(); // GeeXLab built-in
    float rt_h = inTexture.get_width(); // GeeXLab built-in
    
    
    
    float3 tc = float3(1.0, 0.0, 0.0);
    float t = sin(*timeDelta);
    float pixel_w = 12 + 5 * t; // 15.0
    float pixel_h  = 12 + 5 * t; // 10.0

    float dx = pixel_w*(1./rt_w);
    float dy = pixel_h*(1./rt_h);
    float2 crd = float2(dx*floor(uv.x/dx),
                        dy*floor(uv.y/dy));
    
    tc = inTexture.sample(source, crd).rgb;
    
    
    outTexture.write(float4(tc, 1.0),gid);
    
}

float rand(float2 co){
    return fract(sin( dot(co ,float2(12.9898,78.233))) * 43758.5453 );
}

kernel void ColorGlitch(texture2d<float, access::sample> inTexture [[texture(0)]],
                     texture2d<float, access::write> outTexture [[texture(1)]],
                     const device float *timeDelta [[ buffer(0) ]],
                     uint2 gid [[thread_position_in_grid]],
                     uint2 tpg [[threads_per_grid]]){
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    float t = sin(*timeDelta) * cos(*timeDelta);
    
//    float rt_w = inTexture.get_height(); // GeeXLab built-in
//    float rt_h = inTexture.get_width(); // GeeXLab built-in
    
//    float _ChromAberrAmountY = 5;
//    float _ChromAberrAmountX = 5;
//    float2 _ChromAberrAmount = float2(_ChromAberrAmountX, _ChromAberrAmountY);
//    float _RightStripesAmount = 5;
//    float _LeftStripesAmount = 5;
//    float _RightStripesFill = 10;
//    float _LeftStripesFill = 10;
    //Stripes section
//    float stripesRight = floor(uv.y * _RightStripesAmount);
//    stripesRight = step(_RightStripesFill, rand(float2(stripesRight, stripesRight)));
    
//    float stripesLeft = floor(uv.y * _LeftStripesAmount);
//    stripesLeft = step(_LeftStripesFill, rand(float2(stripesLeft, stripesLeft)));
    //Stripes section
//    float _WavyDisplFreq = 10;
//    float4 wavyDispl = mix(float4(1,0,0,1), float4(0,1,0,1), (sin(uv.y * _WavyDisplFreq) + 1) / 2);
//    float4 _DisplacementAmount = float4(0.3, 0.5, 0.1, 0.6);
    //Displacement section
//    float2 displUV = (_DisplacementAmount.xy * stripesRight) - (_DisplacementAmount.xy * stripesLeft);
//    displUV += (_DisplacementAmount.zw * wavyDispl.r) - (_DisplacementAmount.zw * wavyDispl.g);
    //Displacement section
    
    //Chromatic aberration section
//    float2 uv1 = float2(0.15)*t;
//    if (uv1.y < 0 || uv1.y > 1.0 || uv1.x < 0 || uv1.x > 1.0){
//        uv1 = float2(0);
//    }
//    float2 uv2 = float2(0.21)*t;
//    if (uv2.y < 0 || uv2.y > 1.0 || uv2.x < 0 || uv2.x > 1.0){
//        uv2 = float2(0);
//    }
    float chromR = inTexture.sample(source, uv + float2(0.15)*t).r;
    float chromG = inTexture.sample(source, uv + float2(0.21)*t).g;
    float chromB = inTexture.sample(source, uv).b;
    //Chromatic aberration section
    
    float4 finalCol = float4(chromR, chromG, chromB, 1);
    
    outTexture.write(finalCol,gid);
    
}


kernel void ColorBurn(texture2d<float, access::sample> inTexture [[texture(0)]],
                        texture2d<float, access::write> outTexture [[texture(1)]],
                        const device float *timeDelta [[ buffer(0) ]],
                        uint2 gid [[thread_position_in_grid]],
                        uint2 tpg [[threads_per_grid]]){
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
//    float t = sin(*timeDelta) * cos(*timeDelta);
    float2 uv1 =  uv + float2(0.15);
    if ( uv1.y > 1.0 || uv1.x > 1.0){
        uv1 = uv;
    }
    float4 blend = inTexture.sample(source,uv1);
    float4 base = inTexture.sample(source, uv);
    
//    if (uv.x < 0.5) {
//        float4 result = 2.0 * base * blend;
//        outTexture.write(result,gid);
//    } else {
        float4 result = float4(1.0) - 2.0 * (float4(1.0) - blend) * (float4(1.0) - base);
        outTexture.write(result,gid);
//    }
}


kernel void MaskBlendOverlay(texture2d<float, access::sample> inTexture [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           texture2d<float, access::sample> movieTexture [[texture(2)]],
                           const device float *timeDelta [[ buffer(0) ]],
                           uint2 gid [[thread_position_in_grid]],
                           uint2 tpg [[threads_per_grid]]){
    float2 ngid = float2(gid);
    ngid.x /= inTexture.get_width();
    ngid.y /= inTexture.get_height();
    float4 base = inTexture.read(gid);
    float4 blend = movieTexture.read(gid);
    float3 color = blendOverlay(base.rgb, blend.rgb);
    
    outTexture.write(float4(color,1), gid);
}


kernel void MaskBlendHardLight(texture2d<float, access::sample> inTexture [[texture(0)]],
                               texture2d<float, access::write> outTexture [[texture(1)]],
                               texture2d<float, access::sample> movieTexture [[texture(2)]],
                               const device float *timeDelta [[ buffer(0) ]],
                               uint2 gid [[thread_position_in_grid]],
                               uint2 tpg [[threads_per_grid]]){
    float2 ngid = float2(gid);
    ngid.x /= inTexture.get_width();
    ngid.y /= inTexture.get_height();
    float4 base = inTexture.read(gid);
    float4 blend = movieTexture.read(gid);
    float3 color = blendPhoenix(blend.rgb, base.rgb, 0.6) ;
    
    outTexture.write(float4(color,1), gid);
}

kernel void MaskBlendPinLight(texture2d<float, access::sample> inTexture [[texture(0)]],
                               texture2d<float, access::write> outTexture [[texture(1)]],
                               texture2d<float, access::sample> movieTexture [[texture(2)]],
                               const device float *timeDelta [[ buffer(0) ]],
                               uint2 gid [[thread_position_in_grid]],
                               uint2 tpg [[threads_per_grid]]){
    float2 ngid = float2(gid);
    ngid.x /= inTexture.get_width();
    ngid.y /= inTexture.get_height();
    float4 base = inTexture.read(gid);
    float4 blend = movieTexture.read(gid);
    float3 color = blendReflect( base.rgb,blend.rgb, 0.5) ;
    
    outTexture.write(float4(color,1), gid);
}

kernel void MaskBlendMultiply(texture2d<float, access::sample> inTexture [[texture(0)]],
                              texture2d<float, access::write> outTexture [[texture(1)]],
                              texture2d<float, access::sample> movieTexture [[texture(2)]],
                              const device float *timeDelta [[ buffer(0) ]],
                              uint2 gid [[thread_position_in_grid]],
                              uint2 tpg [[threads_per_grid]]){
    float2 ngid = float2(gid);
    ngid.x /= inTexture.get_width();
    ngid.y /= inTexture.get_height();
    float4 base = inTexture.read(gid);
    float4 blend = movieTexture.read(gid);
    float3 color = blendMultiply( base.rgb,blend.rgb, 0.5) ;

    outTexture.write(float4(color,1), gid);
    
}

kernel void ColorShift(texture2d<float, access::sample> inTexture [[texture(0)]],
                              texture2d<float, access::write> outTexture [[texture(1)]],
                              texture2d<float, access::sample> movieTexture [[texture(2)]],
                              const device float *timeDelta [[ buffer(0) ]],
                              uint2 gid [[thread_position_in_grid]],
                              uint2 tpg [[threads_per_grid]]){
    
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    float2 redShift = float2(0.05, 0) * uv;
    if ((redShift + uv).x> 1.0){
        redShift.x = 1;
    }
    float2 greenShift = float2(0.075, 0) * uv;
    if ((greenShift + uv).x > 1){
        greenShift.x = 1;
    }
    float2 blueShift = float2(0.06, 0) * uv;
    if ((blueShift + uv).x > 1){
        blueShift.x = 1;
    }
    
    
    float chromR = inTexture.sample(source, uv + redShift).r;
    float chromG = inTexture.sample(source, uv + greenShift).g;
    float chromB = inTexture.sample(source, uv + blueShift).b;
    
    
    outTexture.write(float4(chromR,chromG,chromB, 1), gid);
}


kernel void ColoeAnimEffect(texture2d<float, access::sample> inTexture [[texture(0)]],
                        texture2d<float, access::write> outTexture [[texture(1)]],
                        const device float *timeDelta [[ buffer(0) ]],
                        uint2 gid [[thread_position_in_grid]],
                        uint2 tpg [[threads_per_grid]]){
    
    
    constexpr sampler source(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid)/float2(tpg);
    float2 resolution = float2(gid.xy);
    float time = *timeDelta;
    float2 q = uv / float2(inTexture.get_width(), inTexture.get_height());
    float3 col = inTexture.sample(source, uv).rgb;
    col *= sin(gid.y*350.+time)*0.04+1.;//Scanlines
    col *= sin(gid.x*350.+time)*0.04+1.;
    col *= pow( 16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.1)*0.35+0.65; //Vign
    outTexture.write(float4(col, 1), gid);
//    fragColor = vec4(col,1.0);
    
    
}
