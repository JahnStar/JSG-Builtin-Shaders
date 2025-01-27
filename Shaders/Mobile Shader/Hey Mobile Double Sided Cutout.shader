Shader "JS Games/Hey Mobile Double Sided Cutout" 
{
    Properties {
        _MainTex ("Diffuse Map", 2D) = "white" {}
        _Color ("Diffuse Color", Color) = (1,1,1,1)
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
    }
    SubShader {
        Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
        LOD 100

        CGPROGRAM
        #pragma surface surf Lambert alphatest:_Cutoff addshadow
        #pragma multi_compile_instancing
        #pragma instancing_options assumeuniformscaling

        sampler2D _MainTex;
        fixed4 _Color;

        struct Input {
            float2 uv_MainTex;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props) 

        void surf (Input IN, inout SurfaceOutput o) {
            UNITY_SETUP_INSTANCE_ID(IN);
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Alpha = c.a;
        }
        ENDCG

        Cull Front
        CGPROGRAM
        #pragma surface surf Lambert alphatest:_Cutoff addshadow
        #pragma multi_compile_instancing
        #pragma instancing_options assumeuniformscaling

        sampler2D _MainTex;
        fixed4 _Color;

        struct Input {
            float2 uv_MainTex;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutput o) {
            UNITY_SETUP_INSTANCE_ID(IN);
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Alpha = c.a;
            o.Normal = -o.Normal;
        }
        ENDCG
    }
    FallBack "Mobile/VertexLit"
}