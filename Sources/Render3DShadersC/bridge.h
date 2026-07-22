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
  vector_float3 normal VERTEX_ATTR(1);
};

struct CameraUniforms {
  matrix_float4x4 projection;
  matrix_float4x4 view;
  vector_float3 position;
};

struct SceneUniforms {
  vector_float3 lightDirection;
  vector_float3 lightColor;

  float diffuseStrength;
  float ambientStrength;
};

struct InstanceUniforms {
  matrix_float4x4 model;
  matrix_float3x3 normal;
  vector_float3 color;
  float shininess;

  int skipLight;
};

#endif
