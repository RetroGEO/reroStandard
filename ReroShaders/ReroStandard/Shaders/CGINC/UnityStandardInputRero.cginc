// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_INPUT_INCLUDED
#define UNITY_STANDARD_INPUT_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityPBSLightingRero.cginc" // TBD: remove
#include "UnityStandardUtilsRero.cginc"

//---------------------------------------
// Directional lightmaps & Parallax require tangent space too
#if (_NORMALMAP || DIRLIGHTMAP_COMBINED || _PARALLAXMAP)
    #define _TANGENT_TO_WORLD 1
#endif

#if (_DETAIL_MULX2 || _DETAIL_MUL || _DETAIL_ADD || _DETAIL_LERP)
    #define _DETAIL 1
#endif

//---------------------------------------
half4       _Color;
half4	   _DetColor;
half        _Cutoff;

sampler2D   _MainTex;
float4      _MainTex_ST;

sampler2D   _DetailAlbedoMap;
float4      _DetailAlbedoMap_ST;

sampler2D   _BumpMap;
half        _BumpScale;

sampler2D   _DetailMask;
sampler2D   _DetailNormalMap;
half        _DetailNormalMapScale;

sampler2D   _SpecGlossMap;
sampler2D   _MetallicGlossMap;
half        _Metallic;
float       _Glossiness;
float       _GlossMapScale;

sampler2D   _OcclusionMap;
half        _OcclusionStrength;

sampler2D   _ParallaxMap;
half        _Parallax;
half        _UVSec;

half4       _EmissionColor;
sampler2D   _EmissionMap;

int _metallicChannel;
int _occlusionChannel;
int _glossChannel;
int _maskChannel;

//-------------------------------------------------------------------------------------
// Input functions

struct VertexInput
{
    float4 vertex   : POSITION;
    half3 normal    : NORMAL;
    float2 uv0      : TEXCOORD0;
    float2 uv1      : TEXCOORD1;
#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
    float2 uv2      : TEXCOORD2;
#endif
#ifdef _TANGENT_TO_WORLD
    half4 tangent   : TANGENT;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

float4 TexCoords(VertexInput v)
{
    float4 texcoord;
    texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex); // Always source from uv0
    texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
    return texcoord;
}

half DetailMask(float2 uv)
{
    half mask;
    if(_maskChannel == 0)
        mask = tex2D(_DetailMask, uv).r;
    else if(_maskChannel == 1)
        mask = tex2D(_DetailMask, uv).g;
    else if(_maskChannel == 2)
        mask = tex2D(_DetailMask, uv).b;
    else
        mask = tex2D(_DetailMask, uv).a;
    return mask;
}

half3 Albedo(float4 texcoords)
{
    half3 albedo = _Color.rgb * tex2D (_MainTex, texcoords.xy).rgb;
#if _DETAIL
    #if (SHADER_TARGET < 30)
        // SM20: instruction count limitation
        // SM20: no detail mask
        half mask = 1;
    #else
        half4 mask = DetailMask(texcoords.xy);
		mask *= _DetColor.a;
    #endif
    half4 detailAlbedo = tex2D (_DetailAlbedoMap, texcoords.zw) * _DetColor;
    #if _DETAIL_MULX2
        albedo *= LerpWhiteTo (detailAlbedo * unity_ColorSpaceDouble.rgb, mask);
    #elif _DETAIL_MUL
        albedo *= LerpWhiteTo (detailAlbedo, mask);
    #elif _DETAIL_ADD
        albedo += detailAlbedo * mask;
    #elif _DETAIL_LERP
        albedo = lerp (albedo, detailAlbedo, mask);
    #endif
#endif
    return albedo;
}

half Alpha(float2 uv)
{
#if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
    return _Color.a;
#else
    return tex2D(_MainTex, uv).a * _Color.a;
#endif
}

half Occlusion(float2 uv)
{
#if (SHADER_TARGET < 30)
    // SM20: instruction count limitation
    // SM20: simpler occlusion
    return tex2D(_OcclusionMap, uv).g;
#else
    half occ;
    if(_occlusionChannel == 0)
        occ = tex2D(_OcclusionMap, uv).r;
    else if(_occlusionChannel == 1)
        occ = tex2D(_OcclusionMap, uv).g;
    else if(_occlusionChannel == 2)
        occ = tex2D(_OcclusionMap, uv).b;
    else
        occ = tex2D(_OcclusionMap, uv).a;

    return LerpOneTo (occ, _OcclusionStrength);
#endif
}

half4 SpecularGloss(float2 uv)
{
    half4 sg;
#ifdef _SPECGLOSSMAP
    #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
        sg.rgb = tex2D(_SpecGlossMap, uv).rgb;
        sg.a = tex2D(_MainTex, uv).a;
    #else
        sg = tex2D(_SpecGlossMap, uv);
    #endif
    sg.a *= _GlossMapScale;
#else
    sg.rgb = _SpecColor.rgb;
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        sg.a = tex2D(_MainTex, uv).a * _GlossMapScale;
    #else
        sg.a = _Glossiness;
    #endif
#endif
    return sg;
}

