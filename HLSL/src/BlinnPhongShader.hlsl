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
    float4 location;
    float4 ambient;
    float4 diffuse;
    float4 specular;
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

    float4 ambientColour  = float4(0.0, 0.0, 0.0, 0.0);
    float4 specularColour = float4(0.0, 0.0, 0.0, 0.0);
    float4 diffuseColour  = diffuseTexColour;

    // For now gonna do a check and only use the first light if available
    if (lightCount.count != 0)
    {
        LightInfo light = lightInfo[0];

        // Ambient
        ambientColour = light.ambient * diffuseTexColour * material.ambient;

        // Diffuse
        float3 lightDirection = normalize(light.location.xyz - worldPixelPosition);

        float diffuseStrength = saturate(dot(lightDirection.xyz, worldNormal));

        diffuseColour         = diffuseStrength * light.diffuse * diffuseTexColour * material.diffuse;

        // Specular
        float3 viewDirection   = normalize(cameraData.viewPosition.xyz - worldPixelPosition);

        float3 halfwayVec      = normalize(viewDirection + lightDirection);

        float specularStrength = pow(saturate(dot(halfwayVec, worldNormal)), material.shininess);

        specularColour = specularStrength * light.specular * specularTexColour * material.specular;
    }

    return diffuseColour + ambientColour + specularColour;
}
