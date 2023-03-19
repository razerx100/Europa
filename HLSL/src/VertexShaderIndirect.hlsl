#include "VertexProcessing.hlsli"

struct ModelData {
    matrix modelMat;
    matrix viewNormalMatrix;
    float3 modelOffset;
    float3 positiveBounds;
    float3 negativeBounds;
    float3 padding;
};

struct ModelInfo {
    uint index;
};

struct CameraMatrices {
    matrix view;
    matrix projection;
};

StructuredBuffer<ModelData> modelData : register(t0);
ConstantBuffer<ModelInfo> modelInfo : register(b0);
ConstantBuffer<CameraMatrices> camera : register(b1);

VertexOut main(float3 position : Position, float3 normal : Normal, float2 uv : UV) {
    const ModelData model = modelData[modelInfo.index];

    Vertex vertex;
    vertex.position = position;
    vertex.normal = normal;
    vertex.uv = uv;

    return GetVertexAttributes(
        model.modelMat, camera.view, camera.projection, model.viewNormalMatrix, vertex,
        model.modelOffset, modelInfo.index
    );
}