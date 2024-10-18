// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 8/Alpha Blending With ZWrite"
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
			// 因为这个 shader 会写入深度，要用透明队列的从远到近特性来做
			"Queue" = "Transparent"
            // 不接受投影
			"IgnoreProjector" = "True"
            // 渲染类型为 透明材质
			"RenderType" = "Transparent"
        }
        
        // 只写入深度的 Pass
		// 通过先写入深度可以让本身有遮挡的透明物体被遮挡住的部分不会渲染，达到一种防止渲染层次错误的效果
		// 但这也有代价，首先因为写入了深度很依赖从后往前渲染，可能会打断合批
		// 此外由于自身的被遮挡部分不渲染也会产生不自然的情况，看起来比起物体本身是透明的更像是一个不透明的物体用视频特效的方式改成了半透明图层
		// 这导致这种效果可能很不适合半透明手镯之类的物品
        Pass
        {
            Name "ZWrite"

			// Tags
			// {
			// 	// 光照模式为 URP前向渲染路径（这个光照模式可以在 URP 允许范围内接收尽可能多的光源）
			// 	// 不知道什么原因，但是如果在前面的 pass 添加的话这个 pass 会完全渲染不出内容，同样的原因也不能加到 subshader 里，只能在这里写
			// 	"LightMode" = "DepthNormalsOnly"
			// }

            ZWrite On
            ColorMask 0 // 不输出任何颜色，这里可以是 RGBA 的任意组合，0 表示任何一个通道都不输出
        }
        
		// 负责渲染的 Pass
        Pass
        {
            Name "Render"

			Tags
			{
				// 光照模式为 URP前向渲染路径（这个光照模式可以在 URP 允许范围内接收尽可能多的光源）
				// 不知道什么原因，但是如果在前面的 pass 添加的话这个 pass 会完全渲染不出内容，同样的原因也不能加到 subshader 里，只能在这里写
				"LightMode" = "UniversalForward"
			}

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
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float2 uv : TEXCOORD1;
            };
            
            v2f vert(a2v v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
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

	FallBack "Universal Render Pipeline/Lit"
}
