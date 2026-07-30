#include <metal_stdlib>

#include "./Shared.h"

using namespace metal;


vertex VertexOutput vertexMain(Vertex v [[stage_in]],
                               constant CameraUniform &camera [[buffer(1)]],
                               constant InstanceUniform *models [[buffer(3)]],
                               uint instanceID [[instance_id]]) {
    VertexOutput data;
    InstanceUniform instance = models[instanceID];
    float4 worldPosition = instance.model * float4(v.position, 1.0);

    data.position = camera.projection * camera.view * worldPosition;

    data.worldPosition = worldPosition.xyz;
    data.instanceID = instanceID;

    data.normal = instance.normal * v.normal;
    if (length_squared(data.normal) > 0.0) {
        data.normal = normalize(data.normal);
    }

    return data;
};

fragment half4 fragmentLightMain(VertexOutput frag [[stage_in]], 
                            bool frontFacing [[front_facing]],
                            constant CameraUniform &camera [[buffer(1)]],
                            constant SceneUniform &scene [[buffer(2)]],
                            constant InstanceUniform *models [[buffer(3)]]) {
    if (!frontFacing) {
        frag.normal = -frag.normal;
    }

    InstanceUniform instance = models[frag.instanceID];

    if (all(frag.normal == float3(0.0))) {
        return half4(half3(instance.color.rgb), 1.0);
    }

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
        instance.color.rgb * lighting + specularLight;

    return half4(
        half3(finalColor),
        half(instance.color.a)
    );
};
