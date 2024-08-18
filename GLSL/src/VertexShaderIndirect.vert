#version 460

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;

layout(location = 0) out VetexOut
{
	vec3 viewVertexPosition;
	vec3 normal;
	vec2 uv;
	uint modelIndex;
	uint materialIndex;
} vOut;

struct ModelData
{
    mat4 modelMatrix;
    vec4 modelOffset; // materialIndex on the last component.
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
	vec3 viewVertexPosition;
	vec3 normal;
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

layout(binding = 1) readonly buffer ModelIndices
{
	uint indices[];
} modelIndices;

layout(binding = 2) uniform CameraMatrices
{
	mat4 view;
	mat4 projection;
} camera;

VertexOut GetVertexAttributes(
    mat4 modelM, mat4 viewM, mat4 projectionM, mat4 viewNormalM, Vertex vertex,
	vec3 modelOffset, uint modelIndex, uint materialIndex
) {
    mat4 viewSpace          = viewM * modelM;
    vec4 vertexPosition     = vec4(vertex.position + modelOffset, 1.0);
    vec4 viewVertexPosition = viewSpace * vertexPosition;

    VertexOut vout;
    vout.glPosition         = projectionM * viewVertexPosition;
    vout.viewVertexPosition = viewVertexPosition.xyz;
    vout.normal             = mat3(viewNormalM) * vertex.normal;
    vout.uv                 = vertex.uv;
    vout.modelIndex         = modelIndex;
    vout.materialIndex      = materialIndex;

    return vout;
}

void SetOutputs(
    mat4 modelM, mat4 viewM, mat4 projectionM, mat4 viewNormalM, Vertex vertex,
	vec3 modelOffset, uint modelIndex, uint materialIndex
) {
	VertexOut pVOut = GetVertexAttributes(
		modelM, viewM, projectionM, viewNormalM, vertex, modelOffset, modelIndex, materialIndex
	);

	gl_Position             = pVOut.glPosition;
	vOut.uv                 = pVOut.uv;
	vOut.modelIndex         = pVOut.modelIndex;
	vOut.viewVertexPosition = pVOut.viewVertexPosition;
	vOut.normal             = pVOut.normal;
	vOut.materialIndex      = pVOut.materialIndex;
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

    vec3 modelOffset      = model.modelOffset.xyz;
    mat4 viewNormalMatrix = transpose(inverse(model.modelMatrix * camera.view));
    uint materialIndex    = floatBitsToUint(model.modelOffset.w);

	SetOutputs(
		model.modelMatrix, camera.view, camera.projection, viewNormalMatrix, vertex,
		modelOffset, modelIndex, materialIndex
	);
}
