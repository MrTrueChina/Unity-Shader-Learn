// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'TransformObjectToHClip(*)'

Shader "Unity Shaders Book/Chapter 8/Alpha Blend With Both Side"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" { }
        _AlphaScale ("Alpha Scale", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags
		{
            // 使用通用渲染管线（URP）
            "RenderPipeline" = "UniversalPipeline"
            // 渲染队列为透明队列，这个队列会按照从远到近渲染
			"Queue" = "Transparent"
            // 不接受投影
			"IgnoreProjector" = "True"
            // 渲染类型为 透明材质
			"RenderType" = "Transparent"
        }
        
        Pass
        {
            Tags
            {
				// 光照模式为 URP前向渲染路径（这是通用模式，会统计所有的光照信息）
				"LightMode" = "UniversalForward"
			}
			
			// First pass renders only back faces 
			Cull Front
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
			
			half4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			half _AlphaScale;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float2 uv : TEXCOORD1;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = TransformObjectToHClip(v.vertex);
				
				o.worldNormal = TransformObjectToWorldNormal(v.normal);
				
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				return o;
			}
			
			half4 frag(v2f i) : SV_Target {

				// 获取主光源
				Light light = GetMainLight();

				half3 worldNormal = normalize(i.worldNormal);
				half3 worldLightDir = light.direction;
				
				half4 texColor = tex2D(_MainTex, i.uv);
				
				half3 albedo = texColor.rgb * _Color.rgb;
				
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				half3 diffuse = light.color.rgb * albedo * max(0, dot(worldNormal, worldLightDir));
				
				return half4(ambient + diffuse, texColor.a * _AlphaScale);
			}
			
			ENDHLSL
		}
		
		Pass
		{
            Tags
            {
				// 光照模式为 USB-AfterTransparentPass
				// 这个光照模式是给 《入门精要》 额外扩增的渲染通道，URP 不支持传统的通道，需要用 ScriptableRenderFeature 来添加
				// 这个方式添加的通道和传统通道不一样，尤其是顺序上有所不同
				"LightMode" = "USB-AfterTransparentPass"
			}
			
			// Second pass renders only front faces 
			Cull Back
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
			
			half4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			half _AlphaScale;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float2 uv : TEXCOORD1;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = TransformObjectToHClip(v.vertex);
				
				o.worldNormal = TransformObjectToWorldNormal(v.normal);
				
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				return o;
			}
			
			half4 frag(v2f i) : SV_Target {

				// 获取主光源
				Light light = GetMainLight();
				
				half3 worldNormal = normalize(i.worldNormal);
				half3 worldLightDir = light.direction;
				
				half4 texColor = tex2D(_MainTex, i.uv);
				
				half3 albedo = texColor.rgb * _Color.rgb;
				
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				half3 diffuse = light.color.rgb * albedo * max(0, dot(worldNormal, worldLightDir));
				
				return half4(ambient + diffuse, texColor.a * _AlphaScale);
			}
			
			ENDHLSL
		}
    }
    
    // 最终失败转发，转给 URP 的基础光照材质
    FallBack "Universal Render Pipeline/Lit"
}
