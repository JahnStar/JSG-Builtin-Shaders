// Advanced Terrain Detail Shader with Fade Distance & Projection
// Developed by Halil Emre Yildiz @JahnStar - Github
// Enhanced with projection mapping for rocks and fade distance

Shader "JS Games/Nature/Hey Terrain Detail Advanced" 
{
    Properties
    {
        [Header(Jahn Star Games Shader)][Space(5)]
        _Color("Main Color", Color) = (0.2,0.2,0.2,1)
        _MainTex("Main (RGB)", 2D) = "white" {}
        [Space(15)]
        _Color2("Overlay Color", Color) = (0.2,0.2,0.2,1)
        _DetailTex("Mix Layer (RGB)", 2D) = "white" {}
        _Overlay("Overlay Mixer", Range(0.0, 1.0)) = 0.0
        [Enum(Normal,0,Multiply,1,Screen,2,Overlay,3,Soft Light,4,Hard Light,5)] _OverlayMode("Mix Mode", Int) = 3
        [Space(15)]
        _Color3("Blend Color", Color) = (0.2,0.2,0.2,1)
        _BlendTex("Blend (RGB)", 2D) = "white" {}
        _Blend("Blend Mixer", Range(0.0, 1.0)) = 0.0
        [Header(Alpha Channel Mixer)][Space(5)]	
        _TexMixer("Alpha Mixer (RGB)", 2D) = "white" {}
        [Toggle] _DetailAlpha("Overlay Alpha (Red channel)", Float) = 0
        [Toggle] _BlendAlpha("Blend Alpha (Blue channel)", Float) = 0
        
        // Projection Settings - For rock texture
        [Header(Projection Mapping (Rocks))][Space(5)]
        [Toggle] _UseProjection("Enable Projection", Float) = 0
        _ProjectionTex("Projection Texture (Rock)", 2D) = "white" {}
        _ProjectionColor("Projection Color", Color) = (1,1,1,1)
        [Enum(Normal (Steep Surfaces),0,Inverted (Flat Surfaces),1)] _ProjectionMode("Projection Mode", Int) = 1
        [Enum(X,0,Y,1,Z,2)] _ProjectionDirection("Projection Direction", Int) = 1
        _ProjectionStrength("Projection Strength", Range(0,1)) = 0.5
        _ProjectionScale("Projection Scale", Range(0.1,10)) = 1
        _ProjectionFalloff("Projection Falloff", Range(0.1,10)) = 1
        _ProjectionThreshold("Projection Threshold", Range(0.1,1)) = 0.5
        
        // Fade Distance Control
        [Header(Detail Fade Distance)][Space(5)]
        _FadeStart("Fade Start Distance", Float) = 50.0
        _FadeEnd("Fade End Distance", Float) = 100.0
        [Toggle] _UseFade("Enable Distance Fade", Float) = 1
        
        // Android Settings
        [Header(Android Settings)][Space(5)]
        [Toggle] _UseMipControl("Enable Mipmap Control", Float) = 1
        _MipBias("Mipmap Bias", Range(-1.0, 1.0)) = 0.0
        
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 2 // "Back" 
    }
    
    SubShader
    {
        Tags { 
            "LIGHTMODE" = "ForwardBase" 
            "SHADOWSUPPORT" = "false" 
            "Queue" = "Geometry-100" 
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True" 
            "TerrainCompatible" = "True"
        }
        
        LOD 150
        Cull[_CullMode]
        
        CGPROGRAM
        #pragma surface surf Lambert vertex:vert nolightmap fullforwardshadows
        #pragma target 3.0
        #pragma multi_compile_fog
        #include "UnityCG.cginc"
        
        sampler2D _MainTex;
        sampler2D _DetailTex;
        sampler2D _TexMixer;
        sampler2D _BlendTex;
        sampler2D _ProjectionTex;
        half4 _Color, _Color2, _Color3, _ProjectionColor;
        half _Blend, _Overlay, _DetailAlpha, _BlendAlpha;
        half _UseMipControl, _MipBias;
        int _OverlayMode;
        
        // Fade Distance parameters
        half _FadeStart, _FadeEnd, _UseFade;
        
        // Projection parameters
        half _UseProjection;
        int _ProjectionDirection, _ProjectionMode;
        half _ProjectionStrength, _ProjectionScale, _ProjectionFalloff, _ProjectionThreshold;
        
        // Balanced texture sampling function
        half4 SampleTexture(sampler2D tex, half2 uv)
        {
            #if defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
                if (_UseMipControl > 0.5)
                {
                    return tex2Dbias(tex, float4(uv, 0, _MipBias));
                }
            #endif
            
            return tex2D(tex, uv);
        }
        
        // Fade factor calculation function
        half CalculateFadeFactor(half distance)
        {
            if (_UseFade < 0.5) return 1.0; // If fade is off, return full strength
            
            // Smooth fade between start and end distances
            half fadeFactor = 1.0 - saturate((distance - _FadeStart) / (_FadeEnd - _FadeStart));
            return fadeFactor;
        }
        
        // Projection factor calculation function
        half CalculateProjectionFactor(half3 worldNormal, half3 worldPos)
        {
            if (_UseProjection < 0.5) return 0.0; // If projection is off
            
            // Y direction - for horizontal surfaces
            if (_ProjectionDirection == 1) // Y direction
            {
                if (_ProjectionMode == 1) // Inverted - for horizontal surfaces
                {
                    // Apply projection when worldNormal.y is high (horizontal surface)
                    half flatness = worldNormal.y; // 0 = steep, 1 = completely horizontal
                    
                    // Use smoothstep for soft transition
                    half thresholdMin = _ProjectionThreshold - 0.2; // Lower bound
                    half thresholdMax = _ProjectionThreshold + 0.1; // Upper bound
                    
                    // Clamp values
                    thresholdMin = max(0.0, thresholdMin);
                    thresholdMax = min(1.0, thresholdMax);
                    
                    // Smoothstep for very soft transition
                    half projFactor = smoothstep(thresholdMin, thresholdMax, flatness);
                    
                    // Additional falloff control
                    return pow(projFactor, 1.0 / max(0.1, _ProjectionFalloff));
                }
                else // Normal - for steep surfaces
                {
                    half steepness = 1.0 - worldNormal.y; // 0 = horizontal, 1 = steep
                    
                    half thresholdMin = _ProjectionThreshold - 0.2;
                    half thresholdMax = _ProjectionThreshold + 0.1;
                    thresholdMin = max(0.0, thresholdMin);
                    thresholdMax = min(1.0, thresholdMax);
                    
                    half projFactor = smoothstep(thresholdMin, thresholdMax, steepness);
                    return pow(projFactor, 1.0 / max(0.1, _ProjectionFalloff));
                }
            }
            
            // Other directions (X, Z)
            half normalComponent = 0.0;
            if (_ProjectionDirection == 0) // X direction
                normalComponent = abs(worldNormal.x);
            else // Z direction
                normalComponent = abs(worldNormal.z);
            
            half projFactor = 0.0;
            if (_ProjectionMode == 1) // Inverted
            {
                half thresholdMin = _ProjectionThreshold - 0.2;
                half thresholdMax = _ProjectionThreshold + 0.1;
                thresholdMin = max(0.0, thresholdMin);
                thresholdMax = min(1.0, thresholdMax);
                projFactor = smoothstep(thresholdMin, thresholdMax, normalComponent);
            }
            else // Normal
            {
                half thresholdMin = _ProjectionThreshold - 0.2;
                half thresholdMax = _ProjectionThreshold + 0.1;
                thresholdMin = max(0.0, thresholdMin);
                thresholdMax = min(1.0, thresholdMax);
                projFactor = smoothstep(thresholdMin, thresholdMax, 1.0 - normalComponent);
            }
            
            return pow(projFactor, 1.0 / max(0.1, _ProjectionFalloff));
        }
        
        // Projection UV calculation function
        half2 CalculateProjectionUV(half3 worldPos)
        {
            half2 projUV;
            if (_ProjectionDirection == 0) // X direction
                projUV = worldPos.yz * _ProjectionScale;
            else if (_ProjectionDirection == 1) // Y direction
                projUV = worldPos.xz * _ProjectionScale;
            else // Z direction
                projUV = worldPos.xy * _ProjectionScale;
            
            return projUV;
        }
        
        // Mix mode functions
        half3 BlendMix(half3 base, half3 blend, int mode, half strength)
        {
            half3 result = base;
            
            if (mode == 0) // Normal
            {
                result = lerp(base, blend, strength);
            }
            else if (mode == 1) // Multiply
            {
                result = lerp(base, base * blend, strength);
            }
            else if (mode == 2) // Screen
            {
                result = lerp(base, 1.0 - (1.0 - base) * (1.0 - blend), strength);
            }
            else if (mode == 3) // Overlay
            {
                half3 overlayResult = base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend));
                result = lerp(base, overlayResult, strength);
            }
            else if (mode == 4) // Soft Light
            {
                half3 softResult = blend < 0.5 ? 
                    (2.0 * base * blend + base * base * (1.0 - 2.0 * blend)) :
                    (sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend));
                result = lerp(base, softResult, strength);
            }
            else if (mode == 5) // Hard Light
            {
                half3 hardResult = blend < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend));
                result = lerp(base, hardResult, strength);
            }
            
            return result;
        }
        
        half3 overlay(half3 a, half3 b, half3 mix)
        {
            half3 result = a < 0.5 ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
            return lerp(a, result, mix);
        }
        
        struct Input 
        {
            half2 uv_MainTex : TEXCOORD0;
            half2 uv_DetailTex: TEXCOORD1;
            half2 uv_TexMixer;
            half2 uv_BlendTex : TEXCOORD2;
            half mixZ;
            half3 worldPos; // World position
            half3 worldNormal; // World normal
            INTERNAL_DATA
        };
        
        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input,o);
            half4 wpos = mul(unity_ObjectToWorld, v.vertex);
            o.mixZ = wpos.xz;
            o.worldPos = wpos.xyz;
            o.worldNormal = UnityObjectToWorldNormal(v.normal);
        }
        
        void surf(Input IN, inout SurfaceOutput o)
        {
            // Calculate distance from camera
            half distanceFromCamera = distance(IN.worldPos, _WorldSpaceCameraPos);
            half fadeFactor = CalculateFadeFactor(distanceFromCamera);
            
            // Main texture
            half3 _main = SampleTexture(_MainTex, IN.uv_MainTex) * _Color;
            _main *= (_Color.a * 5.1);
            half3 albedo = _main.rgb;
            
            half3 _texMixer = SampleTexture(_TexMixer, IN.uv_TexMixer);
            
            // Overlay (Detail) - controlled by fade factor
            if (_Overlay != 0) 
            {
                half3 _detail = SampleTexture(_DetailTex, IN.uv_DetailTex) * _Color2;
                _detail *= (_Color2.a * 5.1);
                
                // Multiply overlay strength with fade factor
                half overlayStrength = _Overlay * fadeFactor;
                
                // Blend with new mix mode system
                _detail = BlendMix(albedo.rgb, _detail.rgb, _OverlayMode, overlayStrength);
                
                if (_DetailAlpha)
                {
                    half texMixer_detail = _texMixer.r * fadeFactor;
                    albedo = lerp(_main, _detail, texMixer_detail);
                }
                else 
                {
                    albedo = lerp(_main, _detail, fadeFactor);
                }
            }
            
            // Blend - controlled by fade factor
            if (_Blend != 0)
            {
                half3 _blend = SampleTexture(_BlendTex, IN.uv_BlendTex) * _Color3;
                _blend *= (_Color3.a * 5.1);
                
                half blendStrength = _Blend * fadeFactor;
                _blend = lerp(albedo.rgb, _blend.rgb, _blend * blendStrength);
                
                if (_BlendAlpha)
                {
                    half texMixer_blend = _texMixer.b * fadeFactor;
                    albedo = lerp(albedo, _blend, texMixer_blend);
                }
                else 
                {
                    albedo = lerp(albedo, _blend, fadeFactor);
                }
            }
            
            // Projection (Rock) - Based on Normal
            if (_UseProjection > 0.5)
            {
                // Use world normal directly (calculated in vertex)
                half3 worldNormal = normalize(IN.worldNormal);
                
                // Calculate projection factor
                half projFactor = CalculateProjectionFactor(worldNormal, IN.worldPos);
                
                if (projFactor > 0.01) // Threshold check
                {
                    // Calculate projection UV
                    half2 projUV = CalculateProjectionUV(IN.worldPos);
                    
                    // Sample projection texture
                    half3 projTexture = SampleTexture(_ProjectionTex, projUV) * _ProjectionColor;
                    projTexture *= (_ProjectionColor.a * 5.1);
                    
                    // Final projection strength
                    half finalProjStrength = projFactor * _ProjectionStrength;
                    
                    // Blend albedo with projection texture
                    albedo = lerp(albedo, projTexture, finalProjStrength);
                }
            }
            
            o.Albedo = albedo;
            o.Alpha = 1;
        }
        ENDCG
    } 
    Fallback "Mobile/VertexLit"
}