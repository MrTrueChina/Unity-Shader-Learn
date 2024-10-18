// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 6/My-DiffusePixelLevel"
{
	Properties
	{
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
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
				// 顶点位置
				float4 position : SV_POSITION;
				// 世界空间法线
				float3 worldNormal : TEXCOORD0;
			};

			vertexToFragment vertex(vertexInput input)
			{
				// 输出结构
				vertexToFragment output;
				
				// 将顶点位置从对象空间转换到齐次空间
				output.position = TransformObjectToHClip(input.position);
				
				// 将法线从对象空间转换到世界空间
				output.worldNormal = TransformObjectToWorldNormal(input.normal);
				
				return output;
			}

			half4 fragment(vertexToFragment i) : SV_Target
			{
				// 获取主光源
				Light light = GetMainLight();

				// 获取环境光
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				// 漫反射颜色
				half3 diffuse = light.color.rgb * _Diffuse.rgb * saturate(dot(i.worldNormal, light.direction));
				
				// 合并环境光和漫反射
				half3 color = ambient + diffuse;
				
				return half4(color, 1.0);
			}
			
			ENDHLSL
		}
	} 
	FallBack "Diffuse"
}
