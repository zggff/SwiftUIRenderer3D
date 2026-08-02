#include <metal_stdlib>
#include "./Shared.h"

using namespace metal;

fragment half4 fragmentWireframeMain(VertexOutput frag [[stage_in]],
                                    constant InstanceUniform *models [[buffer(3)]]) {
    return half4(half3(frag.color.rgb), half(1.0));
}

