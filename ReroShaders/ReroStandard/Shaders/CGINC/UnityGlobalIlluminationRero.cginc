// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_GLOBAL_ILLUMINATION_INCLUDED
#define UNITY_GLOBAL_ILLUMINATION_INCLUDED
#if defined(UNITY_SHOULD_SAMPLE_SH)
	#undef UNITY_SHOULD_SAMPLE_SH
	#define SAMPLE_SH_NONLINEAR
#endif

// Functions sampling light environment data (lightmaps, light probes, reflection probes), which is then returned as the UnityGI struct.

#include "UnityImageBasedLightingRero.cginc"
#include "UnityStandardUtilsRero.cginc"
#include "UnityShadowLibrary.cginc"

float shEvaluateDiffuseL1Geomerics(float L0, float3 L1, float3 n)
{
	// average energy
    float R0 = L0;

	// avg direction of incoming light
    float3 R1 = 0.5f * L1;

	// directional brightness
    float lenR1 = length(R1);

	// linear angle between normal and direction 0-1
    float q = dot(normalize(R1), n) * 0.5 + 0.5;

	// power for q
	// lerps from 1 (linear) to 3 (cubic) based on directionality
    float p = 1.0f + 2.0f * lenR1 / R0;

	// dynamic range constant
	// should vary between 4 (highly directional) and 0 (ambient)
    float a = (1.0f - lenR1 / R0) / (1.0f + lenR1 / R0);

    return R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p));
}

half3 getVertexLightsDir(float3 worldPos)
{
    half3 toLightX = half3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
    half3 toLightY = half3(unity_4LightPosX0.y, unity_4LightPosY0.y, unity_4LightPosZ0.y);
    half3 toLightZ = half3(unity_4LightPosX0.z, unity_4LightPosY0.z, unity_4LightPosZ0.z);
    half3 toLightW = half3(unity_4LightPosX0.w, unity_4LightPosY0.w, unity_4LightPosZ0.w);

    half3 dirX = toLightX - worldPos;
    half3 dirY = toLightY - worldPos;
    half3 dirZ = toLightZ - worldPos;
    half3 dirW = toLightW - worldPos;
    
    dirX *= length(toLightX);
    dirY *= length(toLightY);
    dirZ *= length(toLightZ);
    dirW *= length(toLightW);

    half3 dir = (dirX + dirY + dirZ + dirW);
    return normalize(dir); //Has to be normalized before feeding into LightDir, otherwise you end up with some weird behavior.
}

inline half3 DecodeDirectionalSpecularLightmap (half3 color, half4 dirTex, half3 normalWorld, bool isRealtimeLightmap, fixed4 realtimeNormalTex, out UnityLight o_light)
{
    o_light.color = color;
    o_light.dir = dirTex.xyz * 2 - 1;
    o_light.ndotl = 0; // Not use;

    // The length of the direction vector is the light's "directionality", i.e. 1 for all light coming from this direction,
    // lower values for more spread out, ambient light.
    half directionality = max(0.001, length(o_light.dir));
    o_light.dir /= directionality;

    #ifdef DYNAMICLIGHTMAP_ON
    if (isRealtimeLightmap)
    {
        // Realtime directional lightmaps' intensity needs to be divided by N.L
        // to get the incoming light intensity. Baked directional lightmaps are already
        // output like that (including the max() to prevent div by zero).
        half3 realtimeNormal = realtimeNormalTex.xyz * 2 - 1;
        o_light.color /= max(0.125, dot(realtimeNormal, o_light.dir));
    }
    #endif

    // Split light into the directional and ambient parts, according to the directionality factor.
    half3 ambient = o_light.color * (1 - directionality);
    o_light.color = o_light.color * directionality;

    // Technically this is incorrect, but helps hide jagged light edge at the object silhouettes and
    // makes normalmaps show up.
    //ambient *= saturate(dot(normalWorld, o_light.dir));
    return ambient;
}

inline void ResetUnityLight(out UnityLight outLight)
{
    outLight.color = half3(0, 0, 0);
    outLight.dir = half3(0, 1, 0); // Irrelevant direction, just not null
    outLight.ndotl = 0; // Not used
}

