struct TextureInfo {
    uint uStart;
    uint uEnd;
    uint uMax;
    uint vStart;
    uint vEnd;
    uint vMax;
};

struct Transform {
    matrix view;
};

struct VSOut
{
    float2 uv : UV;
    float4 position : SV_Position;
};

ConstantBuffer<TextureInfo> texInfo : register(b1);
ConstantBuffer<Transform> viewMatrix : register(b2);

float PixelToUV(uint pixelCoord, uint maxLength) {
    return (float)((pixelCoord - 1) * 2 + 1) / (maxLength * 2);
}

VSOut main(float3 position : Position) {
    VSOut obj;
    obj.position = mul(viewMatrix.view, float4(position, 1.0f));

    obj.uv = float2(
        PixelToUV(texInfo.uStart, texInfo.uMax),
        PixelToUV(texInfo.vStart, texInfo.vMax)
    );

    return obj;
}