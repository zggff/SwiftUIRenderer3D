#include <simd/simd.h>
#include "../../Render3DShadersC/bridge.h"


struct VertexOutput {
    vector_float4 position VERTEX_POS;
    vector_float3 normal;
    vector_float3 worldPosition;
    vector_float4 color;
    unsigned int instanceID;
};