inline half3 SubtractMainLightWithRealtimeAttenuationFromLightmap (half3 lightmap, half attenuation, half4 bakedColorTex, half3 normalWorld)
{
    // Let's try to make realtime shadows work on a surface, which already contains
    // baked lighting and shadowing from the main sun light.
    half3 shadowColor = unity_ShadowColor.rgb;
    half shadowStrength = _LightShadowData.x;

    // Summary:
    // 1) Calculate possible value in the shadow by subtracting estimated light contribution from the places occluded by realtime shadow:
    //      a) preserves other baked lights and light bounces
    //      b) eliminates shadows on the geometry facing away from the light
    // 2) Clamp against user defined ShadowColor.
    // 3) Pick original lightmap value, if it is the darkest one.


    // 1) Gives good estimate of illumination as if light would've been shadowed during the bake.
    //    Preserves bounce and other baked lights
    //    No shadows on the geometry facing away from the light
    half ndotl = LambertTerm (normalWorld, _WorldSpaceLightPos0.xyz);
    half3 estimatedLightContributionMaskedByInverseOfShadow = ndotl * (1- attenuation) * _LightColor0.rgb;
    half3 subtractedLightmap = lightmap - estimatedLightContributionMaskedByInverseOfShadow;

    // 2) Allows user to define overall ambient of the scene and control situation when realtime shadow becomes too dark.
    half3 realtimeShadow = max(subtractedLightmap, shadowColor);
    realtimeShadow = lerp(realtimeShadow, lightmap, shadowStrength);

    // 3) Pick darkest color
    return min(lightmap, realtimeShadow);
}

half4 _FakeLight;
half _RampSmooth;
bool  _StylizeRamp;

half3 GetSHLength()
{
    half3 x, x1;
    x.r = length(unity_SHAr);
    x.g = length(unity_SHAg);
    x.b = length(unity_SHAb);
    x1.r = length(unity_SHBr);
    x1.g = length(unity_SHBg);
    x1.b = length(unity_SHBb);
    return x + x1;
}

inline void ResetUnityGI(out UnityGI outGI)
{
    ResetUnityLight(outGI.light);
    outGI.indirect.diffuse = 0;
    outGI.indirect.specular = 0;
}

inline UnityGI UnityGI_Base(UnityGIInput data, half occlusion, half3 normalWorld)
{
    UnityGI o_gi;
    ResetUnityGI(o_gi);

    // Base pass with Lightmap support is responsible for handling ShadowMask / blending here for performance reason
    #if defined(HANDLE_SHADOWS_BLENDING_IN_GI)
        half bakedAtten = UnitySampleBakedOcclusion(data.lightmapUV.xy, data.worldPos);
        float zDist = dot(_WorldSpaceCameraPos - data.worldPos, UNITY_MATRIX_V[2].xyz);
        float fadeDist = UnityComputeShadowFadeDistance(data.worldPos, zDist);
        data.atten = UnityMixRealtimeAndBakedShadows(data.atten, bakedAtten, UnityComputeShadowFade(fadeDist));
    #endif

    o_gi.light = data.light;
    #if defined(USING_DIRECTIONAL_LIGHT)
	    float attenuationChange = data.atten + _RampSmooth;
	    float shadow = smoothstep(0, attenuationChange, data.atten);
    #else
	    //for other light types (point, spot), put the cutoff near black, so the falloff doesn't affect the range
	    float attenuationChange = fwidth(data.atten);
	    float shadow = smoothstep(0, attenuationChange, data.atten);
    #endif
    float nShadow = pow(1-shadow, 5);
    shadow = saturate(shadow + (1-nShadow));
    
	UNITY_BRANCH
	if (!_StylizeRamp) shadow = data.atten;
    o_gi.light.color *= shadow;

    UNITY_BRANCH
    half3 probeLightDir = normalize(mul(unity_ColorSpaceLuminance.rgb, half3x3(unity_SHAr.xyz, unity_SHAg.xyz, unity_SHAb.xyz)));
    if (any(_WorldSpaceLightPos0) == 0)
    {
        o_gi.light.dir += probeLightDir;
    }

    half3 vertexDir = getVertexLightsDir(data.worldPos);
    #if defined(VERTEXLIGHT_ON)
        o_gi.light.dir += (probeLightDir + vertexDir);
    #endif

    #if !defined(POINT) && !defined(SPOT) && !defined(VERTEXLIGHT_ON)
            if (length(unity_SHAr.xyz * unity_SHAr.w + unity_SHAg.xyz * unity_SHAg.w + unity_SHAb.xyz * unity_SHAb.w) == 0 && length(o_gi.light.dir) < 0.1)
            {
                o_gi.light.dir = _FakeLight;
            }
    #endif

    o_gi.light.dir = normalize(o_gi.light.dir);

	//Bakery Standard ambient fix
    #if defined(SAMPLE_SH_NONLINEAR)
		float3 L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
		float3 nonLinearSH = float3(0,0,0); 
        float3 nonImpLight = Shade4PointLights(unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                                                unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                                                unity_4LightAtten0, data.worldPos, normalWorld);
		nonLinearSH.r = shEvaluateDiffuseL1Geomerics(L0.r, unity_SHAr.xyz, normalWorld);
		nonLinearSH.g = shEvaluateDiffuseL1Geomerics(L0.g, unity_SHAg.xyz, normalWorld);
		nonLinearSH.b = shEvaluateDiffuseL1Geomerics(L0.b, unity_SHAb.xyz, normalWorld);
		o_gi.indirect.diffuse = max(0, nonLinearSH);
		UNITY_BRANCH
        if (_StylizeRamp || nonLinearSH==1,1,1) o_gi.indirect.diffuse = ShadeSH9(float4(normalWorld * _RampSmooth, 1));
	#endif

    //#if defined(UNITY_SHOULD_SAMPLE_SH)
    //    o_gi.indirect.diffuse = ShadeSHPerPixel(normalWorld, data.ambient, data.worldPos);
    //#endif

    #if defined(LIGHTMAP_ON)
        // Baked lightmaps
        half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.lightmapUV.xy);
        half3 bakedColor = DecodeLightmap(bakedColorTex);

        #ifdef DIRLIGHTMAP_COMBINED
            fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy);
            o_gi.indirect.diffuse += DecodeDirectionalLightmap (bakedColor, bakedDirTex, normalWorld);

            #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
                ResetUnityLight(o_gi.light);
                o_gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap (o_gi.indirect.diffuse, data.atten, bakedColorTex, normalWorld);
            #endif

        #else // not directional lightmap
            o_gi.indirect.diffuse += bakedColor;

            #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
                ResetUnityLight(o_gi.light);
                o_gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap(o_gi.indirect.diffuse, data.atten, bakedColorTex, normalWorld);
            #endif

        #endif
    #endif

    #ifdef DYNAMICLIGHTMAP_ON
        // Dynamic lightmaps
        fixed4 realtimeColorTex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, data.lightmapUV.zw);
        half3 realtimeColor = DecodeRealtimeLightmap (realtimeColorTex);

        #ifdef DIRLIGHTMAP_COMBINED
            half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, data.lightmapUV.zw);
            o_gi.indirect.diffuse += DecodeDirectionalLightmap (realtimeColor, realtimeDirTex, normalWorld);
        #else
            o_gi.indirect.diffuse += realtimeColor;
        #endif
    #endif

    o_gi.indirect.diffuse *= occlusion;
    o_gi.indirect.diffuse += max(0, nonImpLight);
    UNITY_BRANCH
    if (any(_WorldSpaceLightPos0) == 0) o_gi.light.color += o_gi.indirect.diffuse;
    
    return o_gi;
}


