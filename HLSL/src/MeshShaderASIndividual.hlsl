#define AS_GROUP_SIZE 32

struct ModelData
{
	matrix modelMatrix;
	float4 modelOffset; // materialIndex on the last component.
    uint   meshIndex;
    uint   padding[3];
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
	uint vertexCount;
	uint vertexOffset;
	uint primitiveCount;
	uint primitiveOffset;
};

struct CameraMatrices
{
	matrix  view;
	matrix  projection;
    Frustum frustum;
};

struct MeshletDetails
{
    Meshlet meshlet;
    float4  sphereBV;
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

struct ConstantData
{
	ModelDetails modelDetails;
	MeshDetails  meshDetails;
};

struct Payload
{
	uint meshletIndices[AS_GROUP_SIZE];
};

groupshared Payload s_Payload;

ConstantBuffer<ConstantData> constantData    : register(b0);
ConstantBuffer<CameraMatrices> cameraData    : register(b1);

StructuredBuffer<ModelData> modelData        : register(t0);
StructuredBuffer<MeshletDetails> meshletData : register(t1);

bool IsMeshletVisible(ModelData modelDataInst, MeshletDetails meshletDetails)
{
    matrix world = modelDataInst.modelMatrix;

    return true;
}

[NumThreads(AS_GROUP_SIZE, 1, 1)]
void main(uint gtid : SV_GroupThreadID, uint dtid : SV_DispatchThreadID, uint gid : SV_GroupID)
{
	bool isMeshletVisible = false;

	ModelDetails modelDetails = constantData.modelDetails;
	MeshDetails meshDetails   = constantData.meshDetails;

	if (dtid < modelDetails.meshletCount)
	{
		uint meshletOffset            = meshDetails.meshletOffset + modelDetails.meshletOffset;
		MeshletDetails meshletDetails = meshletData[meshletOffset + dtid];

		ModelData modelDataInst       = modelData[modelDetails.modelIndex];

		isMeshletVisible = IsMeshletVisible(modelDataInst, meshletDetails);
    }

	if (isMeshletVisible)
    {
        uint currentIndex = WavePrefixCountBits(isMeshletVisible);

        s_Payload.meshletIndices[currentIndex] = dtid;
    }

	uint validCount = WaveActiveCountBits(isMeshletVisible);

	// The arguments are taken on the first invocation.
	DispatchMesh(validCount, 1, 1, s_Payload);
}
