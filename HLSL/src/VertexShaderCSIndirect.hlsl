#define threadBlockSize 64

struct ModelData
{
    matrix modelMatrix;
    float4 modelOffset; // materialIndex on the last component.
    uint   meshIndex;
    uint   padding;
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

struct AABB
{
    float4 maxAxes;
    float4 minAxes;
};

struct PerModelData
{
    uint modelBundleIndex;
    uint modelIndex;
};

struct PerMeshData
{
    AABB aabb;
};

struct PerMeshBundleData
{
    uint meshOffset;
};

struct CameraMatrices
{
    matrix  view;
    matrix  projection;
    Frustum frustum;
};

struct ConstantData
{
    uint modelCount;
};

ConstantBuffer<ConstantData> constantData             : register(b0);
ConstantBuffer<CameraMatrices> cameraData             : register(b1);

StructuredBuffer<ModelData> modelData                 : register(t0);
StructuredBuffer<IndirectArguments> inputData         : register(t1);
StructuredBuffer<CullingData> cullingData             : register(t2);
StructuredBuffer<PerModelData> perModelData           : register(t3);
StructuredBuffer<PerMeshData> perMeshData             : register(t4);
StructuredBuffer<PerMeshBundleData> perMeshBundleData : register(t5);
StructuredBuffer<uint> meshBundleIndices              : register(t6);

RWStructuredBuffer<IndirectArguments> outputData      : register(u0);
RWStructuredBuffer<uint> outputCounters               : register(u1);

bool IsOnOrForwardPlane(float4 plane, float4 extents, float4 centre)
{
    float radius = extents.x * plane.x + extents.y * plane.y + extents.z * plane.z;

    return -radius <= dot(plane, centre);
}

bool IsModelInsideFrustum(uint threadIndex)
{
    PerModelData perModelDataInst = perModelData[threadIndex];

    uint modelIndex         = perModelDataInst.modelIndex;
    uint modelBundleIndex   = perModelDataInst.modelBundleIndex;
    uint meshBundleIndex    = meshBundleIndices[modelBundleIndex];
    uint meshOffset         = perMeshBundleData[meshBundleIndex].meshOffset;
    ModelData modelDataInst = modelData[modelIndex];

    float4 modelOffset    = modelDataInst.modelOffset;
    matrix transformWorld = mul(cameraData.view, modelDataInst.modelMatrix);
    matrix transformClip  = mul(cameraData.projection, transformWorld);

    // Local space
    AABB aabb      = perMeshData[meshOffset + modelDataInst.meshIndex].aabb;

    float4 centre  = (aabb.maxAxes + aabb.minAxes) * 0.5;
    float4 extents = float4(
        aabb.maxAxes.x - centre.x,
        aabb.maxAxes.y - centre.y,
        aabb.maxAxes.z - centre.z,
        1.0
    );

    float4 right   = transformClip[0] * extents.x;
    float4 up      = transformClip[1] * extents.y;
    float4 forward = transformClip[2] * extents.z;

    // The magnitude of the extents in the Clip space
    float newX = abs(dot(float4(1.0, 0.0, 0.0, 1.0), right))
        + abs(dot(float4(1.0, 0.0, 0.0, 1.0), up))
        + abs(dot(float4(1.0, 0.0, 0.0, 1.0), forward));

    float newY = abs(dot(float4(0.0, 1.0, 0.0, 1.0), right))
        + abs(dot(float4(0.0, 1.0, 0.0, 1.0), up))
        + abs(dot(float4(0.0, 1.0, 0.0, 1.0), forward));

    float newZ = abs(dot(float4(0.0, 0.0, 1.0, 1.0), right))
        + abs(dot(float4(0.0, 0.0, 1.0, 1.0), up))
        + abs(dot(float4(0.0, 0.0, 1.0, 1.0), forward));

    // We don't need the homogenous component here. As this will be used
    // for calculating the radius only and the x, y and z should already
    // been transformed to be in the clip space.
    float4 scaledExtents     = float4(newX, newY, newZ, 1.0);
    float4 transformedCentre = mul(cameraData.projection, mul(transformWorld, (centre + modelOffset)));

    Frustum frustum    = cameraData.frustum;

    bool isModelInside = IsOnOrForwardPlane(frustum.left, scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.right,  scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.bottom, scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.top,    scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.near,   scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.far,    scaledExtents, transformedCentre);

    return isModelInside;
}

[numthreads(threadBlockSize, 1, 1)]
void main(uint groupId : SV_GroupID, uint groupIndex : SV_GroupIndex)
{
    uint threadIndex = groupId * threadBlockSize + groupIndex;

    if (threadIndex < constantData.modelCount)
    {
        uint modelBundleIndex = perModelData[threadIndex].modelBundleIndex;
        CullingData cData     = cullingData[modelBundleIndex];

        uint commandEnd       = cData.commandOffset + cData.commandCount;

        // Only process the models which are in the range of the bundle's commands.
        if (cData.commandOffset <= threadIndex && threadIndex < commandEnd)
        {
            if (IsModelInsideFrustum(threadIndex))
            {
                // If the model is inside the frustum, increase the counter by 1.
                // Using the bundle index to index, because each bundle should have its
                // own counter and arguments range.
                uint oldCounterValue = 0u;

                InterlockedAdd(outputCounters[modelBundleIndex], 1, oldCounterValue);

                // The argument buffer for this model bundle should start at the commandOffset.
                // Since each argument represent each model, we should put the arguments of the
                // models which are inside the frustum back to back. The old counter value + the
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
}
