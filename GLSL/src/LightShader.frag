#version 460
#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in vec2 inUV;
flat layout(location = 1) in uint inTexIndex;
flat layout(location = 2) in uint inModelIndex;

layout(location = 0) out vec4 outColour;

struct Material {
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    float shininess;
};

struct Light {
    vec3 position;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
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

    // Ambient
    vec3 ambient = material.ambient;

    // Diffuse
    vec3 diffuse = material.diffuse;

    // Specular
    vec3 specular = material.specular;

    vec3 totalColour = ambient + diffuse + specular;

    outColour = vec4(totalColour, 1.0) * texture(g_textures[inTexIndex], inUV);
}
