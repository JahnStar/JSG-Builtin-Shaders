// URP Mobile Double Sided Cutout Shader
// Developed by Halil Emre Yildiz @JahnStar - Github
// Converted from Built-in to URP with GPU Instancing support

Shader "JS Games/URP/Hey Mobile Double Sided Cutout"
{
    Properties
    {
        [Header(Jahn Star Games URP Shader)][Space(5)]
        _MainTex ("Diffuse Map", 2D) = "white" {}
        _Color ("Diffuse Color", Color) = (1,1,1,1)
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0.5

        [Header(Performance)][Space(5)]
        [Toggle] _SimpleLighting("Simple Lighting (Mobile)", Float) = 1
        [KeywordEnum(Single_Pass, Dual_Pass)] _RenderMode("Render Mode", Float) = 0

        [Header(URP Settings)][Space(5)]
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.0
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "TransparentCutout"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "AlphaTest"
            "IgnoreProjector" = "True"
        }

        LOD 100

        // Single Pass Version (More Performance)
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off  // Double sided in single pass

            HLSLPROGRAM
            #pragma target 3.0

            #pragma vertex vert
            #pragma fragment frag

            // Performance keywords
            #pragma shader_feature_local _SIMPLELIGHTING_ON
            #pragma shader_feature_local _RENDERMODE_SINGLE_PASS _RENDERMODE_DUAL_PASS

            // Alpha test (always on for cutout)
            #define _ALPHATEST_ON 1

            // URP Keywords (minimal)
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling

            // URP Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Texture
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            // Properties with GPU Instancing support
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(half, _Cutoff)
                UNITY_DEFINE_INSTANCED_PROP(half, _Smoothness)
                UNITY_DEFINE_INSTANCED_PROP(half, _Metallic)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

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
                float2 uv : TEXCOORD0;

                #if !defined(_SIMPLELIGHTING_ON)
                    float3 positionWS : TEXCOORD1;
                    float3 normalWS : TEXCOORD2;
                #else
                    float3 normalWS : TEXCOORD1;
                #endif

                float fogCoord : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

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
                #else
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                #endif

                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                // UV calculation
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);

                // Fog
                output.fogCoord = ComputeFogFactor(output.positionCS.z);

                return output;
            }

            half4 frag(Varyings input, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // Sample texture with instancing
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
                col *= color;

                // Alpha test
                half cutoff = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
                clip(col.a - cutoff);

                // Fix normals for back faces
                half3 normalWS = input.normalWS;
                if (!isFrontFace)
                {
                    normalWS = -normalWS;
                }
                normalWS = normalize(normalWS);

                half4 finalColor;

                // Lighting calculation
                #if defined(_SIMPLELIGHTING_ON)
                    // Fast mobile lighting
                    half3 lightDir = normalize(_MainLightPosition.xyz);
                    half ndotl = saturate(dot(normalWS, lightDir)) * 0.5 + 0.5;
                    finalColor.rgb = col.rgb * _MainLightColor.rgb * ndotl;
                    finalColor.a = 1.0;
                #else
                    // Full URP PBR lighting
                    InputData inputData = (InputData)0;
                    inputData.positionWS = input.positionWS;
                    inputData.normalWS = normalWS;
                    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                    #if defined(_MAIN_LIGHT_SHADOWS) || defined(_MAIN_LIGHT_SHADOWS_CASCADE) || defined(_ADDITIONAL_LIGHT_SHADOWS)
                        inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                    #else
                        inputData.shadowCoord = float4(0,0,0,0); 
                    #endif
                    inputData.fogCoord = input.fogCoord;

                    SurfaceData surfaceData = (SurfaceData)0;
                    surfaceData.albedo = col.rgb;
                    surfaceData.metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
                    surfaceData.smoothness = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness);
                    surfaceData.normalTS = half3(0, 0, 1);
                    surfaceData.alpha = 1.0; 

                    finalColor = UniversalFragmentPBR(inputData, surfaceData);
                #endif

                // Apply fog
                finalColor.rgb = MixFog(finalColor.rgb, input.fogCoord);

                return finalColor;
            }
            ENDHLSL
        }

        // Shadow Caster Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off  // Double sided shadows

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #define _ALPHATEST_ON 1

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            float4 _MainTex_ST; 

            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(half, _Cutoff)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

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
                #if defined(_ALPHATEST_ON)
                    float2 uv : TEXCOORD0;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                #if defined(_ALPHATEST_ON)
                    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                #endif

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                float3 lightDirectionWS;
                #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                    lightDirectionWS = normalize(_LightPosition.xyz - positionWS);
                #else
                    lightDirectionWS = _MainLightPosition.xyz;
                #endif

                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

                #if UNITY_REVERSED_Z
                    output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);

                #if defined(_ALPHATEST_ON)
                    half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                    half4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
                    albedo *= color;
                    half cutoff = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
                    clip(albedo.a - cutoff);
                #endif

                return 0;
            }
            ENDHLSL
        }

        // Depth Only Pass
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0
            Cull Off  // Double sided depth

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #define _ALPHATEST_ON 1

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // The include below might not be strictly necessary anymore if Alpha() isn't used,
            // but doesn't harm. It contains other helpers.
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(half, _Cutoff)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                #if defined(_ALPHATEST_ON)
                    float2 uv : TEXCOORD0;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                #if defined(_ALPHATEST_ON)
                    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                #endif

                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);

                #if defined(_ALPHATEST_ON)
                    half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                    half4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
                    albedo *= color;
                    half cutoff = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
                    clip(albedo.a - cutoff); // FIX: Reverted to direct clip function
                #endif

                return 0;
            }
            ENDHLSL
        }
    }

    Fallback "Universal Render Pipeline/Unlit"
}