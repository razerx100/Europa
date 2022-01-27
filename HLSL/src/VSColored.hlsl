struct VSOut {
    float4 color : Color;
    float4 position : SV_Position;
};

VSOut main(float3 position : Position) {
    VSOut obj;
    obj.position = float4(position, 1.0f);
    obj.color = float4(1.0f, 0.0f, 1.0f, 1.0f);

    return obj;
}