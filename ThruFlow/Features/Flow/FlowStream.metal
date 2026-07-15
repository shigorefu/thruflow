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
    float detail,
    float layerCount,
    float waveFrequency,
    float turbulence,
    float impulse,
    half4 color0,
    half4 color1,
    half4 color2,
    half4 color3
) {
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float3 accumulated = float3(0.0);
    float accumulatedWeight = 0.0;
    int count = clamp(int(layerCount), 1, 8);

    // Every layer follows one shared channel. This keeps the scene readable as a
    // stream instead of filling the whole surface when daily progress grows.
    float spine = 0.5;
    spine += sin(uv.x * 3.14159 * 1.45 - time * 0.16) * 0.070;
    spine += sin(uv.x * 6.28318 * 0.72 + time * 0.09) * 0.028;
    float envelopeDistance = abs(uv.y - spine);
    float envelope = 1.0 - smoothstep(0.30, 0.46, envelopeDistance);

    for (int index = 0; index < count; index++) {
        float layer = float(index);
        float seed = hash21(float2(layer + 1.0, 3.7));
        float lane = count == 1 ? 0.5 : layer / float(count - 1);
        int depthIndex = index % 3;
        float depth = float(depthIndex);
        float depthSpeed = depthIndex == 0 ? 0.70 : (depthIndex == 1 ? 1.0 : 1.24);
        float phase = time * mix(0.78, 1.22, seed) * depthSpeed + layer * 0.91;
        float primary = sin(uv.x * 6.28318 * waveFrequency + phase);
        float secondary = sin(uv.x * 12.56636 * (0.72 + seed * 0.34) - phase * 0.63);
        float laneOffset = mix(-0.245, 0.245, lane);
        float parallax = (depth - 1.0) * sin(uv.x * 4.2 - time * 0.12) * 0.018;
        float center = spine + laneOffset + parallax;
        center += primary * mix(0.035, 0.075, turbulence);
        center += secondary * 0.020 * turbulence * detail;

        float baseThickness = mix(0.070, 0.105, volume);
        float depthScale = depthIndex == 0 ? 1.30 : (depthIndex == 1 ? 0.92 : 0.58);
        float thickness = baseThickness * depthScale;

        float distanceToBand = abs(uv.y - center);
        float band = 1.0 - smoothstep(thickness * 0.52, thickness, distanceToBand);
        float glow = 1.0 - smoothstep(thickness * 0.80, thickness * 1.90, distanceToBand);
        float edgeLight = smoothstep(thickness * 0.62, thickness * 0.18, distanceToBand);

        float firstBlend = 0.5 + sin(uv.x * 4.8 + seed * 6.28318 + time * 0.08) * 0.5;
        float secondBlend = 0.5 + sin(uv.x * 3.6 - seed * 4.2 - time * 0.06) * 0.5;
        half4 firstPair = mix(color0, color1, half(firstBlend));
        half4 secondPair = mix(color2, color3, half(secondBlend));
        half4 selected = mix(firstPair, secondPair, half(fract(lane + progress * 0.45)));
        float fineCurrent = 0.92 + sin(uv.x * mix(15.0, 26.0, detail) - phase * 0.70) * 0.08 * detail;
        float depthOpacity = depthIndex == 0 ? 0.17 : (depthIndex == 1 ? 0.25 : 0.32);
        float brightness = (0.92 + edgeLight * 0.34 + progress * 0.10) * fineCurrent;
        float contribution = band * depthOpacity + glow * mix(0.020, 0.045, detail);

        accumulated += float3(selected.rgb) * brightness * contribution;
        accumulatedWeight += contribution;
    }

    float ambientBlend = 0.5 + sin(uv.x * 3.4 - time * 0.045) * 0.5;
    half4 ambientPair = mix(color0, color2, half(ambientBlend));
    half4 ambientAccent = mix(color1, color3, half(1.0 - ambientBlend));
    float3 ambientColor = float3(mix(ambientPair, ambientAccent, half(0.34)).rgb);
    float ambientStrength = mix(0.090, 0.145, progress);
    float ambientField = mix(0.72, 1.0, envelope);

    float shimmer = 0.96 + sin((uv.x + uv.y) * 10.0 - time * 0.42) * 0.04 * detail;
    float3 rendered = (accumulated * envelope + ambientColor * ambientStrength * ambientField) * shimmer;

    // A completed half Block sends one restrained energy pulse through the channel.
    if (impulse >= 0.0 && impulse <= 1.0) {
        float pulseDistance = abs(uv.x - impulse);
        float pulse = exp(-pulseDistance * pulseDistance * 180.0) * sin(impulse * 3.14159);
        rendered += rendered * pulse * 0.38;
    }

    float peak = max(max(rendered.r, rendered.g), rendered.b);

    // Compress highlights after composition so overlapping colors stay saturated
    // without becoming a featureless white field.
    if (peak > 0.90) {
        float compressedPeak = 0.90 + 0.07 * (1.0 - exp(-(peak - 0.90) * 1.7));
        rendered *= compressedPeak / peak;
    }

    float alpha = clamp(accumulatedWeight * envelope + 0.64, 0.64, 1.0);
    return half4(half3(rendered), half(alpha));
}
