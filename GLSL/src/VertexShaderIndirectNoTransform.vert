#version 460

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;

layout(location = 0) out VetexOut
{
	vec3 worldVertexPosition;
	vec3 worldNormal;
	vec2 uv;
	uint modelIndex;
	uint materialIndex;
} vOut;

struct ModelData
{
    mat4  modelMatrix;
    mat4  normalMatrix; // In world space.
    vec4  modelOffset; // materialIndex on the last component.
    uint  meshIndex;
    float modelScale;
    uint  padding[2];
};

struct Frustum
{
	vec4 left;
	vec4 right;
	vec4 bottom;
	vec4 top;
	vec4 near;
	vec4 far;
};

struct Vertex
{
    vec3 position;
    vec3 normal;
    vec2 uv;
};

struct VertexOut
{
	vec4 glPosition;
	vec3 worldVertexPosition;
	vec3 worldNormal;
	vec2 uv;
	uint modelIndex;
	uint materialIndex;
};

layout(push_constant) uniform Constantdata
{
    uint modelIndexOffset;
} constantData;

layout(binding = 0) readonly buffer Modeldata
{
	ModelData models[];
} modelData;

layout(binding = 1) uniform CameraMatrices
{
	mat4    view;
	mat4    projection;
	Frustum frustum;
	vec4    viewPosition;
} camera;

layout(binding = 2) readonly buffer ModelIndices
{
	uint indices[];
} modelIndices;

VertexOut GetVertexAttributes(
    mat4 modelM, mat4 viewM, mat4 projectionM, mat4 normalM, Vertex vertex,
	vec3 modelOffset, uint modelIndex, uint materialIndex
) {
    vec4 localVertexPosition = vec4(vertex.position + modelOffset, 1.0);

    VertexOut vout;
    vout.glPosition          = localVertexPosition;
    vout.worldVertexPosition = localVertexPosition.xyz;
    vout.worldNormal         = vertex.normal;
    vout.uv                  = vertex.uv;
    vout.modelIndex          = modelIndex;
    vout.materialIndex       = materialIndex;

    return vout;
}

void SetOutputs(
    mat4 modelM, mat4 viewM, mat4 projectionM, mat4 normalM, Vertex vertex,
	vec3 modelOffset, uint modelIndex, uint materialIndex
) {
	VertexOut pVOut = GetVertexAttributes(
		modelM, viewM, projectionM, normalM, vertex, modelOffset, modelIndex, materialIndex
	);

	gl_Position              = pVOut.glPosition;
	vOut.uv                  = pVOut.uv;
	vOut.modelIndex          = pVOut.modelIndex;
	vOut.worldVertexPosition = pVOut.worldVertexPosition;
	vOut.worldNormal         = pVOut.worldNormal;
	vOut.materialIndex       = pVOut.materialIndex;
}

void main()
{
	// There will be a single Dispatch invocation but one invocation of Draw
	// per Model bundle. So, drawID will start from 0 at each invocation.
	const uint modelIndex = modelIndices.indices[constantData.modelIndexOffset + gl_DrawID];
	const ModelData model = modelData.models[modelIndex];

	Vertex vertex;
	vertex.position = inPosition;
	vertex.normal   = inNormal;
	vertex.uv       = inUV;

    vec3 modelOffset   = model.modelOffset.xyz;
    uint materialIndex = floatBitsToUint(model.modelOffset.w);

	SetOutputs(
		model.modelMatrix, camera.view, camera.projection, model.normalMatrix, vertex,
		modelOffset, modelIndex, materialIndex
	);
}
