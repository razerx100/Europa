struct PerModelData {
    float2 uvOffset;
    float2 uvRatio;
    matrix modelMat;
    uint texIndex;
    float3 modelOffset;
    float3 boundingBox[8];
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
    float4 position : SV_Position;
};

StructuredBuffer<PerModelData> b_modelData : register(t0);
ConstantBuffer<ModelIndex> b_modelIndex : register(b0);
ConstantBuffer<CameraMatrices> b_camera : register(b1);

VSOut main(float3 position : Position, float2 uv : UV) {
    VSOut obj;

    const PerModelData modelData = b_modelData[b_modelIndex.index];

    matrix transform = mul(b_camera.projection, mul(b_camera.view, modelData.modelMat));

    obj.position = mul(transform, float4(position + modelData.modelOffset, 1.0f));
    obj.uv = uv * modelData.uvRatio + modelData.uvOffset;
    obj.texIndex = modelData.texIndex;

    return obj;
}