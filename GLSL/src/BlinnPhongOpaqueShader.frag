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
    vec4  location; // Used for point and spotlight.
    vec4  direction; // Used for directional and spotlight.
    vec4  ambient; // w component has innerCutoff for spotlight
    vec4  diffuse;
    vec4  specular; // w component has outerCutoff for spotlight
    // Attenuation co-efficient
    float constantC;
    float linearC;
    float quadratic;
    uint  type; // 0 for Directional, 1 Point, 1 Spotlight
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

float CalculateSpecularStrength(
    vec3 worldFragmentPosition, vec3 worldNormal, vec3 lightDirection, float shininess
){
    vec3 viewDirection = normalize(camera.viewPosition.xyz - worldFragmentPosition);

    vec3 halfwayVec    = normalize(viewDirection + lightDirection);

    return pow(max(dot(halfwayVec, worldNormal), 0.0), shininess);
}

vec4 CalculateDirectionalLight(
    LightInfo light, vec4 diffuseTex, vec4 specularTex, Material material,
    vec3 worldFragmentPosition, vec3 worldNormal, vec3 lightDirection
) {
    // Ambient
    vec4 ambientColour = vec4(light.ambient.xyz, 1.0) * diffuseTex * material.ambient;

    // Diffuse
    float diffuseStrength = max(dot(lightDirection, worldNormal), 0.0);

    vec4 diffuseColour    = diffuseStrength * light.diffuse * diffuseTex * material.diffuse;

    // Specular
    float specularStrength = CalculateSpecularStrength(
        worldFragmentPosition, worldNormal, lightDirection, material.shininess
    );

    vec4 specularColour
        = specularStrength * vec4(light.specular.xyz, 1.0) * specularTex * material.specular;

    return diffuseColour + ambientColour + specularColour;
}

vec4 CalculatePointLight(
    LightInfo light, vec4 diffuseTex, vec4 specularTex, Material material,
    vec3 worldFragmentPosition, vec3 worldNormal
) {
    // 1 / kc + kl * d + kq * d * d
    vec3 ray        = light.location.xyz - worldFragmentPosition;
    float rayLength = length(ray);

    float attenuation = 1.0 /
        (light.constantC + light.linearC * rayLength + light.quadratic * rayLength * rayLength);

    // Ambient
    vec4 ambientColour = vec4(light.ambient.xyz, 1.0) * diffuseTex * material.ambient * attenuation;

    // Diffuse
    vec3 lightDirection   = normalize(ray);

    float diffuseStrength = max(dot(lightDirection, worldNormal), 0.0);

    vec4 diffuseColour = diffuseStrength * light.diffuse * diffuseTex * material.diffuse * attenuation;

    // Specular
    float specularStrength = CalculateSpecularStrength(
        worldFragmentPosition, worldNormal, lightDirection, material.shininess
    );

    vec4 specularColour =
        specularStrength * vec4(light.specular.xyz, 1.0) * specularTex * material.specular * attenuation;

    return diffuseColour + ambientColour + specularColour;
}

vec4 CalculateSpotLight(
    LightInfo light, vec4 diffuseTex, vec4 specularTex, Material material,
    vec3 worldFragmentPosition, vec3 worldNormal
) {
    // 1 / kc + kl * d + kq * d * d
    vec3 ray        = light.location.xyz - worldFragmentPosition;
    float rayLength = length(ray);

    float attenuation = 1.0 /
        (light.constantC + light.linearC * rayLength + light.quadratic * rayLength * rayLength);

    // Ambient
    vec4 ambientColour = vec4(light.ambient.xyz, 1.0) * diffuseTex * material.ambient * attenuation;

    // Diffuse
    vec3 lightDirection    = normalize(ray);

    float theta            = dot(lightDirection, -light.direction.xyz);

    float innerCutoff      = light.ambient.w;
    float outerCutoff      = light.specular.w;

    float epsilon          = innerCutoff - outerCutoff;

    // If the fragment is inside the inner cutoff then the intensity will be 1.0. It will be
    // varied between the inner and outer cutoff and 0.0 outside.
    float intensity        = clamp((theta - outerCutoff) / epsilon, 0.0, 1.0);

    float diffuseStrength  = max(dot(lightDirection, worldNormal), 0.0);

    vec4 diffuseColour
        = diffuseStrength * light.diffuse * diffuseTex * material.diffuse * attenuation * intensity;

    // Specular
    float specularStrength = CalculateSpecularStrength(
        worldFragmentPosition, worldNormal, lightDirection, material.shininess
    );

    vec4 specularColour
        = specularStrength * vec4(light.specular.xyz, 1.0)
        * specularTex * material.specular * attenuation * intensity;

    return diffuseColour + ambientColour + specularColour;
}

vec4 CalculateOutputColour()
{
    Material material        = materialData.materials[vIn.materialIndex];

    ModelTexture textureInfo = modelTextureData.textureData[vIn.modelIndex];
    UVInfo diffuseUVInfo     = textureInfo.diffuseTexUVInfo;
    UVInfo specularUVInfo    = textureInfo.specularTexUVInfo;

    vec2 offsetDiffuseUV   = vIn.uv * diffuseUVInfo.scale + diffuseUVInfo.offset;

    vec4 diffuseTexColour  = texture(g_textures[textureInfo.diffuseTexIndex], offsetDiffuseUV);

    vec2 offsetSpecularUV  = vIn.uv * specularUVInfo.scale + specularUVInfo.offset;

    vec4 specularTexColour = texture(g_textures[textureInfo.specularTexIndex], offsetSpecularUV);

    vec4 outputColour = vec4(0.0, 0.0, 0.0, 0.0);

    for (uint index = 0; index < lightCount.count; ++index)
    {
        LightInfo light = lightInfo.info[index];

        if (light.type == 0)
            outputColour += CalculateDirectionalLight(
                light, diffuseTexColour, specularTexColour, material, vIn.worldFragmentPosition,
                vIn.worldNormal, light.direction.xyz
            );
        else if (light.type == 1)
            outputColour += CalculatePointLight(
                light, diffuseTexColour, specularTexColour, material, vIn.worldFragmentPosition,
                vIn.worldNormal
            );
        else if (light.type == 2)
            outputColour += CalculateSpotLight(
                light, diffuseTexColour, specularTexColour, material, vIn.worldFragmentPosition,
                vIn.worldNormal
            );
    }

    return outputColour;
}

void main()
{
    outColour = CalculateOutputColour();
}
