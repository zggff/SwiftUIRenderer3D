#include <metal_stdlib>
#include <simd/simd.h>

#include "../../Render3DShadersC/bridge.h"

using namespace metal;

struct VertexOutput {
    float4 position [[position]];
    float3 normal;
    float3 worldPosition;
    uint instanceID;
};


vertex VertexOutput vertexMain(Vertex v [[stage_in]],
                               constant CameraUniforms &camera [[buffer(1)]],
                               constant InstanceUniforms *models [[buffer(3)]],
                               uint instanceID [[instance_id]]) {
    VertexOutput data;
    InstanceUniforms instance = models[instanceID];
    float4 worldPosition = instance.model * float4(v.position, 1.0);

    data.position = camera.projection * camera.view * worldPosition;
    if (instance.skipLight) return data;

    data.worldPosition = worldPosition.xyz;
    data.instanceID = instanceID;

    data.normal = normalize(instance.normal * v.normal);

    return data;
};

fragment half4 fragmentMain(VertexOutput frag [[stage_in]], 
                            constant CameraUniforms &camera [[buffer(1)]],
                            constant SceneUniforms &scene [[buffer(2)]],
                            constant InstanceUniforms *models [[buffer(3)]]) {



    InstanceUniforms instance = models[frag.instanceID];
    if (instance.skipLight) return half4(half3(instance.color), 1.0h);

    float3 lightDir = normalize(scene.lightDirection);

    float diffuse =
        max(dot(frag.normal, lightDir), 0.0);

    float3 ambient =
        scene.ambientStrength * scene.lightColor;

    float3 diffuseLight =
        diffuse *
        scene.diffuseStrength * scene.lightColor;

    float3 lighting =
        ambient + diffuseLight;

    float3 viewDir =
        normalize(camera.position - frag.worldPosition);

    float3 halfway =
        normalize(lightDir + viewDir);

    float specular =
        pow(
            max(dot(frag.normal, halfway), 0.0),
            instance.shininess
        );

    float3 specularLight =
        specular * 0.5 *
        scene.lightColor;

    float3 finalColor =
        instance.color * lighting + specularLight;

    return half4(
        half3(finalColor),
        1.0h
    );
};
