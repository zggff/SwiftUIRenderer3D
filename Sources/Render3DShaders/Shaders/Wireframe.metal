#include <metal_stdlib>
#include "./Shared.h"

using namespace metal;

fragment half4 fragmentWireframeMain(VertexOutput frag [[stage_in]],
                                    constant InstanceUniform *models [[buffer(3)]]) {
    InstanceUniform instance = models[frag.instanceID];
    return half4(instance.color);
}

