#version 460
#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in vec2 inUV;
flat layout(location = 1) in uint inModelIndex;
layout(location = 2) in vec3 inViewFragmentPosition;
layout(location = 3) in vec3 inNormal;

layout(location = 0) out vec4 outColour;

struct Material {
    vec4 ambient;
    vec4 diffuse;
    vec4 specular;
    vec2 diffuseTexUVOffset;
    vec2 diffuseTexUVRatio;
    vec2 specularTexUVOffset;
    vec2 specularTexUVRatio;
    uint diffuseTexIndex;
    uint specularTexIndex;
    float shininess;
};

struct Light {
    vec3 position;
    vec4 ambient;
    vec4 diffuse;
    vec4 specular;
};

layout(binding = 2) uniform sampler2D g_textures[];

layout(binding = 3) readonly buffer Materialdata {
	Material materials[];
} materialData;

layout(binding = 4) readonly buffer Lightdata {
	Light lights[];
} lightData;

layout(binding = 5) uniform FragmentData {
    uint lightCount;
} fragmentData;

vec4 CalculateAmbient(vec4 lightAmbient, vec4 fragmentAmbient) {
    return lightAmbient * fragmentAmbient;
}

vec4 CalculateDiffuse(
    vec3 lightDirection, vec3 normal, vec4 lightDiffuse, vec4 fragmentDiffuse
) {
    float diffuseStrength = max(dot(normal, lightDirection), 0.0);

    return lightDiffuse * (diffuseStrength * fragmentDiffuse);
}

vec4 CalculateSpecular(
    vec3 lightDirection, vec3 normal, vec4 lightSpecular, vec4 fragmentSpecular,
    float shininess
) {
    vec3 viewPosition = vec3(0.0);
    vec3 viewDirection = normalize(viewPosition - inViewFragmentPosition);
    vec3 reflectionDirection = reflect(-lightDirection, normal);
    float speculationStrength = pow(
                                    max(dot(viewDirection, reflectionDirection), 0.0), shininess
                                );

    return lightSpecular * (speculationStrength * fragmentSpecular);
}

void main() {
    Material material = materialData.materials[inModelIndex];
    vec2 offsettedDiffuseUV = inUV * material.diffuseTexUVRatio + material.diffuseTexUVOffset;
    vec2 offsettedSpecularUV = inUV * material.specularTexUVRatio + material.specularTexUVOffset;

    vec4 diffuseTexColour = texture(g_textures[material.diffuseTexIndex], offsettedDiffuseUV);
    vec4 specularTexColour = texture(g_textures[material.diffuseTexIndex], offsettedSpecularUV);

    vec4 fragmentAmbient = material.ambient * diffuseTexColour;
    vec4 fragmentDiffuse = material.diffuse * diffuseTexColour;
    vec4 fragmentSpecular = material.specular * specularTexColour;

    vec4 totalAmbient = vec4(0.0);
    vec4 totalDiffuse = vec4(0.0);
    vec4 totalSpecular = vec4(0.0);

    for(uint index = 0; index < fragmentData.lightCount; ++index){
        Light currentLight = lightData.lights[index];

        totalAmbient += CalculateAmbient(currentLight.ambient, fragmentAmbient);

        vec3 lightDirection = normalize(currentLight.position - inViewFragmentPosition);
        vec3 normal = normalize(inNormal);

        totalDiffuse += CalculateDiffuse(
                            lightDirection, normal, currentLight.diffuse, fragmentDiffuse
                        );

        totalSpecular += CalculateSpecular(
                            lightDirection, normal, currentLight.specular, fragmentSpecular,
                            material.shininess
                        );
    }

    outColour = totalAmbient + totalDiffuse + totalSpecular;
}
