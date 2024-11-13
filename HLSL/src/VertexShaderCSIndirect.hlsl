#define threadBlockSize 64

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

bool IsOnOrForwardPlane(float4 plane, float3 extents, float4 centre)
{
    // Collapse the extents on the plane, which would result in a line
    // which should represent the half extent of the AABB.
    float collapsedHalfExtentLine = extents.x * abs(plane.x)
                                + extents.y * abs(plane.y)
                                + extents.z * abs(plane.z);

    // The dot product minus the distance of the plane represents the
    // distance of the centre from the plane. If it equals to the collapsedHalfExtent
    // then the centre of the AABB is on the plane and if it is bigger than the
    // collapsedHalfExtent then it is forward on the plane.
    // We are negating the collaspsedHalfExtent because even if the centre dot is
    // negative, the other half of the AABB might still be forward on the plane.
    // It would only be fully outside when it is lower than the negative half extent.
    // The distance subtract is only needed for the far and the near plane, as they
    // will have a distance. The other 4 planes will have 0 as their distance/w.
    return -collapsedHalfExtentLine <= (dot(plane.xyz, centre.xyz) - plane.w);
}

bool IsModelInsideFrustum(uint threadIndex)
{
    PerModelData perModelDataInst = perModelData[threadIndex];

    uint modelIndex         = inputData[threadIndex].modelIndex;
    uint modelBundleIndex   = perModelDataInst.modelBundleIndex;
    uint meshBundleIndex    = meshBundleIndices[modelBundleIndex];
    uint meshOffset         = perMeshBundleData[meshBundleIndex].meshOffset;
    ModelData modelDataInst = modelData[modelIndex];

    float3 modelOffset = modelDataInst.modelOffset.xyz;
    matrix view        = cameraData.view;

    // Local space
    AABB aabb      = perMeshData[meshOffset + modelDataInst.meshIndex].aabb;

    float4 centre  = (aabb.maxAxes + aabb.minAxes) * 0.5;
    float3 extents = float3(
        aabb.maxAxes.x - centre.x,
        aabb.maxAxes.y - centre.y,
        aabb.maxAxes.z - centre.z
    );

    // Need to get the pre-transformed direction vectors. So,
    // have to use the original view matrix.
    float4 right   = view[0] * extents.x;
    float4 up      = view[1] * extents.y;
    float4 forward = view[2] * extents.z;

    // The scaled magnitude of the extents in the world space
    float newX = abs(dot(float4(1.0, 0.0, 0.0, 1.0), right))
            + abs(dot(float4(1.0, 0.0, 0.0, 1.0), up))
            + abs(dot(float4(1.0, 0.0, 0.0, 1.0), forward));

    float newY = abs(dot(float4(0.0, 1.0, 0.0, 1.0), right))
        + abs(dot(float4(0.0, 1.0, 0.0, 1.0), up))
        + abs(dot(float4(0.0, 1.0, 0.0, 1.0), forward));

    float newZ = abs(dot(float4(0.0, 0.0, 1.0, 1.0), right))
        + abs(dot(float4(0.0, 0.0, 1.0, 1.0), up))
        + abs(dot(float4(0.0, 0.0, 1.0, 1.0), forward));

    float3 scaledExtents     = float3(newX, newY, newZ);
    // Transform the centre to be in the World space, since the frustum planes are also
    // in the world space.
    float4 transformedCentre = mul(
        view, mul(modelDataInst.modelMatrix, float4(centre.xyz + modelOffset, 1.0))
    );

    Frustum frustum = cameraData.frustum;

    return IsOnOrForwardPlane(frustum.left,   scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.right,  scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.bottom, scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.top,    scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.near,   scaledExtents, transformedCentre)
        && IsOnOrForwardPlane(frustum.far,    scaledExtents, transformedCentre);
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
