// URP Fade Transparent Shader
// Developed by Halil Emre Yildiz @JahnStar - Github
// Converted from Built-in to URP with hybrid alpha test/blend

Shader "JS Games/URP/Hey Fade Transparent"
{
    Properties
    {
        [Header(Jahn Star Games URP Shader)][Space(5)]
        _Color("Main Color", Color) = (1,1,1,1)
        _MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
        _Cutoff("Alpha cutoff", Range(0,1)) = 0.5

        [Space(10)]
        [Header(Blend Settings)][Space(5)]
        _BlendTex("Blend Texture (RGB)", 2D) = "white" {}
        _Blend("Blend", Range(0,1)) = 0
        _MaxBlend("Max Blend", Range(0,1)) = 0.5
        _BrightnessV("Brightness", Range(0,5)) = 1

        [Header(Rendering)][Space(5)]
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 // CullMode.Back
        [Enum(Off,0,On,1)] _ZWrite("ZWrite", Float) = 0 // ZWrite Off for traditional transparency

        [Header(URP Settings)][Space(5)]
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.1
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0

        [Header(Performance)][Space(5)]
        [Toggle] _SimpleLighting("Simple Lighting (Mobile)", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }

        LOD 150
        // These are set per-pass by URP for ForwardLit.
        // For custom passes, ensure they are what you intend.
        // ZWrite[_ZWrite] // ZWrite is typically Off for transparent queue
        // Cull[_CullMode] // Cull mode can be useful
        // Blend SrcAlpha OneMinusSrcAlpha // Standard alpha blending

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            ZWrite[_ZWrite]
            Cull[_CullMode]
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma target 3.0

            #pragma vertex vert
            #pragma fragment frag

            // Performance keywords
            #pragma shader_feature_local _SIMPLELIGHTING_ON

            // URP Keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT // For receiving soft shadows
            #pragma multi_compile_fog

            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling

            // URP Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Textures
            TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);
            TEXTURE2D(_BlendTex);   SAMPLER(sampler_BlendTex);

            // Texture properties
            float4 _MainTex_ST;
            float4 _BlendTex_ST;

            // Properties
            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half _Cutoff;
                half _Blend;
                half _MaxBlend;
                half _BrightnessV;
                half _Smoothness;
                half _Metallic;
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
                float2 uv_BlendTex : TEXCOORD1;

                #if !defined(_SIMPLELIGHTING_ON)
                    float3 positionWS : TEXCOORD2;
                    float3 normalWS : TEXCOORD3;
                #else
                    float3 normalWS : TEXCOORD2;
                #endif

                float fogCoord : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if !defined(_SIMPLELIGHTING_ON)
                    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                    output.positionCS = TransformWorldToHClip(output.positionWS);
                #else
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                #endif

                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                output.uv_MainTex = TRANSFORM_TEX(input.uv, _MainTex);
                output.uv_BlendTex = TRANSFORM_TEX(input.uv, _BlendTex);

                output.fogCoord = ComputeFogFactor(output.positionCS.z);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv_MainTex) * _Color;

                if (_Blend > 0.01)
                {
                    half4 blendTex = SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, input.uv_BlendTex);
                    mainTex = lerp(mainTex, blendTex, _Blend * _MaxBlend);
                }

                half3 albedo = mainTex.rgb * _BrightnessV;

                half alpha;
                if (mainTex.a > _Cutoff) // Alpha test part
                    alpha = mainTex.a;   // Use texture alpha for blending
                else
                    alpha = 0.0;         // Discarded part by alpha test

                // For "Transparent" queue, alpha should primarily control blending,
                // clip() is for "TransparentCutout". If you want parts to be fully
                // cut out and others blended, this logic is okay.
                // If alpha is 0 from the above, it will be fully transparent.

                half4 color;
                half3 normalWS = normalize(input.normalWS);

                #if defined(_SIMPLELIGHTING_ON)
                    half3 lightDir = normalize(_MainLightPosition.xyz);
                    half ndotl = saturate(dot(normalWS, lightDir)) * 0.5 + 0.5;
                    color.rgb = albedo * _MainLightColor.rgb * ndotl;
                    color.a = alpha;
                #else
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
                    surfaceData.albedo = albedo;
                    surfaceData.metallic = _Metallic;
                    surfaceData.smoothness = _Smoothness;
                    surfaceData.normalTS = half3(0, 0, 1); // Assuming no normal map
                    surfaceData.alpha = alpha;

                    color = UniversalFragmentPBR(inputData, surfaceData);
                    // UniversalFragmentPBR already applies surfaceData.alpha to the output alpha.
                    // Re-assigning here might be redundant unless you intend to override PBR alpha.
                    color.a = alpha; 
                #endif

                color.rgb = MixFog(color.rgb, input.fogCoord);

                return color;
            }
            ENDHLSL
        }

        // Shadow Caster Pass (for alpha tested parts)
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_CullMode] // Use material's cull mode for shadows too

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling // Added for consistency

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
            // FIX: Moved declarations to the top
            TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);
            TEXTURE2D(_BlendTex);   SAMPLER(sampler_BlendTex);
            // For shadow/depth passes, UVs are often passed directly (input.texcoord)
            // If tiling/offset from _MainTex_ST/_BlendTex_ST is needed, declare them and use TRANSFORM_TEX
            float4 _MainTex_ST;
            float4 _BlendTex_ST;

            CBUFFER_START(UnityPerMaterial)
                half4 _Color; // Main color, affects shadow alpha if its alpha component is used
                half _Cutoff;
                half _Blend;
                half _MaxBlend;
                // _BrightnessV, _Smoothness, _Metallic are not typically needed for shadow caster
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 texcoord     : TEXCOORD0; // Using 'texcoord' as name for raw UVs
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0; // Will carry transformed UVs
                float4 positionCS   : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // Shadow Helper (from original shader)
            // Note: For URP, GetShadowPositionHClip(Attributes input) is usually defined in URP includes
            // or you can use the pattern: TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS))
            // The custom GetShadowPositionHClip here is fine if it serves a specific purpose.

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                // Apply tiling and offset for shadow pass UVs
                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex); 
                // If _BlendTex uses different UVs or T/O for shadows, handle similarly.
                // Assuming _BlendTex uses the same UVs as _MainTex for simplicity here for shadows.

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                // Determine light direction (standard URP way)
                float3 lightDirectionWS;
                #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW) // This keyword is set by URP for punctual light shadow passes
                    lightDirectionWS = normalize(_LightPosition.xyz - positionWS);
                #else // For directional lights
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
                
                half4 mainTexColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                // Apply base color only if it's intended to affect shadow alpha test (e.g., _Color.a)
                // For typical cutout, only texture alpha is used.
                // If _Color.a is part of the cutout alpha, then: mainTexColor *= _Color;
                half alpha = mainTexColor.a * _Color.a; // Consider if _Color.a should affect shadow

                if (_Blend > 0.01)
                {
                    // Assuming blend texture also uses input.uv from _MainTex T/O for shadows
                    half4 blendTexColor = SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, input.uv); 
                    // If _BlendTex needs its own T/O for shadows, pass its UVs separately.
                    // Lerp the alpha values if blend affects alpha, or lerp colors then take alpha.
                    // Original logic lerps colors, then takes alpha. For shadows, usually alpha is key.
                    half blendedAlpha = lerp(alpha, blendTexColor.a * _Color.a, _Blend * _MaxBlend); // Example: lerping alphas
                    alpha = blendedAlpha;
                }
                
                if (alpha <= _Cutoff)
                    discard;
                
                return 0; // Shadow caster outputs 0
            }
            ENDHLSL
        }

        // Depth Only Pass
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On // DepthOnly should always write to ZBuffer
            ColorMask 0
            Cull[_CullMode]

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling // Added for consistency

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // FIX: Moved declarations to the top
            TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);
            TEXTURE2D(_BlendTex);   SAMPLER(sampler_BlendTex);
            float4 _MainTex_ST;     // For TRANSFORM_TEX
            float4 _BlendTex_ST;    // For TRANSFORM_TEX

            CBUFFER_START(UnityPerMaterial)
                half4 _Color; // Main color, affects depth alpha if its alpha component is used
                half _Cutoff;
                half _Blend;
                half _MaxBlend;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0; // Raw UVs
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0; // Transformed UVs
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                // Apply tiling and offset for depth pass UVs
                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                // If _BlendTex uses different UVs or T/O for depth, handle similarly.

                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);

                half4 mainTexColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half alpha = mainTexColor.a * _Color.a; // Consider if _Color.a should affect depth write

                if (_Blend > 0.01)
                {
                    // Assuming blend texture uses input.uv from _MainTex T/O for depth
                    half4 blendTexColor = SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, input.uv);
                    // Lerp the alpha values if blend affects alpha
                    half blendedAlpha = lerp(alpha, blendTexColor.a * _Color.a, _Blend * _MaxBlend);
                    alpha = blendedAlpha;
                }

                if (alpha <= _Cutoff)
                    discard;

                return 0; // DepthOnly pass outputs 0
            }
            ENDHLSL
        }
    }

    Fallback "Universal Render Pipeline/Unlit"
}