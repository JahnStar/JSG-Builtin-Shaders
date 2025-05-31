// URP Ultra Mobile Diffuse Shader - CLEAN SYNTAX
// Developed by Halil Emre Yildiz @JahnStar - Github
// Converted from Built-in to URP with extreme performance optimization

Shader "JS Games/URP/Hey Mobile Diffuse"
{
    Properties 
    {
        [Header(Jahn Star Games Ultra Mobile Shader)]
        _Color("Main Color", Color) = (1,1,1,1)
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _Brightness("Brightness", Range(0,4)) = 1
        
        [Header(Performance Modes)]
        [KeywordEnum(UltraFast, Simple, FullPBR)] _PerformanceMode("Performance Mode", Float) = 1
        
        [Header(Optional Features)]
        [Toggle] _ReceiveShadows("Receive Shadows", Float) = 1
        [Toggle] _CastShadows("Cast Shadows", Float) = 1
        
        [Header(PBR Settings)]
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.0
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
    }
    
    SubShader 
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        LOD 100
        Cull Back
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma target 2.0
            
            #pragma vertex vert
            #pragma fragment frag
            
            // Keywords
            #pragma multi_compile_local __ _PERFORMANCEMODE_ULTRAFAST _PERFORMANCEMODE_SIMPLE _PERFORMANCEMODE_FULLPBR
            #pragma shader_feature_local _RECEIVESHADOWS_ON
            
            // URP Keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling
            
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            // Texture
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            // Properties
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(half, _Brightness)
                UNITY_DEFINE_INSTANCED_PROP(half, _Smoothness)
                UNITY_DEFINE_INSTANCED_PROP(half, _Metallic)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float fogCoord : TEXCOORD2;
                
                #if defined(_PERFORMANCEMODE_FULLPBR)
                    float3 positionWS : TEXCOORD3;
                    #if defined(_RECEIVESHADOWS_ON)
                        float4 shadowCoord : TEXCOORD4;
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
                
                #if defined(_PERFORMANCEMODE_FULLPBR)
                    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                    output.positionCS = TransformWorldToHClip(output.positionWS);
                    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                    
                    #if defined(_RECEIVESHADOWS_ON)
                        output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
                    #endif
                    output.fogCoord = ComputeFogFactor(output.positionCS.z);
                #else
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                    
                    #if !defined(_PERFORMANCEMODE_ULTRAFAST)
                        output.fogCoord = ComputeFogFactor(output.positionCS.z);
                    #endif
                #endif
                
                // UV transform
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
                half brightness = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Brightness);
                
                col *= color;
                col.rgb *= brightness;
                
                half4 finalColor;
                
                #if defined(_PERFORMANCEMODE_ULTRAFAST)
                    // Ultra Fast: No lighting
                    finalColor = col;
                    
                #elif defined(_PERFORMANCEMODE_SIMPLE)
                    // Simple: Basic lighting
                    half3 normalWS = normalize(input.normalWS);
                    half3 lightDir = normalize(_MainLightPosition.xyz);
                    half ndotl = saturate(dot(normalWS, lightDir)) * 0.5 + 0.5;
                    
                    finalColor.rgb = col.rgb * _MainLightColor.rgb * ndotl;
                    finalColor.a = col.a;
                    
                    finalColor.rgb = MixFog(finalColor.rgb, input.fogCoord);
                    
                #elif defined(_PERFORMANCEMODE_FULLPBR)
                    // Full PBR: Complete lighting
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
                    surfaceData.metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
                    surfaceData.smoothness = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness);
                    surfaceData.normalTS = half3(0, 0, 1);
                    surfaceData.alpha = col.a;
                    
                    finalColor = UniversalFragmentPBR(inputData, surfaceData);
                #else
                    // Default: Simple lighting fallback
                    half3 normalWS = normalize(input.normalWS);
                    half3 lightDir = normalize(_MainLightPosition.xyz);
                    half ndotl = saturate(dot(normalWS, lightDir)) * 0.5 + 0.5;
                    
                    finalColor.rgb = col.rgb * _MainLightColor.rgb * ndotl;
                    finalColor.a = col.a;
                    
                    finalColor.rgb = MixFog(finalColor.rgb, input.fogCoord);
                #endif
                
                return finalColor;
            }
            ENDHLSL
        }
        
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
            
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            // Simplified - always include shadows
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
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
                
                return output;
            }
            
            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                return 0;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            
            ZWrite On
            ColorMask 0
            Cull Back
            
            HLSLPROGRAM
            #pragma target 2.0
            
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }
            
            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                return 0;
            }
            ENDHLSL
        }
    }
    
    Fallback "Universal Render Pipeline/Lit"
}