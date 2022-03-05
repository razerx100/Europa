#version 450

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec4 inColour;

layout(location = 0) out vec4 fragColour;

void main(){
	gl_Position = vec4(inPosition.x, -inPosition.y, inPosition.z, 1.0);
	fragColour = inColour;
}
