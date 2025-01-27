Shader "JS Games/Hey Mobile Bumped" 
{
    Properties 
    {
        [Header(Jahn Star Games Shader)] [Space(5)]
        _Color("Main Color", Color) = (1,1,1,1)
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _Brightness("Brightness", Range(0,4)) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 // "Back" 
        _UseNormalMap("Use Normal Map", Int) = 1
    }
    SubShader 
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull[_CullMode]

        CGPROGRAM
        #pragma surface surf Lambert fullforwardshadows // for ultra performance use 'noforwardadd'

        sampler2D _MainTex;
        sampler2D _BumpMap;
        half _Brightness;
        half4 _Color;
        int _UseNormalMap;
        float _CullMode;

        struct Input 
        {
            float2 uv_MainTex;
            float2 uv_BumpMap;
        };

        void surf (Input IN, inout SurfaceOutput o) 
        {
            half4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb * _Brightness;
            if (_UseNormalMap > 0)  o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
            else  o.Normal = float3(0, 0, 1); // Default normal
            o.Alpha = c.a;
        }
        ENDCG
    }
    Fallback "Mobile/VertexLit"
}