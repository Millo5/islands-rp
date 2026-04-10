#version 330

#moj_import <minecraft:light.glsl>
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:projection.glsl>
#moj_import <minecraft:globals.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in vec2 UV1;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler2;

out float sphericalVertexDistance;

out float cylindricalVertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec2 texCoord1;
out vec2 texCoord2;
out vec3 vertexPosition;
out vec4 baseColor;
out float skyboxColorIndex;
out float skyboxQuality;
out vec3 modelPos;
out mat4 invProjView;

out float timeOfDay;
out vec3 camWorldPos;

bool is_color(vec4 c,int r,int g,int b) {
    return (int(c.x*255.0)==r && int(c.y*255.0)==g && int(c.z*255.0)==b);
}

vec3 rgb(int r, int g, int b) {
    return vec3(r / 255.0, g / 255.0, b / 255.0);
}

const float transition_phase = 0.2;
const float transition_phase_threshold = 1.0-transition_phase;
const float transition_phase_multiplier = 1.0/transition_phase;

void main() {
    vec3 pos = Position + ModelOffset;
    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);

    modelPos = Position;
    invProjView = inverse(ProjMat * ModelViewMat);

    camWorldPos = CameraBlockPos - CameraOffset - vec3(1200, 1, 170000.); // ModelViewMat[3].xyz;


    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);
    vertexPosition = Position;
    baseColor = Color;
    skyboxColorIndex = 1.0;
    skyboxQuality = 1.0;
    if (is_color(Color,255,0,0) || is_color(Color,128,0,0)){
        skyboxColorIndex = 1.0;
    }
    if (is_color(Color,0,255,0) || is_color(Color,0,128,0)){
        skyboxColorIndex = 2.0;
    }
    if (is_color(Color,128,128,128) || is_color(Color,128,0,0) || is_color(Color,0,128,0)){
        skyboxQuality = 0.0;
    }
    vertexColor = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, Color) * texelFetch(Sampler2, UV2 / 16, 0);
    if (is_color(Color,16,32,64)){ // #102040: team rotation color
        int team_index = int(floor(GameTime * 1200))%8;
        float progress_next_color = GameTime * 1200 - floor(GameTime * 1200);
        vec3 team_color = vec3(1.0,1.0,1.0);
        vec3 next_color = vec3(1.0,1.0,1.0);
        switch (team_index) {
            case 0: team_color = rgb(228,45,56); next_color = rgb(52,122,208); break;
            case 1: team_color = rgb(52,122,208); next_color = rgb(137,221,71); break;
            case 2: team_color = rgb(137,221,71); next_color = rgb(250,209,52); break;
            case 3: team_color = rgb(250,209,52); next_color = rgb(255,125,0); break;
            case 4: team_color = rgb(255,125,0); next_color = rgb(200,92,156); break;
            case 5: team_color = rgb(200,92,156); next_color = rgb(61,63,76); break;
            case 6: team_color = rgb(61,63,76); next_color = rgb(200,213,229); break;
            case 7: team_color = rgb(200,213,229); next_color = rgb(228,45,56); break;
        }
        if (progress_next_color>transition_phase_threshold) {
            float t = (progress_next_color-transition_phase_threshold)*transition_phase_multiplier;
            team_color = team_color*(1.-t)+next_color*t;
        }
        vertexColor = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, vec4(team_color,Color.a)) * texelFetch(Sampler2, UV2 / 16, 0);
    }
    texCoord0 = UV0;
    texCoord1 = UV1;
    texCoord2 = UV2;
}
