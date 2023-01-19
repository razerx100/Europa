#define threadBlockSize 64

struct PerModelData {
    float2 uvOffset;
    float2 uvRatio;
    matrix modelMat;
    uint texIndex;
    float3 modelOffset;
    float3 positiveBounds;
    float3 negativeBounds;
    matrix viewNormalMatrix;
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
    uint modelTypes;
    float2 xBounds;
    float2 yBounds;
    float2 zBounds;
};

struct CounterBuffer{
    uint counter;
    uint modelCountOffset;
};

StructuredBuffer<PerModelData> b_modelData : register(t0);
StructuredBuffer<IndirectCommand> b_inputCommands : register(t1);
RWStructuredBuffer<IndirectCommand> b_outputCommands : register(u0);
RWStructuredBuffer<CounterBuffer> b_counterBuffers : register(u1);
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
    uint threadIndex = (groupId.x * threadBlockSize) + groupIndex;

    if (cullingData.commandCount > threadIndex)
        if(IsModelInsideBounds(threadIndex)) {
            uint currentCounterIndex = 0;
            for(uint typeIndex = 0; typeIndex < cullingData.modelTypes; ++typeIndex){
                if(b_counterBuffers[typeIndex].modelCountOffset <= threadIndex)
                    currentCounterIndex = typeIndex;
                else
                    break;
            }

            uint oldCounterValue = 0u;
            InterlockedAdd(
                b_counterBuffers[currentCounterIndex].counter, 1, oldCounterValue
            );
            uint modelWriteIndex =
                b_counterBuffers[currentCounterIndex].modelCountOffset + oldCounterValue;

            b_outputCommands[modelWriteIndex] = b_inputCommands[threadIndex];
        }
}
