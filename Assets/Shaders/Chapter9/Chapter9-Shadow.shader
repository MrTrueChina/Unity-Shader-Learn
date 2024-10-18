// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 9/Shadow"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags
		{
            // 使用通用渲染管线（URP）
            "RenderPipeline" = "UniversalPipeline"
            // 渲染队列为几何体
			"Queue" = "Geometry"
            // 渲染类型为不透明
			"RenderType" = "Opaque"
        }
		
		// 这个 Shader 在原版基础上大改，几乎没有原版的内容了
		// URP 的阴影逻辑和 BiRP 的阴影接口大不相同，阴影代码参考的是官方手册
		// https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@14.0/manual/use-built-in-shader-methods-shadows.html#example

		Pass
		{
            Tags
            {
                // 光照模式为 URP前向渲染路径（这个光照模式会产生光照贡献，即可以写入光照信息）
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM
            
			// 编译主光源投影版本
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			// 编译附加光源版本
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			// 编译附加光源投影版本
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			// 编译软阴影版本
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
			// 编译光照层版本
			#pragma multi_compile_fragment _ _LIGHT_LAYERS
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
            
            half4 _Diffuse;
            half4 _Specular;
            float _Gloss;
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
				float4 shadowCoords : TEXCOORD2;
				
				// 顶点附加光源颜色和高光只在附加光源模式为逐顶点时使用
                #ifdef _ADDITIONAL_LIGHTS_VERTEX
				half3 vertexAdditionalLighting : TESSFACTOR3;
				half3 vertexAdditionalSpecular : TESSFACTOR4;
                #endif
            };
            
            v2f vert(a2v v)
            {
                v2f o;

                // 获取位置信息，包含了各种空间中的位置
                VertexPositionInputs positions = GetVertexPositionInputs(v.vertex.xyz);

				// 齐次空间坐标，在位置信息里包含了，就是裁剪空间坐标
				o.pos = positions.positionCS;

				// 世界空间坐标，位置信息里也有
				o.worldPos = positions.positionWS;

                // 这个顶点在阴影贴图上的坐标
				// URP 的阴影是先根据场景计算出一张阴影贴图，然后着色器再根据顶点或片元在阴影贴图上的位置来控制要不要显示阴影
                o.shadowCoords = GetShadowCoord(positions);
                
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                
                // 如果附加光源为逐顶点模式则在这里获取逐顶点的附加光源并传递给片元着色器
                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    o.vertexAdditionalLighting = VertexLighting(o.worldPos, o.worldNormal);
                    o.vertexAdditionalSpecular = GetAdditionalSpecularColor(o.worldPos, o.worldNormal, _Specular, _Gloss);
                #endif
                
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
				// 主光源部分，URP 的主光源只有逐像素和关两个设置，这个 Shader 不考虑主光源关闭的情况
				// URP 将平行光视为主光源，因此主光源不考虑衰减问题
				Light mainLight = GetMainLight();
				half3 lambert = LightingLambert(mainLight.color, mainLight.direction, i.worldNormal);

				// 主光源高光
				half3 specular = LightingSpecular(mainLight.color, mainLight.direction, i.worldNormal, GetWorldSpaceViewDir(i.worldPos), _Specular, _Gloss);
				
                // 主光源产生的影子的浓度
                half shadowAmount = MainLightRealtimeShadow(i.shadowCoords);

				// 计算主光源的颜色总和
				// 阴影浓度是 0-1，其中 0 表示阴影 1 表示不在阴影里，用乘法就行
				half3 mainLighting = (lambert + specular) * shadowAmount;


				// TODO: 附加光部分没有考虑到阴影
				// 附加光源部分，附加光源有三种模式，要根据模式处理
                #if defined(_ADDITIONAL_LIGHTS_VERTEX)
					// 附加光源是逐顶点模式，取出顶点着色器计算的附加光
                    half3 additionalLighting = i.vertexAdditionalLighting;
                #elif defined(_ADDITIONAL_LIGHTS)
					// 附加光源是逐像素模式，计算附加光
                    half3 additionalLighting = GetAdditionalLighting(i.worldPos, i.worldNormal);
				#else
					// 附加光源被禁用了，附加光是纯黑
					half3 additionalLighting = half3(0, 0, 0);
                #endif

				// 附加光源的高光，附加光源有三种模式，要根据模式处理
                #if defined(_ADDITIONAL_LIGHTS_VERTEX)
					// 附加光源是逐顶点模式，取出顶点着色器计算的附加光源高光
                    half3 additionaSpecular = i.vertexAdditionalSpecular;
                #elif defined(_ADDITIONAL_LIGHTS)
					// 附加光源是逐像素模式，附加光源高光
                    half3 additionaSpecular = GetAdditionalSpecularColor(i.worldPos, i.worldNormal, _Specular, _Gloss);
				#else
					// 附加光源被禁用了，附加光源高光是纯黑
					half3 additionaSpecular = half3(0, 0, 0);
                #endif
				
				// 环境光
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                
                return half4((mainLighting + additionalLighting + additionaSpecular + ambient) * _Diffuse.rgb, 1.0);
            }
            
            ENDHLSL
        }
    }
	
    // 最终失败转发，转给 URP 的基础光照材质
	FallBack "Universal Render Pipeline/Lit"
}