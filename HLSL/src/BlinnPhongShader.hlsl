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
    float4 ambient; // w component has innerCutoff for spotlight
    float4 diffuse;
    float4 specular; // w component has outerCutoff for spotlight
    // Attenuation co-efficient
    float  constantC;
    float  linearC;
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

float CalculateSpecularStrength(
    float3 worldPixelPosition, float3 worldNormal, float3 lightDirection, float shininess
){
    float3 viewDirection = normalize(cameraData.viewPosition.xyz - worldPixelPosition);

    float3 halfwayVec    = normalize(viewDirection + lightDirection);

    return pow(saturate(dot(halfwayVec, worldNormal)), shininess);
}

float4 CalculateDirectionalLight(
    LightInfo light, float4 diffuseTex, float4 specularTex, Material material,
    float3 worldPixelPosition, float3 worldNormal, float3 lightDirection
) {
    // Ambient
    float4 ambientColour = float4(light.ambient.xyz, 1.0) * diffuseTex * material.ambient;

    // Diffuse
    float diffuseStrength = saturate(dot(lightDirection, worldNormal));

    float4 diffuseColour  = diffuseStrength * light.diffuse * diffuseTex * material.diffuse;

    // Specular
    float specularStrength = CalculateSpecularStrength(
        worldPixelPosition, worldNormal, lightDirection, material.shininess
    );

    float4 specularColour
        = specularStrength * float4(light.specular.xyz, 1.0) * specularTex * material.specular;

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
    float4 ambientColour = float4(light.ambient.xyz, 1.0) * diffuseTex * material.ambient * attenuation;

    // Diffuse
    float3 lightDirection = normalize(ray);

    float diffuseStrength = saturate(dot(lightDirection, worldNormal));

    float4 diffuseColour
        = diffuseStrength * light.diffuse * diffuseTex * material.diffuse * attenuation;

    // Specular
    float specularStrength = CalculateSpecularStrength(
        worldPixelPosition, worldNormal, lightDirection, material.shininess
    );

    float4 specularColour
        = specularStrength * float4(light.specular.xyz, 1.0)
        * specularTex * material.specular * attenuation;

    return diffuseColour + ambientColour + specularColour;
}

float4 CalculateSpotLight(
    LightInfo light, float4 diffuseTex, float4 specularTex, Material material,
    float3 worldPixelPosition, float3 worldNormal
) {
    // 1 / kc + kl * d + kq * d * d
    float3 ray      = light.location.xyz - worldPixelPosition;
    float rayLength = length(ray);

    float attenuation = 1.0 /
        (light.constantC + light.linearC * rayLength + light.quadratic * rayLength * rayLength);

    // Ambient
    float4 ambientColour = float4(light.ambient.xyz, 1.0) * diffuseTex * material.ambient * attenuation;

    float3 lightDirection = normalize(ray);

    float theta           = dot(lightDirection, -light.direction.xyz);

    float innerCutoff     = light.ambient.w;
    float outerCutoff     = light.specular.w;

    float epsilon         = innerCutoff - outerCutoff;

    // If the pixel is inside the inner cutoff then the intensity will be 1.0. It will be
    // varied between the inner and outer cutoff and 0.0 outside.
    float intensity       = clamp((theta - outerCutoff) / epsilon, 0.0, 1.0);

    // Diffuse
    float diffuseStrength = saturate(dot(lightDirection, worldNormal));

    float4 diffuseColour
        = diffuseStrength * light.diffuse * diffuseTex * material.diffuse * attenuation * intensity;

    // Specular
    float specularStrength = CalculateSpecularStrength(
        worldPixelPosition, worldNormal, lightDirection, material.shininess
    );

    float4 specularColour
        = specularStrength * float4(light.specular.xyz, 1.0)
        * specularTex * material.specular * attenuation * intensity;

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

    float4 outputColour = float4(0.0, 0.0, 0.0, 0.0);

    for (uint index = 0; index < lightCount.count; ++index)
    {
        LightInfo light = lightInfo[index];

        if (light.type == 0)
            outputColour += CalculateDirectionalLight(
                light, diffuseTexColour, specularTexColour, material, worldPixelPosition,
                worldNormal, light.direction.xyz
            );
        else if (light.type == 1)
            outputColour += CalculatePointLight(
                light, diffuseTexColour, specularTexColour, material, worldPixelPosition, worldNormal
            );
        else if (light.type == 2)
            outputColour += CalculateSpotLight(
                light, diffuseTexColour, specularTexColour, material, worldPixelPosition, worldNormal
            );
    }

    return outputColour;
}
