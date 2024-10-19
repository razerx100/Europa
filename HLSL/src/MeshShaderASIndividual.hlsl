#define AS_GROUP_SIZE 32

struct ConstantData
{
	uint meshletCount;
};

struct Payload
{
	uint meshletIndices[AS_GROUP_SIZE];
};

groupshared Payload s_Payload;

ConstantBuffer<ConstantData> constantData : register(b0);

[NumThreads(AS_GROUP_SIZE, 1, 1)]
void main(uint gtid : SV_GroupThreadID, uint dtid : SV_DispatchThreadID, uint gid : SV_GroupID)
{
	bool doesMeshletExist = false;

	if (dtid < constantData.meshletCount)
	{
		doesMeshletExist = true;
	}

	uint validCount = WaveActiveCountBits(doesMeshletExist);

	// The arguments are taken on the first invocation.
	DispatchMesh(validCount, 1, 1, s_Payload);
}
