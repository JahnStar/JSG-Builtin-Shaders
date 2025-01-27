// © 2015 Mario Lelas // Contributed by Halil Emre Yildiz 2022

// Simplified Diffuse shader. Differences from regular Diffuse one:
// - no Main Color
// - fully supports only 1 directional light. Other lights can affect it, but it will be per-vertex/SH.

Shader "DoubleSided/Mobile/MobileDiffuseCutout"
{
	Properties
	{
		_Color("Main Color", Color) = (1,1,1,1)
		_MainTex("Base (RGB)", 2D) = "white" {}
		_Cutoff("Alpha cutoff", Range(0,1)) = 0.5
		_BlendTex("Blend Texture (RGB)", 2D) = "white" {}
		_Blend("Blend", Range(0,1)) = 0
		_MaxBlend("MaxBlend", Range(0,1)) = 0.5
		_BrightnessV("Brightness", Range(0,4)) = 1
		[Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 2 // "Back" 
	}
	SubShader
	{
		Tags{ "Queue" = "Geometry-100" "IgnoreProjector" = "True" "RenderType" = "TransparentCutout" } // "Queue" = "Transparent"
		Cull[_CullMode]

		LOD 150

		CGPROGRAM


		#pragma surface surfDS LambertDS  noforwardadd
		#pragma target 3.0


		sampler2D _MainTex;
		float _Cutoff;
		sampler2D _BlendTex;
		fixed _Blend, _MaxBlend, _BrightnessV;
		fixed4 _Color;

		struct Input
		{
			float2 uv_MainTex;
			float2 uv_BlendTex;
			float face : VFACE;
		};

		struct Output
		{
			fixed3 Albedo;
			fixed3 Normal;
			fixed3 Emission;
			half Specular;
			fixed Gloss;
			fixed Alpha;
			float face;
		};

		inline fixed4 UnityLambertLightDS(Output s, UnityLight light)
		{
			fixed diff = max(0, dot(s.Normal, light.dir));

			fixed4 c;
			c.rgb = s.Albedo * light.color * diff;
			c.a = s.Alpha;
			return c;
		}

		inline void LightingLambertDS_GI(
			Output s,
			UnityGIInput data,
			inout UnityGI gi)
		{
			gi = UnityGlobalIllumination(data, 1.0, 0.0, s.Normal, false);
		}

		inline fixed4 LightingLambertDS(Output s, UnityGI gi)
		{
		float3 normal = s.Normal * sign(s.face);
		s.Normal = normal;

		fixed4 c;
		c = UnityLambertLightDS(s, gi.light);

		#if defined(DIRLIGHTMAP_SEPARATE)
		#ifdef LIGHTMAP_ON
				c += UnityLambertLightDS(s, gi.light2);
		#endif
		#ifdef DYNAMICLIGHTMAP_ON
				c += UnityLambertLightDS(s, gi.light3);
		#endif
		#endif

		#ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
				c.rgb += s.Albedo * gi.indirect.diffuse;
		#endif

		return c;
	}


	void surfDS(Input IN,  inout Output o)
	{
		fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;

		clip(c.a - _Cutoff);

		if (_Blend != 0) 
		{
			fixed4 blendTex = tex2D(_BlendTex, IN.uv_BlendTex);
			c = lerp(c, blendTex, _Blend * _MaxBlend);
		}

		o.Albedo = c.rgb * _BrightnessV;
		o.Alpha = c.a;
		o.face = IN.face;
	}
	ENDCG
	}
	Fallback "Mobile/VertexLit" // "DoubleSided/Other/VertexLitCutoutCullOff"
}
