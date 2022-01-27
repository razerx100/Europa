#version 450

layout(location = 0) in vec3 inPosition;

layout(location = 0) out vec4 fragColor;

void main(){
	gl_Position = vec4(inPosition, 1.0);
	fragColor = vec4(1.0f, 0.0f, 1.0f, 1.0f);
}
