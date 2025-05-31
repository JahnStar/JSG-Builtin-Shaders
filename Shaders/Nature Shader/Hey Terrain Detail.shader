// URP Balanced Terrain Detail Shader (Details Fixed + Performance)
// Developed by Halil Emre Yildiz @JahnStar - Github
// Converted from Built-in to URP with terrain compatibility

Shader "JS Games/URP/Nature/Hey Terrain Detail"
{
    Properties
    {
        [Header(Jahn Star Games URP Shader)][Space(5)]
        _Color("Main Color", Color) = (0.2,0.2,0.2,1)
        _MainTex("Main (RGB)", 2D) = "white" {}
        [Space(15)]
        _Color2("Overlay Color", Color) = (0.2,0.2,0.2,1)
        _DetailTex("Overlay (RGB)", 2D) = "white" {}
        _Overlay("Overlay Mixer", Range(0.0, 1.0)) = 0.0
        [Space(15)]
        _Color3("Blend Color", Color) = (0.2,0.2,0.2,1)
        _BlendTex("Blend (RGB)", 2D) = "white" {}
        _Blend("Blend Mixer", Range(0.0, 1.0)) = 0.0
        [Header(Alpha Channel Mixer)][Space(5)]
        _TexMixer("Alpha Mixer (RGB)", 2D) = "white" {}
        [Toggle] _DetailAlpha("Overlay Alpha (Red channel)", Float) = 0
        [Toggle] _BlendAlpha("Blend Alpha (Blue channel)", Float) = 0
        
        [Header(Android Settings)][Space(5)]
        [Toggle] _UseMipControl("Enable Mipmap Control", Float) = 1
        _MipBias("Mipmap Bias", Range(-1.0, 1.0)) = 0.0
        
        [Header(URP Settings)][Space(5)]
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.1
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        
        [Header(Performance)][Space(5)]
        [Toggle] _SimpleLighting("Simple Lighting (Mobile)", Float) = 0
        
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 2
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry-100"
            "IgnoreProjector" = "True"
            "TerrainCompatible" = "True"
        }
        
        LOD 150
        Cull[_CullMode]
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma target 3.0
            
            #pragma vertex vert
            #pragma fragment frag
            
            // Performance keyword (optional)
            #pragma shader_feature_local _SIMPLELIGHTING_ON
            
            // URP Keywords (minimal for performance)
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            
            // URP Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            // All texture samplers (always declared)
            TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);
            TEXTURE2D(_DetailTex);  SAMPLER(sampler_DetailTex);
            TEXTURE2D(_TexMixer);   SAMPLER(sampler_TexMixer);
            TEXTURE2D(_BlendTex);   SAMPLER(sampler_BlendTex);
            
            // Properties
            CBUFFER_START(UnityPerMaterial)
                half4 _Color, _Color2, _Color3;
                half _Blend, _Overlay, _DetailAlpha, _BlendAlpha;
                half _UseMipControl, _MipBias;
                half _Smoothness, _Metallic;
                float4 _MainTex_ST;
                float4 _DetailTex_ST;
                float4 _TexMixer_ST;
                float4 _BlendTex_ST;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv_MainTex : TEXCOORD0;
                float2 uv_DetailTex : TEXCOORD1;
                float2 uv_TexMixer : TEXCOORD2;
                float2 uv_BlendTex : TEXCOORD3;
                
                #if !defined(_SIMPLELIGHTING_ON)
                    float3 positionWS : TEXCOORD4;
                    float3 normalWS : TEXCOORD5;
                #endif
                
                float fogCoord : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            // Original texture sampling function (preserved)
            half4 SampleTextureBiased(TEXTURE2D_PARAM(tex, texSampler), half2 uv)
            {
                #if defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
                    if (_UseMipControl > 0.5)
                    {
                        return SAMPLE_TEXTURE2D_BIAS(tex, texSampler, uv, _MipBias);
                    }
                #endif
                return SAMPLE_TEXTURE2D(tex, texSampler, uv);
            }
            
            // Original overlay blend function (preserved)
            half3 overlay(half3 a, half3 b, half3 mix)
            {
                half3 result = a < 0.5 ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
                return lerp(a, result, mix);
            }
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                // Transform calculations
                #if !defined(_SIMPLELIGHTING_ON)
                    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                    output.positionCS = TransformWorldToHClip(output.positionWS);
                    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                #else
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                #endif
                
                // UV calculations (all preserved)
                output.uv_MainTex = TRANSFORM_TEX(input.uv, _MainTex);
                output.uv_DetailTex = TRANSFORM_TEX(input.uv, _DetailTex);
                output.uv_TexMixer = TRANSFORM_TEX(input.uv, _TexMixer);
                output.uv_BlendTex = TRANSFORM_TEX(input.uv, _BlendTex);
                
                // Fog
                output.fogCoord = ComputeFogFactor(output.positionCS.z);
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                // ORIGINAL ALGORITHM PRESERVED - sample all textures
                half3 mainColor = SampleTextureBiased(TEXTURE2D_ARGS(_MainTex, sampler_MainTex), input.uv_MainTex).rgb * _Color.rgb;
                mainColor *= (_Color.a * 5.1);
                half3 albedo = mainColor;
                
                half3 texMixer = SampleTextureBiased(TEXTURE2D_ARGS(_TexMixer, sampler_TexMixer), input.uv_TexMixer).rgb;
                
                // Overlay blend (ORIGINAL ALGORITHM)
                if (_Overlay > 0.01)
                {
                    half3 detailColor = SampleTextureBiased(TEXTURE2D_ARGS(_DetailTex, sampler_DetailTex), input.uv_DetailTex).rgb * _Color2.rgb;
                    detailColor *= (_Color2.a * 5.1);
                    detailColor = overlay(albedo, detailColor, _Overlay);
                    
                    if (_DetailAlpha > 0.5)
                    {
                        half texMixerDetail = texMixer.r;
                        albedo = lerp(mainColor, detailColor, texMixerDetail);
                    }
                    else albedo = detailColor;
                }
                
                // Blend mix (ORIGINAL ALGORITHM)
                if (_Blend > 0.01)
                {
                    half3 blendColor = SampleTextureBiased(TEXTURE2D_ARGS(_BlendTex, sampler_BlendTex), input.uv_BlendTex).rgb * _Color3.rgb;
                    blendColor *= (_Color3.a * 5.1);
                    blendColor = lerp(albedo, blendColor, blendColor * _Blend);
                    
                    if (_BlendAlpha > 0.5)
                    {
                        half texMixerBlend = texMixer.b;
                        albedo = lerp(albedo, blendColor, texMixerBlend);
                    }
                    else albedo = blendColor;
                }
                
                half4 color;
                
                // Performance option: Simple vs PBR lighting
                #if defined(_SIMPLELIGHTING_ON)
                    // Fast Lambert-style lighting for mobile
                    half3 lightDir = normalize(_MainLightPosition.xyz);
                    half ndotl = saturate(dot(normalize(input.normalWS), lightDir)) * 0.5 + 0.5;
                    color.rgb = albedo * _MainLightColor.rgb * ndotl;
                    color.a = 1.0;
                #else
                    // Full URP PBR lighting
                    InputData inputData = (InputData)0;
                    inputData.positionWS = input.positionWS;
                    inputData.normalWS = normalize(input.normalWS);
                    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                    inputData.fogCoord = input.fogCoord;
                    
                    SurfaceData surfaceData = (SurfaceData)0;
                    surfaceData.albedo = albedo;
                    surfaceData.metallic = _Metallic;
                    surfaceData.smoothness = _Smoothness;
                    surfaceData.normalTS = half3(0, 0, 1);
                    surfaceData.alpha = 1.0;
                    
                    color = UniversalFragmentPBR(inputData, surfaceData);
                #endif
                
                // Apply fog
                color.rgb = MixFog(color.rgb, input.fogCoord);
                
                return color;
            }
            ENDHLSL
        }
        
        // Shadow caster pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_CullMode]
            
            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        
        // Depth only pass  
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            
            ZWrite On
            ColorMask 0
            Cull[_CullMode]
            
            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
    
    Fallback "Universal Render Pipeline/Lit"
}