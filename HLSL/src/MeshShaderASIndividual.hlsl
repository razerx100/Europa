#define AS_GROUP_SIZE 32

struct ModelData
{
	matrix modelMatrix;
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

struct Meshlet
{
	uint indexCount;
	uint indexOffset;
	uint primitiveCount;
	uint primitiveOffset;
};

struct CameraMatrices
{
	matrix  view;
	matrix  projection;
	Frustum frustum;
	float4  viewPosition;
};

struct ConeNormal
{
	uint  packedCone;
	float apexOffset;
};

struct MeshletDetails
{
	Meshlet    meshlet;
	float4     sphereBV;
	ConeNormal coneNormal;
};

struct MeshBundleDetails
{
	uint vertexOffset;
	uint vertexIndicesOffset;
	uint primitiveIndicesOffset;
	uint meshletOffset;
};

struct MeshDetails
{
	uint meshletCount;
	uint meshletOffset;
	uint primitiveOffset;
	uint vertexOffset;
};

// The constants are laid out as vec4s. Since ModelDetails
// isn't aligned to 16 bytes, I have to either align it or
// put it at the end.
struct ModelDetails
{
    MeshDetails meshDetails;
	uint        modelIndex;
};

struct ConstantData
{
	MeshBundleDetails meshBundleDetails;
	ModelDetails      modelDetails;
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

bool IsConeDegenerate(uint packedCone)
{
    return (packedCone >> 24) == 255;
}

float4 UnpackCone(uint packedCone)
{
    float4 unpackedCone;

    unpackedCone.x = float((packedCone >> 0) & 255);
    unpackedCone.y = float((packedCone >> 8) & 255);
    unpackedCone.z = float((packedCone >> 16) & 255);
    unpackedCone.w = float((packedCone >> 24) & 255);

    unpackedCone = unpackedCone / 255.0;

    unpackedCone.xyz = unpackedCone.xyz * 2.0 - 1.0;

    return unpackedCone;
}

bool IsOnOrForwardPlane(float4 plane, float4 centre, float radius)
{
    return -radius <= dot(plane, centre);
}

bool IsMeshletVisible(ModelData modelDataInst, MeshletDetails meshletDetails)
{
    matrix world             = modelDataInst.modelMatrix;

    float4 sphereBV          = meshletDetails.sphereBV;
    float scaledRadius       = sphereBV.w * modelDataInst.modelScale;
    float4 transformedCentre = mul(world, float4(sphereBV.xyz + modelDataInst.modelOffset.xyz, 1.0));

    Frustum frustum = cameraData.frustum;

    bool isInsideFrustum =
        IsOnOrForwardPlane(frustum.left,   transformedCentre, scaledRadius)
        && IsOnOrForwardPlane(frustum.right,  transformedCentre, scaledRadius)
        && IsOnOrForwardPlane(frustum.bottom, transformedCentre, scaledRadius)
        && IsOnOrForwardPlane(frustum.top,    transformedCentre, scaledRadius)
        && IsOnOrForwardPlane(frustum.near,   transformedCentre, scaledRadius)
        && IsOnOrForwardPlane(frustum.far,    transformedCentre, scaledRadius);

	if (!isInsideFrustum)
	    return false;

	ConeNormal coneNormal = meshletDetails.coneNormal;

	if (IsConeDegenerate(coneNormal.packedCone))
	    return true; // Cone is degenerate, the spread is more than 90 degrees.

	float4 unpackedCone = UnpackCone(coneNormal.packedCone);

	float3 coneAxis     = normalize(mul(world, float4(unpackedCone.xyz, 0))).xyz;

	float3 apex = transformedCentre.xyz - coneAxis * coneNormal.apexOffset * modelDataInst.modelScale;

	float3 viewPosition  = cameraData.viewPosition.xyz;
	float3 viewDirection = normalize(viewPosition - apex);

	// The w component has the -cos(angle + 90) degree
	// This is the minimum dot product on the negative axis, from which all the triangles are backface.
	if (dot(viewDirection, -coneAxis) > unpackedCone.w)
	    return false;

	return true;
}

[NumThreads(AS_GROUP_SIZE, 1, 1)]
void main(uint gtid : SV_GroupThreadID, uint dtid : SV_DispatchThreadID, uint gid : SV_GroupID)
{
	bool isMeshletVisible = false;

	ModelDetails modelDetails           = constantData.modelDetails;
	MeshDetails meshDetails             = modelDetails.meshDetails;
	MeshBundleDetails meshBundleDetails = constantData.meshBundleDetails;

	if (dtid < meshDetails.meshletCount)
	{
		uint meshletOffset            = meshBundleDetails.meshletOffset + meshDetails.meshletOffset;
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
