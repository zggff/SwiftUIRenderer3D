#ifndef bridge_h
#define bridge_h

#include <simd/simd.h>

#ifdef __METAL_VERSION__
#define VERTEX_ATTR(x) [[attribute(x)]]
#else
#define VERTEX_ATTR(x)
#endif

struct Vertex {
    vector_float3 position VERTEX_ATTR(0);
};

struct SceneUniforms {
    matrix_float4x4 projection;
    matrix_float4x4 view;
};

struct InstanceUniforms {
    matrix_float4x4 translation;
    vector_float3 color;
};

#endif