half2 MetallicGloss(float2 uv)
{
    half2 mg;

#ifdef _METALLICGLOSSMAP
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
    if (_metallicChannel == 0)
        mg.r = tex2D(_MetallicGlossMap, uv).r;
    else if (_metallicChannel == 1)
        mg.r = tex2D(_MetallicGlossMap, uv).g;
    else if (_metallicChannel == 2)
        mg.r = tex2D(_MetallicGlossMap, uv).b;
    else 
        mg.r = tex2D(_MetallicGlossMap, uv).a;
        mg.g = tex2D(_MainTex, uv).a;
    #else
    if (_metallicChannel == 0)
        mg.r = tex2D(_MetallicGlossMap, uv).r;
    else if (_metallicChannel == 1)
        mg.r = tex2D(_MetallicGlossMap, uv).g;
    else if (_metallicChannel == 2)
        mg.r = tex2D(_MetallicGlossMap, uv).b;
    else
        mg.r = tex2D(_MetallicGlossMap, uv).a;
    #endif
    if (_glossChannel == 0)
        mg.g = tex2D(_MetallicGlossMap, uv).r;
    else if (_glossChannel == 1)
        mg.g = tex2D(_MetallicGlossMap, uv).g;
    else if (_glossChannel == 2)
        mg.g = tex2D(_MetallicGlossMap, uv).b;
    else
        mg.g = tex2D(_MetallicGlossMap, uv).a;
    mg.g *= _GlossMapScale;
#else
    mg.r = _Metallic;
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        mg.g = tex2D(_MainTex, uv).a * _GlossMapScale;
    #else
        mg.g = _Glossiness;
    #endif
#endif
    return mg;
}

half2 MetallicRough(float2 uv)
{
    half2 mg;
#ifdef _METALLICGLOSSMAP
    if(_metallicChannel == 0)
        mg.r = tex2D(_MetallicGlossMap, uv).r * _Metallic;
    else if(_metallicChannel == 1)
        mg.r = tex2D(_MetallicGlossMap, uv).g * _Metallic;
    else if(_metallicChannel == 2)
        mg.r = tex2D(_MetallicGlossMap, uv).b * _Metallic;
    else
        mg.r = tex2D(_MetallicGlossMap, uv).a * _Metallic;

#else
    mg.r = _Metallic;
#endif

#ifdef _SPECGLOSSMAP
    if(_glossChannel == 0)
        mg.g = 1.0f - tex2D(_SpecGlossMap, uv).r  * _Glossiness;
    else if(_glossChannel == 1)
        mg.g = 1.0f - tex2D(_SpecGlossMap, uv).g  * _Glossiness;
    else if(_glossChannel == 2)
        mg.g = 1.0f - tex2D(_SpecGlossMap, uv).b  * _Glossiness;
    else
        mg.g = 1.0f - tex2D(_SpecGlossMap, uv).a  * _Glossiness;

#else
    mg.g = 1.0f - _Glossiness;
#endif
    return mg;
}

half3 Emission(float2 uv)
{
#ifndef _EMISSION
    return 0;
#else
    return tex2D(_EmissionMap, uv).rgb * _EmissionColor.rgb;
#endif
}

#ifdef _NORMALMAP
half3 NormalInTangentSpace(float4 texcoords)
{
    half3 normalTangent = UnpackScaleNormal(tex2D (_BumpMap, texcoords.xy), _BumpScale);

#if _DETAIL && defined(UNITY_ENABLE_DETAIL_NORMALMAP)
    half mask = DetailMask(texcoords.xy);
    half3 detailNormalTangent = UnpackScaleNormal(tex2D (_DetailNormalMap, texcoords.zw), _DetailNormalMapScale);
    #if _DETAIL_LERP
        normalTangent = lerp(
            normalTangent,
            detailNormalTangent,
            mask);
    #else
        normalTangent = lerp(
            normalTangent,
            BlendNormals(normalTangent, detailNormalTangent),
            mask);
    #endif
#endif

    return normalTangent;
}
#endif

float4 Parallax(float4 texcoords, half3 viewDir)
{
    viewDir = Unity_SafeNormalize(viewDir);
    viewDir.xy /= (viewDir.z + 0.42);
#if !defined(_PARALLAXMAP) || (SHADER_TARGET < 30)
    // Disable parallax on pre-SM3.0 shader target models
    return texcoords;
#else
	float2 view = viewDir.xy*_Parallax;
	half depth = ray_intersect_rm(_ParallaxMap, texcoords.zw, view, 1.0f);
	float2 offset = view*depth;
	return float4(texcoords.xy + offset, texcoords.zw + offset);
#endif
}

#endif // UNITY_STANDARD_INPUT_INCLUDED
