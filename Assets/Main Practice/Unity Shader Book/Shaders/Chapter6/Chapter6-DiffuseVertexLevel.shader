// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 6/Diffuse Vertex-Level" {
	Properties {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
	}
	SubShader {
		Pass { 
			Tags { "LightMode"="UniversalForward" }
		
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			
			half4 _Diffuse;
			
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

				// 必须的将顶点坐标转到齐次空间的步骤
				o.pos = TransformObjectToHClip(v.vertex);

                // 获取主光源
                Light light = GetMainLight();
				
				// 获取环境光
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				// 法线转到世界空间
				half3 worldNormal =TransformObjectToWorldNormal(v.normal);
				// Compute diffuse term
				half3 diffuse = light.color.rgb * _Diffuse.rgb * saturate(dot(worldNormal, light.direction));
				
				o.color = ambient + diffuse;
				
				return o;
			}
			
			half4 frag(v2f i) : SV_Target {
				return half4(i.color, 1.0);
			}
			
			ENDHLSL
		}
	}
	FallBack "Diffuse"
}
