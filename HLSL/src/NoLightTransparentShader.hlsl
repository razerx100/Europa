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

struct PixelOut
{
    float4 accumulation : SV_Target0;
    float revealage     : SV_Target1;
};

StructuredBuffer<ModelTexture> modelTextureData : register(t0, space1);
Texture2D g_textures[]                          : register(t1, space1);

SamplerState samplerState                       : register(s0);

float4 CalculateOutputColour(
    float3 worldPixelPosition, float3 worldNormal, float2 uv, uint modelIndex, uint materialIndex
) {
    ModelTexture textureInfo = modelTextureData[modelIndex];
    UVInfo diffuseUVInfo     = textureInfo.diffuseTexUVInfo;

    float2 offsetDiffuseUV   = uv * diffuseUVInfo.scale + diffuseUVInfo.offset;

    return g_textures[textureInfo.diffuseTexIndex].Sample(samplerState, offsetDiffuseUV);
}

PixelOut CalculateWeight(float4 outputColour, float depthPosition)
{
    // The general-purpose equation from the paper.
    float a = min(1.0, outputColour.a * 10.0) + 0.01;
    float b = 1.0 - depthPosition * 0.9;

    float w = clamp(pow(a, 3.0) * 1e8 * pow(b, 3.0), 1e-2, 3e3);

    PixelOut pixelOut;

    pixelOut.accumulation = outputColour * w;
    pixelOut.revealage    = outputColour.a;

    return pixelOut;
}

PixelOut main(
    float3 worldPixelPosition : WorldPosition,
    float3 worldNormal        : WorldNormal,
    float2 uv                 : UV,
    uint   modelIndex         : ModelIndex,
    uint   materialIndex      : MaterialIndex,
    float4 position           : SV_Position
) {
    float4 outputColour = CalculateOutputColour(
        worldPixelPosition, worldNormal, uv, modelIndex, materialIndex
    );

    return CalculateWeight(outputColour, position.z);
}
