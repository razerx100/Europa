#version 460
#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in VetexIn
{
    vec3 worldFragmentPosition;
    vec3 worldNormal;
    vec2 uv;
    flat uint modelIndex;
    flat uint materialIndex;
} vIn;

layout(location = 0) out vec4 outColour;

layout(set = 1, binding = 1) uniform sampler2D g_textures[];

layout(set = 2, binding = 3) uniform RenderTargetData
{
    uint accumulationRTIndex;
    uint revealageRTIndex;
} renderTargetData;

const float EPSILON = 0.00001;

bool isApproximatelyEqual(float a, float b)
{
    return abs(a - b) <= max(abs(a), abs(b)) * EPSILON;
}

float maxComponent(vec3 value)
{
    return max(max(value.x, value.y), value.z);
}

void main()
{
    ivec2 coordinates = ivec2(gl_FragCoord.xy);

    // The coordinates aren't normalised yet, so can't use sample.
    float revealage  = texelFetch(g_textures[renderTargetData.revealageRTIndex], coordinates, 0).r;

    // No need to process opaque pixels.
    if (isApproximatelyEqual(revealage, 1.0))
        discard;

    vec4 accumulation = texelFetch(g_textures[renderTargetData.accumulationRTIndex], coordinates, 0);

    // Suppress overflow.
    if (isinf(maxComponent(abs(accumulation.rgb))))
        accumulation.rgb = vec3(accumulation.a, accumulation.a, accumulation.a);

    vec3 averageColour = accumulation.rgb / max(accumulation.a, EPSILON);

    outColour = vec4(averageColour, 1.0 - revealage);
}

