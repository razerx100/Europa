#version 450

layout(location = 0) in vec2 uv;

layout(location = 0) out vec4 outColour;

layout(push_constant) uniform TextureConstant {
	uint texIndex;
}texConsts;

layout(binding = 0) uniform sampler2D textureAtlas;

void main() {
    outColour = texture(textureAtlas, uv);
}