struct Material {
    float3 ambient;
    float3 diffuse;
    float3 specular;
    float shininess;
};

struct Light {
    float3 position;
    float3 ambient;
    float3 diffuse;
    float3 specular;
};

struct FragmentData {
    uint lightCount;
};

StructuredBuffer<Material> b_materialData : register(t1);
StructuredBuffer<Light> b_lightData : register(t2);
ConstantBuffer<FragmentData> fragmentData : register(b2);
Texture2D g_textures[] : register(t3);
SamplerState samplerState : register(s0);

float4 main(
    float2 uv: UV, uint texIndex : TexIndex, uint modelIndex : ModelIndex
) : SV_Target {
    Material material = b_materialData[modelIndex];

    // Diffuse
    float3 diffuse = material.diffuse;

    return float4(diffuse, 1.0) * g_textures[texIndex].Sample(samplerState, uv);
}