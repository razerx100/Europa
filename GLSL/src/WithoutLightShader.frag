#version 460
#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in vec2 inUV;
flat layout(location = 1) in uint inTexIndex;
flat layout(location = 2) in uint inModelIndex;

layout(location = 0) out vec4 outColour;

struct Material {
    vec4 ambient;
    vec4 diffuse;
    vec4 specular;
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
    Material material = materialData.materials[inModelIndex];

    // Diffuse
    vec4 diffuse = material.diffuse;

    outColour = diffuse * texture(g_textures[inTexIndex], inUV);
}