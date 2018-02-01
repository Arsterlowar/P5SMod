﻿Shader "Tasharen/Metallic (Destroyed)"
{
	Properties
	{
		[NoScaleOffset] _MainTex ("Texture (RGB), Specular (A)", 2D) = "white" {}
		[NoScaleOffset][Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
		[NoScaleOffset] _GlowMap ("Glow (RGB)", 2D) = "white" {}
		[NoScaleOffset] _DamageTex ("Damage Texture (RGBA)", 2D) = "black" {}

		_Color ("Color", Color) = (1,1,1,1)
		_Specular ("Specular", Color) = (0.2,0.2,0.2,1)
		_Smoothness ("Smoothness", Range(0,1)) = 0.81
		_TriplanarScale ("Damage Scale", Vector) = (0.5, 0.25, 1, 1)
		_Condition ("Condition", Range(0,1)) = 1.0

		[HDR] _Glow ("Glow Color", Color) = (0,0,0,1)
		[HideInInspector] _GlowBrightness ("Glow Brightness", Range(0,1)) = 1.0

		_FadeOut ("Fade out", Range (0, 1)) = 1
	}

	SubShader
	{
		LOD 200
		Tags { "RenderType"="Opaque" }
		Cull Off

		Tags
		{

			"Queue" = "AlphaTest"
			"RenderType" = "TransparentCutout"
			"IgnoreProjector" = "True"
		}

		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			Fog { Mode Off }
			Offset [_ShadowBias], [_ShadowBiasSlope]

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"
			#include "Tasharen Damage.cginc"

			sampler2D _MainTex, _DamageTex;
			half _FadeOut;
			half4 _TriplanarScale;

			struct v2f
			{
				V2F_SHADOW_CASTER;
				half2 tc : TEXCOORD1;
				V2F_TRIPLANAR(2, 3)
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert (appdata_full v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				TRANSFER_TRIPLANAR(v, o);
				o.tc = v.texcoord;
				return o;
			}

			float4 frag (v2f i) : COLOR
			{
				TRIPLANAR_SAMPLE_CLIP(i, _DamageTex, _FadeOut, _TriplanarScale.y);
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}

		CGPROGRAM
		#pragma surface surf Tasharen vertex:vert fullforwardshadows
		#pragma multi_compile __ TASHAREN_DITHER LOD_FADE_CROSSFADE
		#pragma target 4.0

		//#define UNITY_GI_MODEL
		//#define GI_SOURCE TOD_Reflection

		#include "Tasharen Lighting.cginc"
		#include "Tasharen Damage.cginc"

		struct Input
		{
			float2 uv_MainTex : TEXCOORD0;
			half4 color : COLOR;
			V2F_TRIPLANAR(1, 2)
			V2F_DITHER_COORDS
		};

		sampler2D _MainTex, _BumpMap, _GlowMap, _DamageTex;
		half4 _Color, _Specular, _Glow, _TriplanarScale;
		half _Smoothness, _GlowBrightness, _Condition, _FadeOut;

		void vert (inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			TRANSFER_DITHER(o, v.vertex);
			TRANSFER_TRIPLANAR(v, o);
			o.color = v.color;
		}

		void surf (Input IN, inout Output o)
		{
			TRIPLANAR_SAMPLE_AND_CLIP2(IN, _DamageTex, _FadeOut, _TriplanarScale.x, _TriplanarScale.y, triplanar, damage);

			half4 tex = tex2D(_MainTex, IN.uv_MainTex);
			half4 glow = tex2D(_GlowMap, IN.uv_MainTex);
			glow.rgb *= _Glow.rgb * (_Glow.a * _GlowBrightness);

			half tintAmount = max(0.0, 1.0 - max(glow.r, max(glow.g, glow.b)));

			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			o.Albedo = lerp(tex.rgb, _Color.rgb * tex.rgb, tintAmount) * IN.color.rgb;

			o.Specular.rgb = _Specular.rgb * (tex.a * tintAmount);
			o.Specular.a = dot(tex.rgb, tex.aaa) * _Specular.a;

			o.Emission = glow.rgb;
			o.Smoothness = _Smoothness;

			TRIPLANAR_OVERLAY(IN, damage, 0.0, 1.0, IN.color.a, 1.0);
			APPLY_DITHER(IN);
		}
		ENDCG
	}
	FallBack "Diffuse"
}
