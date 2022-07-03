struct UVInfo {
    float2 uvOffset;
    float2 uvRatio;
};

struct ModelMat {
    matrix modelMat;
};

struct CameraMatrices {
    matrix view;
    matrix projection;
};

struct VSOut
{
    float2 uv : UV;
    float4 position : SV_Position;
};

ConstantBuffer<UVInfo> uvInfo : register(b1);
ConstantBuffer<ModelMat> modelMatrix : register(b2);
ConstantBuffer<CameraMatrices> camera : register(b3);

VSOut main(float3 position : Position, float2 uv : UV) {
    VSOut obj;

    matrix transform = mul(camera.projection, mul(camera.view, modelMatrix.modelMat));

    obj.position = mul(transform, float4(position, 1.0f));

    obj.uv = uv * uvInfo.uvRatio + uvInfo.uvOffset;

    return obj;
}