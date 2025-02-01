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
    float4 lightColour;
};

struct LightCount
{
    uint count;
};

StructuredBuffer<ModelTexture> modelTextureData : register(t0, space1);
StructuredBuffer<Material>     materialData     : register(t1, space1);
Texture2D g_textures[]                          : register(t2, space1);

SamplerState samplerState                       : register(s0);

ConstantBuffer<LightCount> lightCount           : register(b0, space2);
StructuredBuffer<LightInfo> lightInfo           : register(t1, space2);

float4 main(
    float3 worldPixelPosition : WorldPosition,
    float3 worldNormal        : WorldNormal,
    float2 uv                 : UV,
    uint   modelIndex         : ModelIndex,
    uint   materialIndex      : MaterialIndex
) : SV_Target {
    float4 diffuse    = float4(1.0, 1.0, 1.0, 1.0);

    Material material = materialData[materialIndex];
    diffuse           = material.diffuse;

    ModelTexture textureInfo  = modelTextureData[modelIndex];
    UVInfo modelUVInfo        = textureInfo.diffuseTexUVInfo;

    float4 lightColour = float4(1.0, 1.0, 1.0, 1.0);
    // For now gonna do a check and only use the first light if available
    if (lightCount.count != 0)
        lightColour = lightInfo[0].lightColour;

    float2 offsetDiffuseUV = uv * modelUVInfo.scale + modelUVInfo.offset;

    return diffuse * lightColour * g_textures[textureInfo.diffuseTexIndex].Sample(
        samplerState, offsetDiffuseUV
    );
}
