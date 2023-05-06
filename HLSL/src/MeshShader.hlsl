#include "VertexProcessing.hlsli"

struct ModelData {
    matrix modelMat;
    matrix viewNormalMatrix;
    float3 modelOffset;
    float padding;
};

struct Meshlet {
    uint vertCount;
    uint vertOffset;
    uint primCount;
    uint primOffset;
};

struct CameraMatrices {
    matrix view;
    matrix projection;
};

struct ModelInfo {
    uint index;
    uint meshletOffset;
};

ConstantBuffer<ModelInfo> modelInfo : register(b0);
ConstantBuffer<CameraMatrices> camera : register(b1);
StructuredBuffer<ModelData> modelData : register(t0);
StructuredBuffer<Vertex> vertices : register(t3);
StructuredBuffer<uint> vertexIndices : register(t4);
StructuredBuffer<uint> primIndices : register(t5);
StructuredBuffer<Meshlet> meshlets : register(t6);

uint3 UnpackPrimitive(uint primitive) {
    return uint3(primitive & 0x3FF, (primitive >> 10) & 0x3FF, (primitive >> 20) & 0x3FF);
}

uint3 GetPrimitive(Meshlet meshlet, uint index) {
    return UnpackPrimitive(primIndices[meshlet.primOffset + index]);
}

uint GetVertexIndex(Meshlet meshlet, uint localIndex) {
    return vertexIndices[meshlet.vertOffset + localIndex];
}

VertexOut GetVertexAttributes(uint modelIndex, uint vertexIndex) {
    Vertex vertex = vertices[vertexIndex];

    const ModelData model = modelData[modelIndex];

    return GetVertexAttributes(
        model.modelMat, camera.view, camera.projection, model.viewNormalMatrix,
        vertex, model.modelOffset, modelIndex
    );
}

[NumThreads(128, 1, 1)]
[OutputTopology("triangle")]
void main(
    uint gtid : SV_GroupThreadID, uint gid : SV_GroupID,
    out indices uint3 prims[126], out vertices VertexOut verts[64]
) {
    Meshlet meshlet = meshlets[modelInfo.meshletOffset + gid];

    SetMeshOutputCounts(meshlet.vertCount, meshlet.primCount);

    if (gtid < meshlet.primCount)
        prims[gtid] = GetPrimitive(meshlet, gtid);

    if (gtid < meshlet.vertCount)
        verts[gtid] = GetVertexAttributes(modelInfo.index, GetVertexIndex(meshlet, gtid));
}