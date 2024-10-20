#define AS_GROUP_SIZE 32

struct VertexOut
{
	float3 viewVertexPosition : ViewPosition;
	float3 normal             : Normal;
	float2 uv                 : UV;
	uint   modelIndex         : ModelIndex;
	uint   materialIndex      : MaterialIndex;
	float4 position           : SV_Position;
};

struct ModelData
{
	matrix modelMatrix;
	float4 modelOffset; // materialIndex on the last component.
};

struct Meshlet
{
	uint vertexCount;
	uint vertexOffset;
	uint primitiveCount;
	uint primitiveOffset;
};

struct Vertex
{
	float3 position;
	float3 normal;
	float2 uv;
};

struct CameraMatrices
{
	matrix view;
	matrix projection;
};

struct MeshDetails
{
	uint vertexOffset;
	uint vertexIndicesOffset;
	uint primitiveIndicesOffset;
	uint meshletOffset;
};

// The constants are laid out as vec4s. The padding here
// isn't necessary but it would still be padded implicitly.
// So, just doing it explicitly.
struct ModelDetails
{
	uint meshletCount;
	uint meshletOffset;
	uint modelIndex;
	uint padding;
};

struct Payload
{
	uint meshletIndices[AS_GROUP_SIZE];
};

struct ConstantData
{
	ModelDetails modelDetails;
	MeshDetails  meshDetails;
};

ConstantBuffer<ConstantData> constantData : register(b1);
ConstantBuffer<CameraMatrices> cameraData : register(b2);

StructuredBuffer<ModelData> modelData     : register(t0);
StructuredBuffer<Meshlet> meshletData     : register(t1);
StructuredBuffer<Vertex> vertexData       : register(t2);
StructuredBuffer<uint> vertexIndexData    : register(t3);
StructuredBuffer<uint> primIndexData      : register(t4);

uint3 UnpackPrimitive(uint primitive)
{
	return uint3(primitive & 0x3FF, (primitive >> 10) & 0x3FF, (primitive >> 20) & 0x3FF);
}

uint3 GetPrimitive(uint primOffset, uint index)
{
	return UnpackPrimitive(primIndexData[primOffset + index]);
}

uint GetVertexIndex(uint vertexIndicesOffset, uint localIndex)
{
	return vertexIndexData[vertexIndicesOffset + localIndex];
}

VertexOut GetVertexAttributes(
    matrix modelM, matrix viewM, matrix projectionM, matrix viewNormalM, Vertex vertex,
	float3 modelOffset, uint modelIndex, uint materialIndex
) {
    matrix viewSpace          = mul(viewM, modelM);
    float4 vertexPosition     = float4(vertex.position + modelOffset, 1.0);
    float4 viewVertexPosition = mul(viewSpace, vertexPosition);

    VertexOut vout;
    vout.position           = mul(projectionM, viewVertexPosition);
    vout.viewVertexPosition = viewVertexPosition.xyz;
    vout.normal             = mul((float3x3) viewNormalM, vertex.normal);
    vout.uv                 = vertex.uv;
    vout.modelIndex         = modelIndex;
    vout.materialIndex      = materialIndex;

    return vout;
}

VertexOut GetVertexAttributes(uint modelIndex, uint vertexIndex)
{
    Vertex vertex         = vertexData[vertexIndex];
    const ModelData model = modelData[modelIndex];

    float3 modelOffset      = model.modelOffset.xyz;
    // Probably going to calculate this on the CPU later.
    // mat4 viewNormalMatrix = transpose(inverse(model.modelMatrix * camera.view));
    matrix viewNormalMatrix = model.modelMatrix;
    uint materialIndex      = asuint(model.modelOffset.w);

	return GetVertexAttributes(
		model.modelMatrix, cameraData.view, cameraData.projection, viewNormalMatrix, vertex,
		modelOffset, modelIndex, materialIndex
	);
}

[NumThreads(128, 1, 1)]
[OutputTopology("triangle")]
void main(
	uint gtid : SV_GroupThreadID, uint gid : SV_GroupID,
	in payload Payload payload,
	out indices uint3 prims[126], out vertices VertexOut verts[64]
) {
	MeshDetails meshDetails   = constantData.meshDetails;
	ModelDetails modelDetails = constantData.modelDetails;

	uint meshletOffset = meshDetails.meshletOffset + modelDetails.meshletOffset;
	Meshlet meshlet    = meshletData[meshletOffset + gid];

	SetMeshOutputCounts(meshlet.vertexCount, meshlet.primitiveCount);

	if (gtid < meshlet.primitiveCount)
	{
		uint primOffset = meshDetails.primitiveIndicesOffset + meshlet.primitiveOffset;
		prims[gtid]     = GetPrimitive(primOffset, gtid);
	}

	if (gtid < meshlet.vertexCount)
	{
		uint vertexIndicesOffset = meshDetails.vertexIndicesOffset + meshlet.vertexOffset;

		verts[gtid] = GetVertexAttributes(
			modelDetails.modelIndex, GetVertexIndex(vertexIndicesOffset, gtid)
		);
	}
}
