#version 450

layout(location = 0) in vec3 inPosition;

layout(location = 0) out vec2 uv;

layout(push_constant) uniform TextureInfo {
	uint uStart;
	uint uEnd;
	uint uMax;
	uint vStart;
	uint vEnd;
	uint vMax;
}texInfo;

float PixelToUV(uint pixelCoord, uint maxLength) {
	return float((pixelCoord - 1) * 2 + 1) / (maxLength * 2);
}

void main(){
	gl_Position = vec4(inPosition.x, -inPosition.y, inPosition.z, 1.0);
	uv = vec2(
		PixelToUV(texInfo.uStart, texInfo.uMax),
		PixelToUV(texInfo.vStart, texInfo.vMax)
	);
}
