#version 330 core
precision highp float;

in vec3 fragment_normal;
in vec3 fragment_position;
smooth in vec2 fragment_texture;

out vec4 out_color;

uniform sampler2D colorTexture;
uniform vec3 lightPosition;
uniform vec3 viewPosition;
uniform vec4 objectColor;

void main(void) {
    
    vec3 lightColor = vec3(1.0, 1.0, 1.0);

    // ambient
    float ambientStrength = 0.6;
    vec3 ambient = ambientStrength * lightColor;

    // diffuse
    float diffuseStrength = 0.4;
    vec3 norm = normalize(fragment_normal);
    vec3 lightDir = normalize(lightPosition - fragment_position);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diffuseStrength * diff * lightColor;

    // specular
    float specularStrength = 0.1;
    vec3 viewDir = normalize(viewPosition - fragment_position);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    vec3 specular = specularStrength * spec * lightColor;
    
    // all together now
    vec4 lightContribution = vec4(ambient + diffuse + specular, 1.0);

    if (objectColor.a == 0.0) {
        out_color = lightContribution * texture(colorTexture, fragment_texture);
    }
    else {
        out_color = lightContribution * objectColor;
    }
    
}
