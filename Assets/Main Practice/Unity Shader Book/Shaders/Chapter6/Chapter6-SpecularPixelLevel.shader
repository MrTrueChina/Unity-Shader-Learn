// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 6/Specular Pixel-Level" {
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
				
				// 获取主光源
                Light light = GetMainLight();
				
				// Compute diffuse term
				half3 diffuse = light.color.rgb * _Diffuse.rgb * saturate(dot(i.worldNormal, light.direction));
				
				// Get the reflect direction in world space
				half3 reflectDir = normalize(reflect(-light.direction, i.worldNormal));
				// Get the view direction in world space
				half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				// Compute specular term
				half3 specular = light.color.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);
				
				return half4(ambient + diffuse + specular, 1.0);
			}
			
			ENDHLSL
		}
	} 
	FallBack "Specular"
}
