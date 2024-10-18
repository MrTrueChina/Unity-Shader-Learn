// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 12/My Gaussian Blur"
{
    Properties
    {
        // 卷积核大小，即一个像素会和多大范围内的其他像素进行颜色混合
        _KernelSize ("Kernel Size", Float) = 1.0
        // 方差，即一个像素会多大程度受到偏远的像素的影响，方差越小则受到远处像素影响程度越小，视觉上模糊效果就越小
        _StandardDeviation ("Standard Deviation", Float) = 3.0
    }
    
    SubShader
    {
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // Blit 包，提供了一些快速的渲染的功能，对于后期处理相当有用
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        ENDHLSL

        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Overlay" }
        LOD 100
        ZTest Always ZWrite Off Cull Off

        // 水平模糊的通道
        // 高斯模糊是二维的模糊，假设模糊范围是 5 像素，则一个像素需要 5*5=25 个像素的计算量
        // 但很幸运高斯模糊是圆形均匀扩散的，这就表示可以先整体水平一次再整体垂直一次，这样一个像素就只需要 5+5=10 个像素的计算量
        Pass
        {
            Name "Horizontal"

            HLSLPROGRAM
            
            #pragma vertex Vert // 后期处理都是全屏的不需要什么特殊逻辑，顶点着色器就用 Blit 包里提供的
            #pragma fragment Edge

            // 卷积核大小
            half _KernelSize;
            // 方差
            half _StandardDeviation;

            // 计算高斯权重
            float CalculateGaussianWeight(float x, float standardDeviation)
            {
                return exp(-(x * x) / (2.0 * standardDeviation * standardDeviation)) / (sqrt(2.0 * 3.14159) * standardDeviation);
            }
            
            float4 Edge(Varyings input) : SV_Target
            {
                // 根据模糊体积计算出需要模糊的像素距离
                // 因为 UV 的范围是 0-1，这里乘了一个 0.001，这样在调整粗细的时候数值会好看一些
                // 用宽高小的那个是考虑到带鱼屏，如果用长边或者宽高各自用各自的在带鱼屏上可能会很怪，同样也是因为带鱼屏如果用长边的话会糊到根本看不出任何东西
                int blurPixel = min(_ScreenParams.x, _ScreenParams.y) * _KernelSize * 0.001;

                // 从负到正遍历每个像素，按照公式计算出颜色占比，进行总和
                float4 blurredColor = (0, 0, 0, 0);
                for (int i = -blurPixel; i <= blurPixel; i++)
                {
                    // 计算出这个像素的颜色权重
                    float weight = CalculateGaussianWeight(i, _StandardDeviation);
                    // 计算出这个像素的UV
                    float2 uv = float2(input.texcoord.x + (i / _ScreenParams.x), input.texcoord.y);

                    // 根据权重计算模糊后的颜色
                    blurredColor += weight * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
                }

                return blurredColor;
            }
            
            ENDHLSL
        }
        
        Pass
        {
            Name "Vertical"

            HLSLPROGRAM
            
            #pragma vertex Vert // 后期处理都是全屏的不需要什么特殊逻辑，顶点着色器就用 Blit 包里提供的
            #pragma fragment Edge

            // 卷积核大小
            half _KernelSize;
            // 方差
            half _StandardDeviation;

            // 计算高斯权重
            float CalculateGaussianWeight(float x, float standardDeviation)
            {
                return exp(-(x * x) / (2.0 * standardDeviation * standardDeviation)) / (sqrt(2.0 * 3.14159) * standardDeviation);
            }
            
            float4 Edge(Varyings input) : SV_Target
            {
                // 根据模糊体积计算出需要模糊的像素距离
                // 因为 UV 的范围是 0-1，这里乘了一个 0.001，这样在调整粗细的时候数值会好看一些
                // 用宽高小的那个是考虑到带鱼屏，如果用长边或者宽高各自用各自的在带鱼屏上可能会很怪，同样也是因为带鱼屏如果用长边的话会糊到根本看不出任何东西
                int blurPixel = min(_ScreenParams.x, _ScreenParams.y) * _KernelSize * 0.001;

                // 从负到正遍历每个像素，按照公式计算出颜色占比，进行总和
                float4 blurredColor = (0, 0, 0, 0);
                for (int i = -blurPixel; i <= blurPixel; i++)
                {
                    // 计算出这个像素的颜色权重
                    float weight = CalculateGaussianWeight(i, _StandardDeviation);
                    // 计算出这个像素的UV
                    float2 uv = float2(input.texcoord.x, input.texcoord.y + (i / _ScreenParams.y));

                    // 根据权重计算模糊后的颜色
                    blurredColor += weight * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
                }

                return blurredColor;
            }
            
            ENDHLSL
        }
    }
}
