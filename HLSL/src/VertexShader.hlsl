struct VSOut {
    float4 colour : Colour;
    float4 position : SV_Position;
};

VSOut main(float3 position : Position, float4 colour : Colour) {
    VSOut obj;
    obj.position = float4(position, 1.0f);
    obj.colour = colour;

    return obj;
}