# Europa
Europa consists of shaders written in HLSL and GLSL.

## Notes
### HLSL
Since HLSL doesn't have any specific extensions for its different types of shaders, write "Pixel" in front of the shader file while writing a new Pixel Shader to mark that it's a Pixel Shader. But the "Pixel" will be removed while generating the output binaries. So, use the name without the "Pixel" in front, while reading the shader binaries.

## Requirements
[glslc](https://github.com/google/shaderc) with SPIR-V target 1.4 support.\
[dxc](https://github.com/microsoft/DirectXShaderCompiler)