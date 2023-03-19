struct Vertex {
    float3 position;
    float3 normal;
    float2 uv;
};

struct VertexOut {
    float2 uv : UV;
    uint modelIndex : ModelIndex;
    float3 viewVertexPosition : ViewPosition;
    float3 normal : Normal;
    float4 position : SV_Position;
};

VertexOut GetVertexAttributes(
    matrix modelM, matrix viewM, matrix projectionM, matrix viewNormalM, Vertex vertex,
    float3 modelOffset, uint modelIndex
) {
    matrix viewSpace = mul(viewM, modelM);
    float4 vertexPosition = float4(vertex.position + modelOffset, 1.0);
    float4 viewVertexPosition = mul(viewSpace, vertexPosition);

    VertexOut vout;
    vout.position = mul(projectionM, viewVertexPosition);
    vout.viewVertexPosition = viewVertexPosition.xyz;
    vout.normal = mul((float3x3)viewNormalM, vertex.normal);
    vout.uv = vertex.uv;
    vout.modelIndex = modelIndex;

    return vout;
}
