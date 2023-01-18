struct Material {
    float4 ambient;
    float4 diffuse;
    float4 specular;
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
Texture2D g_textures[] : register(t3);
SamplerState samplerState : register(s0);

float4 main(
    float2 uv: UV, uint texIndex : TexIndex, uint modelIndex : ModelIndex
) : SV_Target {
    Material material = b_materialData[modelIndex];

    // Ambient
    float4 ambient = material.ambient;

    // Diffuse
    float4 diffuse = material.diffuse;

    // Specular
    float4 specular = material.specular;

    float4 totalColour = ambient + diffuse + specular;

    return totalColour * g_textures[texIndex].Sample(samplerState, uv);
}
