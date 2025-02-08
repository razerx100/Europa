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
    vec4 location;
    vec4 ambient;
    vec4 diffuse;
    vec4 specular;
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

layout(set = 1, binding = 1) uniform sampler2D g_textures[];

layout(set = 2, binding = 0) uniform LightCount
{
    uint count;
} lightCount;

layout(set = 2, binding = 1) readonly buffer LightInfoData
{
    LightInfo info[];
} lightInfo;

layout(set = 2, binding = 2) readonly buffer Materialdata
{
	Material materials[];
} materialData;

void main()
{
    Material material        = materialData.materials[vIn.materialIndex];

    ModelTexture textureInfo = modelTextureData.textureData[vIn.modelIndex];
    UVInfo diffuseUVInfo     = textureInfo.diffuseTexUVInfo;
    UVInfo specularUVInfo    = textureInfo.specularTexUVInfo;

    vec2 offsetDiffuseUV   = vIn.uv * diffuseUVInfo.scale + diffuseUVInfo.offset;

    vec4 diffuseTexColour  = texture(g_textures[textureInfo.diffuseTexIndex], offsetDiffuseUV);

    vec2 offsetSpecularUV  = vIn.uv * specularUVInfo.scale + specularUVInfo.offset;

    vec4 specularTexColour = texture(g_textures[textureInfo.specularTexIndex], offsetSpecularUV);

    vec4 ambientColour  = vec4(0.0, 0.0, 0.0, 0.0);
    vec4 specularColour = vec4(0.0, 0.0, 0.0, 0.0);
    vec4 diffuseColour  = diffuseTexColour;

    // For now gonna do a check and only use the first light if available
    if (lightCount.count != 0)
    {
        LightInfo light = lightInfo.info[0];

        // Ambient
        ambientColour = light.ambient * diffuseTexColour * material.ambient;

        // Diffuse
        vec3 lightDirection   = normalize(light.location.xyz - vIn.worldFragmentPosition);

        float diffuseStrength = max(dot(lightDirection.xyz, vIn.worldNormal), 0.0);

        diffuseColour         = diffuseStrength * light.diffuse * diffuseTexColour * material.diffuse;

        // Specular
        vec3 viewDirection     = normalize(camera.viewPosition.xyz - vIn.worldFragmentPosition);

        vec3 halfwayVec        = normalize(viewDirection + lightDirection);

        float specularStrength = pow(max(dot(halfwayVec, vIn.worldNormal), 0.0), material.shininess);

        specularColour =  specularStrength * light.specular * specularTexColour * material.specular;
    }

    outColour = diffuseColour + ambientColour + specularColour;
}
