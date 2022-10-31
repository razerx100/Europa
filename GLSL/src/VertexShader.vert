#version 460

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 uvIn;

layout(location = 0) out vec2 uvOut;
layout(location = 1) out uint texIndex;

struct PerModelData {
    vec2 uvOffset;
    vec2 uvRatio;
    mat4 modelMat;
    uint texIndex;
    float padding0[3];
    vec3 modelOffset;
    float padding1;
};

layout(binding = 2) readonly buffer Modeldata {
	PerModelData models[];
} modelData;

layout(binding = 0) uniform CameraMatrices {
	mat4 view;
	mat4 projection;
}camera;

void main(){
	const PerModelData modelData = modelData.models[gl_BaseInstance];

	mat4 transform = camera.projection * camera.view * modelData.modelMat;

	gl_Position = transform * vec4(inPosition + modelData.modelOffset, 1.0);

	uvOut = uvIn * modelData.uvRatio + modelData.uvOffset;
	texIndex = modelData.texIndex;
}
