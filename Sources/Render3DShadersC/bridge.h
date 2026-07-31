#ifndef bridge_h
#define bridge_h

#include <simd/simd.h>

#ifdef __METAL_VERSION__
#define VERTEX_ATTR(x) [[attribute(x)]]
#define VERTEX_POS [[position]]
#else
#define VERTEX_ATTR(x)
#define VERTEX_POS
#endif

struct Vertex {
  vector_float3 position VERTEX_ATTR(0);
  vector_float3 normal VERTEX_ATTR(1);
  vector_float3 colorUV VERTEX_ATTR(2);
};

struct CameraUniform {
  matrix_float4x4 projection;
  matrix_float4x4 view;
  vector_float3 position;
};

struct SceneUniform {
  vector_float3 lightDirection;
  vector_float3 lightColor;

  float diffuseStrength;
  float ambientStrength;
};

struct InstanceUniform {
  matrix_float4x4 model;
  matrix_float3x3 normal;
  vector_float4 color;
  float shininess;

  int vertexColorType; // 0 - ignored, 1 - vertexColor, 2 - textureColor
};

#endif
