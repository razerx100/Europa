struct PerModelData {
    matrix modelMat;
    matrix viewNormalMatrix;
    float3 modelOffset;
    float3 positiveBounds;
    float3 negativeBounds;
    float3 padding;
};

struct ModelInfo {
    uint index;
};

struct CameraMatrices {
    matrix view;
    matrix projection;
};

struct VSOut {
    float2 uv : UV;
    uint modelIndex : ModelIndex;
    float3 viewVertexPosition : ViewPosition;
    float3 normal : Normal;
    float4 position : SV_Position;
};

StructuredBuffer<PerModelData> b_modelData : register(t0);
ConstantBuffer<ModelInfo> b_modelInfo : register(b0);
ConstantBuffer<CameraMatrices> b_camera : register(b1);

VSOut main(float3 position : Position, float3 normal : Normal, float2 uv : UV) {
    VSOut obj;

    const PerModelData modelData = b_modelData[b_modelInfo.index];

    matrix viewSpace = mul(b_camera.view, modelData.modelMat);

    float4 vertexPosition = float4(position + modelData.modelOffset, 1.0);
    float4 viewVertexPosition = mul(viewSpace, vertexPosition);

    obj.position = mul(b_camera.projection, viewVertexPosition);
    obj.uv = uv;
    obj.modelIndex = b_modelInfo.index;
    obj.viewVertexPosition = viewVertexPosition.xyz;
    obj.normal = mul((float3x3)modelData.viewNormalMatrix, normal);

    return obj;
}