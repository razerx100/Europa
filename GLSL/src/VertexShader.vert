#version 460

layout(location = 0) in vec3 inPosition;

layout(location = 0) out vec2 uv;

layout(push_constant) uniform PushData {
	mat4 view;
	uint uStart;
	uint uEnd;
	uint uMax;
	uint vStart;
	uint vEnd;
	uint vMax;
}pushData;

float PixelToUV(uint pixelCoord, uint maxLength) {
	return float((pixelCoord - 1) * 2 + 1) / (maxLength * 2);
}

void main(){
	gl_Position = pushData.view * vec4(inPosition.x, -inPosition.y, inPosition.z, 1.0);
	uv = vec2(
		PixelToUV(pushData.uStart, pushData.uMax),
		PixelToUV(pushData.vStart, pushData.vMax)
	);
}