inline half3 UnityGI_IndirectSpecular(UnityGIInput data, half occlusion, Unity_GlossyEnvironmentData glossIn)
{
    half3 specular;

    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
        // we will tweak reflUVW in glossIn directly (as we pass it to Unity_GlossyEnvironment twice for probe0 and probe1), so keep original to pass into BoxProjectedCubemapDirection
        half3 originalReflUVW = glossIn.reflUVW;
        glossIn.reflUVW = BoxProjectedCubemapDirection (originalReflUVW, data.worldPos, data.probePosition[0], data.boxMin[0], data.boxMax[0]);
    #endif

    #ifdef _GLOSSYREFLECTIONS_OFF
        specular = unity_IndirectSpecColor.rgb;
    #else
        half3 env0 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube0), data.probeHDR[0], glossIn);
        #ifdef UNITY_SPECCUBE_BLENDING
            const float kBlendFactor = 0.99999;
            float blendLerp = data.boxMin[0].w;
            UNITY_BRANCH
            if (blendLerp < kBlendFactor)
            {
                #ifdef UNITY_SPECCUBE_BOX_PROJECTION
                    glossIn.reflUVW = BoxProjectedCubemapDirection (originalReflUVW, data.worldPos, data.probePosition[1], data.boxMin[1], data.boxMax[1]);
                #endif

                half3 env1 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0), data.probeHDR[1], glossIn);
                specular = lerp(env1, env0, blendLerp);
            }
            else
            {
                specular = env0;
            }
        #else
            specular = env0;
        #endif
    #endif

    return specular * occlusion;
}

// Deprecated old prototype but can't be move to Deprecated.cginc file due to order dependency
inline half3 UnityGI_IndirectSpecular(UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
{
    // normalWorld is not used
    return UnityGI_IndirectSpecular(data, occlusion, glossIn);
}

inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half3 normalWorld)
{
    return UnityGI_Base(data, occlusion, normalWorld);
}

inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
{
    UnityGI o_gi = UnityGI_Base(data, occlusion, normalWorld);
    o_gi.indirect.specular = UnityGI_IndirectSpecular(data, occlusion, glossIn);
    return o_gi;
}

//
// Old UnityGlobalIllumination signatures. Kept only for backward compatibility and will be removed soon
//

inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half smoothness, half3 normalWorld, bool reflections)
{
    if(reflections)
    {
        Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(smoothness, data.worldViewDir, normalWorld, float3(0, 0, 0));
        return UnityGlobalIllumination(data, occlusion, normalWorld, g);
    }
    else
    {
        return UnityGlobalIllumination(data, occlusion, normalWorld);
    }
}
inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half smoothness, half3 normalWorld)
{
#if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
    // No need to sample reflection probes during deferred G-buffer pass
    bool sampleReflections = false;
#else
    bool sampleReflections = true;
#endif
    return UnityGlobalIllumination (data, occlusion, smoothness, normalWorld, sampleReflections);
}


#endif
