#version 330

#moj_import <minecraft:light.glsl>
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:projection.glsl>
#moj_import <minecraft:globals.glsl>

uniform sampler2D Sampler0;

in float sphericalVertexDistance;
in float cylindricalVertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec2 texCoord1;
in vec3 vertexPosition;
in float skyboxColorIndex;
in float skyboxQuality;
in vec3 camWorldPos;
in float timeOfDay;

out vec4 fragColor;

const float waterHeight = 49.9;

// Noise primitives

vec2 noise_random2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)),
                          dot(p, vec2(269.5, 183.3)))) * 43758.5453) * 2.0 - 1.0;
}

float noise_perlin(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = dot(noise_random2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
    float b = dot(noise_random2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
    float c = dot(noise_random2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
    float d = dot(noise_random2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float noise_ridgedPerlin(vec2 p) {
    float sum = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 3; i++) {
        float n = noise_perlin(p * freq);
        n = 1.0 - abs(n);
        n *= n;
        sum += n * amp;
        freq *= 2.0;
        amp *= 0.5;
    }
    return sum;
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise_ridgedPerlin(p * 0.1);
        p  = p * 2.0 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

// Wave / normal
vec2 getTimeOffsets() {
    float time = GameTime * 1200.0 * 20.;
    return vec2(time * 0.012, time * 0.008);
}

float getWave(vec2 uv) {
    vec2 t = getTimeOffsets();
    vec2 uvA = uv * 0.7 + t;
    vec2 uvB = uv * 0.4 + vec2(-t.x * 0.75, t.y * 1.75);
    return fbm(uvA) * 0.6 + fbm(uvB) * 0.4;
}

void getWaveAndNormal(vec2 uv, out float wave, out vec3 normal) {
    const float eps = 0.01;
    wave = getWave(uv);
    float waveRight = getWave(uv + vec2(eps, 0.0));
    float waveUp = getWave(uv + vec2(0.0, eps));
    normal = normalize(vec3(waveRight - wave, eps, waveUp - wave));
}

// Lighting

vec3 getLightDir() {
    float dayTime = (timeOfDay > 0.0) ? 30.0 : 0.0;
    float angle = dayTime / 24000.0 * 6.2831853;
    vec3 sunDir = vec3(cos(angle), sin(angle), 0.0);
    return normalize(mix(vec3(0.0, 1.0, 0.0), sunDir, 0.5));
}

// Sky / water

vec3 getMinecraftSkyWithClouds(vec3 rayDir) {
    if (abs(rayDir.y) < 0.01) rayDir.y = 0.01;

    const vec3 skyColor = vec3(0.435, 0.794, 0.884);

    float t = (waterHeight - camWorldPos.y) / rayDir.y;
    if (t < 0.0) {
        // Sky
        vec3 sunDir = getLightDir();
        float sunIntensity = max(dot(rayDir, sunDir), 0.0);
        float horizonFactor = smoothstep(0.0, 0.5, rayDir.y);
        vec3 col = mix(skyColor, vec3(1.0), pow(sunIntensity, 16.0) * 0.8);
        col = mix(col, vec3(0.635, 0.794, 0.884), horizonFactor * 0.5);
        return col;
    }

    // Water
    vec3 hit = camWorldPos + rayDir * t;
    vec2 waterUv = hit.xz;
    float distSq = dot(hit - camWorldPos, hit - camWorldPos);

    if (distSq > 10000.0) return skyColor;

    float fog = (distSq > 2500.0) ? (sqrt(distSq) - 50.0) / 50.0 : 0.0;

    float wave;
    vec3 normal;
    getWaveAndNormal(waterUv, wave, normal);

    vec3 lightDir = getLightDir();
    float NdotL = max(dot(normal, lightDir), 0.0);
    vec3 viewDir = normalize(camWorldPos - hit);
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 16.0);
    float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 3.0) * 0.65 + 0.35;

    const vec3 deepColor = vec3(0.04, 0.12, 0.26);
    const vec3 shallowColor = vec3(0.12, 0.38, 0.55);

    vec3 waterColor = mix(deepColor, shallowColor, wave);
    vec3 diffuse = waterColor * NdotL;
    vec3 reflection = skyColor * fresnel;

    vec3 finalColor = diffuse + spec * 0.8;
    finalColor = mix(finalColor, reflection, fresnel);
    finalColor = mix(finalColor, skyColor, fog);
    return finalColor;
}



void main() {
    float texAlpha = texture(Sampler0, texCoord0).a * 255.0;
    bool isSkyPixel = abs(texAlpha - 254.0) < 1.0;

    if (isSkyPixel) {
        if (skyboxQuality > 0.0) {
            vec3 viewDir = normalize(vertexPosition);
            fragColor = vec4(getMinecraftSkyWithClouds(viewDir), 1.0);
            return;
        }
    }

    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    if (color.a < 0.1) {
        discard;
    }
    
    fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
}