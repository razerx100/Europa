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

struct UVInfo
{
    vec2 offset;
    vec2 scale;
};

struct ModelTexture
{
	UVInfo diffuseTexUVInfo;
	UVInfo specularTexUVInfo;
	uint   diffuseTexIndex;
	uint   specularTexIndex;
	float  padding[2];
};

struct FragmentOut
{
    vec4  accumulation;
    float revealage;
};

layout(location = 0) out vec4 outAccumulation;
layout(location = 1) out float outRevealage;

layout(set = 1, binding = 0) readonly buffer ModelTextureData
{
	ModelTexture textureData[];
} modelTextureData;

layout(set = 1, binding = 1) uniform sampler2D g_textures[];

vec4 CalculateOutputColour()
{
    ModelTexture textureInfo = modelTextureData.textureData[vIn.modelIndex];
    UVInfo diffuseUVInfo     = textureInfo.diffuseTexUVInfo;

    vec2 offsetDiffuseUV     = vIn.uv * diffuseUVInfo.scale + diffuseUVInfo.offset;

    return texture(g_textures[textureInfo.diffuseTexIndex], offsetDiffuseUV);
}

FragmentOut CalculateWeight(vec4 outputColour, float depthPosition)
{
    // The general-purpose equation from the paper.
    float a = min(1.0, outputColour.a * 10.0) + 0.01;
    float b = 1.0 - depthPosition * 0.9;

    float w = clamp(pow(a, 3.0) * 1e8 * pow(b, 3.0), 1e-2, 3e3);

    FragmentOut fragmentOut;

    fragmentOut.accumulation = outputColour * w;
    fragmentOut.revealage    = outputColour.a;

    return fragmentOut;
}

void main()
{
    vec4 outColour = CalculateOutputColour();

    FragmentOut fragmentOut = CalculateWeight(outColour, gl_FragCoord.z);

    outAccumulation = fragmentOut.accumulation;
    outRevealage    = fragmentOut.revealage;
}
