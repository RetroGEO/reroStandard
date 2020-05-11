// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

using System;
using UnityEngine;

namespace UnityEditor
{
    internal class ReroStandardShaderGUI : ShaderGUI
    {
        private enum WorkflowMode
        {
            Specular,
            Metallic,
            Dielectric
        }

        public enum BlendMode
        {
            Opaque,
            Cutout,
            Fade,   // Old school alpha-blending mode, fresnel does not affect amount of transparency
            Transparent // Physically plausible transparency mode, implemented as alpha pre-multiply
        }

        public enum SmoothnessMapChannel
        {
            SpecularMetallicAlpha,
            AlbedoAlpha,
        }

        private static class Styles
        {
            public static GUIContent uvSetLabel = new GUIContent("UV Set");
			public static GUIContent cullText = new GUIContent("Cull", "Face Culling (Front, Back, Off)");
            public static GUIContent albedoText = new GUIContent("Albedo", "Albedo (RGB) and Transparency (A)");
			public static GUIContent probeText = new GUIContent("Use Reflection Probe", "Uses fallback cubemap otherwise");
			public static GUIContent fallbackText = new GUIContent("Fallback Cubemap", "Used for reflections if there is no reflection probe");
            public static GUIContent alphaCutoffText = new GUIContent("Alpha Cutoff", "Threshold for alpha cutoff");
            public static GUIContent specularMapText = new GUIContent("Specular", "Specular (RGB) and Smoothness (A)");
            public static GUIContent metallicMapText = new GUIContent("Metallic", "Metallic and Smoothness");
            public static GUIContent metallicEnumText = new GUIContent("", "Metallic Channel Used");
            public static GUIContent glossEnumText = new GUIContent("", "Gloss Channel Used");
            public static GUIContent heightEnumText = new GUIContent("", "Height Channel Used");
            public static GUIContent occlusionEnumText = new GUIContent("", "Occlusion Channel Used");
            public static GUIContent maskEnumText = new GUIContent("", "Mask Channel Used");
            public static GUIContent smoothnessText = new GUIContent("Smoothness", "Smoothness value");
			public static GUIContent shadowColor = new GUIContent("Shadow Color", "Shadow Color Tint");
			public static GUIContent rampOffText = new GUIContent("Ramp Offset", "Offset value");
			public static GUIContent rampHardText = new GUIContent("Ramp Softness", "Hardness value");
			public static GUIContent fakeLightText = new GUIContent("Fake Light Dir", "Direction of the fake light used in baked lighting scenarios. W is an intensity amplifier");
            public static GUIContent smoothnessScaleText = new GUIContent("Smoothness", "Smoothness scale factor");
            public static GUIContent smoothnessMapChannelText = new GUIContent("Source", "Smoothness texture and channel");
            public static GUIContent highlightsText = new GUIContent("Specular Highlights", "Specular Highlights");
            public static GUIContent reflectionsText = new GUIContent("Reflections", "Glossy Reflections");
            public static GUIContent advancedChannelsText = new GUIContent("Advanced Channel Selection", "Color channel used for each PBR property");
            public static GUIContent normalMapText = new GUIContent("Normal Map", "Normal Map");
            public static GUIContent heightMapText = new GUIContent("Height Map", "Height Map (G)");
            public static GUIContent occlusionText = new GUIContent("Occlusion", "Occlusion (G)");
            public static GUIContent emissionText = new GUIContent("Color", "Emission (RGB)");
            public static GUIContent detailMaskText = new GUIContent("Detail Mask", "Mask for Secondary Maps (A)");
            public static GUIContent detailAlbedoText = new GUIContent("Detail Albedo x2", "Albedo (RGB) multiplied by 2");
            public static GUIContent detailNormalMapText = new GUIContent("Normal Map", "Normal Map");			

            public static string primaryMapsText = "Main Maps";
            public static string secondaryMapsText = "Secondary Maps";
            public static string forwardText = "Forward Rendering Options";
            public static string renderingMode = "Rendering Mode";
            public static string advancedText = "Advanced Options";
            public static readonly string[] blendNames = Enum.GetNames(typeof(BlendMode));
        }

