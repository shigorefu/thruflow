#include <metal_stdlib>
using namespace metal;

static float hash21(float2 value) {
    value = fract(value * float2(123.34, 456.21));
    value += dot(value, value + 45.32);
    return fract(value.x * value.y);
}

static half4 ribbonColor(
    int index,
    half4 color0,
    half4 color1,
    half4 color2,
    half4 color3,
    half4 color4,
    half4 color5,
    half4 color6
) {
    switch (index) {
        case 0: return color0;
        case 1: return color1;
        case 2: return color2;
        case 3: return color3;
        case 4: return color4;
        case 5: return color5;
        default: return color6;
    }
}

[[ stitchable ]] half4 flowStream(
    float2 position,
    half4 sourceColor,
    float2 size,
    float time,
    float progress,
    float identityReveal,
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
    half4 color4,
    half4 color5,
    half4 color6,
    half4 backgroundColor,
    float darkMode
) {
    constexpr int ribbonCount = 7;
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float3 accumulated = float3(0.0);
    float3 haloAccumulated = float3(0.0);
    float accumulatedWeight = 0.0;
    float haloWeight = 0.0;
    float dailyReveal = smoothstep(0.0, 1.0, clamp(identityReveal, 0.0, 1.0));

    // A new profile opens on the familiar neutral S-stream. The date/profile
    // topology is revealed continuously through the first Block, so Play never
    // replaces the current frame with a different picture.
    float legacySpine = 0.5;
    legacySpine += sin(uv.x * 3.14159 * 1.45 - time * 0.16) * 0.070;
    legacySpine += sin(uv.x * 6.28318 * 0.72 + time * 0.09) * 0.028;

    float directionSign = dailyBend < 0.5 ? -1.0 : 1.0;
    float topologyPhase = topology * 6.2831853;
    float dailySpine = 0.5;
    dailySpine += sin(uv.x * 4.10 + topologyPhase - time * 0.105) * mix(0.048, 0.082, topology);
    dailySpine += sin(uv.x * 7.15 - topologyPhase * 0.63 + time * 0.062) * 0.024 * directionSign;
    dailySpine += (uv.x - 0.5) * mix(-0.075, 0.075, dailyBend);
    float spine = mix(legacySpine, dailySpine, dailyReveal);

    float envelopeDistance = abs(uv.y - spine);
    float legacyEnvelope = 1.0 - smoothstep(0.30, 0.46, envelopeDistance);
    float dailyEnvelope = 1.0 - smoothstep(0.31, 0.46, envelopeDistance);
    float envelope = mix(legacyEnvelope, dailyEnvelope, dailyReveal);
    // Keep the daily lanes close enough that every ribbon remains inside the
    // visible flow envelope while preserving clear gaps between their cores.
    float laneSpan = mix(0.33, 0.40, dailySpacing);

    for (int index = 0; index < ribbonCount; index++) {
        float layer = float(index);
        float legacyLane = min(layer, 5.0) / 5.0;
        float dailyLane = layer / float(ribbonCount - 1);
        float legacySeed = hash21(float2(layer + 1.0, 3.7));
        float dailySeed = hash21(float2(layer + 1.0, topology * 9.7 + 2.3));
        int depthIndex = index % 3;
        float depthLane = float(depthIndex);
        float legacyDepthSpeed = depthIndex == 0 ? 0.70 : (depthIndex == 1 ? 1.0 : 1.24);
        float dailyDepthSpeed = depthIndex == 0 ? 0.76 : (depthIndex == 1 ? 1.0 : 1.20);
        float legacyPhase = time * mix(0.78, 1.22, legacySeed) * legacyDepthSpeed + layer * 0.91;
        float dailyPhase = time * mix(0.76, 1.18, dailySeed) * dailyDepthSpeed;
        dailyPhase += layer * mix(0.72, 1.12, topology);

        float legacyPrimary = sin(uv.x * 6.28318 * waveFrequency + legacyPhase);
        float legacySecondary = sin(
            uv.x * 12.56636 * (0.72 + legacySeed * 0.34) - legacyPhase * 0.63
        );
        float dailyPrimary = sin(
            uv.x * 6.2831853 * waveFrequency
                + dailyPhase
                + topologyPhase * mix(-0.45, 0.45, dailyLane)
        );
        float dailySecondary = sin(
            uv.x * 12.5663706 * mix(0.68, 1.02, dailySeed)
                - dailyPhase * 0.61
                + dailyBend * 3.4
        );

        float legacyCenter = legacySpine + mix(-0.245, 0.245, legacyLane);
        legacyCenter += (depthLane - 1.0) * sin(uv.x * 4.2 - time * 0.12) * 0.018;
        legacyCenter += legacyPrimary * mix(0.035, 0.075, turbulence);
        legacyCenter += legacySecondary * 0.020 * turbulence * detail;

        float dailyCenter = dailySpine + mix(-laneSpan, laneSpan, dailyLane);
        dailyCenter += (depthLane - 1.0)
            * sin(uv.x * 4.4 - time * 0.11 + topologyPhase)
            * mix(0.006, 0.025, depth);
        dailyCenter += dailyPrimary * mix(0.025, 0.060, turbulence);
        dailyCenter += dailySecondary * mix(0.006, 0.022, detail) * turbulence;
        float center = mix(legacyCenter, dailyCenter, dailyReveal);

        float legacyDepthScale = depthIndex == 0 ? 1.30 : (depthIndex == 1 ? 0.92 : 0.58);
        float legacyThickness = mix(0.070, 0.105, volume) * legacyDepthScale;
        // Daily ribbons should read as broad streams rather than hairlines.
        // Foreground lanes get the largest correction because their former
        // depth scale made them visually disappear on compact displays.
        float dailyDepthScale = depthIndex == 0 ? 1.20 : (depthIndex == 1 ? 0.98 : 0.78);
        float dailyThickness = mix(0.044, 0.066, volume) * dailyDepthScale;
        float thickness = mix(legacyThickness, dailyThickness, dailyReveal);
        float distanceToBand = abs(uv.y - center);
        float legacyBand = 1.0 - smoothstep(thickness * 0.52, thickness, distanceToBand);
        float dailyBand = 1.0 - smoothstep(thickness * 0.44, thickness, distanceToBand);
        float legacyGlow = 1.0 - smoothstep(thickness * 0.80, thickness * 1.90, distanceToBand);
        float dailyGlow = 1.0 - smoothstep(thickness * 0.72, thickness * 2.20, distanceToBand);
        float squaredDistance = distanceToBand * distanceToBand;
        float squaredThickness = max(thickness * thickness, 0.0001);
        float legacyHalo = exp(-squaredDistance / (squaredThickness * 4.20));
        float dailyHalo = exp(-squaredDistance / (squaredThickness * 5.00));
        float legacyMist = exp(-squaredDistance / (squaredThickness * 12.0));
        float dailyMist = exp(-squaredDistance / (squaredThickness * 14.0));
        float legacyEdgeLight = smoothstep(thickness * 0.62, thickness * 0.18, distanceToBand);
        float dailyEdgeLight = smoothstep(thickness * 0.66, thickness * 0.16, distanceToBand);

        float firstBlend = 0.5 + sin(uv.x * 4.8 + legacySeed * 6.28318 + time * 0.08) * 0.5;
        float secondBlend = 0.5 + sin(uv.x * 3.6 - legacySeed * 4.2 - time * 0.06) * 0.5;
        half4 firstPair = mix(color0, color1, half(firstBlend));
        half4 secondPair = mix(color2, color3, half(secondBlend));
        half4 legacySelected = mix(
            firstPair,
            secondPair,
            half(fract(legacyLane + progress * 0.45))
        );
        int colorIndex = (index + int(paletteRotation * float(ribbonCount))) % ribbonCount;
        half4 dailySelected = ribbonColor(
            colorIndex,
            color0,
            color1,
            color2,
            color3,
            color4,
            color5,
            color6
        );
        half4 selected = mix(legacySelected, dailySelected, half(dailyReveal));

        float legacyCurrent = 0.92
            + sin(uv.x * mix(15.0, 26.0, detail) - legacyPhase * 0.70) * 0.08 * detail;
        float legacyDepthOpacity = depthIndex == 0 ? 0.17 : (depthIndex == 1 ? 0.25 : 0.32);
        float legacyBrightness = (0.92 + legacyEdgeLight * 0.34 + progress * 0.10)
            * legacyCurrent;
        float legacyContribution = legacyBand * legacyDepthOpacity;
        legacyContribution += legacyGlow * mix(0.020, 0.045, detail);

        float dailyCurrent = 0.94
            + sin(uv.x * mix(13.0, 25.0, detail) - dailyPhase * 0.72) * 0.06 * detail;
        float dailyDepthOpacity = depthIndex == 0 ? 0.20 : (depthIndex == 1 ? 0.28 : 0.35);
        float dailyProgressReveal = mix(0.58, 1.0, progress);
        dailyProgressReveal *= mix(0.78, 1.0, 1.0 - abs(dailyLane - 0.5) * 2.0);
        float dailyBrightness = (
            0.88 + dailyEdgeLight * mix(0.18, 0.34, depth)
        ) * dailyCurrent;
        float dailyContribution = dailyBand * dailyDepthOpacity * dailyProgressReveal;
        dailyContribution += dailyGlow
            * mix(0.010, 0.048, glowStrength)
            * dailyProgressReveal;

        float brightness = mix(legacyBrightness, dailyBrightness, dailyReveal);
        float contribution = mix(legacyContribution, dailyContribution, dailyReveal);
        float layerVisibility = index < 6 ? 1.0 : dailyReveal;
        contribution *= layerVisibility;
        float band = mix(legacyBand, dailyBand, dailyReveal);
        float halo = mix(legacyHalo, dailyHalo, dailyReveal);
        float mist = mix(legacyMist, dailyMist, dailyReveal);
        float haloReveal = mix(0.72, 1.0, progress);
        float haloStrength = mix(0.105, 0.230, glowStrength)
            * mix(0.86, 1.08, depth);
        float mistStrength = mix(0.020, 0.060, glowStrength);
        float haloContribution = (
            max(halo - band * 0.56, 0.0) * haloStrength
                + mist * mistStrength
        ) * haloReveal * layerVisibility;

        accumulated += float3(selected.rgb) * brightness * contribution;
        haloAccumulated += float3(selected.rgb) * brightness * haloContribution;
        accumulatedWeight += contribution;
        haloWeight += haloContribution;
    }

    float legacyAmbientBlend = 0.5 + sin(uv.x * 3.4 - time * 0.045) * 0.5;
    float dailyAmbientBlend = 0.5
        + sin(uv.x * 3.1 + topologyPhase - time * 0.040) * 0.5;
    float ambientBlend = mix(legacyAmbientBlend, dailyAmbientBlend, dailyReveal);
    half4 ambientPair = mix(color0, color2, half(ambientBlend));
    half4 ambientAccent = mix(color1, color3, half(1.0 - ambientBlend));
    float ambientAccentMix = mix(0.34, 0.28, dailyReveal);
    float3 ambientColor = float3(
        mix(ambientPair, ambientAccent, half(ambientAccentMix)).rgb
    );
    float legacyAmbientStrength = mix(0.090, 0.145, progress);
    float dailyAmbientStrength = mix(0.045, 0.105, progress);
    float ambientStrength = mix(legacyAmbientStrength, dailyAmbientStrength, dailyReveal);
    float ambientField = mix(
        mix(0.72, 1.0, envelope),
        mix(0.62, 1.0, envelope),
        dailyReveal
    );

    float legacyShimmer = 0.96
        + sin((uv.x + uv.y) * 10.0 - time * 0.42) * 0.04 * detail;
    float dailyShimmer = 0.97
        + sin((uv.x + uv.y) * mix(8.0, 14.0, detail) - time * 0.32)
            * 0.03
            * detail;
    float shimmer = mix(legacyShimmer, dailyShimmer, dailyReveal);
    float3 rendered = (
        accumulated * envelope
            + haloAccumulated * mix(1.08, 1.42, glowStrength)
            + ambientColor * ambientStrength * ambientField
    ) * shimmer;

    if (impulse >= 0.0 && impulse <= 1.0) {
        float pulseDistance = abs(uv.x - impulse);
        float pulse = exp(-pulseDistance * pulseDistance * 180.0) * sin(impulse * 3.14159);
        rendered += rendered * pulse * mix(0.38, 0.34, dailyReveal);
    }

    float peak = max(max(rendered.r, rendered.g), rendered.b);
    float compressionThreshold = mix(0.90, 0.88, dailyReveal);
    if (peak > compressionThreshold) {
        float compressedPeak = compressionThreshold
            + mix(0.07, 0.08, dailyReveal)
                * (1.0 - exp(-(peak - compressionThreshold) * mix(1.7, 1.6, dailyReveal)));
        rendered *= compressedPeak / peak;
    }

    float3 background = float3(backgroundColor.rgb);
    float3 composited;

    if (darkMode > 0.5) {
        composited = background + rendered;
    } else {
        float legacyCoverage = clamp(
            accumulatedWeight * envelope * 1.18
                + haloWeight * 0.42
                + ambientStrength * ambientField * 0.22,
            0.045,
            0.82
        );
        float dailyCoverage = clamp(
            accumulatedWeight * envelope * 1.55
                + haloWeight * 0.52
                + ambientStrength * ambientField * 0.30,
            0.035,
            0.80
        );
        float coverage = mix(legacyCoverage, dailyCoverage, dailyReveal);
        float3 normalizedStream = accumulated / max(accumulatedWeight, 0.001);
        float3 legacyStreamInk = clamp(
            normalizedStream + rendered * 0.30,
            float3(0.0),
            float3(0.84)
        );
        float3 dailyStreamInk = clamp(
            normalizedStream * 0.70 + rendered * 0.34,
            float3(0.0),
            float3(0.80)
        );
        float3 streamInk = mix(legacyStreamInk, dailyStreamInk, dailyReveal);
        composited = mix(background, streamInk, coverage);
    }

    return half4(half3(clamp(composited, float3(0.0), float3(1.0))), half(1.0));
}
