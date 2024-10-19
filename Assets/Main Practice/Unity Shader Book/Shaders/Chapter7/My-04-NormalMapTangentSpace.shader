Shader "Unity Shaders Book/Chapter 7/My-NormalMapTangentSpace"
{
    // 对外暴露的属性
    Properties
    {
        // 纹理贴图
        _MainTexture ("Texture", 2D) = "white" { } // 使用 white 作为默认贴图，这是 Unity 提供的一张纯白贴图
        // 贴图颜色
        _Color ("Texture Tint", Color) = (1, 1, 1, 1)
        // 法线贴图
        _Normal ("Normal Map", 2D) = "bump" { }
        // 法线缩放
        _NormalScale ("Normal Scale", Float) = 1
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
            #include "../Common/ShaderUtils.hlsl"

            // 在子着色器内部定义一遍对外暴露的属性，名字需要和属性名完全一样，类型要能够转换过来
            sampler2D _MainTexture;
			float4 _MainTexture_ST; // 对于一个贴图需要有一个 名字_ST 的属性配套，这个属性就是贴图的缩放和偏移的那四个参数
            half4 _Color;
            sampler2D _Normal;
            float4 _Normal_ST;
            float _NormalScale;
            half4 _SpecularColor;
            float _Gloss;

            // 顶点着色器的输入结构
            struct vertexInput
            {
                // 位置
                float4 position: POSITION; // POSITION 语义是 Unity 提供的位置语义，适合作为顶点着色器的输入（因为这个输入是 Unity 发出来的）
                // 法线
                float3 normal: NORMAL;
                // 切线
                float4 tangent: TANGENT;
                // UV 信息，UV 是存储在顶点上的
				float4 texcoord: TEXCOORD0;
            };
            // 顶点着色器向片元着色器传输的数据结构
            struct vertexToFragment
            {
                // 齐次空间的位置
				float4 hPosition: SV_POSITION;
                // 这个片元对应的贴图和法线图的坐标
                float4 uv: TEXCOORD0;
                // 切线空间的光线
                float3 tangentLightDirection: TEXCOORD1;
                // 切线空间的视角
                float3 tangentViewDirection: TEXCOORD2;
            };


            vertexToFragment vert(vertexInput vertexData)
            {
                // 准备一个输出结构
                vertexToFragment outputData;

                // 必须有的将位置转为齐次空间
				outputData.hPosition = TransformObjectToHClip(vertexData.position);

                // 用内置方法处理一下 UV 变化，其实就是对着平铺和偏转进行简单的计算
                // 两个 UV 各自存入一个轴，节约一下 TEXCOORD
                // 在实际使用时如果有把握模型的贴图和法线在默认情况就是正确的也可以不进行这个计算，省一些计算量
                outputData.uv.xy = TRANSFORM_TEX(vertexData.texcoord, _MainTexture);
                outputData.uv.zw = TRANSFORM_TEX(vertexData.texcoord, _Normal);
                
                // 创建一个从世界空间到切线空间的转换矩阵
                float3x3 tangentToWorld = CreateTangentToWorldByObject(vertexData.normal, vertexData.tangent);

                // 获取主光源
                Light mainLight = GetMainLight();

                // 转换光线到切线空间并保存
                outputData.tangentLightDirection = TransformWorldToTangentDir(mainLight.direction, tangentToWorld);
                // 转换视线到切线空间并保存
                outputData.tangentViewDirection = TransformWorldToTangentDir(GetWorldSpaceNormalizeViewDir(TransformObjectToWorld(vertexData.position.xyz)), tangentToWorld);

                return outputData;
            }

			half4 frag(vertexToFragment input) : SV_Target // SV_Target 语义，基本等同于"COLOR"，但推荐是 SV_Target
            {
                // 漫反射颜色，是贴图的颜色
                // 如果能保证贴图颜色正确且绝不更改的话可以只获取贴图颜色，这样计算量少一些
                half3 albedo = tex2D(_MainTexture, input.uv.xy).rgb * _Color.rgb;

                // 计算法线
                half3 tangentNormal = UnpackTangentSpaceNormal(_Normal, input.uv.zw, _NormalScale);

                // 获取主光源
                Light light = GetMainLight();
                
                // 环境光
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // 漫反射光
                half3 diffuse = GetDiffuseColor(light.color.rgb, tangentNormal, input.tangentLightDirection);

                // 高光
                half3 specular = GetSpecualrColorBlinnPhong(input.tangentLightDirection, tangentNormal, input.tangentViewDirection, _SpecularColor, light.color, _Gloss);

                // 环境光和漫反射是受到物体颜色影响的，高光可以理解为像是涂层一样的东西就不受物体颜色影响了
                return half4((diffuse + ambient) * albedo + specular, 1);
			}
    
            ENDHLSL
        }
    }

    // 最终失败转发，如果所有的子着色器都不能用则转发到这个着色器去
    // Diffuse 是 U3D 自带的那个最普通的着色器
    FallBack "Diffuse"
}
