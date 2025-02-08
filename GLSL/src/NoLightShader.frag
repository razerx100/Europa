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

layout(location = 0) out vec4 outColour;

layout(set = 1, binding = 0) readonly buffer ModelTextureData
{
	ModelTexture textureData[];
} modelTextureData;

layout(set = 1, binding = 1) uniform sampler2D g_textures[];

void main()
{
    ModelTexture textureInfo = modelTextureData.textureData[vIn.modelIndex];
    UVInfo diffuseUVInfo     = textureInfo.diffuseTexUVInfo;

    vec2 offsetDiffuseUV     = vIn.uv * diffuseUVInfo.scale + diffuseUVInfo.offset;

    outColour = texture(g_textures[textureInfo.diffuseTexIndex], offsetDiffuseUV);
}
