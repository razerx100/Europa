#version 460
#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in VetexIn{
	vec3 viewFragmentPosition;
	vec3 normal;
	vec2 uv;
	flat uint modelIndex;
} vIn;

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

void main() {
    Material material = materialData.materials[vIn.modelIndex];
    vec2 offsettedDiffuseUV = vIn.uv * material.diffuseTexUVRatio + material.diffuseTexUVOffset;

    outColour = material.diffuse * texture(
        g_textures[material.diffuseTexIndex], offsettedDiffuseUV
    );
}