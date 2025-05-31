// URP Leaf Diffuse Shake Shader
// Developed by Halil Emre Yildiz @JahnStar - Github
// Converted from Built-in to URP with advanced wind animation

Shader "JS Games/URP/Nature/Hey Leaf Diffuse Shake"
{
    Properties
    {
        [Header(Jahn Star Games URP Leaf Shader)][Space(5)]
        _Color("Main Color", Color) = (1,1,1,1)
        _MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
        _Cutoff("Alpha cutoff", Range(0,1)) = 0.5
        
        [Header(Wind Animation)][Space(5)]
        _ShakeDisplacement("Displacement", Range(0, 1.0)) = 1.0
        _ShakeTime("Shake Time", Range(0, 1.0)) = 1.0
        _ShakeWindspeed("Shake Windspeed", Range(0, 1.0)) = 1.0
        _ShakeBending("Shake Bending", Range(0, 1.0)) = 1.0
        
        [Header(Appearance)][Space(5)]
        _BrightnessValue("Brightness", Range(0,5)) = 1
        
        [Header(Performance)][Space(5)]
        [Toggle] _SimpleLighting("Simple Lighting (Mobile)", Float) = 1
        
        [Header(URP Settings)][Space(5)]
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.0
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2
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
        
        LOD 200
        Cull[_CullMode]
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma target 3.0
            
            #pragma vertex vert
            #pragma fragment frag
            
            // Alpha test (always on)
            #define _ALPHATEST_ON 1
            
            // Performance keywords
            #pragma shader_feature_local _SIMPLELIGHTING_ON
            
            // URP Keywords (minimal for performance)
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
            
            // Properties
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(half, _Cutoff)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeDisplacement)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeTime)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeWindspeed)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeBending)
                UNITY_DEFINE_INSTANCED_PROP(half, _BrightnessValue)
                UNITY_DEFINE_INSTANCED_PROP(half, _Smoothness)
                UNITY_DEFINE_INSTANCED_PROP(half, _Metallic)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float2 texcoord : TEXCOORD1;  // For wind calculation
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
            
            // Fast sin/cos approximation (preserved from original)
            void FastSinCos(half4 val, out half4 s, out half4 c) 
            {
                val = val * 6.2831853 - 3.1415927; // 2 * PI
                half4 val2 = val * val;
                s = val * (1 - val2 * (1/6.0 - val2 * (1/120.0)));
                c = 1 - val2 * (0.5 - val2 * (1/24.0));
            }
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                // Get instanced properties
                half shakeDisplacement = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeDisplacement);
                half shakeTime = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeTime);
                half shakeWindspeed = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeWindspeed);
                half shakeBending = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeBending);
                
                // ORIGINAL WIND ANIMATION ALGORITHM (preserved)
                half factor = (1 - shakeDisplacement - input.color.r) * 0.5;
                
                const half windSpeed = (shakeWindspeed + input.color.g);
                const half waveScale = shakeDisplacement;
                
                const half4 waveXSize = half4(0.048, 0.06, 0.24, 0.096);
                const half4 waveZSize = half4(0.024, 0.08, 0.08, 0.2);
                const half4 waveSpeed = half4(1.2, 2, 1.6, 4.8);
                
                const half4 waveXmove = half4(0.024, 0.04, -0.12, 0.096);
                const half4 waveZmove = half4(0.006, 0.02, -0.02, 0.1);
                
                half4 waves = input.positionOS.x * waveXSize + input.positionOS.z * waveZSize;
                waves += _Time.x * (1 - shakeTime * 2 - input.color.b) * waveSpeed * windSpeed;
                
                half4 s, c;
                waves = frac(waves);
                FastSinCos(waves, s, c);
                
                half waveAmount = input.texcoord.y * (input.color.a + shakeBending);
                s *= waveAmount;
                
                s *= normalize(waveSpeed);
                
                s = s * s;
                half fade = dot(s, 1.3);
                s = s * s;
                
                half3 waveMove = half3(0, 0, 0);
                waveMove.x = dot(s, waveXmove);
                waveMove.z = dot(s, waveZmove);
                
                // Apply wind movement
                float4 animatedPos = input.positionOS;
                animatedPos.xz -= mul((half3x3)unity_WorldToObject, waveMove).xz;
                
                // Transform calculations
                #if !defined(_SIMPLELIGHTING_ON)
                    output.positionWS = TransformObjectToWorld(animatedPos.xyz);
                    output.positionCS = TransformWorldToHClip(output.positionWS);
                #else
                    output.positionCS = TransformObjectToHClip(animatedPos.xyz);
                #endif
                
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                // Manual UV transform for instanced properties
                float4 mainTexST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
                output.uv = input.uv * mainTexST.xy + mainTexST.zw;
                
                // Fog
                output.fogCoord = ComputeFogFactor(output.positionCS.z);
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                // Sample texture with instancing
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
                half brightness = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BrightnessValue);
                
                col *= color;
                col.rgb *= brightness;
                
                // Alpha test
                half cutoff = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
                clip(col.a - cutoff);
                
                half3 normalWS = normalize(input.normalWS);
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
                    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
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
        
        // Shadow Caster Pass with wind animation
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
            
            // Alpha test (always on)
            #define _ALPHATEST_ON 1
            
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling
            
            // Shadow keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
            // Texture for alpha test
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(half, _Cutoff)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeDisplacement)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeTime)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeWindspeed)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeBending)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float2 texcoord : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            // Fast sin/cos for shadows (same as main pass)
            void FastSinCos(half4 val, out half4 s, out half4 c) 
            {
                val = val * 6.2831853 - 3.1415927;
                half4 val2 = val * val;
                s = val * (1 - val2 * (1/6.0 - val2 * (1/120.0)));
                c = 1 - val2 * (0.5 - val2 * (1/24.0));
            }
            
            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                
                // Apply same wind animation as main pass
                half shakeDisplacement = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeDisplacement);
                half shakeTime = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeTime);
                half shakeWindspeed = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeWindspeed);
                half shakeBending = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeBending);
                
                const half windSpeed = (shakeWindspeed + input.color.g);
                const half4 waveXSize = half4(0.048, 0.06, 0.24, 0.096);
                const half4 waveZSize = half4(0.024, 0.08, 0.08, 0.2);
                const half4 waveSpeed = half4(1.2, 2, 1.6, 4.8);
                const half4 waveXmove = half4(0.024, 0.04, -0.12, 0.096);
                const half4 waveZmove = half4(0.006, 0.02, -0.02, 0.1);
                
                half4 waves = input.positionOS.x * waveXSize + input.positionOS.z * waveZSize;
                waves += _Time.x * (1 - shakeTime * 2 - input.color.b) * waveSpeed * windSpeed;
                
                half4 s, c;
                waves = frac(waves);
                FastSinCos(waves, s, c);
                
                half waveAmount = input.texcoord.y * (input.color.a + shakeBending);
                s *= waveAmount;
                s *= normalize(waveSpeed);
                s = s * s;
                s = s * s;
                
                half3 waveMove = half3(0, 0, 0);
                waveMove.x = dot(s, waveXmove);
                waveMove.z = dot(s, waveZmove);
                
                float4 animatedPos = input.positionOS;
                animatedPos.xz -= mul((half3x3)unity_WorldToObject, waveMove).xz;
                
                // Shadow position calculation
                float3 positionWS = TransformObjectToWorld(animatedPos.xyz);
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
                
                // Manual UV transform for instanced properties
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
            ENDHLSL
        }
        
        // Depth Only Pass with wind animation
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
            
            // Alpha test (always on)
            #define _ALPHATEST_ON 1
            
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            // Same wind system as main pass
            void FastSinCos(half4 val, out half4 s, out half4 c) 
            {
                val = val * 6.2831853 - 3.1415927;
                half4 val2 = val * val;
                s = val * (1 - val2 * (1/6.0 - val2 * (1/120.0)));
                c = 1 - val2 * (0.5 - val2 * (1/24.0));
            }
            
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(half, _Cutoff)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeDisplacement)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeTime)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeWindspeed)
                UNITY_DEFINE_INSTANCED_PROP(half, _ShakeBending)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float2 texcoord : TEXCOORD1;
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
                
                // Apply wind animation (same as main pass)
                half shakeDisplacement = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeDisplacement);
                half shakeTime = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeTime);
                half shakeWindspeed = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeWindspeed);
                half shakeBending = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShakeBending);
                
                const half windSpeed = (shakeWindspeed + input.color.g);
                const half4 waveXSize = half4(0.048, 0.06, 0.24, 0.096);
                const half4 waveZSize = half4(0.024, 0.08, 0.08, 0.2);
                const half4 waveSpeed = half4(1.2, 2, 1.6, 4.8);
                const half4 waveXmove = half4(0.024, 0.04, -0.12, 0.096);
                const half4 waveZmove = half4(0.006, 0.02, -0.02, 0.1);
                
                half4 waves = input.positionOS.x * waveXSize + input.positionOS.z * waveZSize;
                waves += _Time.x * (1 - shakeTime * 2 - input.color.b) * waveSpeed * windSpeed;
                
                half4 s, c;
                waves = frac(waves);
                FastSinCos(waves, s, c);
                
                half waveAmount = input.texcoord.y * (input.color.a + shakeBending);
                s *= waveAmount;
                s *= normalize(waveSpeed);
                s = s * s;
                s = s * s;
                
                half3 waveMove = half3(0, 0, 0);
                waveMove.x = dot(s, waveXmove);
                waveMove.z = dot(s, waveZmove);
                
                float4 animatedPos = input.positionOS;
                animatedPos.xz -= mul((half3x3)unity_WorldToObject, waveMove).xz;
                
                output.positionCS = TransformObjectToHClip(animatedPos.xyz);
                
                // Manual UV transform for instanced properties
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
            ENDHLSL
        }
    }
    
    Fallback "Universal Render Pipeline/Unlit"
}