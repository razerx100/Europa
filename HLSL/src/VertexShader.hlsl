struct PerModelData {
    float2 uvOffset;
    float2 uvRatio;
    matrix modelMat;
    uint texIndex;
};

struct CameraMatrices {
    matrix view;
    matrix projection;
};

struct VSOut
{
    float2 uv : UV;
    uint texIndex : TexIndex;
    float4 position : SV_Position;
};

ConstantBuffer<PerModelData> modelData : register(b0);
ConstantBuffer<CameraMatrices> camera : register(b1);

VSOut main(float3 position : Position, float2 uv : UV) {
    VSOut obj;

    matrix transform = mul(camera.projection, mul(camera.view, modelData.modelMat));

    obj.position = mul(transform, float4(position, 1.0f));
    obj.uv = uv * modelData.uvRatio + modelData.uvOffset;
    obj.texIndex = modelData.texIndex;

    return obj;
}