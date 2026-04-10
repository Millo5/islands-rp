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

const float cloudscale = 1.1;
const float clouddark = 0.5;
const float cloudlight = 0.3;
const float cloudcover = 0.2;
const float cloudalpha = 8.0;
const float skytint = 0.5;
const mat2 m = mat2(1.6, 1.2, -1.2, 1.6);

const float waterHeight = 49.9;

bool isTextureAlpha(float valueToExpected) {
    float epsilon = 1.0;
    float colorValue = texture(Sampler0, texCoord0).a * 255.0;
    return abs(colorValue - valueToExpected) < epsilon;
}


vec4 mod289(vec4 x)
{
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x)
{
  return mod289(((x*34.0)+10.0)*x);
}

vec4 taylorInvSqrt(vec4 r)
{
  return 1.79284291400159 - 0.85373472095314 * r;
}

vec2 fade(vec2 t) {
  return t*t*t*(t*(t*6.0-15.0)+10.0);
}

// Classic Perlin noise
float cnoise(vec2 P)
{
  vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
  vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
  Pi = mod289(Pi); // To avoid truncation effects in permutation
  vec4 ix = Pi.xzxz;
  vec4 iy = Pi.yyww;
  vec4 fx = Pf.xzxz;
  vec4 fy = Pf.yyww;

  vec4 i = permute(permute(ix) + iy);

  vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0 ;
  vec4 gy = abs(gx) - 0.5 ;
  vec4 tx = floor(gx + 0.5);
  gx = gx - tx;

  vec2 g00 = vec2(gx.x,gy.x);
  vec2 g10 = vec2(gx.y,gy.y);
  vec2 g01 = vec2(gx.z,gy.z);
  vec2 g11 = vec2(gx.w,gy.w);

  vec4 norm = taylorInvSqrt(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));

  float n00 = norm.x * dot(g00, vec2(fx.x, fy.x));
  float n01 = norm.y * dot(g01, vec2(fx.z, fy.z));
  float n10 = norm.z * dot(g10, vec2(fx.y, fy.y));
  float n11 = norm.w * dot(g11, vec2(fx.w, fy.w));

  vec2 fade_xy = fade(Pf.xy);
  vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
  float n_xy = mix(n_x.x, n_x.y, fade_xy.y);
  return 2.3 * n_xy;
}

// Classic Perlin noise, periodic variant
float pnoise(vec2 P, vec2 rep)
{
  vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
  vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
  Pi = mod(Pi, rep.xyxy); // To create noise with explicit period
  Pi = mod289(Pi);        // To avoid truncation effects in permutation
  vec4 ix = Pi.xzxz;
  vec4 iy = Pi.yyww;
  vec4 fx = Pf.xzxz;
  vec4 fy = Pf.yyww;

  vec4 i = permute(permute(ix) + iy);

  vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0 ;
  vec4 gy = abs(gx) - 0.5 ;
  vec4 tx = floor(gx + 0.5);
  gx = gx - tx;

  vec2 g00 = vec2(gx.x,gy.x);
  vec2 g10 = vec2(gx.y,gy.y);
  vec2 g01 = vec2(gx.z,gy.z);
  vec2 g11 = vec2(gx.w,gy.w);

  vec4 norm = taylorInvSqrt(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));

  float n00 = norm.x * dot(g00, vec2(fx.x, fy.x));
  float n01 = norm.y * dot(g01, vec2(fx.z, fy.z));
  float n10 = norm.z * dot(g10, vec2(fx.y, fy.y));
  float n11 = norm.w * dot(g11, vec2(fx.w, fy.w));

  vec2 fade_xy = fade(Pf.xy);
  vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
  float n_xy = mix(n_x.x, n_x.y, fade_xy.y);
  return 2.3 * n_xy;
}


vec2 random2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)),
                          dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);

    float minDist = 1.0;

    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(i, j);
            vec2 o = random2(n + g);
            vec2 r = g + o - f;
            float d = dot(r, r);
            minDist = min(minDist, d);
        }
    }

    return sqrt(minDist);
}

// float hash(float n) { return fract(sin(n) * 1e4); }
// float hash(vec2 p) { return fract(1e4 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x)))); }

// float noise(vec2 x) {
// 	vec2 i = floor(x);
// 	vec2 f = fract(x);

// 	// Four corners in 2D of a tile
// 	float a = hash(i);
// 	float b = hash(i + vec2(1.0, 0.0));
// 	float c = hash(i + vec2(0.0, 1.0));
// 	float d = hash(i + vec2(1.0, 1.0));

// 	// Simple 2D lerp using smoothstep envelope between the values.
// 	// return vec3(mix(mix(a, b, smoothstep(0.0, 1.0, f.x)),
// 	//			mix(c, d, smoothstep(0.0, 1.0, f.x)),
// 	//			smoothstep(0.0, 1.0, f.y)));

// 	// Same code, with the clamps in smoothstep and common subexpressions
// 	// optimized away.
// 	vec2 u = f * f * (3.0 - 2.0 * f);
// 	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
// }

vec2 noise_fade(vec2 t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

vec2 noise_random2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)),
                          dot(p, vec2(269.5, 183.3)))) * 43758.5453) * 2.0 - 1.0;
}

