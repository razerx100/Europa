#define threadBlockSize 64

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

struct PerPipelineData
{
	uint modelCount;
	uint modelOffset;
	uint modelBundleIndex;
};

struct AABB
{
    float4 maxAxes;
    float4 minAxes;
};

struct PerModelData
{
    uint pipelineIndex;
    uint modelFlags;
};

struct PerModelBundleData
{
    uint meshBundleIndex;
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
    float4  viewPosition;
};

struct ConstantData
{
    uint allocatedModelCount;
};

ConstantBuffer<ConstantData> constantData               : register(b0);
ConstantBuffer<CameraMatrices> cameraData               : register(b1);

StructuredBuffer<ModelData> modelData                   : register(t0);
StructuredBuffer<IndirectArguments> inputData           : register(t1);
StructuredBuffer<PerPipelineData> perPipelineData       : register(t2);
StructuredBuffer<PerModelData> perModelData             : register(t3);
StructuredBuffer<PerMeshData> perMeshData               : register(t4);
StructuredBuffer<PerMeshBundleData> perMeshBundleData   : register(t5);
StructuredBuffer<PerModelBundleData> perModelBundleData : register(t6);

RWStructuredBuffer<IndirectArguments> outputData        : register(u0);
RWStructuredBuffer<uint> outputCounters                 : register(u1);

bool IsModelVisible(uint modelFlags)
{
    uint visiblityFlagBit = 1;

    return (modelFlags & visiblityFlagBit) == visiblityFlagBit;
}

bool ShouldSkipCulling(uint modelFlags)
{
    uint skipCullingFlagBit = 2;

    return (modelFlags & skipCullingFlagBit) == skipCullingFlagBit;
}

bool IsOnOrForwardPlane(float4 plane, float3 extents, float4 centre)
{
    // Collapse the extents on the plane, which would result in a line
    // which should represent the half extent of the AABB.
    float collapsedHalfExtentLine = extents.x * abs(plane.x)
                                + extents.y * abs(plane.y)
                                + extents.z * abs(plane.z);

    // The dot product of the plane and the centre represents the distance of the
    // centre from the plane. If it equals to the collapsedHalfExtent
    // then the centre of the AABB is on the plane and if it is bigger than the
    // collapsedHalfExtent then it is forward on the plane.
    // We are negating the collaspsedHalfExtent because even if the centre dot is
    // negative, the other half of the AABB might still be forward on the plane.
    // It would only be fully outside when it is lower than the negative half extent.
    return -collapsedHalfExtentLine <= dot(plane, centre);
}

bool IsModelInsideFrustum(uint threadIndex)
{
    PerModelData perModelDataInst = perModelData[threadIndex];

    uint modelIndex         = inputData[threadIndex].modelIndex;
    uint pipelineIndex      = perModelDataInst.pipelineIndex;
    uint modelBundleIndex   = perPipelineData[pipelineIndex].modelBundleIndex;;
    uint meshBundleIndex    = perModelBundleData[modelBundleIndex].meshBundleIndex;
    uint meshOffset         = perMeshBundleData[meshBundleIndex].meshOffset;
    ModelData modelDataInst = modelData[modelIndex];

    float4 modelOffset = float4(modelDataInst.modelOffset.xyz, 1.0);
    matrix world       = modelDataInst.modelMatrix;

    // Local space
    AABB aabb      = perMeshData[meshOffset + modelDataInst.meshIndex].aabb;

    float4 centre  = (aabb.maxAxes + aabb.minAxes) * 0.5;
    float3 extents = float3(
        aabb.maxAxes.x - centre.x,
        aabb.maxAxes.y - centre.y,
        aabb.maxAxes.z - centre.z
    );

    // Need to get the x, y and z vectors from the model's world matrix
    // to correctly scale/rotate the extents. And skip the translation.
    // We need to grab them from the rows and in HLSL, the index operator
    // grabs one the of rows.
    float3 right   = world[0].xyz * extents.x;
    float3 up      = world[1].xyz * extents.y;
    float3 forward = world[2].xyz * extents.z;

    // The scaled magnitude of the extents in the world space
    float newX = abs(dot(float3(1.0, 0.0, 0.0), right))
                + abs(dot(float3(1.0, 0.0, 0.0), up))
                + abs(dot(float3(1.0, 0.0, 0.0), forward));

    float newY = abs(dot(float3(0.0, 1.0, 0.0), right))
                + abs(dot(float3(0.0, 1.0, 0.0), up))
                + abs(dot(float3(0.0, 1.0, 0.0), forward));

    float newZ = abs(dot(float3(0.0, 0.0, 1.0), right))
                + abs(dot(float3(0.0, 0.0, 1.0), up))
                + abs(dot(float3(0.0, 0.0, 1.0), forward));

    float3 scaledExtents     = float3(newX, newY, newZ);
    // Transform the centre to be in the World space, since the frustum planes are also
    // in the world space.
    float4 transformedCentre = mul(world, centre);
    transformedCentre       += modelOffset;

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

    if (threadIndex < constantData.allocatedModelCount)
    {
        PerModelData pModelData = perModelData[threadIndex];
        uint pipelineIndex      = pModelData.pipelineIndex;
        PerPipelineData pData   = perPipelineData[pipelineIndex];

        uint modelEnd           = pData.modelOffset + pData.modelCount;
        uint modelFlags         = pModelData.modelFlags;

        // Only process the models which are in the range of the bundle's commands.
        if (pData.modelOffset <= threadIndex && threadIndex < modelEnd && IsModelVisible(modelFlags))
        {
            if (ShouldSkipCulling(modelFlags) || IsModelInsideFrustum(threadIndex))
            {
                // If the model is inside the frustum, increase the counter by 1.
                // Using the bundle index to index, because each bundle should have its
                // own counter and arguments range.
                uint oldCounterValue = 0u;

                InterlockedAdd(outputCounters[pipelineIndex], 1, oldCounterValue);

                // The argument buffer for this model bundle should start at the commandOffset.
                // Since each argument represent each model, we should put the arguments of the
                // models which are inside the frustum back to back. The old counter value + the
                // offset should be the latest available model index.
                // The reason I am doing it before assigning the argument is because multiple
                // threads could try to write to the same index. But because of the atomicAdd
                // the old value should be unique for this bundle's range. The argument assignment
                // isn't atomic though.
                uint modelWriteIndex        = pData.modelOffset + oldCounterValue;
                outputData[modelWriteIndex] = inputData[threadIndex];
            }
        }
    }
}
