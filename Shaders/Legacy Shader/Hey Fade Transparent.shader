// Developed by Halil Emre Yildiz @JahnStar - Github
Shader "JS Games/Hey Fade Transparent"
{
    Properties
    {
        _Color("Main Color", Color) = (1,1,1,1)
        _MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
        _Cutoff("Alpha cutoff", Range(0,1)) = 0.5
        _BlendTex("Blend Texture (RGB)", 2D) = "white" {}
        _Blend("Blend", Range(0,1)) = 0
        _MaxBlend("MaxBlend", Range(0,1)) = 0.5
        _BrightnessV("Brightness", Range(0,5)) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 // "Back" 
    }

    SubShader
    {
        Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "TransparentCutout" } /*"RenderType" = "Opaque"*/
        LOD 150
        ZWrite Off
        Cull[_CullMode]

        CGPROGRAM
        #pragma surface surf Lambert alpha noforwardadd

        sampler2D _MainTex;
        sampler2D _BlendTex;
        half _Blend, _MaxBlend, _BrightnessV;
        half4 _Color;
        half _Cutoff;

        struct Input
        {
            half2 uv_MainTex;
            half2 uv_BlendTex;
        };

        void surf(Input IN, inout SurfaceOutput o)
        {
            half4 mainTex = tex2D(_MainTex, IN.uv_MainTex) * _Color;

            if (_Blend != 0)
            {
                half4 blendTex = tex2D(_BlendTex, IN.uv_BlendTex);
                mainTex = lerp(mainTex, blendTex, _Blend * _MaxBlend);
            }
            o.Albedo = mainTex * _BrightnessV;

            if (mainTex.a > _Cutoff)
            o.Alpha = mainTex.a;
            else o.Alpha = 0;
        }
        ENDCG
    }
    Fallback "Legacy Shaders/Transparent/Cutout/VertexLit" // Fallback "Diffuse"
}