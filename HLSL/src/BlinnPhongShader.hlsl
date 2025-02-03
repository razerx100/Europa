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
    float4 lightColour;
    float  ambientStrength;
    float  padding[3];
};

struct LightCount
{
    uint count;
};

StructuredBuffer<ModelTexture> modelTextureData : register(t0, space1);
StructuredBuffer<Material>     materialData     : register(t1, space1);
Texture2D g_textures[]                          : register(t2, space1);

SamplerState samplerState                       : register(s0);

ConstantBuffer<CameraMatrices> cameraData       : register(b1);

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

    float4 ambientColour = float4(1.0, 1.0, 1.0, 1.0);
    // For now gonna do a check and only use the first light if available
    if (lightCount.count != 0)
    {
        LightInfo info = lightInfo[0];

        ambientColour  = info.ambientStrength * info.lightColour;
    }

    float2 offsetDiffuseUV = uv * modelUVInfo.scale + modelUVInfo.offset;

    return diffuse * ambientColour * g_textures[textureInfo.diffuseTexIndex].Sample(
        samplerState, offsetDiffuseUV
    );
}
