// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 6/Blinn-Phong" {
	Properties {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
	}
	SubShader {
		Pass { 
			Tags { "LightMode"="UniversalForward" }
		
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			
			half4 _Diffuse;
			half4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};
			
			v2f vert(a2v v) {
				v2f o;

				// 管线要求的一定要有的坐标转换和存入
				o.pos = TransformObjectToHClip(v.vertex);
				
				// 法线和坐标转到世界空间
				o.worldNormal = TransformObjectToWorldNormal(v.normal);
				o.worldPos = TransformObjectToWorld(v.vertex);
				
				return o;
			}
			
			half4 frag(v2f i) : SV_Target {
				// 环境光
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				// // 法线归一化，原版代码在顶点着色器里只转换没有归一，现在修改后转换和归一在一起进行这里就不用操作了
				// half3 worldNormal = normalize(i.worldNormal);
				half3 worldNormal = i.worldNormal;
				
                Light light = GetMainLight();
				
				// 计算漫反射，使用了 max 而不是 saturate，但这个没有道理，光线角度和法线都是归一的，saturate 比 max 简单而且理论上可能速度还要快一点
				half3 diffuse = light.color.rgb * _Diffuse.rgb * max(0, dot(worldNormal, light.direction));
				

				// 下面是 Blinn-Phong 模型计算高光的逻辑
				// 这个模型是 Phong 模型的改版，他可以少计算一次反射，因此一般来说会比 Phong 模型快一些
				// 这个模型比 Phong 模型更加经验模型，但是它的效果也很好
				
				// 视线角度
				half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				// 获取视线方向和光线方向的中间的那个方向
				half3 halfDir = normalize(light.direction + viewDir);
				// 计算高光
				half3 specular = light.color.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);


				return half4(ambient + diffuse + specular, 1.0);
			}
			
			ENDHLSL
		}
	} 
	FallBack "Specular"
}
