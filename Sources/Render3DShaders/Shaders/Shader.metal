#include <metal_stdlib>
#include <simd/simd.h>

struct Vertex {
    vector_float3 position [[attribute(0)]];
};

struct SceneUniforms {
    matrix_float4x4 projection;
    matrix_float4x4 view;
};

struct InstanceUniforms {
    matrix_float4x4 translation;
    vector_float3 color;
};

using namespace metal;

struct VertexOutput {
    float4 position [[position]];
    half3 color;
};

vertex VertexOutput vertexMain(Vertex v [[stage_in]],
                               constant SceneUniforms &scene [[buffer(1)]],
                               constant InstanceUniforms *models [[buffer(2)]],
                               uint instanceID [[instance_id]]) {
    VertexOutput data;
    InstanceUniforms model = models[instanceID];
    float4 position = float4(v.position, 1.0);
    data.position = scene.projection * scene.view * model.translation * position;
    data.color = half3(model.color);
    return data;
};

fragment half4 fragmentMain(VertexOutput frag [[stage_in]]){
    return half4(frag.color, 1.0);
};
