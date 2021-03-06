#version 460
#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in vec2 uv;

layout(location = 0) out vec4 outColour;

layout(std140, push_constant) uniform TextureConstant {
	layout(offset = 80) uint texIndex;
}texConsts;

layout(binding = 1) uniform sampler2D g_textures[];

void main() {
    outColour = texture(g_textures[texConsts.texIndex], uv);
}