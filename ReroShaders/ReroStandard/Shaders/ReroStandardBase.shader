Shader ".Rero/Rero Standard/Rero Standard" {
	Properties {
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
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0
		[Gamma] _specularBrightness("Specular Brightness", Float) = 1.0

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

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
        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
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
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	CustomEditor "ReroStandardShaderGUI"
}
