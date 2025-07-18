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
        #pragma surface surf Lambert fullforwardshadows vertex:vert // for ultra performance use 'noforwardadd'
        #pragma multi_compile_instancing
        #pragma target 3.0

        sampler2D _MainTex;
        fixed _Brightness;
        fixed4 _Color;

        struct Input 
        {
            float2 uv_MainTex;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        void vert (inout appdata_full v, out Input o) 
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_TRANSFER_INSTANCE_ID(v, o);
        }

        void surf (Input IN, inout SurfaceOutput o) 
        {
            UNITY_SETUP_INSTANCE_ID(IN);
            
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb * _Brightness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    Fallback "Mobile/Diffuse"
}