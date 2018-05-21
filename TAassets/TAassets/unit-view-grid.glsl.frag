#version 330 core
precision highp float;

out vec4 out_color;

uniform vec4 objectColor;

void main(void) {
    out_color = objectColor;
}
