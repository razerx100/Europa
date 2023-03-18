struct Material {
    float4 ambient;
    float4 diffuse;
    float4 specular;
    float2 diffuseTexUVOffset;
    float2 diffuseTexUVRatio;
    float2 specularTexUVOffset;
    float2 specularTexUVRatio;
    uint diffuseTexIndex;
    uint specularTexIndex;
    float shininess;
};

struct Light {
    float3 position;
    float4 ambient;
    float4 diffuse;
    float4 specular;
};

struct PixelData {
    uint lightCount;
};

StructuredBuffer<Material> b_materialData : register(t1);
StructuredBuffer<Light> b_lightData : register(t2);
ConstantBuffer<PixelData> b_pixelData : register(b2);
Texture2D g_textures[] : register(t0, space1);
SamplerState samplerState : register(s0);
