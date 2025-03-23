Shader "JS Games/Hey Mobile Bumped Projection" 
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
        
        [Space(10)]
        [Header(Projection Settings)] [Space(5)]
        _ProjectionTex("Projection Texture", 2D) = "white" {}
        [Enum(X,0,Y,1,Z,2)] _ProjectionDirection("Projection Direction", Int) = 1
        _ProjectionStrength("Projection Strength", Range(0,1)) = 0.5
        _ProjectionScale("Projection Scale", Range(0.1,10)) = 1
        _ProjectionFalloff("Projection Falloff", Range(0.1,10)) = 1
        _ProjectionThreshold("Projection Threshold", Range(0.1,1)) = 0.5
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
        sampler2D _ProjectionTex;
        half _Brightness;
        half4 _Color;
        int _UseNormalMap;
        float _CullMode;
        int _ProjectionDirection;
        float _ProjectionStrength;
        float _ProjectionScale;
        float _ProjectionFalloff;
        float _ProjectionThreshold;

        struct Input 
        {
            float2 uv_MainTex;
            float2 uv_BumpMap;
            float3 worldPos;
            float3 worldNormal;
            INTERNAL_DATA
        };

        void surf (Input IN, inout SurfaceOutput o) 
        {
            // Base texture
            half4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            
            // Normal mapping
            if (_UseNormalMap > 0)  
                o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
            else  
                o.Normal = float3(0, 0, 1); // Default normal
            
            // Projection texture coordinates based on direction
            float2 projUV;
            if (_ProjectionDirection == 0) // X direction
                projUV = IN.worldPos.yz * _ProjectionScale;
            else if (_ProjectionDirection == 1) // Y direction
                projUV = IN.worldPos.xz * _ProjectionScale;
            else // Z direction
                projUV = IN.worldPos.xy * _ProjectionScale;
            
            // Sample projection texture
            half4 projTex = tex2D(_ProjectionTex, projUV);
            
            // Calculate projection intensity based on normal
            float3 worldNormal = WorldNormalVector(IN, o.Normal);
            float projFactor = 0.0;
            
            // Get the appropriate normal component based on direction
            if (_ProjectionDirection == 0) // X direction
                projFactor = abs(worldNormal.x);
            else if (_ProjectionDirection == 1) // Y direction
                projFactor = abs(worldNormal.y);
            else // Z direction
                projFactor = abs(worldNormal.z);
            
            // Apply threshold to limit coverage area
            projFactor = max(0, projFactor - (1.0 - _ProjectionThreshold));
            
            // Apply non-linear falloff for smoother transition
            projFactor = pow(projFactor * (1.0 / _ProjectionThreshold), _ProjectionFalloff);
            
            // Clamp the result to avoid values outside [0,1]
            projFactor = saturate(projFactor);
            
            // Blend base texture with projection texture
            float blendFactor = projFactor * _ProjectionStrength;
            o.Albedo = lerp(c.rgb, projTex.rgb, blendFactor) * _Brightness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    Fallback "Mobile/VertexLit"
}