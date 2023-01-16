#version 460
#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in vec2 inUV;
flat layout(location = 1) in uint inTexIndex;

layout(location = 0) out vec4 outColour;

layout(binding = 1) uniform sampler2D g_textures[];

void main() {
    outColour = texture(g_textures[inTexIndex], inUV);
}