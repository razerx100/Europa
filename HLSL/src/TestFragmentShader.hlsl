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

StructuredBuffer<ModelTexture> modelTextureData : register(t0, space1);
StructuredBuffer<Material>     materialData     : register(t1, space1);
Texture2D g_textures[]                          : register(t2, space1);
SamplerState samplerState                       : register(s0);

float4 main(
    float3 viewVertexPosition : ViewPosition,
    float3 normal             : Normal,
    float2 uv                 : UV,
    uint   modelIndex         : ModelIndex,
    uint   materialIndex      : MaterialIndex
) : SV_Target {
    float4 diffuse    = float4(1.0, 1.0, 1.0, 1.0);

    Material material = materialData[materialIndex];
    diffuse           = material.diffuse;

    ModelTexture textureInfo  = modelTextureData[modelIndex];
    UVInfo modelUVInfo        = textureInfo.diffuseTexUVInfo;

    float2 offsettedDiffuseUV = uv * modelUVInfo.scale + modelUVInfo.offset;

    return diffuse * g_textures[textureInfo.diffuseTexIndex].Sample(
        samplerState, offsettedDiffuseUV
    );
}
