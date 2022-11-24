#define threadBlockSize 128

struct PerModelData {
    float2 uvOffset;
    float2 uvRatio;
    matrix modelMat;
    uint texIndex;
    float3 modelOffset;
    float3 positiveBounds;
    float3 negativeBounds;
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

struct CullingData {
    uint commandCount;
    float2 xBounds;
    float2 yBounds;
    float2 zBounds;
};

StructuredBuffer<PerModelData> b_modelData : register(t0);
StructuredBuffer<IndirectCommand> b_inputCommands : register(t1);
AppendStructuredBuffer<IndirectCommand> b_outputCommands : register(u0);
ConstantBuffer<CameraMatrices> b_camera : register(b0);
ConstantBuffer<CullingData> cullingData : register(b1);

bool IsInsideBounds(uint index) {
    return true;
}

[numthreads(threadBlockSize, 1, 1)]
void main(uint3 groupId : SV_GroupID, uint groupIndex : SV_GroupIndex) {
    uint index = (groupId.x * threadBlockSize) + groupIndex;

    if(cullingData.commandCount > index)
        if(IsInsideBounds(index))
            b_outputCommands.Append(b_inputCommands[index]);
}