float noise_perlin(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = noise_fade(f);

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

    for (int i = 0; i < 5; i++) {
        float n = noise_perlin(p * freq);
        n = 1.0 - abs(n);
        n *= n;
        sum += n * amp;

        freq *= 2.0;
        amp *= 0.5;
    }

    return sum;
}

//
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        // v += a * noise(p * 0.2);
        // v += a * pnoise(p * 0.2, vec2(256.));
        // v += a * pow(1. - voronoi(p * 0.2), 0.9);
        v += a * noise_ridgedPerlin(p * 0.1);
        p  = p * 2.0 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

float getWave(vec2 uv) {
    float time = GameTime * 1200.0 * 20.;
    vec2 uvA = uv * 0.7 + vec2( time * 0.012,  time * 0.008);
    vec2 uvB = uv * 0.4 + vec2(-time * 0.009,  time * 0.014);
    return fbm(uvA) * 0.6 + fbm(uvB) * 0.4;
}

vec3 getNormal(vec2 uv) {
    float eps = 0.01;
    
    float waveCenter = getWave(uv);
    float waveRight = getWave(uv + vec2(eps, 0.0));
    float waveUp = getWave(uv + vec2(0.0, eps));
    vec3 normal = vec3(waveRight - waveCenter, eps, waveUp - waveCenter);
    return normalize(normal);
}

vec3 getLightDir() {
    float dayTime = 0.;

    if (timeOfDay > 0) {
        dayTime = 30;
    }

    vec3 axis = vec3(0.3, 0.0, 0.7);
    float angle = dayTime / 24000.0 * 2.0 * 3.1415926;

    vec3 sunDir = vec3(cos(angle), sin(angle), 0.0);
    sunDir = normalize(mix(vec3(0.0, 1.0, 0.0), sunDir, 0.5));
    return sunDir;
}

vec3 getMinecraftSkyWithClouds(vec3 rayDir) {
    vec3 CameraPos = camWorldPos;

    // return vec3(0, CameraPos.y, 0);

    if (abs(rayDir.y) < 0.01) {
        rayDir.y = 0.01;
    }
    vec3 skyColor = vec3(0.435, 0.794, 0.884);

    float t = (waterHeight - CameraPos.y) / rayDir.y;
    if (t < 0.0) {
        // The sun
        vec3 sunDir = getLightDir();
        float sunIntensity = max(dot(rayDir, sunDir), 0.0);
        float horizonFactor = smoothstep(0.0, 0.5, rayDir.y);

        skyColor = mix(skyColor, vec3(1.0), pow(sunIntensity, 16.0) * 0.8);
        skyColor = mix(skyColor, vec3(0.635, 0.794, 0.884), horizonFactor * 0.5);

        return skyColor;
    }

    vec3 intersectionPoint = CameraPos + rayDir * t;
    vec2 waterUv = intersectionPoint.xz;
    // return vec3(mod(waterUv, 1.), 0.);

    float distSquared = dot(intersectionPoint - CameraPos, intersectionPoint - CameraPos);
    if (distSquared > 10000.0) {
        return skyColor;
    }
    float fog = 0.;
    if (distSquared > 2500.0) {
        fog = (sqrt(distSquared) - 50.0) / 50.0;
    }

    // return vec3(mod(waterUv, 1.), 0.);

    // The waves
    float wave = getWave(waterUv);
    vec3 lightDir = getLightDir();
    vec3 normal = getNormal(waterUv);
    float NdotL = max(dot(normal, lightDir), 0.0);
    vec3 viewDir = normalize(CameraPos - intersectionPoint);
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 16.0);
    float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 3.0) * 0.65 + 0.35;


    vec3 deepColor    = vec3(0.04, 0.12, 0.26);
    vec3 shallowColor = vec3(0.12, 0.38, 0.55);
    vec3 foamColor    = vec3(1.);//vec3(0.65, 0.82, 0.90);


    vec3 waterColor = mix(deepColor, shallowColor, wave);
    vec3 diffuse = waterColor * NdotL;

    vec3 reflection = skyColor * fresnel;
    
    vec3 finalColor = diffuse + spec * 0.8;
    finalColor = mix(finalColor, reflection, fresnel);

    finalColor = mix(finalColor, skyColor, fog);

    return finalColor;

}

void main() {
    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    
    if(isTextureAlpha(254) && skyboxQuality>0.0) {
        vec3 viewDir = normalize(vertexPosition);
        vec3 clouds = getMinecraftSkyWithClouds(viewDir);
        fragColor = vec4(clouds, 1.0);
        return;
    }
    
    if(isTextureAlpha(254) && skyboxQuality==0.0) {
        fragColor = vec4(0.235, 0.694, 0.784, 1.0);
        if (skyboxColorIndex > 0.9) {
            fragColor = vec4(1.0,0.7,0.0,1.0);
        }
        if (skyboxColorIndex > 1.9) {
            fragColor = vec4(0.729,0.156,0.3607,1.0);
        }
        return;
    }

    if (color.a < 0.1) {
        discard;
    }
    
    fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
}