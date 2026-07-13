#include <metal_stdlib>
using namespace metal;

static float hash21(float2 value) {
    value = fract(value * float2(123.34, 456.21));
    value += dot(value, value + 45.32);
    return fract(value.x * value.y);
}

[[ stitchable ]] half4 flowStream(
    float2 position,
    half4 sourceColor,
    float2 size,
    float time,
    float progress,
    float volume,
    float layerCount,
    float waveFrequency,
    float turbulence,
    half4 color0,
    half4 color1,
    half4 color2,
    half4 color3
) {
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float3 accumulated = float3(0.0);
    float alpha = 0.0;
    int count = clamp(int(layerCount), 1, 10);
    float thickness = mix(0.210, 0.390, volume);

    for (int index = 0; index < count; index++) {
        float layer = float(index);
        float seed = hash21(float2(layer + 1.0, 3.7));
        float lane = count == 1 ? 0.5 : layer / float(count - 1);
        float phase = time * mix(0.78, 1.22, seed) + layer * 0.91;
        float primary = sin(uv.x * 6.28318 * waveFrequency + phase);
        float secondary = sin(uv.x * 12.56636 * (0.72 + seed * 0.34) - phase * 0.63);
        float slowBend = sin(uv.x * 3.14159 + time * 0.31 + layer * 0.47);
        float center = mix(0.20, 0.80, lane);
        center += primary * mix(0.07, 0.13, turbulence);
        center += secondary * 0.035 * turbulence;
        center += slowBend * 0.045;

        float distanceToBand = abs(uv.y - center);
        float band = 1.0 - smoothstep(thickness * 0.20, thickness, distanceToBand);
        float glow = 1.0 - smoothstep(thickness * 0.82, thickness * 2.55, distanceToBand);
        float edgeLight = smoothstep(thickness * 0.58, thickness * 0.18, distanceToBand);

        float firstBlend = 0.5 + sin(uv.x * 4.8 + seed * 6.28318 + time * 0.08) * 0.5;
        float secondBlend = 0.5 + sin(uv.x * 3.6 - seed * 4.2 - time * 0.06) * 0.5;
        half4 firstPair = mix(color0, color1, half(firstBlend));
        half4 secondPair = mix(color2, color3, half(secondBlend));
        half4 selected = mix(firstPair, secondPair, half(fract(lane + progress * 0.45)));
        float brightness = 0.78 + edgeLight * 0.30 + progress * 0.12;
        float contribution = band * (0.15 + seed * 0.07) + glow * 0.042;

        accumulated += float3(selected.rgb) * brightness * contribution;
        alpha = min(1.0, alpha + contribution * 0.72);
    }

    float shimmer = 0.97 + sin((uv.x + uv.y) * 10.0 - time * 0.42) * 0.03;
    accumulated *= shimmer;

    // Compress highlights with one shared scale so overlapping ribbons retain hue.
    float peak = max(max(accumulated.r, accumulated.g), accumulated.b);
    float compressedPeak = 0.88 * (1.0 - exp(-peak * 0.92));
    float3 mapped = peak > 0.0001 ? accumulated * (compressedPeak / peak) : accumulated;
    float luminance = dot(mapped, float3(0.2126, 0.7152, 0.0722));
    mapped = clamp(mix(float3(luminance), mapped, 1.12), 0.0, 0.92);

    return half4(half3(mapped), half(alpha));
}
