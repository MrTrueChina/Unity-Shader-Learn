Shader "Unity Shaders Book/Chapter 8/My Alpha Blend With Both Side"
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
            // 渲染队列为透明队列，这个队列会按照从远到近渲染
			"Queue" = "Transparent"
            // 不接受投影
			"IgnoreProjector" = "True"
            // 渲染类型为 透明材质
			"RenderType" = "Transparent"
        }

        Pass
        {
            Tags
            {
                // 光照模式为 URP前向渲染路径（这个光照模式可以在 URP 允许范围内接收尽可能多的光源）
                "LightMode" = "UniversalForward"
            }

			// 关闭深度写入
			ZWrite Off
            // 片元剔除为剔除正面
            Cull Front
			// 混合模式为 当前片元使用自身透明度，已有内容使用 1-片元透明度。就是最普通的透明材质
			Blend SrcAlpha OneMinusSrcAlpha

            // 使用 HLSL 语法
            HLSLPROGRAM
    
            // 指定顶点着色器方法和片元着色器方法
            #pragma vertex vert
            #pragma fragment frag
    
            ENDHLSL
        }

        Pass
        {
            Tags
            {
				// 光照模式为 USB-AfterTransparentPass
				// 这个光照模式是给 《入门精要》 额外扩增的渲染通道，URP 不支持传统的通道，需要用 ScriptableRenderFeature 来添加
				// 这个方式添加的通道和传统通道不一样，尤其是顺序上有所不同
				"LightMode" = "USB-AfterTransparentPass"
                
                // // 光照模式为 SRPDefaultUnlit (脚本自定义渲染通道的默认光照模式，根据名字分析这个通道没有光照信息)
                // // 这是 URP 给自定义通道提供的光照模式，也是在不写光照模式时默认使用的光照模式
				// "LightMode" = "SRPDefaultUnlit"
                
                // // 光照模式为 UniversalGBuffer (G缓冲)
                // // G缓冲是计算机图形学的通用设计，是一个记录了光照、深度、法线等各种信息的缓冲区，常用于延迟渲染
                // // 这个光照模式不会写入光照信息，但可以读取，这也是为什么他常用于延迟渲染，因为必须有其他光照模式进行正确的光照信息写入这个通道才能正常渲
				// "LightMode" = "UniversalGBuffer"
            }

			// 关闭深度写入
			ZWrite Off
            // 片元剔除为剔除背面
            Cull Back
			// 混合模式为 当前片元使用自身透明度，已有内容使用 1-片元透明度。就是最普通的透明材质
			Blend SrcAlpha OneMinusSrcAlpha

            // 使用 HLSL 语法
            HLSLPROGRAM
    
            // 指定顶点着色器方法和片元着色器方法
            #pragma vertex vert
            #pragma fragment frag
            // #pragma fragment debug_frag

            half4 debug_frag(vertexToFragment input) : SV_Target
            {
                return half4(1,1,1,1);
            }
    
            ENDHLSL
        }

        // 导入 HLSL 的语法，这里直接写内容也是导入允许的一种方式，在这里把具体的着色器逻辑写了，两个 Pass 就只要设置一下参数就可以了
        HLSLINCLUDE
    
        // 指定顶点着色器方法和片元着色器方法
    
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
        };
    
    
        vertexToFragment vert(vertexInput vertexData)
        {
            // 准备一个输出结构
            vertexToFragment outputData;
    
            // 必须有的将位置转为齐次空间
            outputData.hPosition = TransformObjectToHClip(vertexData.position);
    
            // 将位置和法线转为世界空间存入
            outputData.worldNormal = TransformObjectToWorldNormal(vertexData.normal);
    
            // 转换 UV
            outputData.uv = TRANSFORM_TEX(vertexData.texcoord, _MainTex);
    
            return outputData;
        }
    
        half4 frag(vertexToFragment input) : SV_Target // SV_Target 语义，基本等同于"COLOR"，但推荐是 SV_Target
        {
            // 计算漫反射的基础色
            // 这个 shader 是半透明的，a 通道也参与计算
            half4 albedo = tex2D(_MainTex, input.uv) * _Color;
    
            // 获取主光源
            Light light = GetMainLight();
    
            // 获取环境光
            half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
            
            // 漫反射颜色
            half3 diffuse = GetDiffuseColor(light.color.rgb * albedo.rgb, input.worldNormal, light.direction);
    
            return half4(ambient + diffuse, albedo.a * _AlphaScale);
        }
    
        ENDHLSL
    }

    // 最终失败转发，转给 URP 的基础光照材质
	FallBack "Universal Render Pipeline/Lit"
}
