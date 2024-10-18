// 边缘检测的 Shader
// 外壳和《入门精要》基本没关系了，但是核心的算法是一样的
Shader "Unity Shaders Book/Chapter 12/My Edge Detection"
{
    Properties
    {
        // 边缘粗细
        _EdgeThickness ("Edge Thickness", Float) = 1.0
        // 只显示边缘
        _EdgeOnly ("Edge Only", Float) = 1.0
        // 边缘颜色
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        // 只显示边缘时的背景颜色
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
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

        // 边缘检测的通道
        Pass
        {
            Name "Edge"

            HLSLPROGRAM
            
            #pragma vertex Vert // 后期处理都是全屏的不需要什么特殊逻辑，顶点着色器就用 Blit 包里提供的
            #pragma fragment Edge

            // 边缘粗细
            half _EdgeThickness;
            // 只显示边缘
            half _EdgeOnly;
            // 边缘颜色
            half4 _EdgeColor;
            // 只显示边缘时的背景颜色
            half4 _BackgroundColor;

            // 计算亮度
            half luminance(half4 color)
            {
                // 这个公式是 ITU-R Recommendation BT.709. 标准，是根据人眼对颜色的感知能力制定的
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            // 计算边缘程度
            half GetEdgeValue(Varyings input)
            {
                // Sobel 算子，边缘检测的算子之一
                // 边缘检测的原理是计算卷积，可以看到这个卷积核的左右两侧是相反的，如果左右两侧的值相同则卷积就是0，左右两侧值相差越大则卷积的绝对值越大
                // 通过这个卷积核对亮度进行卷积，就可以得知这个像素周围是不是有亮度差，而一般来说物体边缘两侧的亮度差较大，卷积结果的绝对值越大则这里越可能是边缘
                const half Gx[9] = {
                    - 1, 0, 1,
                    - 2, 0, 2,
                    - 1, 0, 1
                };
                // 同样是一个 Sobel 算子，只是这个是用在 y 轴的
                const half Gy[9] = {
                    - 1, -2, -1,
                    0, 0, 0,
                    1, 2, 1
                };
                // 到八个方向的附近像素的 UV 坐标，也包括了这个片元自己的 UV 坐标，总共九个
                const float2 Gu[9] = {
                    // UV 偏转量是 (边缘粗细 / 屏幕宽高 * (宽高里小的那个))
                    // 因为 UV 的范围是 0-1，偏转的量是 0.001，这样在调整粗细的时候数值会好看一些
                    // 用宽高小的那个是考虑到带鱼屏，如果用长边或者宽高各自用各自的在带鱼屏上可能会很怪
                    input.texcoord + float2(-0.001, -0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y))),
                    input.texcoord + float2(0, -0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y))),
                    input.texcoord + float2(0.001, -0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y))),
                    input.texcoord + float2(-0.001, 0) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y))),
                    input.texcoord + float2(0, 0) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y))),
                    input.texcoord + float2(0.001, 0) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y))),
                    input.texcoord + float2(-0.001, 0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y))),
                    input.texcoord + float2(0, 0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y))),
                    input.texcoord + float2(0.001, 0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)))
                };
                
                // 下面是正式计算边缘
                half texColor;
                half edgeX = 0;
                half edgeY = 0;
                for (int it = 0; it < 9; it++)
                {
                    // 计算亮度，然后乘，循环9次就是卷积了
                    texColor = luminance(SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, Gu[it]));
                    edgeX += texColor * Gx[it];
                    edgeY += texColor * Gy[it];
                }
                
                half edge = 1 - abs(edgeX) - abs(edgeY);
                
                return edge;
            }
            
            float4 Edge(Varyings input) : SV_Target
            {
                // 取出输入的颜色
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);

                // 计算边缘
                half edge = GetEdgeValue(input);
                
                // 根据设置返回颜色
                half4 withEdgeColor = lerp(_EdgeColor, color, edge);
                half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
                return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
            }
            
            ENDHLSL
        }
    }
}
