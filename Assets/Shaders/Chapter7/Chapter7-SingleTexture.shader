// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 7/Single Texture" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {} // white 是 Unity 内置的一个很小的纯白图的名字，表示如果没设置的话就用那张纯白图
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
	}
	SubShader {		
		Pass { 
            Tags
            {
                // 使用通用渲染管线（URP）
                "RenderPipeline" = "UniversalPipeline"
                // 渲染类型为不透明
                "RenderType" = "Opaque"
                // 光照模式为 URP前向渲染路径（这个光照模式可以在 URP 允许范围内接收尽可能多的光源）
                "LightMode" = "UniversalForward"
            }
		
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			
			half4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST; // 对于一个贴图需要有一个 名字_ST 的属性配套，这个属性就是贴图的缩放和偏移的那四个参数
			half4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float2 uv : TEXCOORD2;
			};
			
			v2f vert(a2v v) {
				v2f o;
				
				// 将顶点位置从对象空间转换到齐次空间
				o.pos = TransformObjectToHClip(v.vertex);
				
				o.worldNormal = TransformObjectToWorldNormal(v.normal);
				
				o.worldPos = TransformObjectToWorld(v.vertex);
				
				// 转换 UV
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				return o;
			}
			
			half4 frag(v2f i) : SV_Target {
				// 获取主光源
				Light light = GetMainLight();
				
				// 计算漫反射贴图颜色，就是贴图颜色乘以漫反射颜色
				half3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				
				// 环境光
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				// 漫反射，用到了刚刚计算的贴图颜色
				half3 diffuse = light.color.rgb * albedo * max(0, dot(i.worldNormal, light.direction));
				
				// 高光
				half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				half3 halfDir = normalize(light.direction + viewDir);
				half3 specular = light.color.rgb * _Specular.rgb * pow(max(0, dot(i.worldNormal, halfDir)), _Gloss);
				
				return half4(ambient + diffuse + specular, 1.0);
			}
			
			ENDHLSL
		}
	}
	FallBack "Specular"
}
