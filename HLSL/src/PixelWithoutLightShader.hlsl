#include "PixelData.hlsli"

float4 main(float2 uv : UV, uint modelIndex : ModelIndex) : SV_Target {
    Material material = b_materialData[modelIndex];
    float2 offsettedDiffuseUV = uv * material.diffuseTexUVRatio + material.diffuseTexUVOffset;

    return material.diffuse * g_textures[material.diffuseTexIndex].Sample(
        samplerState, offsettedDiffuseUV
    );
}