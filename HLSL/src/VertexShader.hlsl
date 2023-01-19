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

struct ModelIndex {
    uint index;
};

struct CameraMatrices {
    matrix view;
    matrix projection;
};

struct VSOut {
    float2 uv : UV;
    uint texIndex : TexIndex;
    uint modelIndex : ModelIndex;
    float3 viewVertexPosition : ViewPosition;
    float3 normal : Normal;
    float4 position : SV_Position;
};

StructuredBuffer<PerModelData> b_modelData : register(t0);
ConstantBuffer<ModelIndex> b_modelIndex : register(b0);
ConstantBuffer<CameraMatrices> b_camera : register(b1);

VSOut main(float3 position : Position, float3 normal : Normal, float2 uv : UV) {
    VSOut obj;

    const PerModelData modelData = b_modelData[b_modelIndex.index];

    matrix viewSpace = mul(b_camera.view, modelData.modelMat);

    float4 vertexPosition = float4(position + modelData.modelOffset, 1.0);
    float4 viewVertexPosition = mul(viewSpace, vertexPosition);

    obj.position = mul(b_camera.projection, viewVertexPosition);
    obj.uv = uv * modelData.uvRatio + modelData.uvOffset;
    obj.texIndex = modelData.texIndex;
    obj.modelIndex = b_modelIndex.index;
    obj.viewVertexPosition = viewVertexPosition.xyz;
    obj.normal = mul((float3x3)modelData.viewNormalMatrix, normal);

    return obj;
}