        MaterialProperty blendMode = null;
		MaterialProperty cullMode = null;
        MaterialProperty albedoMap = null;
		MaterialProperty useProbe = null;
		MaterialProperty fallbackMap = null;
        MaterialProperty albedoColor = null;
        MaterialProperty alphaCutoff = null;
        MaterialProperty specularMap = null;
        MaterialProperty specularColor = null;
        MaterialProperty metallicMap = null;
        MaterialProperty metallic = null;
        MaterialProperty smoothness = null;
		MaterialProperty shadowToggle = null;
		MaterialProperty shadowColor = null;
		MaterialProperty rampOff = null;
		MaterialProperty rampHard = null;
		MaterialProperty fakeLight = null;
        MaterialProperty smoothnessScale = null;
        MaterialProperty smoothnessMapChannel = null;
        MaterialProperty highlights = null;
        MaterialProperty reflections = null;
        MaterialProperty advancedChannels = null;
        MaterialProperty bumpScale = null;
        MaterialProperty bumpMap = null;
        MaterialProperty occlusionStrength = null;
        MaterialProperty occlusionMap = null;
        MaterialProperty heigtMapScale = null;
        MaterialProperty heightMap = null;
        MaterialProperty emissionColorForRendering = null;
        MaterialProperty emissionMap = null;
        MaterialProperty detailMask = null;
		MaterialProperty detailColor = null;
        MaterialProperty detailAlbedoMap = null;
        MaterialProperty detailNormalMapScale = null;
        MaterialProperty detailNormalMap = null;
        MaterialProperty uvSetSecondary = null;
		MaterialProperty stylizeRamp = null;
		MaterialProperty stylizeSpec = null;
		MaterialProperty stylizeRim = null;
		MaterialProperty outlineEnabled = null;
		MaterialProperty outlineWidth = null;
        MaterialProperty outlineColor = null;
		MaterialProperty outlineColorMix = null;
		MaterialProperty stencilRef = null;
		MaterialProperty specularBrightness = null;
		MaterialProperty rimMax = null;
		MaterialProperty rimMin = null;
		MaterialProperty litRim = null;
        MaterialProperty metallicEnum = null;
        MaterialProperty glossEnum = null;
        MaterialProperty heightEnum = null;
        MaterialProperty occlusionEnum = null;
        MaterialProperty maskEnum = null;

        MaterialEditor m_MaterialEditor;
        WorkflowMode m_WorkflowMode = WorkflowMode.Specular;
        private const float kMaxfp16 = 65536f; // Clamp to a value that fits into fp16.
        ColorPickerHDRConfig m_ColorPickerHDRConfig = new ColorPickerHDRConfig(0f, kMaxfp16, 1 / kMaxfp16, 3f);

        bool m_FirstTimeApply = true;

