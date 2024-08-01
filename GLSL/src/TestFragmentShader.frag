#version 460
#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in VetexIn
{
	vec3 viewFragmentPosition;
	vec3 normal;
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

layout(location = 0) out vec4 outColour;

layout(binding = 1) readonly buffer ModelTextureData {
	ModelTexture textureData[];
} modelTextureData;

layout(binding = 3) readonly buffer Materialdata {
	Material materials[];
} materialData;

layout(binding = 4) uniform sampler2D g_textures[];

void main()
{
    vec4 diffuse      = vec4(1.0, 1.0, 1.0, 1.0);

    if(materialData.materials.length() > vIn.materialIndex)
    {
        Material material = materialData.materials[vIn.materialIndex];
        diffuse           = material.diffuse;
    }

    ModelTexture textureInfo = modelTextureData.textureData[vIn.modelIndex];
    UVInfo modelUVInfo       = textureInfo.diffuseTexUVInfo;

    vec2 offsettedDiffuseUV = vIn.uv * modelUVInfo.scale + modelUVInfo.offset;

    outColour = diffuse * texture(
        g_textures[textureInfo.diffuseTexIndex], offsettedDiffuseUV
    );
}
