#define threadBlockSize 64

struct PerModelData {
    float2 uvOffset;
    float2 uvRatio;
    matrix modelMat;
    uint texIndex;
    float3 modelOffset;
    float3 positiveBounds;
    float3 negativeBounds;
    float2 padding;
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
RWStructuredBuffer<IndirectCommand> b_outputCommands : register(u0);
RWStructuredBuffer<uint> b_counterBuffers : register(u1);
ConstantBuffer<CameraMatrices> b_camera : register(b0);
ConstantBuffer<CullingData> cullingData : register(b1);

bool IsVertexInsideBounds(float4 vertex, matrix transform) {
    vertex = mul(transform, vertex);
    vertex /= vertex.w;

    if(cullingData.xBounds.x < vertex.x || vertex.x < cullingData.xBounds.y)
        return false;

    if(cullingData.yBounds.x < vertex.y || vertex.y < cullingData.yBounds.y)
        return false;

    if(cullingData.zBounds.x < vertex.z || vertex.z < cullingData.zBounds.y)
        return false;

    return true;
}

bool IsModelInsideBounds(uint index) {
    PerModelData modelData = b_modelData[index];

    float3 positives = modelData.positiveBounds;
    float3 negatives = modelData.negativeBounds;
    float3 offsets = modelData.modelOffset;

    matrix transform = mul(b_camera.projection, mul(b_camera.view, modelData.modelMat));

    float4 vertex0 = float4(float3(negatives.x, positives.y, negatives.z) + offsets, 1.0f);
    if(IsVertexInsideBounds(vertex0, transform))
        return true;

    float4 vertex1 = float4(float3(positives.x, positives.y, negatives.z) + offsets, 1.0f);
    if(IsVertexInsideBounds(vertex1, transform))
        return true;

    float4 vertex2 = float4(float3(negatives.x, negatives.y, negatives.z) + offsets, 1.0f);
    if(IsVertexInsideBounds(vertex2, transform))
        return true;

    float4 vertex3 = float4(float3(positives.x, negatives.y, negatives.z) + offsets, 1.0f);
    if(IsVertexInsideBounds(vertex3, transform))
        return true;

    float4 vertex4 = float4(float3(negatives.x, positives.y, positives.z) + offsets, 1.0f);
    if(IsVertexInsideBounds(vertex4, transform))
        return true;

    float4 vertex5 = float4(float3(positives.x, positives.y, positives.z) + offsets, 1.0f);
    if(IsVertexInsideBounds(vertex5, transform))
        return true;

    float4 vertex6 = float4(float3(negatives.x, negatives.y, positives.z) + offsets, 1.0f);
    if(IsVertexInsideBounds(vertex6, transform))
        return true;

    float4 vertex7 = float4(float3(positives.x, negatives.y, positives.z) + offsets, 1.0f);
    if(IsVertexInsideBounds(vertex7, transform))
        return true;

    return false;
}

[numthreads(threadBlockSize, 1, 1)]
void main(uint3 groupId : SV_GroupID, uint groupIndex : SV_GroupIndex) {
    uint index = (groupId.x * threadBlockSize) + groupIndex;

    if (cullingData.commandCount > index)
        if (IsModelInsideBounds(index)) {
            uint outputIndex = 0;
            InterlockedAdd(b_counterBuffers[0], 1, outputIndex);
            b_outputCommands[outputIndex] = b_inputCommands[index];
        }
}
