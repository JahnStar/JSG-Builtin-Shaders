// URP Mobile Bumped Projection Shader
// Developed by Halil Emre Yildiz @JahnStar - Github
// Converted from Built-in to URP with advanced projection features

Shader "JS Games/URP/Hey Mobile Bumped Projection"
{
    Properties 
    {
        [Header(Jahn Star Games URP Shader)][Space(5)]
        _Color("Main Color", Color) = (1,1,1,1)
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _Brightness("Brightness", Range(0,4)) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2
        [Toggle] _UseNormalMap("Use Normal Map", Float) = 1
        
        [Space(10)]
        [Header(Projection Settings)][Space(5)]
        _ProjectionTex("Projection Texture", 2D) = "white" {}
        [Enum(X,0,Y,1,Z,2)] _ProjectionDirection("Projection Direction", Int) = 1
        _ProjectionStrength("Projection Strength", Range(0,1)) = 0.5
        _ProjectionScale("Projection Scale", Range(0.1,10)) = 1
        _ProjectionFalloff("Projection Falloff", Range(0.1,10)) = 1
        _ProjectionThreshold("Projection Threshold", Range(0.1,1)) = 0.5
        
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
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        LOD 100
        Cull[_CullMode]
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma target 3.0
            
            #pragma vertex vert
            #pragma fragment frag
            
            // Feature keywords
            #pragma shader_feature_local _USENORMALMAP_ON
            #pragma shader_feature_local _SIMPLELIGHTING_ON
            
            // URP Keywords (minimal for performance)
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            
            // GPU Instancing
            #pragma multi_compile_instancing
            
            // URP Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            // Textures
            TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
            TEXTURE2D(_BumpMap);        SAMPLER(sampler_BumpMap);
            TEXTURE2D(_ProjectionTex);  SAMPLER(sampler_ProjectionTex);
            
            // Texture properties
            float4 _MainTex_ST;
            float4 _BumpMap_ST;
            
            // Properties
            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half _Brightness;
                half _Smoothness;
                half _Metallic;
                int _ProjectionDirection;
                half _ProjectionStrength;
                half _ProjectionScale;
                half _ProjectionFalloff;
                half _ProjectionThreshold;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 bumpUV : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                
                #if !defined(_SIMPLELIGHTING_ON)
                    float3 normalWS : TEXCOORD3;
                    #if defined(_USENORMALMAP_ON)
                        float3 tangentWS : TEXCOORD4;
                        float3 bitangentWS : TEXCOORD5;
                    #endif
                #else
                    float3 normalWS : TEXCOORD3;
                #endif
                
                float fogCoord : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                // Position calculations
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                
                // UV calculations
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.bumpUV = TRANSFORM_TEX(input.uv, _BumpMap);
                
                // Normal and tangent calculations
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                #if !defined(_SIMPLELIGHTING_ON) && defined(_USENORMALMAP_ON)
                    // Full normal mapping for high quality
                    output.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
                    real sign = input.tangentOS.w * GetOddNegativeScale();
                    output.bitangentWS = cross(output.normalWS, output.tangentWS) * sign;
                #endif
                
                // Fog
                output.fogCoord = ComputeFogFactor(output.positionCS.z);
                
                return output;
            }
            
            // Projection UV calculation
            float2 GetProjectionUV(float3 worldPos, int direction, half scale)
            {
                float2 projUV;
                if (direction == 0) // X direction
                    projUV = worldPos.yz * scale;
                else if (direction == 1) // Y direction
                    projUV = worldPos.xz * scale;
                else // Z direction (default)
                    projUV = worldPos.xy * scale;
                
                return projUV;
            }
            
            // Projection factor calculation
            half GetProjectionFactor(float3 worldNormal, int direction, half threshold, half falloff)
            {
                half projFactor = 0.0;
                
                // Get appropriate normal component
                if (direction == 0) // X direction
                    projFactor = abs(worldNormal.x);
                else if (direction == 1) // Y direction
                    projFactor = abs(worldNormal.y);
                else // Z direction
                    projFactor = abs(worldNormal.z);
                
                // Apply threshold to limit coverage
                projFactor = max(0, projFactor - (1.0 - threshold));
                
                // Apply non-linear falloff for smooth transition
                projFactor = pow(projFactor * (1.0 / threshold), falloff);
                
                return saturate(projFactor);
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                // Sample base texture
                half4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _Color;
                
                // Normal mapping
                half3 normalTS = half3(0, 0, 1);
                #if defined(_USENORMALMAP_ON)
                    normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.bumpUV));
                #endif
                
                // Calculate world normal
                half3 normalWS;
                #if !defined(_SIMPLELIGHTING_ON) && defined(_USENORMALMAP_ON)
                    // High quality normal mapping
                    normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS, input.bitangentWS, input.normalWS));
                #else
                    // Simple normal mapping or vertex normal
                    #if defined(_USENORMALMAP_ON)
                        // Simplified normal mapping for mobile
                        normalWS = normalize(input.normalWS + normalTS);
                    #else
                        normalWS = input.normalWS;
                    #endif
                #endif
                normalWS = normalize(normalWS);
                
                // Projection texture sampling
                float2 projUV = GetProjectionUV(input.positionWS, _ProjectionDirection, _ProjectionScale);
                half4 projTexture = SAMPLE_TEXTURE2D(_ProjectionTex, sampler_ProjectionTex, projUV);
                
                // Calculate projection factor
                half projFactor = GetProjectionFactor(normalWS, _ProjectionDirection, _ProjectionThreshold, _ProjectionFalloff);
                
                // Blend base and projection textures
                half blendFactor = projFactor * _ProjectionStrength;
                half3 albedo = lerp(baseColor.rgb, projTexture.rgb, blendFactor) * _Brightness;
                
                half4 color;
                
                // Lighting calculation
                #if defined(_SIMPLELIGHTING_ON)
                    // Fast mobile lighting
                    half3 lightDir = normalize(_MainLightPosition.xyz);
                    half ndotl = saturate(dot(normalWS, lightDir)) * 0.5 + 0.5;
                    color.rgb = albedo * _MainLightColor.rgb * ndotl;
                    color.a = baseColor.a;
                #else
                    // Full URP PBR lighting
                    InputData inputData = (InputData)0;
                    inputData.positionWS = input.positionWS;
                    inputData.normalWS = normalWS;
                    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                    inputData.fogCoord = input.fogCoord;
                    
                    SurfaceData surfaceData = (SurfaceData)0;
                    surfaceData.albedo = albedo;
                    surfaceData.metallic = _Metallic;
                    surfaceData.smoothness = _Smoothness;
                    surfaceData.normalTS = normalTS;
                    surfaceData.alpha = baseColor.a;
                    
                    color = UniversalFragmentPBR(inputData, surfaceData);
                #endif
                
                // Apply fog
                color.rgb = MixFog(color.rgb, input.fogCoord);
                
                return color;
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
            Cull[_CullMode]
            
            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        
        // Depth Only Pass
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