        public void FindProperties(MaterialProperty[] props)
        {
            blendMode = FindProperty("_Mode", props);
			cullMode = FindProperty("_Cull", props);
            albedoMap = FindProperty("_MainTex", props);
			useProbe = FindProperty("_UseProbe", props);
			fallbackMap = FindProperty("_Cube", props);
            albedoColor = FindProperty("_Color", props);
            alphaCutoff = FindProperty("_Cutoff", props);
            specularMap = FindProperty("_SpecGlossMap", props, false);
            specularColor = FindProperty("_SpecColor", props, false);
            metallicMap = FindProperty("_MetallicGlossMap", props, false);
            metallic = FindProperty("_Metallic", props, false);
            if (specularMap != null && specularColor != null)
                m_WorkflowMode = WorkflowMode.Specular;
            else if (metallicMap != null && metallic != null)
                m_WorkflowMode = WorkflowMode.Metallic;
            else
                m_WorkflowMode = WorkflowMode.Dielectric;
            metallicEnum = FindProperty("_metallicChannel", props);
            glossEnum = FindProperty("_glossChannel", props);
            heightEnum = FindProperty("_heightChannel", props);
            occlusionEnum = FindProperty("_occlusionChannel", props);
            maskEnum = FindProperty("_maskChannel", props);
            smoothness = FindProperty("_Glossiness", props);
			shadowToggle = FindProperty("_ShadowToggle", props);
			shadowColor = FindProperty("_ShadowColor", props);
			rampOff = FindProperty("_RampThreshold", props);
			rampHard = FindProperty("_RampSmooth", props);
			fakeLight = FindProperty("_FakeLight", props);
            smoothnessScale = FindProperty("_GlossMapScale", props, false);
            smoothnessMapChannel = FindProperty("_SmoothnessTextureChannel", props, false);
            highlights = FindProperty("_SpecularHighlights", props, false);
            reflections = FindProperty("_GlossyReflections", props, false);
            advancedChannels = FindProperty("_AdvancedChannels", props, false);
            bumpScale = FindProperty("_BumpScale", props);
            bumpMap = FindProperty("_BumpMap", props);
            heigtMapScale = FindProperty("_Parallax", props);
            heightMap = FindProperty("_ParallaxMap", props);
            occlusionStrength = FindProperty("_OcclusionStrength", props);
            occlusionMap = FindProperty("_OcclusionMap", props);
            emissionColorForRendering = FindProperty("_EmissionColor", props);
            emissionMap = FindProperty("_EmissionMap", props);
            detailMask = FindProperty("_DetailMask", props);
			detailColor = FindProperty("_DetColor", props);
            detailAlbedoMap = FindProperty("_DetailAlbedoMap", props);
            detailNormalMapScale = FindProperty("_DetailNormalMapScale", props);
            detailNormalMap = FindProperty("_DetailNormalMap", props);
            uvSetSecondary = FindProperty("_UVSec", props);
            stylizeRamp = FindProperty("_StylizeRamp", props);
            stylizeSpec = FindProperty("_StylizeSpecular", props);
            stylizeRim = FindProperty("_StylizeRim", props);
            outlineEnabled = FindProperty("_OutlineEnabled", props);
			outlineWidth = FindProperty("_Outline", props);
            outlineColor = FindProperty("_OutlineColor", props);
            outlineColorMix = FindProperty("_OutlineColorMix", props);
            stencilRef = FindProperty("_Stencil", props);
            specularBrightness = FindProperty("_specularBrightness", props);
            rimMax = FindProperty("_RimMax", props);
            rimMin = FindProperty("_RimMin", props);
            litRim = FindProperty("_LitRim", props);
        }

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            FindProperties(props); // MaterialProperties can be animated so we do not cache them but fetch them every event to ensure animated values are updated correctly
            m_MaterialEditor = materialEditor;
            Material material = materialEditor.target as Material;
            // Make sure that needed setup (ie keywords/renderqueue) are set up if we're switching some existing
            // material to a standard shader.
            // Do this before any GUI code has been issued to prevent layout issues in subsequent GUILayout statements (case 780071)
            if (m_FirstTimeApply)
            {
                MaterialChanged(material, m_WorkflowMode);
                m_FirstTimeApply = false;
            }

            ShaderPropertiesGUI(material);
        }

        public void ShaderPropertiesGUI(Material material)
        {
            // Use default labelWidth
            EditorGUIUtility.labelWidth = 0f;

            // Detect any changes to the material
            EditorGUI.BeginChangeCheck();
            {
                BlendModePopup();
				m_MaterialEditor.ShaderProperty(cullMode, Styles.cullText);
				if(outlineEnabled.floatValue == 0)stencilRef.floatValue = 0;
				
				GUILayout.BeginHorizontal();
				ButtonToggle(ref stylizeRamp, "Custom Ramp");
				ButtonToggle(ref stylizeSpec, "Custom Specular");
				ButtonToggle(ref stylizeRim, "Custom Rim");
				ButtonToggle(ref outlineEnabled, "Outlines");
				GUILayout.EndHorizontal();

                // Primary properties
                GUILayout.Label(Styles.primaryMapsText, EditorStyles.boldLabel);
                DoAlbedoArea(material);
                DoSpecularMetallicArea();
                DoNormalArea();
                m_MaterialEditor.TexturePropertySingleLine(Styles.heightMapText, heightMap, heightMap.textureValue != null ? heigtMapScale : null);
                if (advancedChannels.floatValue == 1) ProperPopup(ref heightEnum, 100);
                m_MaterialEditor.TexturePropertySingleLine(Styles.occlusionText, occlusionMap, occlusionMap.textureValue != null ? occlusionStrength : null);
                if (advancedChannels.floatValue == 1) ProperPopup(ref occlusionEnum, 90);
                m_MaterialEditor.TexturePropertySingleLine(Styles.detailMaskText, detailMask);
                if (advancedChannels.floatValue == 1) ProperPopup(ref maskEnum, 102);
                DoEmissionArea(material);
                EditorGUI.BeginChangeCheck();
                m_MaterialEditor.TextureScaleOffsetProperty(albedoMap);
                if (EditorGUI.EndChangeCheck())
                    emissionMap.textureScaleAndOffset = albedoMap.textureScaleAndOffset; // Apply the main texture scale and offset to the emission texture as well, for Enlighten's sake

                EditorGUILayout.Space();

                // Secondary properties
                GUILayout.Label(Styles.secondaryMapsText, EditorStyles.boldLabel);
                m_MaterialEditor.TexturePropertySingleLine(Styles.detailAlbedoText, detailAlbedoMap, detailColor);
                m_MaterialEditor.TexturePropertySingleLine(Styles.detailNormalMapText, detailNormalMap, detailNormalMapScale);
                m_MaterialEditor.TextureScaleOffsetProperty(detailAlbedoMap);
                m_MaterialEditor.ShaderProperty(uvSetSecondary, Styles.uvSetLabel.text);

                // Third properties
                GUILayout.Label(Styles.forwardText, EditorStyles.boldLabel);
                if (highlights != null)
                    m_MaterialEditor.ShaderProperty(highlights, Styles.highlightsText);
                if (reflections != null)
                    m_MaterialEditor.ShaderProperty(reflections, Styles.reflectionsText);
            }
            if (EditorGUI.EndChangeCheck())
            {
                foreach (var obj in blendMode.targets)
                    MaterialChanged((Material)obj, m_WorkflowMode);
            }

            EditorGUILayout.Space();

            // NB renderqueue editor is not shown on purpose: we want to override it based on blend mode
            GUILayout.Label(Styles.advancedText, EditorStyles.boldLabel);
            m_MaterialEditor.ShaderProperty(advancedChannels, Styles.advancedChannelsText);
            m_MaterialEditor.EnableInstancingField();
            m_MaterialEditor.DoubleSidedGIField();
        }

