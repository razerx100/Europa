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

struct Material
{
    vec4  ambient;
    vec4  diffuse;
    vec4  specular;
    float shininess;
    float padding[3];
};

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

struct LightInfo
{
    vec4 location;
    vec4 lightColour;
};

layout(location = 0) out vec4 outColour;

layout(set = 1, binding = 0) readonly buffer ModelTextureData
{
	ModelTexture textureData[];
} modelTextureData;

layout(set = 1, binding = 1) readonly buffer Materialdata
{
	Material materials[];
} materialData;

layout(set = 1, binding = 2) uniform sampler2D g_textures[];

layout(set = 2, binding = 0) uniform LightCount
{
    uint count;
} lightCount;

layout(set = 2, binding = 1) readonly buffer LightInfoData
{
    LightInfo info[];
} lightInfo;

void main()
{
    vec4 diffuse      = vec4(1.0, 1.0, 1.0, 1.0);

    Material material = materialData.materials[vIn.materialIndex];
    diffuse           = material.diffuse;

    ModelTexture textureInfo = modelTextureData.textureData[vIn.modelIndex];
    UVInfo modelUVInfo       = textureInfo.diffuseTexUVInfo;

    vec4 lightColour = vec4(1.0, 1.0, 1.0, 1.0);
    // For now gonna do a check and only use the first light if available
    if (lightCount.count != 0)
        lightColour = lightInfo.info[0].lightColour;

    vec2 offsetDiffuseUV = vIn.uv * modelUVInfo.scale + modelUVInfo.offset;

    outColour = diffuse * lightColour * texture(
        g_textures[textureInfo.diffuseTexIndex], offsetDiffuseUV
    );
}
