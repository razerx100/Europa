struct Material {
    float4 ambient;
    float4 diffuse;
    float4 specular;
    float shininess;
    float3 padding;
};

struct Light {
    float3 position;
    float4 ambient;
    float4 diffuse;
    float4 specular;
    float padding;
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
    float4 diffuse = material.diffuse;

    return diffuse * g_textures[texIndex].Sample(samplerState, uv);
}