        internal void DetermineWorkflow(MaterialProperty[] props)
        {
            if (FindProperty("_SpecGlossMap", props, false) != null && FindProperty("_SpecColor", props, false) != null)
                m_WorkflowMode = WorkflowMode.Specular;
            else if (FindProperty("_MetallicGlossMap", props, false) != null && FindProperty("_Metallic", props, false) != null)
                m_WorkflowMode = WorkflowMode.Metallic;
            else
                m_WorkflowMode = WorkflowMode.Dielectric;
        }

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            // _Emission property is lost after assigning Standard shader to the material
            // thus transfer it before assigning the new shader
            if (material.HasProperty("_Emission"))
            {
                material.SetColor("_EmissionColor", material.GetColor("_Emission"));
            }

            base.AssignNewShaderToMaterial(material, oldShader, newShader);

            if (oldShader == null || !oldShader.name.Contains("Legacy Shaders/"))
            {
                SetupMaterialWithBlendMode(material, (BlendMode)material.GetFloat("_Mode"));
                return;
            }

            BlendMode blendMode = BlendMode.Opaque;
            if (oldShader.name.Contains("/Transparent/Cutout/"))
            {
                blendMode = BlendMode.Cutout;
            }
            else if (oldShader.name.Contains("/Transparent/"))
            {
                // NOTE: legacy shaders did not provide physically based transparency
                // therefore Fade mode
                blendMode = BlendMode.Fade;
            }
            material.SetFloat("_Mode", (float)blendMode);

