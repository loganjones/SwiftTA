#version 330 core

layout (location = 0) in vec3 in_position;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main(void) {
    vec3 m_position = vec3(model * vec4(in_position, 1.0));
    gl_Position = projection * view * vec4(m_position, 1.0);
}
