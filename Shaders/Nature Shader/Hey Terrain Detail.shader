// Simplified Diffuse shader. // Developed by Halil Emre Yildiz @JahnStar - Github
// - fully supports only 1 directional light. Other lights can affect it, but it will be per-vertex/SH.

Shader "JS Games/Nature/Hey Terrain Detail" 
{
    Properties
    {
        [Header(Jahn Star Games Shader)][Space(5)]
        _Color("Main Color", Color) = (0.2,0.2,0.2,1)
        _MainTex("Main (RGB)", 2D) = "white" {}
        [Space(15)]
        _Color2("Overlay Color", Color) = (0.2,0.2,0.2,1)
        _DetailTex("Overlay (RGB)", 2D) = "white" {}
        _Overlay("Overlay Mixer", Range(0.0, 1.0)) = 0.0
        [Space(15)]
        _Color3("Blend Color", Color) = (0.2,0.2,0.2,1)
        _BlendTex("Blend (RGB)", 2D) = "white" {}
        _Blend("Blend Mixer", Range(0.0, 1.0)) = 0.0
        [Header(Alpha Channel Mixer)][Space(5)]	
        _TexMixer("Alpha Mixer (RGB)", 2D) = "white" {}
        [Toggle] _DetailAlpha("Overlay Alpha (Red channel)", Float) = 0
        [Toggle] _BlendAlpha("Blend Alpha (Blue channel)", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 2 // "Back" 
    }
    SubShader
    {
        Tags 
        { "LIGHTMODE" = "ForwardBase" "SHADOWSUPPORT" = "false" "Queue" = "Geometry-100" "RenderType" = "Opaque"  "IgnoreProjector" = "True" "TerrainCompatible" = "True"}
        LOD 150
        Cull[_CullMode]

        CGPROGRAM
        #pragma surface surf Lambert vertex:vert
        #pragma target 4.0
        #pragma multi_compile_fog
        #pragma exclude_renderers gles
        #include "UnityCG.cginc"

        sampler2D _MainTex;
        sampler2D _DetailTex;
        sampler2D _TexMixer;
        sampler2D _BlendTex;
        half4 _Color, _Color2, _Color3;
        half _Blend, _Overlay, _DetailAlpha, _BlendAlpha;

        half3 overlay(half3 a, half3 b, half3 mix)
        {
            half3 result = a < 0.5 ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
            return lerp(a, result, mix); // result * mix + (a * (1 - mix));
        }

        struct Input 
        {
            half2 uv_MainTex : TEXCOORD0;
            half2 uv_DetailTex: TEXCOORD1;
            half2 uv_TexMixer;
            half2 uv_BlendTex : TEXCOORD2;
            half mixZ;
        };

        void vert(inout appdata_full v, out Input o) 
        {
            UNITY_INITIALIZE_OUTPUT(Input,o);
            half4 wpos = mul(unity_ObjectToWorld, v.vertex);
            o.mixZ = wpos.xz;
        }

        void surf(Input IN, inout SurfaceOutput o) 
        {
            half3 _main = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            _main *= (_Color.a * 5.1);
            half3 albedo = _main.rgb;
            //

            half3 _texMixer = tex2D(_TexMixer, IN.uv_TexMixer);

            if (_Overlay != 0) 
            {
                half3 _detail = tex2D(_DetailTex, IN.uv_DetailTex) * _Color2;
                _detail *= (_Color2.a * 5.1);
                _detail = overlay(albedo.rgb, _detail.rgb, _Overlay);

                // Red Color Textrue Mix
                if (_DetailAlpha)
                {
                    half texMixer_detail = _texMixer.r;
                    albedo = lerp(_main, _detail, texMixer_detail);
                }
                else albedo = _detail;
            }

            if (_Blend != 0) 
            {
                half3 _blend = tex2D(_BlendTex, IN.uv_BlendTex) * _Color3;
                _blend *= (_Color3.a * 5.1);
                _blend = lerp(albedo.rgb, _blend.rgb, _blend * _Blend);

                // Blue Color Textrue Mix
                if (_BlendAlpha)
                {
                    half texMixer_detail = _texMixer.b;
                    albedo = lerp(albedo, _blend, texMixer_detail);
                }
                else albedo = _blend;
            }

            o.Albedo = albedo;
            o.Alpha = 1;
        }
        ENDCG
    }
    Fallback "Mobile/VertexLit"
}