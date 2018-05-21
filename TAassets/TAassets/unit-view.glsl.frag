#version 330 core
precision highp float;

smooth in vec2 fragment_texture;

out vec4 out_color;

uniform sampler2D colorTexture;
uniform vec4 objectColor;

void main(void) {
    if (objectColor.a == 0.0) {
        out_color = texture(colorTexture, fragment_texture);
    }
    else {
        out_color = objectColor;
    }
}
