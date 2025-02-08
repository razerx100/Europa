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

StructuredBuffer<ModelTexture> modelTextureData : register(t0, space1);
Texture2D g_textures[]                          : register(t1, space1);

SamplerState samplerState                       : register(s0);

float4 main(
    float3 worldPixelPosition : WorldPosition,
    float3 worldNormal        : WorldNormal,
    float2 uv                 : UV,
    uint   modelIndex         : ModelIndex,
    uint   materialIndex      : MaterialIndex
) : SV_Target {
    ModelTexture textureInfo = modelTextureData[modelIndex];
    UVInfo diffuseUVInfo     = textureInfo.diffuseTexUVInfo;

    float2 offsetDiffuseUV   = uv * diffuseUVInfo.scale + diffuseUVInfo.offset;

    return g_textures[textureInfo.diffuseTexIndex].Sample(samplerState, offsetDiffuseUV);
}
