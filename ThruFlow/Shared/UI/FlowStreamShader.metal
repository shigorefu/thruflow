#include <metal_stdlib>
using namespace metal;

static float hash21(float2 value) {
    value = fract(value * float2(123.34, 456.21));
    value += dot(value, value + 45.32);
    return fract(value.x * value.y);
}

static half4 weightedColor(
    float coordinate,
    half4 color0,
    half4 color1,
    half4 color2,
    half4 color3,
    float weight0,
    float weight1,
    float weight2,
    float weight3
) {
    float total = max(weight0 + weight1 + weight2 + weight3, 0.0001);
    float value = fract(coordinate) * total;
    if (value < weight0) {
        return color0;
    }
    if (value < weight0 + weight1) {
        return color1;
    }
    if (value < weight0 + weight1 + weight2) {
        return color2;
    }
    return color3;
}

[[ stitchable ]] half4 flowStream(
    float2 position,
    half4 sourceColor,
    float2 size,
    float time,
    float progress,
    float volume,
    float detail,
    float depth,
    float glowStrength,
    float waveFrequency,
    float turbulence,
    float impulse,
    float topology,
    float dailyBend,
    float dailySpacing,
    float paletteRotation,
    half4 color0,
    half4 color1,
    half4 color2,
    half4 color3,
    float weight0,
    float weight1,
    float weight2,
    float weight3,
    half4 backgroundColor,
    float darkMode
) {
    constexpr int ribbonCount = 7;
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float3 accumulated = float3(0.0);
    float accumulatedWeight = 0.0;

    // The date and profile seed select a stable topology. Progress never changes
    // the route itself, so starting Flow accelerates the existing picture.
    float directionSign = dailyBend < 0.5 ? -1.0 : 1.0;
    float topologyPhase = topology * 6.2831853;
    float spine = 0.5;
    spine += sin(uv.x * 4.10 + topologyPhase - time * 0.105) * mix(0.048, 0.082, topology);
    spine += sin(uv.x * 7.15 - topologyPhase * 0.63 + time * 0.062) * 0.024 * directionSign;
    spine += (uv.x - 0.5) * mix(-0.075, 0.075, dailyBend);

    float envelopeDistance = abs(uv.y - spine);
    float envelope = 1.0 - smoothstep(0.31, 0.46, envelopeDistance);
    float laneSpan = mix(0.37, 0.46, dailySpacing);

    for (int index = 0; index < ribbonCount; index++) {
        float layer = float(index);
        float lane = layer / float(ribbonCount - 1);
        float seed = hash21(float2(layer + 1.0, topology * 9.7 + 2.3));
        int depthIndex = index % 3;
        float depthLane = float(depthIndex);
        float depthSpeed = depthIndex == 0 ? 0.76 : (depthIndex == 1 ? 1.0 : 1.20);
        float phase = time * mix(0.76, 1.18, seed) * depthSpeed;
        phase += layer * mix(0.72, 1.12, topology);

        float primary = sin(
            uv.x * 6.2831853 * waveFrequency
                + phase
                + topologyPhase * mix(-0.45, 0.45, lane)
        );
        float secondary = sin(
            uv.x * 12.5663706 * mix(0.68, 1.02, seed)
                - phase * 0.61
                + dailyBend * 3.4
        );

        float laneOffset = mix(-laneSpan, laneSpan, lane);
        float parallax = (depthLane - 1.0)
            * sin(uv.x * 4.4 - time * 0.11 + topologyPhase)
            * mix(0.006, 0.025, depth);
        float center = spine + laneOffset + parallax;
        center += primary * mix(0.025, 0.060, turbulence);
        center += secondary * mix(0.006, 0.022, detail) * turbulence;

        float depthScale = depthIndex == 0 ? 1.18 : (depthIndex == 1 ? 0.88 : 0.62);
        float thickness = mix(0.032, 0.052, volume) * depthScale;
        float distanceToBand = abs(uv.y - center);
        float band = 1.0 - smoothstep(thickness * 0.44, thickness, distanceToBand);
        float glow = 1.0 - smoothstep(thickness * 0.72, thickness * 2.20, distanceToBand);
        float edgeLight = smoothstep(thickness * 0.66, thickness * 0.16, distanceToBand);

        half4 selected = weightedColor(
            lane * 0.82 + seed * 0.18 + paletteRotation,
            color0,
            color1,
            color2,
            color3,
            weight0,
            weight1,
            weight2,
            weight3
        );

        float current = 0.94
            + sin(uv.x * mix(13.0, 25.0, detail) - phase * 0.72) * 0.06 * detail;
        float depthOpacity = depthIndex == 0 ? 0.20 : (depthIndex == 1 ? 0.28 : 0.35);
        float reveal = mix(0.58, 1.0, progress);
        reveal *= mix(0.78, 1.0, 1.0 - abs(lane - 0.5) * 2.0);
        float brightness = (0.88 + edgeLight * mix(0.18, 0.34, depth)) * current;
        float contribution = band * depthOpacity * reveal;
        contribution += glow * mix(0.010, 0.048, glowStrength) * reveal;

        accumulated += float3(selected.rgb) * brightness * contribution;
        accumulatedWeight += contribution;
    }

    float ambientBlend = 0.5 + sin(uv.x * 3.1 + topologyPhase - time * 0.040) * 0.5;
    half4 ambientPair = mix(color0, color2, half(ambientBlend));
    half4 ambientAccent = mix(color1, color3, half(1.0 - ambientBlend));
    float3 ambientColor = float3(mix(ambientPair, ambientAccent, half(0.28)).rgb);
    float ambientStrength = mix(0.045, 0.105, progress);
    float ambientField = mix(0.62, 1.0, envelope);

    float shimmer = 0.97
        + sin((uv.x + uv.y) * mix(8.0, 14.0, detail) - time * 0.32) * 0.03 * detail;
    float3 rendered = (
        accumulated * envelope
            + ambientColor * ambientStrength * ambientField
    ) * shimmer;

    if (impulse >= 0.0 && impulse <= 1.0) {
        float pulseDistance = abs(uv.x - impulse);
        float pulse = exp(-pulseDistance * pulseDistance * 180.0) * sin(impulse * 3.14159);
        rendered += rendered * pulse * 0.34;
    }

    float peak = max(max(rendered.r, rendered.g), rendered.b);
    if (peak > 0.88) {
        float compressedPeak = 0.88 + 0.08 * (1.0 - exp(-(peak - 0.88) * 1.6));
        rendered *= compressedPeak / peak;
    }

    float3 background = float3(backgroundColor.rgb);
    float3 composited;

    if (darkMode > 0.5) {
        composited = background + rendered;
    } else {
        float coverage = clamp(
            accumulatedWeight * envelope * 1.55 + ambientStrength * ambientField * 0.30,
            0.035,
            0.80
        );
        float3 normalizedStream = accumulated / max(accumulatedWeight, 0.001);
        float3 streamInk = clamp(
            normalizedStream * 0.70 + rendered * 0.34,
            float3(0.0),
            float3(0.80)
        );
        composited = mix(background, streamInk, coverage);
    }

    return half4(half3(clamp(composited, float3(0.0), float3(1.0))), half(1.0));
}
