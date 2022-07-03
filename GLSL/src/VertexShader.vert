#version 460

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 uvIn;

layout(location = 0) out vec2 uvOut;

layout(push_constant) uniform PushData {
	mat4 model;
	vec2 uvOffset;
	vec2 uvRatio;
}pushData;

layout(binding = 0) uniform CameraMatrices {
	mat4 view;
	mat4 projection;
}camera;

void main(){
	mat4 transform = camera.projection * camera.view * pushData.model;

	gl_Position = transform * vec4(inPosition.x, inPosition.y, inPosition.z, 1.0);

	uvOut = uvIn * pushData.uvRatio + pushData.uvOffset;
}
