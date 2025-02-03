struct VertexOut
{
    float3 worldVertexPosition : WorldPosition;
    float3 worldNormal         : WorldNormal;
    float2 uv                  : UV;
    uint   modelIndex          : ModelIndex;
    uint   materialIndex       : MaterialIndex;
    float4 position            : SV_Position;
};

struct ModelData
{
    matrix modelMatrix;
    matrix normalMatrix; // In world space.
    float4 modelOffset; // materialIndex on the last component.
    uint   meshIndex;
    float  modelScale;
    uint   padding[2];
};

struct Frustum
{
	float4 left;
	float4 right;
	float4 bottom;
	float4 top;
	float4 near;
	float4 far;
};

struct Vertex
{
    float3 position;
    float3 normal;
    float2 uv;
};

struct CameraMatrices
{
    matrix  view;
    matrix  projection;
    Frustum frustum;
    float4  viewPosition;
};

struct ConstantData
{
    uint modelIndex;
};

StructuredBuffer<ModelData> modelData     : register(t0);

ConstantBuffer<ConstantData> constantData : register(b0);
ConstantBuffer<CameraMatrices> cameraData : register(b1);

VertexOut GetVertexAttributes(
    matrix modelM, matrix viewM, matrix projectionM, matrix normalM, Vertex vertex,
	float3 modelOffset, uint modelIndex, uint materialIndex
) {
    float4 vertexPosition      = float4(vertex.position + modelOffset, 1.0);
    float4 worldVertexPosition = mul(modelM, vertexPosition);

    VertexOut vout;
    vout.position            = mul(projectionM, mul(viewM, mul(modelM, vertexPosition)));
    vout.worldVertexPosition = worldVertexPosition.xyz;
    vout.worldNormal         = normalize(mul((float3x3) normalM, vertex.normal));
    vout.uv                  = vertex.uv;
    vout.modelIndex          = modelIndex;
    vout.materialIndex       = materialIndex;

    return vout;
}

VertexOut main(float3 position : Position, float3 normal : Normal, float2 uv : UV)
{
	const ModelData model = modelData[constantData.modelIndex];

    Vertex vertex;
    vertex.position = position;
    vertex.normal   = normal;
    vertex.uv       = uv;

    float3 modelOffset = model.modelOffset.xyz;
    uint materialIndex = asuint(model.modelOffset.w);

    return GetVertexAttributes(
    	model.modelMatrix, cameraData.view, cameraData.projection, model.normalMatrix, vertex,
    	modelOffset, constantData.modelIndex, materialIndex
    );
}
