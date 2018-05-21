#version 330 core

layout (location = 0) in vec3 in_position;
layout (location = 1) in vec3 in_normal;
layout (location = 2) in vec2 in_texture;
layout (location = 3) in uint in_offset;

out vec3 fragment_position;
out vec3 fragment_normal;
smooth out vec2 fragment_texture;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform mat4 pieces[40];

void main(void) {
    mat4 M = model * pieces[in_offset];
    //mat4 M = model;
    fragment_position = vec3(M * vec4(in_position, 1.0));
    fragment_normal = mat3(transpose(inverse(M))) * in_normal;
    fragment_texture = in_texture;
    gl_Position = projection * view * vec4(fragment_position, 1.0);
}