            DetermineWorkflow(MaterialEditor.GetMaterialProperties(new Material[] { material }));
            MaterialChanged(material, m_WorkflowMode);
        }

        void BlendModePopup()
        {
            EditorGUI.showMixedValue = blendMode.hasMixedValue;
            var mode = (BlendMode)blendMode.floatValue;

            EditorGUI.BeginChangeCheck();
            mode = (BlendMode)EditorGUILayout.Popup(Styles.renderingMode, (int)mode, Styles.blendNames);
            if (EditorGUI.EndChangeCheck())
            {
                m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
                blendMode.floatValue = (float)mode;
            }

            EditorGUI.showMixedValue = false;
        }

        void DoNormalArea()
        {
            m_MaterialEditor.TexturePropertySingleLine(Styles.normalMapText, bumpMap, bumpMap.textureValue != null ? bumpScale : null);
            if (bumpScale.floatValue != 1 && UnityEditorInternal.InternalEditorUtility.IsMobilePlatform(EditorUserBuildSettings.activeBuildTarget))
                if (m_MaterialEditor.HelpBoxWithButton(
                        new GUIContent("Bump scale is not supported on mobile platforms"),
                        new GUIContent("Fix Now")))
                {
                    bumpScale.floatValue = 1;
                }
        }

        void DoAlbedoArea(Material material)
        {
			float MaxRim = rimMax.floatValue;
            float MinRim = rimMin.floatValue;
            m_MaterialEditor.TexturePropertySingleLine(Styles.albedoText, albedoMap, albedoColor);
			m_MaterialEditor.ShaderProperty(useProbe, Styles.probeText);
			m_MaterialEditor.TexturePropertySingleLine(Styles.fallbackText, fallbackMap);
			
            if (((BlendMode)material.GetFloat("_Mode") == BlendMode.Cutout))
            {
                m_MaterialEditor.ShaderProperty(alphaCutoff, Styles.alphaCutoffText.text, MaterialEditor.kMiniTextureFieldLabelIndentLevel + 1);
            }
		
			if (stylizeSpec.floatValue == 1)
			{
				GUILayout.Space(17);
				GUILayout.Label("Custom Specular", EditorStyles.boldLabel);
				GUILayout.BeginHorizontal();
				m_MaterialEditor.ShaderProperty(specularBrightness, "Specular Brightness");
				GUILayout.FlexibleSpace();
				GUILayout.EndHorizontal();
			}
            
            if (stylizeRim.floatValue == 1)
            {
                float rimVal = litRim.floatValue;
                EditorGUI.BeginChangeCheck();
                EditorGUILayout.MinMaxSlider("Rim (Min / Max)", ref MinRim, ref MaxRim, 0f, 1f);
                rimVal = GUILayout.Toggle(litRim.floatValue == 1, "Directional Rim", "Button", GUILayout.MaxWidth(100)) ? 1 : 0;
                if (EditorGUI.EndChangeCheck())
                {
                    litRim.floatValue = rimVal;
                    rimMax.floatValue = MaxRim;
                    rimMin.floatValue = MinRim;
                }
            }

            if (stylizeRamp.floatValue == 1)
            {
                float shadowVal = shadowToggle.floatValue;
                EditorGUI.BeginChangeCheck();
                GUILayout.Space(17);
                GUILayout.Label("Custom Ramp", EditorStyles.boldLabel);
                EditorGUI.showMixedValue = shadowToggle.hasMixedValue;
                shadowVal = EditorGUILayout.Toggle("Tint Shadows?", shadowToggle.floatValue == 1, GUILayout.MaxWidth(EditorGUIUtility.labelWidth + 13.0f)) ? 1 : 0;
                EditorGUI.showMixedValue = false;
                if (EditorGUI.EndChangeCheck()) shadowToggle.floatValue = shadowVal;
                GUILayout.Space(-17);

                GUILayout.BeginHorizontal();
                EditorGUI.BeginDisabledGroup(shadowToggle.floatValue == 0);
                GUILayout.Space(20);
                ProperColorBox(ref shadowColor, " ");
                EditorGUI.EndDisabledGroup();
                GUILayout.EndHorizontal();

                m_MaterialEditor.ShaderProperty(rampOff, Styles.rampOffText);
            }
            if (stylizeRamp.floatValue == 1 || stylizeSpec.floatValue == 1)
            { m_MaterialEditor.ShaderProperty(rampHard, Styles.rampHardText); GUILayout.Space(17); }

            if (outlineEnabled.floatValue > 0)
			{
				GUILayout.Label("Outlines", EditorStyles.boldLabel);
				ProperColorBox(ref outlineColor, "Outline Color");
		
				GUILayout.BeginHorizontal();
				m_MaterialEditor.ShaderProperty(stencilRef, "Stencil [0-255]");
				if(GUILayout.Button("Randomize"))stencilRef.floatValue = Mathf.RoundToInt(UnityEngine.Random.Range(0f, 255f));
				GUILayout.FlexibleSpace();
				GUILayout.EndHorizontal();
				
				m_MaterialEditor.RangeProperty(outlineColorMix, "Tint");
				m_MaterialEditor.ShaderProperty(outlineWidth, "Width");
				//m_MaterialEditor.ShaderProperty(angleAdjust, "Edge Fix Angle");
			}
			GUILayout.Space(17);
			GUILayout.FlexibleSpace();

			m_MaterialEditor.ShaderProperty(fakeLight, Styles.fakeLightText);
        }

        void DoEmissionArea(Material material)
        {
            // Emission for GI?
            if (m_MaterialEditor.EmissionEnabledProperty())
            {
                bool hadEmissionTexture = emissionMap.textureValue != null;

                // Texture and HDR color controls
                m_MaterialEditor.TexturePropertyWithHDRColor(Styles.emissionText, emissionMap, emissionColorForRendering, m_ColorPickerHDRConfig, false);

                // If texture was assigned and color was black set color to white
                float brightness = emissionColorForRendering.colorValue.maxColorComponent;
                if (emissionMap.textureValue != null && !hadEmissionTexture && brightness <= 0f)
                    emissionColorForRendering.colorValue = Color.white;

                // change the GI flag and fix it up with emissive as black if necessary
                m_MaterialEditor.LightmapEmissionFlagsProperty(MaterialEditor.kMiniTextureFieldLabelIndentLevel, true);
            }
        }

        void DoSpecularMetallicArea()
        {
            bool hasGlossMap = false;
            if (m_WorkflowMode == WorkflowMode.Specular)
            {
                hasGlossMap = specularMap.textureValue != null;
                m_MaterialEditor.TexturePropertySingleLine(Styles.specularMapText, specularMap, hasGlossMap ? null : specularColor);
            }
            else if (m_WorkflowMode == WorkflowMode.Metallic)
            {
                hasGlossMap = metallicMap.textureValue != null;
                m_MaterialEditor.TexturePropertySingleLine(Styles.metallicMapText, metallicMap, hasGlossMap ? null : metallic);
                if (advancedChannels.floatValue == 1)
                {
                    ProperPopup(ref metallicEnum, 80);
                    ProperPopup(ref glossEnum, 110);
                }
            }

            bool showSmoothnessScale = hasGlossMap;
            if (smoothnessMapChannel != null)
            {
                int smoothnessChannel = (int)smoothnessMapChannel.floatValue;
                if (smoothnessChannel == (int)SmoothnessMapChannel.AlbedoAlpha)
                    showSmoothnessScale = true;
            }

            int indentation = 2; // align with labels of texture properties
            m_MaterialEditor.ShaderProperty(showSmoothnessScale ? smoothnessScale : smoothness, showSmoothnessScale ? Styles.smoothnessScaleText : Styles.smoothnessText, indentation);

            ++indentation;
            if (smoothnessMapChannel != null && advancedChannels.floatValue != 1)
                m_MaterialEditor.ShaderProperty(smoothnessMapChannel, Styles.smoothnessMapChannelText, indentation);
            if (advancedChannels.floatValue != 1)
            {
                metallicEnum.floatValue = 0;
                glossEnum.floatValue = 3;
                heightEnum.floatValue = 1;
                occlusionEnum.floatValue = 1;
                maskEnum.floatValue = 3;
            }
        }

        public static void SetupMaterialWithBlendMode(Material material, BlendMode blendMode)
        {
            switch (blendMode)
            {
                case BlendMode.Opaque:
                    //material.shader=Shader.Find("Hidden/.Rero/Rero Standard/Rero Standard Opaque");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                    material.SetInt("_ZWrite", 1);
                    material.DisableKeyword("_ALPHATEST_ON");
                    material.DisableKeyword("_ALPHABLEND_ON");
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.renderQueue = -1;
                    break;
                case BlendMode.Cutout:
                    //material.shader=Shader.Find("Hidden/.Rero/Rero Standard/Rero Standard Cutout");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                    material.SetInt("_ZWrite", 1);
                    material.EnableKeyword("_ALPHATEST_ON");
                    material.DisableKeyword("_ALPHABLEND_ON");
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.AlphaTest;
                    break;
                case BlendMode.Fade:
                    //material.shader=Shader.Find("Hidden/.Rero/Rero Standard/Rero Standard Fade");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.SetInt("_ZWrite", 0);
                    material.DisableKeyword("_ALPHATEST_ON");
                    material.EnableKeyword("_ALPHABLEND_ON");
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    break;
                case BlendMode.Transparent:
                    //material.shader=Shader.Find("Hidden/.Rero/Rero Standard/Rero Standard Transparent");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.SetInt("_ZWrite", 0);
                    material.DisableKeyword("_ALPHATEST_ON");
                    material.DisableKeyword("_ALPHABLEND_ON");
                    material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    break;
            }
        }

        static SmoothnessMapChannel GetSmoothnessMapChannel(Material material)
        {
            int ch = (int)material.GetFloat("_SmoothnessTextureChannel");
            if (ch == (int)SmoothnessMapChannel.AlbedoAlpha)
                return SmoothnessMapChannel.AlbedoAlpha;
            else
                return SmoothnessMapChannel.SpecularMetallicAlpha;
        }

        static void SetMaterialKeywords(Material material, WorkflowMode workflowMode)
        {
            // Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
            // (MaterialProperty value might come from renderer material property block)
            SetKeyword(material, "_NORMALMAP", material.GetTexture("_BumpMap") || material.GetTexture("_DetailNormalMap"));
            if (workflowMode == WorkflowMode.Specular)
                SetKeyword(material, "_SPECGLOSSMAP", material.GetTexture("_SpecGlossMap"));
            else if (workflowMode == WorkflowMode.Metallic)
                SetKeyword(material, "_METALLICGLOSSMAP", material.GetTexture("_MetallicGlossMap"));
            SetKeyword(material, "_PARALLAXMAP", material.GetTexture("_ParallaxMap"));
            SetKeyword(material, "_DETAIL_MULX2", material.GetTexture("_DetailAlbedoMap") || material.GetTexture("_DetailNormalMap"));

            // A material's GI flag internally keeps track of whether emission is enabled at all, it's enabled but has no effect
            // or is enabled and may be modified at runtime. This state depends on the values of the current flag and emissive color.
            // The fixup routine makes sure that the material is in the correct state if/when changes are made to the mode or color.
            MaterialEditor.FixupEmissiveFlag(material);
            bool shouldEmissionBeEnabled = (material.globalIlluminationFlags & MaterialGlobalIlluminationFlags.EmissiveIsBlack) == 0;
            SetKeyword(material, "_EMISSION", shouldEmissionBeEnabled);

            if (material.HasProperty("_SmoothnessTextureChannel"))
            {
                SetKeyword(material, "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A", GetSmoothnessMapChannel(material) == SmoothnessMapChannel.AlbedoAlpha);
            }
        }

        static void MaterialChanged(Material material, WorkflowMode workflowMode)
        {
            SetupMaterialWithBlendMode(material, (BlendMode)material.GetFloat("_Mode"));

            SetMaterialKeywords(material, workflowMode);
			
			material.SetShaderPassEnabled("Always", material.GetFloat("_Mode") < 3);
        }

        static void SetKeyword(Material m, string keyword, bool state)
        {
            if (state)
                m.EnableKeyword(keyword);
            else
                m.DisableKeyword(keyword);
        }
		
		public void ProperColorBox(ref MaterialProperty colorProperty, string text)
		{
			Color boxColor = colorProperty.colorValue;
			EditorGUI.BeginChangeCheck();
			bool hdr=false;
			if(colorProperty.flags == MaterialProperty.PropFlags.HDR)
			{
				hdr=true;
			}
			Rect colorPropertyRect = EditorGUILayout.GetControlRect();
			colorPropertyRect.width = EditorGUIUtility.labelWidth+50.0f;
			EditorGUI.showMixedValue = colorProperty.hasMixedValue;
			boxColor = EditorGUI.ColorField(colorPropertyRect, new GUIContent (text), boxColor,true,true,hdr,new ColorPickerHDRConfig(0,65536,0,3));
			EditorGUI.showMixedValue = false;
			if(EditorGUI.EndChangeCheck())
			{
				colorProperty.colorValue=boxColor;
			}
		}

        public void ProperPopup(ref MaterialProperty Enum, float indent)
        {
            GUILayout.Space(-18);
            GUILayout.BeginHorizontal();
            GUILayout.Space(indent);
            string[] options = { "R", "G", "B", "A" };
            int Index = (int)Enum.floatValue;
            EditorGUI.BeginChangeCheck();
            Index = EditorGUILayout.Popup(Index, options, GUILayout.Width(25.0f));
            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck())
            {
                Enum.floatValue = Index;
            }
            GUILayout.EndHorizontal();
        }

        public void ButtonToggle(ref MaterialProperty boolProperty, string text)
		{
			float boolVal = boolProperty.floatValue;
			EditorGUI.BeginChangeCheck();
			boolVal =  GUILayout.Toggle(boolProperty.floatValue==1, text, "Button")?1:0;
			if(EditorGUI.EndChangeCheck())boolProperty.floatValue = boolVal;
		} 
    }
} // namespace UnityEditor
