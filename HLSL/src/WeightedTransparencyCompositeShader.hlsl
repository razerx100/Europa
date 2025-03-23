struct RenderTargetData
{
    uint accumulationRTIndex;
    uint revealageRTIndex;
};

Texture2D g_textures[]                            : register(t1, space1);
ConstantBuffer<RenderTargetData> renderTargetData : register(b3, space2);

#define EPSILON 0.00001

bool isApproximatelyEqual(float a, float b)
{
    return abs(a - b) <= max(abs(a), abs(b)) * EPSILON;
}

float maxComponent(float3 value)
{
    return max(max(value.x, value.y), value.z);
}

float4 main(
    float3 worldPixelPosition : WorldPosition,
    float3 worldNormal        : WorldNormal,
    float2 uv                 : UV,
    uint   modelIndex         : ModelIndex,
    uint   materialIndex      : MaterialIndex,
    float4 position           : SV_Position
) : SV_Target {
    // The last argument should be the mip level.
    int3 coordinates = int3(int2(position.xy), 1);

    // The coordinates aren't normalised yet, so can't use sample.
    float revealage  = g_textures[renderTargetData.revealageRTIndex].Load(coordinates).r;

    // No need to process opaque pixels.
    if (isApproximatelyEqual(revealage, 1.0))
        discard;

    float4 accumulation = g_textures[renderTargetData.accumulationRTIndex].Load(coordinates);

    // Suppress overflow.
    if (isinf(maxComponent(abs(accumulation.rgb))))
        accumulation.rgb = float3(accumulation.a, accumulation.a, accumulation.a);

    float3 averageColour = accumulation.rgb / max(accumulation.a, EPSILON);

    return float4(averageColour, 1.0 - revealage);
}

