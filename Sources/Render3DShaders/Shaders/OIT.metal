#include <metal_stdlib>

#include "./Shared.h"

using namespace metal;

struct OITFragmentOutput {
    float4 accum [[color(0)]];
    float  reveal [[color(1)]];
};

fragment OITFragmentOutput oitAccumulationFragment(VertexOutput frag [[stage_in]],
                                                   constant CameraUniform &camera [[buffer(1)]],
                                                   constant SceneUniform &scene [[buffer(2)]],
                                                   constant InstanceUniform *models [[buffer(3)]]) {
    InstanceUniform instance = models[frag.instanceID];
    float alpha = frag.color.a;
    
    if (alpha >= 1.0) discard_fragment();

    float3 lightDir = normalize(scene.lightDirection);
    float diffuse = max(dot(frag.normal, lightDir), 0.0);
    float3 ambient = scene.ambientStrength * scene.lightColor;
    float3 diffuseLight = diffuse * scene.diffuseStrength * scene.lightColor;
    float3 lighting = ambient + diffuseLight;
    
    float3 viewDir = normalize(camera.position - frag.worldPosition);
    float3 halfway = normalize(lightDir + viewDir);
    float specular = pow(max(dot(frag.normal, halfway), 0.0), instance.shininess);
    float3 specularLight = specular * 0.5 * scene.lightColor;

    float3 finalColor = frag.color.rgb * lighting + specularLight;

    float z = frag.position.z;
    float depth = z * 0.5 + 0.5;
    depth = clamp(depth, 0.0, 1.0);
    
    float weight = clamp(pow(1.0 - depth, 3.0) * 1000.0 * pow(alpha + 0.01, 3.0), 1e-2, 3e3);

    OITFragmentOutput out;
    out.accum = float4(finalColor * alpha, alpha) * weight;
    out.reveal = alpha;
    return out;
}

struct FullscreenVertexOutput {
    float4 position [[position]];
    float2 uv;
};

vertex FullscreenVertexOutput oitCompositeVertex(uint vertexID [[vertex_id]]) {
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    FullscreenVertexOutput out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = (positions[vertexID] + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y; 
    return out;
}

fragment half4 oitCompositeFragment(FullscreenVertexOutput in [[stage_in]],
                                    texture2d<float> accumTexture [[texture(0)]],
                                    texture2d<float> revealTexture [[texture(1)]]) {
    constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    
    float4 accum = accumTexture.sample(textureSampler, in.uv);
    float reveal = revealTexture.sample(textureSampler, in.uv).r;

    if (reveal >= 0.999) {
        discard_fragment();
    }

    float3 averageColor = accum.rgb / max(accum.a, 1e-4);
    
    return half4(half3(averageColor), 1.0 - reveal);
}
