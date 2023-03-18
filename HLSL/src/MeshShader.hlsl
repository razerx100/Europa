struct Vertex {
    float3 position;
    float3 normal;
    float2 uv;
};

struct PerModelData {
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

struct MeshletOffset {
    uint offset;
};

struct VertexOut {
    float2 uv : UV;
    uint modelIndex : ModelIndex;
    float3 viewVertexPosition : ViewPosition;
    float3 normal : Normal;
    float4 position : SV_Position;
};

ConstantBuffer<MeshletOffset> meshletOffset : register(b0);
ConstantBuffer<CameraMatrices> camera : register(b1);
StructuredBuffer<PerModelData> modelData : register(t0);
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

    const PerModelData model = modelData[modelIndex];
    matrix viewSpace = mul(camera.view, model.modelMat);
    float4 vertexPosition = float4(vertex.position + model.modelOffset, 1.0);
    float4 viewVertexPosition = mul(viewSpace, vertexPosition);

    VertexOut vout;
    vout.position = mul(camera.projection, viewVertexPosition);
    vout.viewVertexPosition = viewVertexPosition.xyz;
    vout.normal = mul((float3x3)model.viewNormalMatrix, vertex.normal);
    vout.uv = vertex.uv;
    vout.modelIndex = modelIndex;

    return vout;
}

[NumThreads(128, 1, 1)]
[OutputTopology("triangle")]
void main(
    uint gtid : SV_GroupThreadID, uint gid : SV_GroupID,
    out indices uint3 prims[126], out vertices VertexOut verts[64]
) {
    Meshlet meshlet = meshlets[meshletOffset.offset + gid];

    SetMeshOutputCounts(meshlet.vertCount, meshlet.primCount);

    if (gtid < meshlet.primCount)
        prims[gtid] = GetPrimitive(meshlet, gtid);

    if (gtid < meshlet.vertCount)
        verts[gtid] = GetVertexAttributes(
            meshletOffset.offset, GetVertexIndex(meshlet, gtid)
        );
}