struct VSOut {
    float4 color : Color;
    float4 position : SV_Position;
};

VSOut main(float3 position : Position, float4 color : Color) {
    VSOut obj;
    obj.position = float4(position, 1.0f);
    obj.color = color;

    return obj;
}