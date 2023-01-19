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

float4 CalculateAmbient(float4 lightAmbient, float4 pixelAmbient) {
    return lightAmbient * pixelAmbient;
}

float4 CalculateDiffuse(
    float3 lightDirection, float3 normal, float4 lightDiffuse, float4 pixelDiffuse
) {
    float diffuseStrength = max(dot(normal, lightDirection), 0.0);

    return lightDiffuse * (diffuseStrength * pixelDiffuse);
}

float4 CalculateSpecular(
    float3 lightDirection, float3 normal, float3 viewPixelPosition, float4 lightSpecular,
    float4 pixelSpecular, float shininess
) {
    float3 viewPosition = float3(0.0, 0.0, 0.0);
    float3 viewDirection = normalize(viewPosition - viewPixelPosition);
    float3 reflectionDirection = reflect(-lightDirection, normal);
    float specularStrength = pow(
                                max(dot(viewDirection, reflectionDirection), 0.0), shininess
                            );

    return lightSpecular * (specularStrength * pixelSpecular);
}

float4 main(
    float2 uv: UV, uint texIndex : TexIndex, uint modelIndex : ModelIndex,
    float3 viewPixelPosition : ViewPosition, float3 normal : Normal
) : SV_Target {
    Material material = b_materialData[modelIndex];
    float4 textureColour = g_textures[texIndex].Sample(samplerState, uv);

    float4 pixelAmbient = material.ambient * textureColour;
    float4 pixelDiffuse = material.diffuse * textureColour;
    float4 pixelSpecular = material.specular;

    float4 totalAmbient = float4(0.0, 0.0, 0.0, 0.0);
    float4 totalDiffuse = float4(0.0, 0.0, 0.0, 0.0);
    float4 totalSpecular = float4(0.0, 0.0, 0.0, 0.0);

    for (uint index = 0; index < b_pixelData.lightCount; ++index) {
        Light currentLight = b_lightData[index];

        totalAmbient += CalculateAmbient(currentLight.ambient, pixelAmbient);

        float3 lightDirection = normalize(currentLight.position - viewPixelPosition);
        float3 nNormal = normalize(normal);

        totalDiffuse += CalculateDiffuse(
                            lightDirection, nNormal, currentLight.diffuse, pixelDiffuse
                        );

        totalSpecular += CalculateSpecular(
                            lightDirection, nNormal, viewPixelPosition, currentLight.specular,
                            pixelSpecular, material.shininess
                        );
    }

    return totalAmbient + totalDiffuse + totalSpecular;
}
