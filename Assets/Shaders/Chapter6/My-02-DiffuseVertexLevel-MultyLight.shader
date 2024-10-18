Shader "Unity Shaders Book/Chapter 6/My-DiffuseVertexLevel-MultyLight"
{
    // 对外暴露的属性
    Properties
    {
        // 漫反射颜色，就是物体可以反射的光的颜色，也是物体在白光下的颜色
        _Diffuse ("Diffuse", Color) = (1,1,1,1)
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
            half4 _Diffuse;

            // 顶点着色器的输入结构
            struct vertexInput
            {
                // 位置，位置可能是世界空间的，用 float
                float4 position: POSITION;
                // 法线，需要很高的精度，用 float
                float3 normal: NORMAL;
            };
            // 顶点着色器向片元着色器传输的数据结构
            struct vertexToFragment
            {
                // 位置是必须的，没有这个位置则片元着色器不知道要在哪里绘制，即使片元着色器代码里没用到也要带这个属性
				float4 pos : SV_POSITION;
                // 因为这个着色器是不透明的，颜色只要传 RGB，half3 就够了
                half3 color: COLOR;
            };


            // 顶点着色器处理方法
            vertexToFragment vert(vertexInput vertexData)
            {
                // 准备一个输出结构
                vertexToFragment outputData;

				// 坐标转换存入返回消息，这个是渲染管线的要求，用不到也要传
				outputData.pos = TransformObjectToHClip(vertexData.position);

                // 法线转换到世界空间
				half3 worldNormal = TransformObjectToWorldNormal(vertexData.normal);
                // 坐标转换到世界空间
                half3 worldPosition = TransformObjectToWorld(vertexData.position);

                // 获取主光源
                Light light = GetMainLight();
                // 计算主光源产生的亮度
                half brightness = saturate(dot(worldNormal, light.direction));
                // 计算光源产生的颜色，但先不计算对应到物体上的颜色
                half3 lightColor = light.color.rgb * brightness;

                // 遍历附加光源
                int additionalLightCount = GetAdditionalLightsCount();
                for (int i = 0; i < additionalLightCount; i++)
                {
                    // 获取附加光源
                    Light lightData = GetAdditionalLight(i, worldPosition);
                    // 计算亮度
                    half brightness = saturate(dot(worldNormal, lightData.direction));
                    // 把光源颜色合并到现在已经计算的颜色里
                    lightColor += lightData.color.rgb * brightness;
                }

                // 计算物体漫反射和光颜色混合后的颜色
                outputData.color = _Diffuse.rgb * lightColor;

                return outputData;
            }

            // 片元着色器处理方法
			half4 frag(vertexToFragment input) : SV_Target {

                // // 用于测试有几个附加光源的代码，附加光源越多则物体越亮
                // // 经过测试只要附加光源可能影响到物体，整个物体的片元着色器执行都会获取到这个附加光源，不管是哪个位置的像素、会不会被影响到
                // // 顶点着色器也已经测试过，同样只要物体可能被影响则所有顶点都可以获取到这个光源
                // // 多物体已经测试过，不同物体可以获取到的附加光源不同，即使他们使用了一样的材质球也会因为位置不同获取到不同的光源
                // int additionalLightCount = GetAdditionalLightsCount();
				// return half4(additionalLightCount * 0.2,additionalLightCount * 0.2,additionalLightCount * 0.2, 1.0);

                // 片元着色器啥都不用干，把颜色输出就行，因为这个 shader 是不透明的，透明度就是 1
				return half4(input.color, 1.0);
			}
    
            ENDHLSL
        }
    }

    // 最终失败转发，如果所有的子着色器都不能用则转发到这个着色器去
    // Diffuse 是 U3D 自带的那个最普通的着色器
    FallBack "Diffuse"
}
