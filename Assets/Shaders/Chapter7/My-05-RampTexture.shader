Shader "Unity Shaders Book/Chapter 7/My-RampTexture"
{
    // 对外暴露的属性
    Properties
    {
        // 贴图颜色
        _Color ("Texture Tint", Color) = (1, 1, 1, 1)
        // 亮度映射图，这张图表示了亮度要转变的颜色，左端为 0，右端为 1
        _RampMap ("Ramp Map", 2D) = "white" {}
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
            half4 _Color;
            sampler2D _RampMap;
            float4 _RampMap_ST;
            half4 _SpecularColor;
            float _Gloss;

            // 顶点着色器的输入结构
            struct vertexInput
            {
                // 位置
                float4 position : POSITION; // POSITION 语义是 Unity 提供的位置语义，适合作为顶点着色器的输入（因为这个输入是 Unity 发出来的）
                // 法线
                float3 normal : NORMAL;
            };

            // 顶点着色器向片元着色器传输的数据结构
            struct vertexToFragment
            {
                // 齐次空间的位置
                float4 hPosition : SV_POSITION;
                // 世界空间法线
				float3 worldNormal : TEXCOORD0;
                // 世界空间位置
				float3 worldPosition : TEXCOORD1;
            };


            vertexToFragment vert(vertexInput vertexData)
            {
                // 准备一个输出结构
                vertexToFragment outputData;

                // 必须有的将位置转为齐次空间
				outputData.hPosition = TransformObjectToHClip(vertexData.position);

                // 法线转到世界空间
                outputData.worldNormal = TransformObjectToWorldNormal(vertexData.normal);

                // 位置转到世界空间
                outputData.worldPosition = TransformObjectToWorld(vertexData.position);
                
                return outputData;
            }

			half4 frag(vertexToFragment input) : SV_Target // SV_Target 语义，基本等同于"COLOR"，但推荐是 SV_Target
            {
                // 获取主光源
                Light light = GetMainLight();

                // 计算漫反射的亮度，为了和原版一致使用了半算法
                half diffuseBrightness = GetDiffuseBrightness(input.worldNormal, light.direction) * 0.5 + 0.5;
                // 映射为亮度映射颜色，原理是亮度范围是 0-1，uv 范围也是 0-1，直接亮度作为 uv 取颜色
                // 当然也存在一些误差的可能，所以最好把映射图设为 Clamp，这样小于 0 效果就相当于最左端、大于 1 则相当于最右端
                // 这张图是从左到右的，纵坐标随便写个值无所谓
                half3 rampedDiffuseBrightness = tex2D(_RampMap, half2(diffuseBrightness, 0.5)).rgb;

                // 最终的漫反射颜色，即映射后亮度 * 漫反射颜色 * 光线颜色
                half3 diffuse = rampedDiffuseBrightness * light.color.rgb * _Color;
                
                // 环境光，没有做亮度映射
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // 高光，这里的高光没有设置亮度映射，因为在印象里似乎很少有画师会给高光做特殊的亮度颜色处理
                half3 specular = GetSpecualrColorBlinnPhong(light.direction, input.worldNormal, GetWorldSpaceNormalizeViewDir(input.worldPosition), _SpecularColor, light.color, _Gloss);

                return half4(diffuse + ambient + specular, 1);
			}
    
            ENDHLSL
        }
    }

    // 最终失败转发，如果所有的子着色器都不能用则转发到这个着色器去
    // Diffuse 是 U3D 自带的那个最普通的着色器
    FallBack "Diffuse"
}
