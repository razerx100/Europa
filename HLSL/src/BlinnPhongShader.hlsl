struct Frustum
{
	float4 left;
	float4 right;
	float4 bottom;
	float4 top;
	float4 near;
	float4 far;
};

struct CameraMatrices
{
    matrix  view;
    matrix  projection;
    Frustum frustum;
    float4  viewPosition;
};

struct Material
{
    float4 ambient;
    float4 diffuse;
    float4 specular;
    float  shininess;
    float  padding[3];
};

struct UVInfo
{
    float2 offset;
    float2 scale;
};

struct ModelTexture
{
	UVInfo diffuseTexUVInfo;
	UVInfo specularTexUVInfo;
	uint   diffuseTexIndex;
	uint   specularTexIndex;
	float  padding[2];
};

struct LightInfo
{
    float4 location; // Used for point and spotlight.
    float4 direction; // Used for directional and spotlight.
    float4 ambient;
    float4 diffuse;
    float4 specular;
    // Attenuation co-efficient
    float  constantC; // Inner Cutoff if Spotlight
    float  linearC; // Outer Cutoff if Spotlight
    float  quadratic;
    uint   type; // 0 for Directional, 1 Point, 1 Spotlight
};

struct LightCount
{
    uint count;
};

StructuredBuffer<ModelTexture> modelTextureData : register(t0, space1);
Texture2D g_textures[]                          : register(t1, space1);

SamplerState samplerState                       : register(s0);

ConstantBuffer<CameraMatrices> cameraData       : register(b1);

ConstantBuffer<LightCount> lightCount           : register(b0, space2);
StructuredBuffer<LightInfo> lightInfo           : register(t1, space2);
StructuredBuffer<Material> materialData         : register(t2, space2);

float4 CalculateDirectionalLight(
    LightInfo light, float4 diffuseTex, float4 specularTex, Material material,
    float3 worldPixelPosition, float3 worldNormal, float3 lightDirection
) {
    // Ambient
    float4 ambientColour   = light.ambient * diffuseTex * material.ambient;

    // Diffuse
    float diffuseStrength  = saturate(dot(lightDirection, worldNormal));

    float4 diffuseColour   = diffuseStrength * light.diffuse * diffuseTex * material.diffuse;

    // Specular
    float3 viewDirection   = normalize(cameraData.viewPosition.xyz - worldPixelPosition);

    float3 halfwayVec      = normalize(viewDirection + lightDirection);

    float specularStrength = pow(saturate(dot(halfwayVec, worldNormal)), material.shininess);

    float4 specularColour  = specularStrength * light.specular * specularTex * material.specular;

    return diffuseColour + ambientColour + specularColour;
}

float4 CalculatePointLight(
    LightInfo light, float4 diffuseTex, float4 specularTex, Material material,
    float3 worldPixelPosition, float3 worldNormal
) {
    // 1 / kc + kl * d + kq * d * d
    float3 ray      = light.location.xyz - worldPixelPosition;
    float rayLength = length(ray);

    float attenuation = 1.0 /
        (light.constantC + light.linearC * rayLength + light.quadratic * rayLength * rayLength);

    // Ambient
    float4 ambientColour = light.ambient * diffuseTex * material.ambient * attenuation;

    // Diffuse
    float3 lightDirection = normalize(ray);

    float diffuseStrength = saturate(dot(lightDirection, worldNormal));

    float4 diffuseColour
        = diffuseStrength * light.diffuse * diffuseTex * material.diffuse * attenuation;

    // Specular
    float3 viewDirection   = normalize(cameraData.viewPosition.xyz - worldPixelPosition);

    float3 halfwayVec      = normalize(viewDirection + lightDirection);

    float specularStrength = pow(saturate(dot(halfwayVec, worldNormal)), material.shininess);

    float4 specularColour
        = specularStrength * light.specular * specularTex * material.specular * attenuation;

    return diffuseColour + ambientColour + specularColour;
}

float4 CalculateSpotLight(
    LightInfo light, float4 diffuseTex, float4 specularTex, Material material,
    float3 worldPixelPosition, float3 worldNormal
) {
    // Ambient
    float4 ambientColour   = light.ambient * diffuseTex * material.ambient;

    // Diffuse
    float3 lightDirection  = normalize(light.location.xyz - worldPixelPosition);
    float diffuseStrength  = saturate(dot(lightDirection, worldNormal));

    float4 diffuseColour   = diffuseStrength * light.diffuse * diffuseTex * material.diffuse;

    // Specular
    float3 viewDirection   = normalize(cameraData.viewPosition.xyz - worldPixelPosition);

    float3 halfwayVec      = normalize(viewDirection + lightDirection);

    float specularStrength = pow(saturate(dot(halfwayVec, worldNormal)), material.shininess);

    float4 specularColour  = specularStrength * light.specular * specularTex * material.specular;

    return diffuseColour + ambientColour + specularColour;
}

float4 main(
    float3 worldPixelPosition : WorldPosition,
    float3 worldNormal        : WorldNormal,
    float2 uv                 : UV,
    uint   modelIndex         : ModelIndex,
    uint   materialIndex      : MaterialIndex
) : SV_Target {
    Material material        = materialData[materialIndex];

    ModelTexture textureInfo = modelTextureData[modelIndex];
    UVInfo diffuseUVInfo     = textureInfo.diffuseTexUVInfo;
    UVInfo specularUVInfo    = textureInfo.specularTexUVInfo;

    float2 offsetDiffuseUV   = uv * diffuseUVInfo.scale + diffuseUVInfo.offset;

    float4 diffuseTexColour  = g_textures[textureInfo.diffuseTexIndex].Sample(
        samplerState, offsetDiffuseUV
    );

    float2 offsetSpecularUV  = uv * specularUVInfo.scale + specularUVInfo.offset;

    float4 specularTexColour = g_textures[textureInfo.specularTexIndex].Sample(
        samplerState, offsetSpecularUV
    );

    float4 outputColour = float4(1.0, 1.0, 1.0, 1.0);

    // For now gonna do a check and only use the first light if available
    if (lightCount.count != 0)
    {
        LightInfo light = lightInfo[0];

        if (light.type == 0)
            outputColour = CalculateDirectionalLight(
                light, diffuseTexColour, specularTexColour, material, worldPixelPosition,
                worldNormal, light.direction.xyz
            );
        else if (light.type == 1)
            outputColour = CalculatePointLight(
                light, diffuseTexColour, specularTexColour, material, worldPixelPosition, worldNormal
            );
        else if (light.type == 2)
            outputColour = CalculateSpotLight(
                light, diffuseTexColour, specularTexColour, material, worldPixelPosition, worldNormal
            );
    }

    return outputColour;
}
