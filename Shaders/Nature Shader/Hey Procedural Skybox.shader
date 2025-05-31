// by Halil Emre Yildiz
// Original Version: https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/DefaultResourcesExtra/Skybox-Procedural.shader

Shader "JS Games/Nature/Hey Procedural Skybox" {
    Properties {
        [KeywordEnum(None, Simple)] _SunDisk ("Sun", Int) = 1
        _SunSize ("Sun Size", Range(0,1)) = 0.04
        _SunSizeConvergence("Sun Size Convergence", Range(1,10)) = 5
    
        _AtmosphereThickness ("Atmosphere Thickness", Range(0.001,5)) = 1.0
        _SkyTint ("Sky Tint", Color) = (.5, .5, .5, 1)
        _GroundColor ("Ground", Color) = (.369, .349, .341, 1)
    
        _Exposure("Exposure", Range(0, 8)) = 1.3
        _MoonColor ("Moon Color", Color) = (.8, .8, .9, 1)
        _MoonSize ("Moon Size", Range(0, 1)) = 0.02

        _NightSkybox ("Night Skybox", Cube) = "" {}
        _NightIntensity ("Night Intensity", Range(0, 1)) = 1
        _NightRot ("Night Rot", Range(0, 6.28)) = 0

        _CloudsSkybox ("Clouds Skybox", Cube) = "" {}
        _CloudsIntensity ("Clouds Intensity", Range(0, 1)) = 1
        _CloudsRot ("Cloud Rot", Range(0, 6.28)) = 0

        _HorizonColor ("Horizon Color", Color) = (1, 1, 1, 1)
        _HorizonSkybox ("Horizon Skybox", Cube) = "" {}
        _HorizonIntensity ("Horizon Intensity", Range(0, 1)) = 1
    }
    
    SubShader {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Cull Off ZWrite Off
    
        Pass {
    
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
    
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
    
            #pragma multi_compile_local _SUNDISK_NONE _SUNDISK_SIMPLE
    
            uniform half _Exposure;     // HDR exposure
            uniform half3 _GroundColor;
            uniform half _SunSize;
            uniform half _SunSizeConvergence;
            uniform half3 _SkyTint;
            uniform half _AtmosphereThickness;
            uniform half3 _MoonColor;
            uniform half _MoonSize;
            uniform half _CloudsRot;
            uniform half _CloudsIntensity;
            uniform half _NightRot;
            uniform half _NightIntensity;
            uniform half _HorizonIntensity;
            uniform half3 _HorizonColor;
            samplerCUBE _HorizonSkybox;
            samplerCUBE _CloudsSkybox;
            samplerCUBE _NightSkybox;
    
        #if defined(UNITY_COLORSPACE_GAMMA)
            #define GAMMA 2
            #define COLOR_2_GAMMA(color) color
            #define COLOR_2_LINEAR(color) color*color
            #define LINEAR_2_OUTPUT(color) sqrt(color)
        #else
            #define GAMMA 2.2
            #define COLOR_2_GAMMA(color) ((unity_ColorSpaceDouble.r>2.0) ? pow(color,1.0/GAMMA) : color)
            #define COLOR_2_LINEAR(color) color
            #define LINEAR_2_LINEAR(color) color
        #endif
    
            static const float3 kDefaultScatteringWavelength = float3(.65, .57, .475);
            static const float3 kVariableRangeForScatteringWavelength = float3(.15, .15, .15);
    
            #define OUTER_RADIUS 1.025
            static const float kOuterRadius = OUTER_RADIUS;
            static const float kOuterRadius2 = OUTER_RADIUS*OUTER_RADIUS;
            static const float kInnerRadius = 1.0;
            static const float kInnerRadius2 = 1.0;
    
            static const float kCameraHeight = 0.0001;
    
            #define kRAYLEIGH (lerp(0.0, 0.0025, pow(_AtmosphereThickness,2.5)))      // Rayleigh constant
            #define kMIE 0.0010             // Mie constant
            #define kSUN_BRIGHTNESS 20.0    // Sun brightness
    
            #define kMAX_SCATTER 50.0 // Maximum scattering value, to prevent math overflows on Adrenos
    
            static const half kSimpleSundiskIntensityFactor = 27.0;
    
            static const half kSunScale = 400.0 * kSUN_BRIGHTNESS;
            static const float kKmESun = kMIE * kSUN_BRIGHTNESS;
            static const float kKm4PI = kMIE * 4.0 * 3.14159265;
            static const float kScale = 1.0 / (OUTER_RADIUS - 1.0);
            static const float kScaleDepth = 0.25;
            static const float kScaleOverScaleDepth = (1.0 / (OUTER_RADIUS - 1.0)) / 0.25;
            static const float kSamples = 2.0; // THIS IS UNROLLED MANUALLY, DON'T TOUCH
    
            #define MIE_G (-0.990)
            #define MIE_G2 0.9801
    
            #define SKY_GROUND_THRESHOLD 0.02
    
            #define SKYBOX_SUNDISK_SIMPLE 1
    
        #ifndef SKYBOX_SUNDISK
            #if defined(_SUNDISK_NONE)
                #define SKYBOX_SUNDISK 0
            #else
                #define SKYBOX_SUNDISK SKYBOX_SUNDISK_SIMPLE
            #endif
        #endif
    
        #ifndef SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
            #if defined(SHADER_API_MOBILE)
                #define SKYBOX_COLOR_IN_TARGET_COLOR_SPACE 1
            #else
                #define SKYBOX_COLOR_IN_TARGET_COLOR_SPACE 0
            #endif
        #endif
    
            half getRayleighPhase(half eyeCos2)
            {
                return 0.75 + 0.75*eyeCos2;
            }
            half getRayleighPhase(half3 light, half3 ray)
            {
                half eyeCos = dot(light, ray);
                return getRayleighPhase(eyeCos * eyeCos);
            }
    
            struct appdata_t
            {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
    
            struct v2f
            {
                float4  pos             : SV_POSITION;
                half3   rayDir          : TEXCOORD0;
                half3   groundColor     : TEXCOORD1;
                half3   skyColor        : TEXCOORD2;
                half3   sunColor        : TEXCOORD3;
                float3  worldPos        : TEXCOORD4;
                UNITY_VERTEX_OUTPUT_STEREO
            };
    
            float scale(float inCos)
            {
                float x = 1.0 - inCos;
                return 0.25 * exp(-0.00287 + x*(0.459 + x*(3.83 + x*(-6.80 + x*5.25))));
            }
    
            v2f vert (appdata_t v)
            {
                v2f OUT;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                OUT.pos = UnityObjectToClipPos(v.vertex);
    
                float3 kSkyTintInGammaSpace = COLOR_2_GAMMA(_SkyTint);
                float3 kScatteringWavelength = lerp (
                    kDefaultScatteringWavelength-kVariableRangeForScatteringWavelength,
                    kDefaultScatteringWavelength+kVariableRangeForScatteringWavelength,
                    half3(1,1,1) - kSkyTintInGammaSpace);
                float3 kInvWavelength = 1.0 / pow(kScatteringWavelength, 4);
    
                float kKrESun = kRAYLEIGH * kSUN_BRIGHTNESS;
                float kKr4PI = kRAYLEIGH * 4.0 * 3.14159265;
    
                float3 cameraPos = float3(0,kInnerRadius + kCameraHeight,0);
                float3 eyeRay = normalize(mul((float3x3)unity_ObjectToWorld, v.vertex.xyz));

                OUT.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    
                float far = 0.0;
                half3 cIn, cOut;
    
                if(eyeRay.y >= 0.0)
                {
                    far = sqrt(kOuterRadius2 + kInnerRadius2 * eyeRay.y * eyeRay.y - kInnerRadius2) - kInnerRadius * eyeRay.y;
                    float3 pos = cameraPos + far * eyeRay;
                    float height = kInnerRadius + kCameraHeight;
                    float depth = exp(kScaleOverScaleDepth * (-kCameraHeight));
                    float startAngle = dot(eyeRay, cameraPos) / height;
                    float startOffset = depth*scale(startAngle);
                    float sampleLength = far / kSamples;
                    float scaledLength = sampleLength * kScale;
                    float3 sampleRay = eyeRay * sampleLength;
                    float3 samplePoint = cameraPos + sampleRay * 0.5;
                    float3 frontColor = float3(0.0, 0.0, 0.0);
                    {
                        float height = length(samplePoint);
                        float depth = exp(kScaleOverScaleDepth * (kInnerRadius - height));
                        float lightAngle = dot(_WorldSpaceLightPos0.xyz, samplePoint) / height;
                        float cameraAngle = dot(eyeRay, samplePoint) / height;
                        float scatter = (startOffset + depth*(scale(lightAngle) - scale(cameraAngle)));
                        float3 attenuate = exp(-clamp(scatter, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));
                        frontColor += attenuate * (depth * scaledLength);
                        samplePoint += sampleRay;
                    }
                    {
                        float height = length(samplePoint);
                        float depth = exp(kScaleOverScaleDepth * (kInnerRadius - height));
                        float lightAngle = dot(_WorldSpaceLightPos0.xyz, samplePoint) / height;
                        float cameraAngle = dot(eyeRay, samplePoint) / height;
                        float scatter = (startOffset + depth*(scale(lightAngle) - scale(cameraAngle)));
                        float3 attenuate = exp(-clamp(scatter, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));
                        frontColor += attenuate * (depth * scaledLength);
                        samplePoint += sampleRay;
                    }
                    cIn = frontColor * (kInvWavelength * kKrESun);
                    cOut = frontColor * kKmESun;
                }
                else
                {
                    far = (-kCameraHeight) / (min(-0.001, eyeRay.y));
                    float3 pos = cameraPos + far * eyeRay;
                    float depth = exp((-kCameraHeight) * (1.0/kScaleDepth));
                    float cameraAngle = dot(-eyeRay, pos);
                    float lightAngle = dot(_WorldSpaceLightPos0.xyz, pos);
                    float cameraScale = scale(cameraAngle);
                    float lightScale = scale(lightAngle);
                    float cameraOffset = depth*cameraScale;
                    float temp = (lightScale + cameraScale);
                    float sampleLength = far / kSamples;
                    float scaledLength = sampleLength * kScale;
                    float3 sampleRay = eyeRay * sampleLength;
                    float3 samplePoint = cameraPos + sampleRay * 0.5;
                    float3 frontColor = float3(0.0, 0.0, 0.0);
                    float3 attenuate;
                    {
                        float height = length(samplePoint);
                        float depth = exp(kScaleOverScaleDepth * (kInnerRadius - height));
                        float scatter = depth*temp - cameraOffset;
                        attenuate = exp(-clamp(scatter, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));
                        frontColor += attenuate * (depth * scaledLength);
                        samplePoint += sampleRay;
                    }
                    cIn = frontColor * (kInvWavelength * kKrESun + kKmESun);
                    cOut = clamp(attenuate, 0.0, 1.0);
                }
    
                OUT.rayDir = half3(-eyeRay);
                OUT.groundColor = _Exposure * (cIn + COLOR_2_LINEAR(_GroundColor) * cOut);
                OUT.skyColor = _Exposure * (cIn * getRayleighPhase(_WorldSpaceLightPos0.xyz, -eyeRay));
                half lightColorIntensity = clamp(length(_LightColor0.xyz), 0.25, 1);
                OUT.sunColor = kSimpleSundiskIntensityFactor * saturate(cOut * kSunScale) * _LightColor0.xyz / lightColorIntensity;
                
            #if defined(UNITY_COLORSPACE_GAMMA) && SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
                OUT.groundColor = sqrt(OUT.groundColor);
                OUT.skyColor = sqrt(OUT.skyColor);
                OUT.sunColor = sqrt(OUT.sunColor);
            #endif
    
                return OUT;
            }
    
            half calcSunAttenuation(half3 lightPos, half3 ray)
            {
                half3 delta = lightPos - ray;
                half dist = length(delta);
                half spot = 1.0 - smoothstep(0.0, _SunSize, dist);
                return spot * spot; 
            }

            half calcMoonAttenuation(half3 moonPos, half3 ray)
            {
                half3 delta = moonPos - ray;
                half dist = length(delta);
                half spot = 1.0 - smoothstep(_MoonSize * 0.8, _MoonSize, dist);
                return spot * spot;
            }
    
            half4 frag (v2f IN) : SV_Target
            {
                half3 col = half3(0.0, 0.0, 0.0);
                half3 ray = IN.rayDir.xyz;

                half y = ray.y / SKY_GROUND_THRESHOLD;
                col = lerp(IN.skyColor, IN.groundColor, saturate(y));

                if (y < 0.0) 
                {
                    // Night Skybox
                    if (_NightIntensity > 0)
                    {
                        float cosNightAngle = cos(_NightRot);
                        float sinNightAngle = sin(_NightRot);
                        float3x3 nightRotationMatrix = float3x3(
                            1, 0, 0,
                            0, cosNightAngle, -sinNightAngle,
                            0, sinNightAngle, cosNightAngle
                        );

                        float3 rotatedNightPos = mul(nightRotationMatrix, IN.worldPos);
                        half4 nightSkyboxColor = texCUBE(_NightSkybox, rotatedNightPos);
                        col = lerp(col, nightSkyboxColor.rgb, nightSkyboxColor.a * _NightIntensity);
                    }

                    // Sun
                    col += IN.sunColor * calcSunAttenuation(_WorldSpaceLightPos0.xyz, -ray);

                    // Moon
                    half3 moonPos = -_WorldSpaceLightPos0.xyz; 
                    half moonAttenuation = calcMoonAttenuation(moonPos, -ray);
                    col = lerp(col, _MoonColor.rgb, moonAttenuation);

                    // Horizon Skybox
                    if (_HorizonIntensity > 0)
                    {
                        half4 horizonSkyboxColor = texCUBE(_HorizonSkybox, IN.worldPos);
                        col = lerp(col, horizonSkyboxColor.rgb * _HorizonColor, horizonSkyboxColor.a * _HorizonIntensity);
                    }
                    
                    // Clouds Skybox
                    if (_CloudsIntensity > 0)
                    {
                        float cosCloudsAngle = cos(_CloudsRot);
                        float sinCloudsAngle = sin(_CloudsRot);
                        float3x3 cloudsRotationMatrix = float3x3(
                            cosCloudsAngle, 0, sinCloudsAngle,
                            0, 1, 0,
                            -sinCloudsAngle, 0, cosCloudsAngle
                        );

                        float3 rotatedCloudsPos = mul(cloudsRotationMatrix, IN.worldPos);
                        half4 cloudsSkyboxColor = texCUBE(_CloudsSkybox, rotatedCloudsPos);
                        col = lerp(col, cloudsSkyboxColor.rgb, cloudsSkyboxColor.a * _CloudsIntensity); 
                    }
                }

            #if defined(UNITY_COLORSPACE_GAMMA) && !SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
                col = LINEAR_2_OUTPUT(col);
            #endif
                return half4(col,1.0);
            }
            ENDCG
        }
    }
    
    Fallback Off
    CustomEditor "SkyboxProceduralShaderGUI"
}