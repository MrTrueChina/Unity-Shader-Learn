// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 6/Specular Vertex-Level" {
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
				half3 color : COLOR;
			};
			
			v2f vert(a2v v) {
				v2f o;

				// 管线要求的一定要有的坐标转换和存入
				o.pos = TransformObjectToHClip(v.vertex);
				
				// 环境光
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				// 主光源
                Light light = GetMainLight();
				
				// 世界空间法线
				half3 worldNormal = TransformObjectToWorldNormal(v.normal);
				
				// 计算漫反射光
				half3 diffuse = light.color.rgb * _Diffuse.rgb * saturate(dot(worldNormal, light.direction));
				

				// 下面是 Phong 模型的高光算法，这个模型使用视线和反射光的角度计算高光
				// 但需要注意尽管这个模型使用了视线和反射光的原理但它实际上还是个经验模型，并不完全准确
				// 计算世界空间中光线在这个法线上产生的反射光
				half3 reflectDir = normalize(reflect(-light.direction, worldNormal));
				// 计算视线方向
				half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld, v.vertex).xyz);
				// 计算高光，核心是 反射光和视线的点积
				half3 specular = light.color.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);


				o.color = ambient + diffuse + specular;
							 	
				return o;
			}
			
			half4 frag(v2f i) : SV_Target {
				return half4(i.color, 1.0);
			}
			
			ENDHLSL
		}
	} 
	FallBack "Specular"
}
