Shader "Unity Shaders Book/Chapter 8/My Dither Both Side"
{
    // 对外暴露的属性
    Properties
    {
        // 纹理贴图
        _MainTex ("Texture", 2D) = "white" { } // 使用 white 作为默认贴图，这是 Unity 提供的一张纯白贴图
        // 贴图颜色
        _Color ("Texture Tint", Color) = (1, 1, 1, 1)
        // 透明度缩放
        _AlphaScale ("Alpha Scale", Range(0, 1)) = 1
    }

    SubShader
    {
        Tags
		{
            // 使用通用渲染管线（URP）
            "RenderPipeline" = "UniversalPipeline"
            // 渲染队列为透明度监测队列，这个队列是给透明物体留的，但是同时又不会像 Transparent 队列一样从后往前渲染
			"Queue" = "AlphaTest"
            // 不接受投影
			"IgnoreProjector" = "True"
            // 渲染类型为带裁剪的半透明
			"RenderType" = "TransparentCutout"
        }

        Pass
        {
            Tags
            {
                // 光照模式为 URP前向渲染路径（这个光照模式会产生光照贡献，即可以写入光照信息）
                "LightMode" = "UniversalForward"
            }

			// // 开启深度写入
			// ZWrite On
            // // 片元剔除为不剔除
            // Cull Off
			// // 不进行颜色混合
            // Blend One Zero

            // 使用 HLSL 语法
            HLSLPROGRAM
    
            // 指定顶点着色器方法和片元着色器方法
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
        
            // 在子着色器内部定义一遍对外暴露的属性，名字需要和属性名完全一样，类型要能够转换过来
            sampler2D _MainTex;
            float4 _MainTex_ST; // 对于一个贴图需要有一个 名字_ST 的属性配套，这个属性就是贴图的缩放和偏移的那四个参数
            half4 _Color;
            half _AlphaScale;
        
            // 顶点着色器的输入结构
            struct vertexInput
            {
                // 位置
                float4 position: POSITION; // POSITION 语义是 Unity 提供的位置语义，适合作为顶点着色器的输入（因为这个输入是 Unity 发出来的）
                // 法线
                float3 normal: NORMAL;
                // UV 信息，UV 是存储在顶点上的
                float4 texcoord: TEXCOORD0; // TEXCOORD 是 Texture Coodinates 的组合词
            };
            // 顶点着色器向片元着色器传输的数据结构
            struct vertexToFragment
            {
                // 齐次空间的位置
                float4 hPosition: SV_POSITION; // SV_POsition 是 HLSL 提供的位置语义，适合作为顶点着色器的输出（因为这个输出会走到片元着色器去，是 HLSL 的内部逻辑）
                // 世界空间法线
                half3 worldNormal: TEXCOORD1; // 法线是单位向量，用 half
                // UV
                float2 uv: TEXCOORD2; // UV 精度要求较高，用 float
                // 屏幕空间 xy 坐标，这个坐标用于抖动，z 轴是没必要的
                float2 screenPosition: TEXCOORD3;
            };
        
        
            vertexToFragment vert(vertexInput vertexData)
            {
                // 准备一个输出结构
                vertexToFragment outputData;
        
                // 必须有的将位置转为齐次空间
                outputData.hPosition = TransformObjectToHClip(vertexData.position);
        
                // 将法线转为世界空间存入
                outputData.worldNormal = TransformObjectToWorldNormal(vertexData.normal);

                // 将齐次空间坐标转为屏幕空间坐标并存入
                outputData.screenPosition = ComputeScreenPos(outputData.hPosition);
        
                // 转换 UV
                outputData.uv = TRANSFORM_TEX(vertexData.texcoord, _MainTex);
        
                return outputData;
            }
        
            half4 frag(vertexToFragment input) : SV_Target // SV_Target 语义，基本等同于"COLOR"，但推荐是 SV_Target
            {
                // 计算漫反射的基础色
                // 这个 shader 是半透明的，a 通道也参与计算
                half4 albedo = tex2D(_MainTex, input.uv) * _Color;

                // return half4(input.screenPosition.xy,1,1);

                // 计算屏幕空间抖动产生的透明度
                float ditherAlpha = UnityDitherFloat(albedo.a, input.screenPosition);

                // return half4(ditherAlpha,ditherAlpha,ditherAlpha,1);

                // 透明度裁剪，包含透明度缩放值
                clip(ditherAlpha * _AlphaScale - 0.01);

                // 获取主光源
                Light light = GetMainLight();
        
                // 获取环境光
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                
                // 漫反射颜色
                half3 diffuse = GetDiffuseColor(light.color.rgb * albedo.rgb, input.worldNormal, light.direction);
        
                // 因为使用了透明度裁剪，这里的透明度输出强制为 1
                return half4(ambient + diffuse, 1);
            }
    
            ENDHLSL
        }
    }

    // 最终失败转发，转给 URP 的基础光照材质
	FallBack "Universal Render Pipeline/Lit"
}
