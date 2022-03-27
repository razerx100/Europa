#version 450

layout(location = 0) in vec2 uv;

layout(location = 0) out vec4 outColour;

layout(push_constant) uniform TextureConstant {
	uint texIndex;
}texConsts;

void main() {
    outColour = vec4(uv, 1.0, 1.0);
}