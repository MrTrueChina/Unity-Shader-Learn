// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 10/Refraction"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
		/// 折射颜色
        _RefractColor ("Refraction Color", Color) = (1, 1, 1, 1)
		/// 折射透明度
        _RefractAmount ("Refraction Amount", Range(0, 1)) = 1
		/// 折射率
        _RefractRatio ("Refraction Ratio", Range(0.1, 1)) = 0.5
        _Cubemap ("Refraction Cubemap", Cube) = "_Skybox" { }
    }
    SubShader
    {
        Tags
		{
            // 使用通用渲染管线（URP）
            "RenderPipeline" = "UniversalPipeline"
			// 不透明类型
			"RenderType" = "Opaque"
			// 几何体队列
			"Queue" = "Geometry"
		}
        
        Pass
        {
            Tags
			{
                // 光照模式为 URP前向渲染
                "LightMode" = "UniversalForward"
			}
            
            HLSLPROGRAM
            
			// 阴影版本编译是必要的，不然阴影无效
			// 编译主光源投影版本
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			// 编译软阴影版本
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
            
            half4 _Color;
			/// 折射颜色
            half4 _RefractColor;
			/// 折射透明度
            float _RefractAmount;
			/// 折射率
            half _RefractRatio;
            samplerCUBE _Cubemap;
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                half3 worldNormal : TEXCOORD1;
                half3 worldRefr : TEXCOORD2;
				float4 shadowCoords : TEXCOORD3;
            };
            
            v2f vert(a2v v)
            {
                v2f o;

                // 获取位置信息
                VertexPositionInputs positions = GetVertexPositionInputs(v.vertex.xyz);
                
				// 裁剪空间坐标
                o.pos = positions.positionCS;
                
				// 世界空间坐标
                o.worldPos = positions.positionWS;
                
				// 世界空间法线
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                
                // 计算折射方向，方法是 Unity 内置的
                o.worldRefr = refract(-GetWorldSpaceViewDir(o.worldPos), o.worldNormal, _RefractRatio);
                
                // 这个顶点在阴影贴图上的坐标
                o.shadowCoords = GetShadowCoord(positions);
                
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
				Light mainLight = GetMainLight();

                // 主光源产生的影子的浓度
                half shadowAmount = MainLightRealtimeShadow(i.shadowCoords);

				// 环境光
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                
				// 漫反射，考虑影子浓度
                half3 diffuse = LightingLambert(mainLight.color.rgb, mainLight.direction, i.worldNormal) * shadowAmount * _Color.rgb;
                
                // 折射
				// 用了 Unity 提供的获取贴图盒子上数据的方法，传入的是世界空间的折射视线方向
                half3 refraction = texCUBE(_Cubemap, i.worldRefr).rgb * _RefractColor.rgb;
                
                // 混合颜色，用 lerp 就可以，反射率是 0-1 正合适
                half3 color = ambient + lerp(diffuse, refraction, _RefractAmount);
                
                return half4(color, 1.0);
            }
            
            ENDHLSL
        }
    }

    // 最终失败转发，转给 URP 的基础光照材质
	FallBack "Universal Render Pipeline/Lit"
}
