Shader "Unity Shaders Book/Chapter 7/My-SingleTexture-PrintUV"
{
    // 对外暴露的属性
    Properties
    {
        // 纹理贴图
        _MainTex ("Texture", 2D) = "white" {} // 使用 white 作为默认贴图，这是 Unity 提供的一张纯白贴图
        // 贴图颜色
        _Color ("Texture Tint", Color) = (1,1,1,1)
        // 高光颜色
		_SpecularColor ("Specular", Color) = (1, 1, 1, 1)
        // 光泽，这个值越高则高光会越集中
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
    
            // 使用 HLSL 方案
            HLSLPROGRAM
    
            // 指定顶点着色器方法和片元着色器方法
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // 在子着色器内部定义一遍对外暴露的属性，名字需要和属性名完全一样，类型要能够转换过来
            sampler2D _MainTex;
			float4 _MainTex_ST; // 对于一个贴图需要有一个 名字_ST 的属性配套，这个属性就是贴图的缩放和偏移的那四个参数
            half4 _Color;
            half4 _SpecularColor;
            float _Gloss;

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
                // 颜色，这个 Shader 是测试用的，顶点计算颜色片元输出就够了
                half3 color: COLOR;
            };


            vertexToFragment vert(vertexInput vertexData)
            {
                // 准备一个输出结构
                vertexToFragment outputData;

                // 必须有的将位置转为齐次空间
				outputData.hPosition = TransformObjectToHClip(vertexData.position);

                // 转换 UV
                // 这一步解释起来是这样的：
                // 0. 在 3D 模型领域，为了让贴图正确显示，需要确认模型表面的每个位置对应贴图的哪个位置。为此引入了一个叫做 UV 的中间层，UV 的作用就是确认模型表面和贴图的位置对应。UV 数据存储在模型的顶点上，贴图不包含任何 UV 信息，因此贴图只要对着 UV 画，不需要做什么其他的处理
                // 1. 这个方法是结合顶点坐标、纹理图计算出 UV，或者说计算出这个顶点对应了贴图上的哪个点
                float2 uv = TRANSFORM_TEX(vertexData.texcoord, _MainTex);

                // 把 UV 缩小一些作为颜色输出
                // 可以看出来 UV 的默认范围是 0-1，但是偏移和平铺设置拉大之后 UV 的值就会产生变化，超出这个范围也是十分正常的
                outputData.color = half3(uv * 0.5, 0);

                return outputData;
            }

			half4 frag(vertexToFragment input) : SV_Target // SV_Target 语义，基本等同于"COLOR"，但推荐是 SV_Target
            {
                // 直接输出颜色
                return half4(input.color.rgb, 1.0);
			}
    
            ENDHLSL
        }
    }

    // 最终失败转发，如果所有的子着色器都不能用则转发到这个着色器去
    // Diffuse 是 U3D 自带的那个最普通的着色器
    FallBack "Diffuse"
}
