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
    vec3 positiveBounds;
    vec3 negativeBounds;
};

struct Vertex {
    vec3 position;
    vec3 normal;
    vec2 uv;
};

struct VertexOut {
	vec4 glPosition;
	vec3 viewVertexPosition;
	vec3 normal;
	vec2 uv;
	uint modelIndex;
};

layout(binding = 4) uniform CameraMatrices {
	mat4 view;
	mat4 projection;
} camera;

layout(binding = 5) readonly buffer Modeldata {
	ModelData models[];
} modelData;

VertexOut GetVertexAttributes(
    mat4 modelM, mat4 viewM, mat4 projectionM, mat4 viewNormalM, Vertex vertex,
	vec3 modelOffset, uint modelIndex
) {
    mat4 viewSpace = viewM * modelM;
    vec4 vertexPosition = vec4(vertex.position + modelOffset, 1.0);
    vec4 viewVertexPosition = viewSpace * vertexPosition;

    VertexOut vout;
    vout.glPosition = projectionM * viewVertexPosition;
    vout.viewVertexPosition = viewVertexPosition.xyz;
    vout.normal = mat3(viewNormalM) * vertex.normal;
    vout.uv = vertex.uv;
    vout.modelIndex = modelIndex;

    return vout;
}

void SetOutputs(
    mat4 modelM, mat4 viewM, mat4 projectionM, mat4 viewNormalM, Vertex vertex,
	vec3 modelOffset, uint modelIndex
) {
	VertexOut pVOut = GetVertexAttributes(
		modelM, viewM, projectionM, viewNormalM, vertex, modelOffset, modelIndex
	);

	gl_Position = pVOut.glPosition;
	vOut.uv = pVOut.uv;
	vOut.modelIndex = pVOut.modelIndex;
	vOut.viewVertexPosition = pVOut.viewVertexPosition;
	vOut.normal = pVOut.normal;
}

void main(){
	const ModelData model = modelData.models[gl_BaseInstance];

	Vertex vertex;
	vertex.position = inPosition;
	vertex.normal = inNormal;
	vertex.uv = inUV;

	SetOutputs(
		model.modelMat, camera.view, camera.projection, model.viewNormalMatrix, vertex,
		model.modelOffset, gl_BaseInstance
	);
}
