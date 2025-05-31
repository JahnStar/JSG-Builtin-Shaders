// URP Ultra Mobile Cutout Shader
// Developed by Halil Emre Yildiz @JahnStar - Github
// Converted from Built-in to URP with maximum performance focus

Shader "JS Games/URP/Hey Mobile Cutout"
{
    Properties 
    {
        [Header(Jahn Star Games Ultra Mobile Shader)][Space(5)]
        _MainTex ("Diffuse Map", 2D) = "white" {}
        _Color ("Diffuse Color", Color) = (1,1,1,1)
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
        
        [Header(Performance)][Space(5)]
        [Toggle] _UltraFast("Ultra Fast Mode (No Shadows)", Float) = 0
        [Toggle] _SimpleLighting("Simple Lighting", Float) = 1
        
        [Header(URP Settings)][Space(5)]
        [Toggle] _ReceiveShadows("Receive Shadows", Float) = 1
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
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma target 2.0  // Mobile optimized
            
            #pragma vertex vert
            #pragma fragment frag
            
            // Alpha test (always on)
            #define _ALPHATEST_ON 1
            
            // Performance keywords
            #pragma shader_feature_local _ULTRAFAST_ON
            #pragma shader_feature_local _SIMPLELIGHTING_ON
            #pragma shader_feature_local _RECEIVESHADOWS_ON
            
            // URP Keywords (conditional for performance)
            #if !defined(_ULTRAFAST_ON)
                #if defined(_RECEIVESHADOWS_ON)
                    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                    #pragma multi_compile _ _SHADOWS_SOFT
                #endif
                #pragma multi_compile_fog
            #endif
            
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling
            
            // URP Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #if !defined(_ULTRAFAST_ON) && !defined(_SIMPLELIGHTING_ON)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #endif
            
            // Texture
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            // Properties with GPU Instancing
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(half, _Cutoff)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                #if !defined(_ULTRAFAST_ON)
                    float3 normalOS : NORMAL;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                
                #if !defined(_ULTRAFAST_ON)
                    #if !defined(_SIMPLELIGHTING_ON)
                        float3 positionWS : TEXCOORD1;
                        float3 normalWS : TEXCOORD2;
                        #if defined(_RECEIVESHADOWS_ON)
                            float4 shadowCoord : TEXCOORD3;
                        #endif
                        float fogCoord : TEXCOORD4;
                    #else
                        float3 normalWS : TEXCOORD1;
                        float fogCoord : TEXCOORD2;
                    #endif
                #endif
                
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                // Transform calculations (optimized based on mode)
                #if defined(_ULTRAFAST_ON)
                    // Ultra fast: Only clip space
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                #else
                    #if !defined(_SIMPLELIGHTING_ON)
                        // Full lighting: World space needed
                        output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                        output.positionCS = TransformWorldToHClip(output.positionWS);
                        output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                        
                        #if defined(_RECEIVESHADOWS_ON)
                            output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
                        #endif
                        output.fogCoord = ComputeFogFactor(output.positionCS.z);
                    #else
                        // Simple lighting: Minimal world space
                        output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                        output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                        output.fogCoord = ComputeFogFactor(output.positionCS.z);
                    #endif
                #endif
                
                // UV with manual transform for instancing
                float4 mainTexST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
                output.uv = input.uv * mainTexST.xy + mainTexST.zw;
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                // Sample texture
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
                col *= color;
                
                // Alpha test
                half cutoff = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
                clip(col.a - cutoff);
                
                half4 finalColor;
                
                #if defined(_ULTRAFAST_ON)
                    // Ultra fast: No lighting, just texture
                    finalColor = col;
                #else
                    #if defined(_SIMPLELIGHTING_ON)
                        // Simple lighting: Fast Lambert-style
                        half3 normalWS = normalize(input.normalWS);
                        half3 lightDir = normalize(_MainLightPosition.xyz);
                        half ndotl = saturate(dot(normalWS, lightDir)) * 0.5 + 0.5;
                        finalColor.rgb = col.rgb * _MainLightColor.rgb * ndotl;
                        finalColor.a = 1.0;
                    #else
                        // Full URP lighting
                        InputData inputData = (InputData)0;
                        inputData.positionWS = input.positionWS;
                        inputData.normalWS = normalize(input.normalWS);
                        inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                        #if defined(_RECEIVESHADOWS_ON)
                            inputData.shadowCoord = input.shadowCoord;
                        #else
                            inputData.shadowCoord = float4(0, 0, 0, 0);
                        #endif
                        inputData.fogCoord = input.fogCoord;
                        
                        SurfaceData surfaceData = (SurfaceData)0;
                        surfaceData.albedo = col.rgb;
                        surfaceData.metallic = 0.0;
                        surfaceData.smoothness = 0.0;
                        surfaceData.normalTS = half3(0, 0, 1);
                        surfaceData.alpha = 1.0;
                        
                        finalColor = UniversalFragmentPBR(inputData, surfaceData);
                    #endif
                    
                    // Apply fog (if not ultra fast)
                    finalColor.rgb = MixFog(finalColor.rgb, input.fogCoord);
                #endif
                
                return finalColor;
            }
            ENDHLSL
        }
        
        // Shadow Caster Pass (conditional)
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back
            
            HLSLPROGRAM
            #pragma target 2.0
            
            // Only include if not ultra fast
            #pragma shader_feature_local _ULTRAFAST_ON
            #pragma exclude_renderers gles
            
            #if !defined(_ULTRAFAST_ON)
                #pragma vertex ShadowPassVertex
                #pragma fragment ShadowPassFragment
                
                // Alpha test
                #define _ALPHATEST_ON 1
                
                // GPU Instancing
                #pragma multi_compile_instancing
                #pragma instancing_options assumeuniformscaling
                
                // Shadow keywords
                #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
                
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
                
                TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
                
                UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                    UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                    UNITY_DEFINE_INSTANCED_PROP(half, _Cutoff)
                    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
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
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };
                
                Varyings ShadowPassVertex(Attributes input)
                {
                    Varyings output = (Varyings)0;
                    UNITY_SETUP_INSTANCE_ID(input);
                    UNITY_TRANSFER_INSTANCE_ID(input, output);
                    
                    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                    
                    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                    #else
                        float3 lightDirectionWS = _MainLightPosition.xyz;
                    #endif
                    
                    output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                    
                    #if UNITY_REVERSED_Z
                        output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                    #else
                        output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                    #endif
                    
                    float4 mainTexST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
                    output.uv = input.uv * mainTexST.xy + mainTexST.zw;
                    
                    return output;
                }
                
                half4 ShadowPassFragment(Varyings input) : SV_TARGET
                {
                    UNITY_SETUP_INSTANCE_ID(input);
                    
                    half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                    half4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
                    col *= color;
                    half cutoff = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
                    clip(col.a - cutoff);
                    
                    return 0;
                }
            #else
                // Ultra fast mode: Empty pass
                #pragma vertex Vert
                #pragma fragment Frag
                
                float4 Vert() : SV_POSITION { return 0; }
                half4 Frag() : SV_Target { return 0; }
            #endif
            ENDHLSL
        }
        
        // Depth Only Pass (conditional)
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            
            ZWrite On
            ColorMask 0
            Cull Back
            
            HLSLPROGRAM
            #pragma target 2.0
            
            #pragma shader_feature_local _ULTRAFAST_ON
            
            #if !defined(_ULTRAFAST_ON)
                #pragma vertex DepthOnlyVertex
                #pragma fragment DepthOnlyFragment
                
                #define _ALPHATEST_ON 1
                
                #pragma multi_compile_instancing
                #pragma instancing_options assumeuniformscaling
                
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                
                TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
                
                UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                    UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                    UNITY_DEFINE_INSTANCED_PROP(half, _Cutoff)
                    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
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
                    float2 uv : TEXCOORD0;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };
                
                Varyings DepthOnlyVertex(Attributes input)
                {
                    Varyings output = (Varyings)0;
                    UNITY_SETUP_INSTANCE_ID(input);
                    UNITY_TRANSFER_INSTANCE_ID(input, output);
                    
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                    
                    float4 mainTexST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
                    output.uv = input.uv * mainTexST.xy + mainTexST.zw;
                    
                    return output;
                }
                
                half4 DepthOnlyFragment(Varyings input) : SV_TARGET
                {
                    UNITY_SETUP_INSTANCE_ID(input);
                    
                    half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                    half4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
                    col *= color;
                    half cutoff = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
                    clip(col.a - cutoff);
                    
                    return 0;
                }
            #else
                // Ultra fast mode: Empty pass
                #pragma vertex Vert
                #pragma fragment Frag
                
                float4 Vert() : SV_POSITION { return 0; }
                half4 Frag() : SV_Target { return 0; }
            #endif
            ENDHLSL
        }
    }
    
    Fallback "Universal Render Pipeline/Unlit"
}