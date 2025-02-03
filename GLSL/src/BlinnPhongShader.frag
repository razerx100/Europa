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

struct Frustum
{
	vec4 left;
	vec4 right;
	vec4 bottom;
	vec4 top;
	vec4 near;
	vec4 far;
};

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
    vec4  location;
    vec4  lightColour;
    float ambientStrength;
    float padding[3];

};

layout(location = 0) out vec4 outColour;

layout(binding = 1) uniform CameraMatrices
{
	mat4    view;
	mat4    projection;
	Frustum frustum;
	vec4    viewPosition;
} camera;

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

    vec4 ambientLightColour = vec4(0.0, 0.0, 0.0, 0.0);
    vec4 diffuseLightColour = vec4(1.0, 1.0, 1.0, 1.0);

    // For now gonna do a check and only use the first light if available
    if (lightCount.count != 0)
    {
        LightInfo info        = lightInfo.info[0];

        ambientLightColour    = info.ambientStrength * info.lightColour;

        vec3 lightDirection   = normalize(info.location.xyz - vIn.worldFragmentPosition);

        float diffuseStrength = max(dot(lightDirection.xyz, vIn.worldNormal), 0.0);

        diffuseLightColour    = diffuseStrength * info.lightColour;
    }

    vec2 offsetDiffuseUV = vIn.uv * modelUVInfo.scale + modelUVInfo.offset;

    outColour = diffuse * (ambientLightColour + diffuseLightColour) * texture(
        g_textures[textureInfo.diffuseTexIndex], offsetDiffuseUV
    );
}
