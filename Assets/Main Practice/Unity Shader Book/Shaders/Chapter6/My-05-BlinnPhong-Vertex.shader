// 使用顶点着色器的 Blinn-Phong 模型的高光着色器
// 经过测试高光移动到顶点里计算会在亮暗交界处产生特别明显的三角面
Shader "Unity Shaders Book/Chapter 6/My-BlinnPhong-Vertex"
{
	Properties
	{
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
	}
	SubShader
	{
		Pass
		{ 
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
			
			#pragma vertex vertex
			#pragma fragment fragment
			
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			
			half4 _Diffuse;
			half4 _Specular;
			float _Gloss;

			// 节点着色器输入结构
			struct vertexInput
			{
				// 位置
				float4 position : POSITION;
				// 法线
				float3 normal : NORMAL;
			};

			// 节点到片元着色器的数据传输结构
			struct vertexToFragment
			{
				// 齐次空间位置
				float4 hPosition : SV_POSITION;
				// 颜色，这个材质是不透明的，只传 RGB 就行
				half3 color : COLOR;
			};

			vertexToFragment vertex(vertexInput input)
			{
				// 输出结构
				vertexToFragment output;
				
				// 将顶点位置从对象空间转换到齐次空间
				output.hPosition = TransformObjectToHClip(input.position);
				
				// 将法线从对象空间转换到世界空间
				half3 worldNormal = TransformObjectToWorldNormal(input.normal);
				// 将顶点位置从对象空间转换到世界空间
				float3 worldPosition = TransformObjectToWorld(input.position);


				// 获取主光源
				Light light = GetMainLight();

				// 获取环境光
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				// 漫反射颜色
				half3 diffuse = light.color.rgb * _Diffuse.rgb * saturate(dot(worldNormal, light.direction));

				// 计算视线角度
				half3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - worldPosition.xyz);
				// 计算世界空间里视线和光线的方向的中间方向
				half3 halfDirection = normalize(light.direction + viewDirection);
				// 计算高光
				half3 specular = light.color.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDirection)), _Gloss);


				output.color = ambient + diffuse + specular;
				return output;
			}

			half4 fragment(vertexToFragment input) : SV_Target
			{
				return half4(input.color, 1.0);
			}
			
			ENDHLSL
		}
	}
	FallBack "Diffuse"
}
