// URP Mobile Double Sided Fast Shader
// Developed by Halil Emre Yildiz @JahnStar - Github
// Converted from Built-in to URP with mobile optimization

Shader "JS Games/URP/Hey Mobile Double Sided Fast"
{
    Properties 
    {
        [Header(Jahn Star Games URP Mobile Shader)][Space(5)]
        _MainTex ("Diffuse Map", 2D) = "white" {}
        _Color ("Diffuse Color", Color) = (1,1,1,1)
        
        [Header(Performance Options)][Space(5)]
        [Toggle] _SimpleLighting("Simple Lighting (Mobile)", Float) = 1
        [Enum(Single Pass,0,Two Pass,1)] _RenderMode("Render Mode", Float) = 0
        
        [Header(URP Settings)][Space(5)]
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
            "IgnoreProjector" = "True"
        }
        
        LOD 100
        
        // ========== SINGLE PASS VERSION (Default - Best Compatibility) ==========
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            Cull Off  // Render both sides in single pass
            
            HLSLPROGRAM
            #pragma target 2.0
            
            #pragma vertex vert
            #pragma fragment frag
            
            // Performance keywords
            #pragma shader_feature_local _SIMPLELIGHTING_ON
            
            // Minimal URP keywords for mobile
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_fog
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half _Smoothness, _Metallic;
                float4 _MainTex_ST;
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
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
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
                
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.fogCoord = ComputeFogFactor(output.positionCS.z);
                
                return output;
            }
            
            half4 frag(Varyings input, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                // Sample main texture
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half3 albedo = texColor.rgb * _Color.rgb;
                
                half4 color;
                
                #if defined(_SIMPLELIGHTING_ON)
                    // Super fast mobile lighting
                    half3 lightDir = normalize(_MainLightPosition.xyz);
                    half3 normal = normalize(input.normalWS);
                    
                    // Flip normal for back faces
                    if (!isFrontFace) normal = -normal;
                    
                    half ndotl = saturate(dot(normal, lightDir)) * 0.5 + 0.5;
                    color.rgb = albedo * _MainLightColor.rgb * ndotl;
                    color.a = texColor.a * _Color.a;
                #else
                    // Full URP PBR lighting
                    InputData inputData = (InputData)0;
                    inputData.positionWS = input.positionWS;
                    inputData.normalWS = normalize(input.normalWS);
                    
                    // Flip normal for back faces
                    if (!isFrontFace) inputData.normalWS = -inputData.normalWS;
                    
                    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                    inputData.fogCoord = input.fogCoord;
                    
                    SurfaceData surfaceData = (SurfaceData)0;
                    surfaceData.albedo = albedo;
                    surfaceData.metallic = _Metallic;
                    surfaceData.smoothness = _Smoothness;
                    surfaceData.normalTS = half3(0, 0, 1);
                    surfaceData.alpha = texColor.a * _Color.a;
                    
                    color = UniversalFragmentPBR(inputData, surfaceData);
                #endif
                
                // Apply fog
                color.rgb = MixFog(color.rgb, input.fogCoord);
                
                return color;
            }
            ENDHLSL
        }
        
        // ========== TWO PASS VERSION (Alternative for specific needs) ==========
        // Uncomment and use this section if you need the exact same behavior as original
        /*
        // Front faces pass
        Pass
        {
            Name "ForwardLit_Front"
            Tags { "LightMode" = "UniversalForward" }
            Cull Back
            
            HLSLPROGRAM
            // Same vertex/fragment code as above but without isFrontFace logic
            // and normal is never flipped
            ENDHLSL
        }
        
        // Back faces pass  
        Pass
        {
            Name "ForwardLit_Back"
            Tags { "LightMode" = "UniversalForward" }
            Cull Front
            
            HLSLPROGRAM
            // Same vertex/fragment code as above but normal is always flipped
            ENDHLSL
        }
        */
        
        // Shadow caster pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off  // Cast shadows from both sides
            
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
            Cull Off  // Depth from both sides
            
            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
    
    // ========== FALLBACK MOBILE VERSION (Ultra Performance) ==========
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        LOD 50  // Ultra low LOD for ancient devices
        
        Pass
        {
            Name "ForwardLit_Mobile"
            Tags { "LightMode" = "UniversalForward" }
            
            Cull Off
            
            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float4 _MainTex_ST;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                return texColor * _Color;
            }
            ENDHLSL
        }
    }
    
    Fallback "Universal Render Pipeline/Unlit"
}