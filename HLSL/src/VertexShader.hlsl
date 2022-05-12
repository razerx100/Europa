struct TextureInfo {
    uint uStart;
    uint uEnd;
    uint uMax;
    uint vStart;
    uint vEnd;
    uint vMax;
};

struct Model {
    matrix model;
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

ConstantBuffer<TextureInfo> texInfo : register(b1);
ConstantBuffer<Model> modelMatrix : register(b2);
ConstantBuffer<CameraMatrices> camera : register(b3);

float PixelToUV(uint pixelCoord, uint maxLength) {
    return (float)((pixelCoord - 1) * 2 + 1) / (maxLength * 2);
}

VSOut main(float3 position : Position) {
    VSOut obj;

    matrix transform = mul(camera.projection, mul(camera.view, modelMatrix.model));

    obj.position = mul(transform, float4(position, 1.0f));

    obj.uv = float2(
        PixelToUV(texInfo.uStart, texInfo.uMax),
        PixelToUV(texInfo.vStart, texInfo.vMax)
    );

    return obj;
}