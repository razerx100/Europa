#define threadBlockSize 128

struct PerModelData {
    float2 uvOffset;
    float2 uvRatio;
    matrix modelMat;
    uint texIndex;
    float3 modelOffset;
};

struct CameraMatrices {
    matrix view;
    matrix projection;
};

struct IndirectCommand {
    uint modelIndex;
    struct {
        uint indexCountPerInstance;
        uint instanceCount;
        uint startIndexLocation;
        int baseVertexLocation;
        uint startInstanceLocation;
    }indexedArguments;
};

StructuredBuffer<PerModelData> b_modelData : register(t0);
StructuredBuffer<IndirectCommand> b_indirectCommands : register(t1);
ConstantBuffer<CameraMatrices> b_camera : register(b0);

[numthreads(threadBlockSize, 1, 1)]
void main(uint3 groupId : SV_GroupID, uint groupIndex : SV_GroupIndex) {
    uint index = (groupId.x * threadBlockSize) + groupIndex;
}
