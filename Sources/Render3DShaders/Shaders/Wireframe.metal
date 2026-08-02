#include <metal_stdlib>
#include "./Shared.h"

using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut wireframeVertex(Vertex in [[stage_in]],
                                  constant CameraUniform &camera [[buffer(1)]],
                                  constant InstanceUniform *models [[buffer(3)]],
                                  uint instanceID [[instance_id]],
                                  uint vertexID [[vertex_id]]) {
    InstanceUniform instance = models[instanceID];

    VertexOut out;
    float4 worldPosition = instance.model * float4(in.position, 1.0);
    out.position = camera.projection * camera.view * worldPosition;

    if (instance.vertexColorType == 0) {
        out.color = instance.color;
    } else {
        out.color = in.colorUV;
    }

    return out;
}


fragment float4 wireframeFragment(VertexOut in [[stage_in]],
                                  float3 barycentric [[barycentric_coord]]) {

    float minBarycentric = min(barycentric.x, min(barycentric.y, barycentric.z));
    float edgeWidth = 0.02;
    
    if (minBarycentric < edgeWidth) {
        return float4(in.color.xyz, 1.0);
    } else {
        discard_fragment();
    }
}
