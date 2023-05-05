#version 460

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;

layout(location = 0) out VetexOut{
	vec3 viewVertexPosition;
	vec3 normal;
	vec2 uv;
	uint modelIndex;
} vOut;

struct ModelData {
    mat4 modelMat;
	mat4 viewNormalMatrix;
    vec3 modelOffset;
};

layout(binding = 4) uniform CameraMatrices {
	mat4 view;
	mat4 projection;
} camera;

layout(binding = 5) readonly buffer Modeldata {
	ModelData models[];
} modelData;

void main(){
	const ModelData model = modelData.models[gl_BaseInstance];

	mat4 viewSpace = camera.view * model.modelMat;

	vec4 vertexPosition = vec4(inPosition + model.modelOffset, 1.0);
	vec4 viewVertexPosition = viewSpace * vertexPosition;

	gl_Position = camera.projection * viewVertexPosition;

	vOut.uv = inUV;
	vOut.modelIndex = gl_BaseInstance;
	vOut.viewVertexPosition = viewVertexPosition.xyz;
	vOut.normal = mat3(model.viewNormalMatrix) * inNormal;
}
