Shader "JS Games/Hey Mobile Diffuse" 
{
    Properties 
    {
        [Header(Jahn Star Games Shader)] [Space(5)]
        _Color("Main Color", Color) = (1,1,1,1)
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _Brightness("Brightness", Range(0,4)) = 1
    }
    SubShader 
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Back

        CGPROGRAM
        #pragma surface surf Lambert fullforwardshadows // for ultra performance use 'noforwardadd'

        sampler2D _MainTex;
        fixed _Brightness;
        fixed4 _Color;

        struct Input 
        {
            float2 uv_MainTex;
        };

        void surf (Input IN, inout SurfaceOutput o) 
        {
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb * _Brightness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    Fallback "Mobile/VertexLit"
}