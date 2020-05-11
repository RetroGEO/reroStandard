// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader ".Rero/Rero Standard/Rero Standard (Specular Setup)"
{
    Properties
    {	
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Int) = 2
		[Gamma]_Stencil ("Stencil ID [0;255]", Float) = 128
		
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
		_Cube ("Reflection Cubemap", Cube) = "_Skybox" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
		
		[Toggle(_)] _UseProbe("Use reflection probe if present", Float) = 1
		[Toggle(_)] _ShadowToggle("Tint Shadows", Float) = 0
		[Toggle(_)] _StylizeRamp("", Float) = 0
		[Toggle(_)] _StylizeSpecular("", Float) = 0
		[Toggle(_)] _StylizeRim("", Float) = 0
		[Toggle(_)] _OutlineEnabled ( "Outline", Float ) = 0
		[Toggle(_)] _LitRim ( "Lit Rim", Float ) = 0
		[Toggle(_)] _AdvancedChannels("Advanced Channel Features", Float) = 0
		_metallicChannel(" ", Float) = 0
		_occlusionChannel(" ", Float) = 0
		_heightChannel(" ", Float) = 0
		_glossChannel(" ", Float) = 0
		_maskChannel(" ", Float) = 0
		
		_ShadowColor("Shadow Color", Color) = (1,1,1,1)
		_RampThreshold ("Ramp Threshold", Range(-1,1)) = 0
		_RampSmooth ("Ramp Smoothing", Range(0,1)) = 1
		_FakeLight ("Fake Light Direction", vector) = (0,.5,1,1)
		_RimMax ("Rim Upper", Range(0,1)) = 1
		_RimMin ("Rim Lower", Range(0,1)) = 0

        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Factor", Range(0.0, 1.0)) = 1.0
        [Enum(Specular Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0
		[Gamma] _specularBrightness("Specular Brightness", Float) = 1.0

        _SpecColor("Specular", Color) = (0.2,0.2,0.2)
        _SpecGlossMap("Specular", 2D) = "white" {}  
		
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _Parallax ("Height Scale", Range (0.005, 0.1)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DetailMask("Detail Mask", 2D) = "white" {}

		[HDR] _DetColor("Detail Color", Color) = (1,1,1,1)
        _DetailAlbedoMap("Detail Albedo x2", 2D) = "white" {} 
        _DetailNormalMapScale("Scale", Float) = 1.0
        _DetailNormalMap("Normal Map", 2D) = "bump" {}

        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0
		
		_Outline ( "Outline Width", Range ( 0.0, 10 ) ) = 1
		_OutlineColor ( "Outline Color", Color ) = ( 0.0, 0.0, 0.0, 1.0 )
        _OutlineColorMix("Base Color Mix", Range (0.0, 1.0)) = 0.0

        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }

    CGINCLUDE
        #define UNITY_SETUP_BRDF_INPUT SpecularSetup
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" "Queue" = "Geometry"}
		
        Stencil
		{
			Ref [_Stencil]
			Comp always
			Pass replace
		}

		LOD 300
		Cull [_Cull]

        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ _GLOSSYREFLECTIONS_OFF
            #pragma shader_feature _PARALLAXMAP

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertBase
            #pragma fragment fragBase
            #include "CGINC/UnityStandardCoreForwardRero.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Additive forward pass (one light per pass)
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _PARALLAXMAP

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #include "CGINC/UnityStandardCoreForwardRero.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------


            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature _PARALLAXMAP
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertShadowCaster
            #pragma fragment fragShadowCaster

            #include "UnityStandardShadow.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Deferred pass
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt


            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _PARALLAXMAP

            #pragma multi_compile_prepassfinal
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertDeferred
            #pragma fragment fragDeferred

            #include "CGINC/UnityStandardCoreRero.cginc"

            ENDCG
        }

        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering.
        Pass
        {
            Name "META"
            Tags { "LightMode"="Meta" }

            Cull Off

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta

            #pragma shader_feature _EMISSION
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "UnityStandardMeta.cginc"
            ENDCG
        }
		
		// Outline Pass
        Pass 
		{
			Name "Outline"
			Tags {"LightMode"="ForwardBase"}
			
			Cull  Off
			Blend SrcAlpha OneMinusSrcAlpha
			
			Stencil
			{
				Ref [_Stencil]
				Comp NotEqual
			}		
			
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma target 4.0
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma shader_feature _ _ALPHABLEND_ON _ALPHATEST_ON
			
			#include "Lighting.cginc"	
			
			half4 _OutlineColor, _Color, _MainTex_ST;
			float _Outline, _OutlineColorMix;
			bool _OutlineEnabled;
			sampler2D _MainTex;
			#if defined(_ALPHATEST_ON)
            float _Cutoff;
			#endif

			struct v2g 
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 viewTan : TANGENT;
				float3 normals : NORMAL;
				float4 color : TEXCOORD1;
			};
			
			struct g2f 
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS( 2 )
				float3 viewTan : TANGENT;
				float3 normals : NORMAL;
				float4 color : COLOR;
			};

			v2g vert(appdata_base v)
			{
				v2g OUT;
				OUT.pos = UnityObjectToClipPos(v.vertex);
				if(_OutlineEnabled==1)
				{
					OUT.uv = v.texcoord;
					OUT.normals = UnityObjectToWorldNormal(v.normal);
					OUT.viewTan = ObjSpaceViewDir(v.vertex);
					float4 tex= tex2Dlod(_MainTex, float4(OUT.uv.xy, 0, 0));
					OUT.color.rgb = _OutlineColor.rgb;
					OUT.color.a = saturate(_OutlineColor.a);
					OUT.color.rgb =  lerp(OUT.color.rgb, _Color.rgb * tex.rgb, _OutlineColorMix);
					#ifdef _ALPHABLEND_ON
					OUT.color.a *= _Color.a;
					#endif
				}
				
				return OUT;
			}
			
			void geom2(v2g start, v2g end, inout TriangleStream<g2f> triStream)
			{
				float thisWidth = _Outline * min(3,start.pos.w) * .002;
				float4 para = start.pos-end.pos;
				normalize(para);
				para *= thisWidth;
				
				float4 perp = float4(para.y,-para.x, 0, 0);
				perp = normalize(perp) * thisWidth;
				float4 v1 = start.pos-para;
				float4 v2 = end.pos+para;
				g2f OUT = (g2f)0;
				OUT.pos = v1-perp;
				OUT.uv = start.uv;
				OUT.viewTan = start.viewTan;
				OUT.normals = start.normals;
				OUT.color = start.color;
                UNITY_TRANSFER_FOG(OUT, OUT.pos);
				triStream.Append(OUT);
				
				OUT.pos = v1+perp;
                UNITY_TRANSFER_FOG(OUT, OUT.pos);
				triStream.Append(OUT);
				
				OUT.pos = v2-perp;
				OUT.uv = end.uv;
				OUT.viewTan = end.viewTan;
				OUT.normals = end.normals;
				OUT.color = end.color;
                UNITY_TRANSFER_FOG(OUT, OUT.pos);
				triStream.Append(OUT);
				
				OUT.pos = v2+perp;
				OUT.uv = end.uv;
				OUT.viewTan = end.viewTan;
				OUT.normals = end.normals;
				OUT.color = end.color;
                UNITY_TRANSFER_FOG(OUT, OUT.pos);
				triStream.Append(OUT);
			}
			
			[maxvertexcount(12)]
			void geom(triangleadj  v2g IN[6], inout TriangleStream<g2f> triStream)
			{
				UNITY_BRANCH
				if(_OutlineEnabled==1)
				{
					geom2(IN[0],IN[1],triStream);
					geom2(IN[1],IN[2],triStream);
					geom2(IN[2],IN[0],triStream);
				}
			}
			
			half4 frag(g2f IN) : SV_Target
			{
				UNITY_BRANCH
				if(_OutlineEnabled!=1)return 0;
				half4 fragTex = tex2D( _MainTex, IN.uv );
				#if defined(_ALPHATEST_ON)
                clip((_Color.a * fragTex.a) - _Cutoff);
				#endif
				float3 brightness = ShadeSH9(float4(0,0,0,1)) + _LightColor0;
				float worldBrightness = saturate((brightness.r + brightness.g + brightness.b)/3);
				IN.color.rgb *= clamp(0, 1, worldBrightness * 100);
				UNITY_APPLY_FOG( IN.fogCoord, IN.color );
				
				return IN.color;
			}
			
			ENDCG
        }
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 150

        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 2.0

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ _GLOSSYREFLECTIONS_OFF
            #pragma shader_feature ___ _DETAIL_MULX2
            // SM2.0: NOT SUPPORTED shader_feature _PARALLAXMAP

            #pragma skip_variants SHADOWS_SOFT DYNAMICLIGHTMAP_ON DIRLIGHTMAP_COMBINED

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            #pragma vertex vertBase
            #pragma fragment fragBase
            #include "CGINC/UnityStandardCoreForwardRero.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Additive forward pass (one light per pass)
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma target 2.0

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature ___ _DETAIL_MULX2
            // SM2.0: NOT SUPPORTED shader_feature _PARALLAXMAP
            #pragma skip_variants SHADOWS_SOFT

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #include "CGINC/UnityStandardCoreForwardRero.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma target 2.0

            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _SPECGLOSSMAP
            #pragma skip_variants SHADOWS_SOFT
            #pragma multi_compile_shadowcaster

            #pragma vertex vertShadowCaster
            #pragma fragment fragShadowCaster

            #include "UnityStandardShadow.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering.
        Pass
        {
            Name "META"
            Tags { "LightMode"="Meta" }

            Cull Off

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta

            #pragma shader_feature _EMISSION
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "UnityStandardMeta.cginc"
            ENDCG
        }
    }
    CustomEditor "ReroStandardSpecularShaderGUI"
}
