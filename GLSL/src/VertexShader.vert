#version 460

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;

layout(location = 0) out vec2 outUV;
layout(location = 1) out uint outModelIndex;
layout(location = 2) out vec3 outViewVertexPosition;
layout(location = 3) out vec3 outNormal;

struct PerModelData {
    mat4 modelMat;
	mat4 viewNormalMatrix;
    vec3 modelOffset;
    vec3 positiveBounds;
    vec3 negativeBounds;
};

layout(binding = 0) uniform CameraMatrices {
	mat4 view;
	mat4 projection;
}camera;

layout(binding = 1) readonly buffer Modeldata {
	PerModelData models[];
} modelData;

void main(){
	const PerModelData modelDataInst = modelData.models[gl_BaseInstance];

	mat4 viewSpace = camera.view * modelDataInst.modelMat;

	vec4 vertexPosition = vec4(inPosition + modelDataInst.modelOffset, 1.0);
	vec4 viewVertexPosition = viewSpace * vertexPosition;

	gl_Position = camera.projection * viewVertexPosition;

	outUV = inUV;
	outModelIndex = gl_BaseInstance;
	outViewVertexPosition = viewVertexPosition.xyz;
	outNormal = mat3(modelDataInst.viewNormalMatrix) * inNormal;
}
