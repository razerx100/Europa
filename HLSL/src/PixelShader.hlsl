Texture2D g_textures[] : register(t1);
SamplerState samplerState : register(s0);

float4 main(float2 uv: UV, uint texIndex : TexIndex) : SV_Target {
    return g_textures[texIndex].Sample(samplerState, uv);
}
