Shader "JS Games/Nature/Hey Leaf Diffuse Shake" 
{
    Properties
    {
        _Color("Main Color", Color) = (1,1,1,1)
        _MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
        _Cutoff("Alpha cutoff", Range(0,1)) = 0.5
        _ShakeDisplacement("Displacement", Range(0, 1.0)) = 1.0
        _ShakeTime("Shake Time", Range(0, 1.0)) = 1.0
        _ShakeWindspeed("Shake Windspeed", Range(0, 1.0)) = 1.0
        _ShakeBending("Shake Bending", Range(0, 1.0)) = 1.0
        _BrightnessV("Brightness", Range(0,5)) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 // "Back" 
    }

    SubShader
    {
        Tags {"Queue" = "AlphaTest" "IgnoreProjector" = "True" "RenderType" = "TransparentCutout"}
        LOD 200
        Cull[_CullMode]
        CGPROGRAM
        #pragma target 3.0
        #pragma surface surf Lambert alphatest:_Cutoff vertex:vert addshadow

        sampler2D _MainTex;
        half4 _Color;
        half _ShakeDisplacement;
        half _ShakeTime;
        half _ShakeWindspeed;
        half _ShakeBending;
        half _BrightnessV;

        struct Input 
        {
            half2 uv_MainTex;
        };

        void FastSinCos(half4 val, out half4 s, out half4 c) 
        {
            val = val * 6.2831853 - 3.1415927; // 2 * PI
            half4 val2 = val * val;
            s = val * (1 - val2 * (1/6.0 - val2 * (1/120.0)));
            c = 1 - val2 * (0.5 - val2 * (1/24.0));
        }

        void vert(inout appdata_full v) 
        {
            half factor = (1 - _ShakeDisplacement - v.color.r) * 0.5;

            const half _WindSpeed = (_ShakeWindspeed + v.color.g);
            const half _WaveScale = _ShakeDisplacement;

            const half4 _waveXSize = half4(0.048, 0.06, 0.24, 0.096);
            const half4 _waveZSize = half4 (0.024, .08, 0.08, 0.2);
            const half4 waveSpeed = half4 (1.2, 2, 1.6, 4.8);

            const half4 _waveXmove = half4(0.024, 0.04, -0.12, 0.096);
            const half4 _waveZmove = half4 (0.006, .02, -0.02, 0.1);

            half4 waves = v.vertex.x * _waveXSize + v.vertex.z * _waveZSize;
            waves += _Time.x * (1 - _ShakeTime * 2 - v.color.b) * waveSpeed * _WindSpeed;

            half4 s, c;
            waves = frac(waves);
            FastSinCos(waves, s, c);

            half waveAmount = v.texcoord.y * (v.color.a + _ShakeBending);
            s *= waveAmount;

            s *= normalize(waveSpeed);

            s = s * s;
            half fade = dot(s, 1.3);
            s = s * s;
            half3 waveMove = half3 (0,0,0);
            waveMove.x = dot(s, _waveXmove);
            waveMove.z = dot(s, _waveZmove);
            v.vertex.xz -= mul((half3x3)unity_WorldToObject, waveMove).xz;
        }

        void surf(Input IN, inout SurfaceOutput o)
        {
            half4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb * _BrightnessV;
            o.Alpha = c.a;
        }
        ENDCG
    }
    Fallback "Transparent/Cutout/VertexLit"
}