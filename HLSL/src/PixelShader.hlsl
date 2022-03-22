struct TextureConstants {
    uint texIndex;
};

ConstantBuffer<TextureConstants> texConstants : register(b0);
Texture2D g_textures[] : register(t0);
SamplerState samplerState : register(s0);

float4 main(float2 uv: UV) : SV_Target {
    return g_textures[texConstants.texIndex].Sample(samplerState, uv);
}
