#define AS_GROUP_SIZE 32

struct VertexOut
{
	float3 worldVertexPosition : WorldPosition;
	float3 worldNormal         : WorldNormal;
	float2 uv                  : UV;
	uint   modelIndex          : ModelIndex;
	uint   materialIndex       : MaterialIndex;
	float4 position            : SV_Position;
};

struct ModelData
{
	matrix modelMatrix;
    matrix normalMatrix; // In world space.
	float4 modelOffset; // materialIndex on the last component.
    uint   meshIndex;
    float  modelScale;
    uint   padding[2];
};

struct Frustum
{
	float4 left;
	float4 right;
	float4 bottom;
	float4 top;
	float4 near;
	float4 far;
};

struct Meshlet
{
	uint indexCount;
	uint indexOffset;
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
	matrix  view;
	matrix  projection;
	Frustum frustum;
	float4  viewPosition;
};

struct ConeNormal
{
	uint  packedCone;
	float apexOffset;
};

struct MeshletDetails
{
	Meshlet    meshlet;
	float4     sphereBV;
	ConeNormal coneNormal;
};

struct MeshBundleDetails
{
	uint vertexOffset;
	uint vertexIndicesOffset;
	uint primitiveIndicesOffset;
	uint meshletOffset;
};

struct MeshDetails
{
	uint meshletCount;
	uint meshletOffset;
	uint indexOffset;
	uint primitiveOffset;
	uint vertexOffset;
};

// The constants are laid out as vec4s. Since ModelDetails
// isn't aligned to 16 bytes, I have to either align it or
// put it at the end.
struct ModelDetails
{
    MeshDetails meshDetails;
	uint        modelIndex;
};

struct Payload
{
	uint meshletIndices[AS_GROUP_SIZE];
};

struct ConstantData
{
	MeshBundleDetails meshBundleDetails;
	ModelDetails      modelDetails;
};

ConstantBuffer<ConstantData> constantData    : register(b0);
ConstantBuffer<CameraMatrices> cameraData    : register(b1);

StructuredBuffer<ModelData> modelData        : register(t0);
StructuredBuffer<MeshletDetails> meshletData : register(t1);
StructuredBuffer<Vertex> vertexData          : register(t2);
StructuredBuffer<uint> vertexIndexData       : register(t3);
StructuredBuffer<uint> primIndexData         : register(t4);

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
    matrix modelM, matrix viewM, matrix projectionM, matrix normalM, Vertex vertex,
	float3 modelOffset, uint modelIndex, uint materialIndex
) {
    float4 vertexPosition      = float4(vertex.position + modelOffset, 1.0);
    float4 worldVertexPosition = mul(modelM, vertexPosition);

    VertexOut vout;
    vout.position            = mul(projectionM, mul(viewM, mul(modelM, vertexPosition)));
    vout.worldVertexPosition = worldVertexPosition.xyz;
    vout.worldNormal         = mul((float3x3) normalM, vertex.normal);
    vout.uv                  = vertex.uv;
    vout.modelIndex          = modelIndex;
    vout.materialIndex       = materialIndex;

    return vout;
}

VertexOut GetVertexAttributes(uint modelIndex, uint vertexIndex)
{
    Vertex vertex         = vertexData[vertexIndex];
    const ModelData model = modelData[modelIndex];

    float3 modelOffset = model.modelOffset.xyz;
    uint materialIndex = asuint(model.modelOffset.w);

	return GetVertexAttributes(
		model.modelMatrix, cameraData.view, cameraData.projection, model.normalMatrix, vertex,
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
	MeshBundleDetails meshBundleDetails = constantData.meshBundleDetails;
	ModelDetails modelDetails           = constantData.modelDetails;
	MeshDetails meshDetails             = modelDetails.meshDetails;

	uint meshletIndex = payload.meshletIndices[gid];

	if (meshletIndex >= meshDetails.meshletCount)
		return;

	uint meshletOffset = meshBundleDetails.meshletOffset + meshDetails.meshletOffset;
	Meshlet meshlet    = meshletData[meshletOffset + meshletIndex].meshlet;

	SetMeshOutputCounts(meshlet.indexCount, meshlet.primitiveCount);

	if (gtid < meshlet.primitiveCount)
	{
		uint primOffset = meshBundleDetails.primitiveIndicesOffset
			+ meshDetails.primitiveOffset + meshlet.primitiveOffset;
		prims[gtid]     = GetPrimitive(primOffset, gtid);
	}

	if (gtid < meshlet.indexCount)
	{
		uint vertexIndicesOffset = meshBundleDetails.vertexIndicesOffset
			+ meshDetails.indexOffset + meshlet.indexOffset;

        uint vertexOffset        = meshBundleDetails.vertexOffset + meshDetails.vertexOffset;

		verts[gtid] = GetVertexAttributes(
			modelDetails.modelIndex, vertexOffset + GetVertexIndex(vertexIndicesOffset, gtid)
		);
	}
}
