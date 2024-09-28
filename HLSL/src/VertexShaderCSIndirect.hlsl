#define threadBlockSize 64

struct ModelData
{
    matrix modelMatrix;
    float4 modelOffset; // materialIndex on the last component.
};

struct DrawArguments
{
    uint indexCount;
    uint instanceCount;
    uint firstIndex;
    int  vertexOffset;
    uint firstInstance;
};

struct IndirectArguments
{
    uint          modelIndex;
    DrawArguments drawArguments;
};

struct CullingData
{
    uint commandCount;
    uint commandOffset;
};

struct MaxBounds
{
    float2 xBounds;
    float2 yBounds;
    float2 zBounds;
};

struct MeshDetails
{
    uint boundOffset;
    uint boundCount;
};

struct CameraMatrices
{
    matrix view;
    matrix projection;
};

struct ConstantData
{
    MaxBounds maxBounds;
};

ConstantBuffer<ConstantData> constantData        : register(b0);
ConstantBuffer<CameraMatrices> cameraData        : register(b1);

StructuredBuffer<ModelData> modelData            : register(t0);
StructuredBuffer<IndirectArguments> inputData    : register(t1);
StructuredBuffer<CullingData> cullingData        : register(t2);
StructuredBuffer<uint> modelBundleIndices        : register(t3);
StructuredBuffer<float3> meshBounds              : register(t4);
StructuredBuffer<uint> meshIndices               : register(t5);
StructuredBuffer<MeshDetails> meshDetails        : register(t6);

RWStructuredBuffer<IndirectArguments> outputData : register(u0);
RWStructuredBuffer<uint> outputCounters          : register(u1);

bool IsVertexInsideBounds(float4 vertex, matrix transform)
{
    vertex  = mul(transform, vertex);
    vertex /= vertex.w;

    MaxBounds mBounds = constantData.maxBounds;

    if (mBounds.xBounds.x < vertex.x || vertex.x < mBounds.xBounds.y)
        return false;

    if (mBounds.yBounds.x < vertex.y || vertex.y < mBounds.yBounds.y)
        return false;

    if (mBounds.zBounds.x < vertex.z || vertex.z < mBounds.zBounds.y)
        return false;

    return true;
}

bool IsModelInsideBounds(uint threadIndex)
{
    uint modelIndex         = inputData[threadIndex].modelIndex;
    ModelData modelDataInst = modelData[modelIndex];
    // A model bundle can have more than a single model. But all of the models
    // of the same Model bundle should have the same mesh. So, use the bundle
    // index to get the mesh index.
    // Each model index should have which bundle it belongs to. So,
    // use the threadIndex to get both the model and model bundle indices.
    uint modelBundleIndex   = modelBundleIndices[threadIndex];
    uint meshIndex          = meshIndices[modelBundleIndex];
    MeshDetails details     = meshDetails[meshIndex];

    float3 modelOffset = modelDataInst.modelOffset.xyz;
    matrix transform   = mul(cameraData.projection, mul(cameraData.view, modelDataInst.modelMatrix));
    uint boundEnd      = details.boundOffset + details.boundCount;

    for (uint index = details.boundOffset; index < boundEnd; ++index)
    {
        float4 boundVertex = float4(meshBounds[index] + modelOffset, 1.0);

        if (IsVertexInsideBounds(boundVertex, transform))
            return true;
    }

    return false;
}

[numthreads(threadBlockSize, 1, 1)]
void main(uint groupId : SV_GroupID, uint groupIndex : SV_GroupIndex)
{
    uint threadIndex      = groupId * threadBlockSize + groupIndex;
    uint modelBundleIndex = modelBundleIndices[threadIndex];
    CullingData cData     = cullingData[modelBundleIndex];

    uint commandEnd       = cData.commandOffset + cData.commandCount;

    // Only process the models which are in the range of the bundle's commands.
    if (cData.commandOffset <= threadIndex && threadIndex < commandEnd)
    {
        if (IsModelInsideBounds(threadIndex))
        {
            // If the model is inside the bounds, increase the counter by 1.
            // Using the bundle index to index, because each bundle should have its
            // own counter and arguments range.
            uint oldCounterValue = 0u;

            InterlockedAdd(outputCounters[modelBundleIndex], 1, oldCounterValue);

            // The argument buffer for this model bundle should start at the commandOffset.
            // Since each argument represent each model, we should put the arguments of the
            // models which are inside the bounds back to back. The old counter value + the
            // offset should be the latest available model index.
            // The reason I am doing it before assigning the argument is because multiple
            // threads could try to write to the same index. But because of the atomicAdd
            // the old value should be unique for this bundle's range. The argument assignment
            // isn't atomic though.
            uint modelWriteIndex        = cData.commandOffset + oldCounterValue;
            outputData[modelWriteIndex] = inputData[threadIndex];
        }
    }
}
