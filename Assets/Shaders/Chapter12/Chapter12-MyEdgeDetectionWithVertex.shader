// 边缘检测的 Shader
// 外壳和《入门精要》基本没关系了，但是核心的算法是一样的
//
// 这是以顶点着色器算 UV 的，和《入门精要》的更接近一些
// 理论上把 UV 坐标的计算量挪到了顶点着色器里算力应该更加节约一点，相对的显存和内存占用应该会高一点
// 实际测试性能差异极小，多占了一些内存和显存，似乎不太值得
Shader "Unity Shaders Book/Chapter 12/My Edge Detection With Vertex"
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
            
            #pragma vertex vert
            #pragma fragment Edge

            // 边缘粗细
            half _EdgeThickness;
            // 只显示边缘
            half _EdgeOnly;
            // 边缘颜色
            half4 _EdgeColor;
            // 只显示边缘时的背景颜色
            half4 _BackgroundColor;

            // 顶点着色器给片元着色器传递的数据
            // 是对 URP 的 Blit 包的 Varyings 的包装，多传递一套 UV 坐标以降低计算量
            struct v2f
            {
                Varyings varyings;
                float2 uvs[9] : TEXCOORD1;
            };

            v2f vert(Attributes input)
            {
                v2f output;

                // 用 Blit 的 Vert 方法处理，这是 URP 提供的顶点着色器方法
                output.varyings = Vert(input);

                // 计算八个方向的像素的 UV 坐标，再加上中间自己的像素的坐标，总共九个
                output.uvs[0] = output.varyings.texcoord + float2(-0.001, -0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)));
                output.uvs[1] = output.varyings.texcoord + float2(0, -0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)));
                output.uvs[2] = output.varyings.texcoord + float2(0.001, -0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)));
                output.uvs[3] = output.varyings.texcoord + float2(-0.001, 0) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)));
                output.uvs[4] = output.varyings.texcoord + float2(0, 0) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)));
                output.uvs[5] = output.varyings.texcoord + float2(0.001, 0) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)));
                output.uvs[6] = output.varyings.texcoord + float2(-0.001, 0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)));
                output.uvs[7] = output.varyings.texcoord + float2(0, 0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)));
                output.uvs[8] = output.varyings.texcoord + float2(0.001, 0.001) * (_EdgeThickness / _ScreenParams.xy * (min(_ScreenParams.x, _ScreenParams.y)));

                return output;
            }

            // 计算亮度
            half luminance(half4 color)
            {
                // 这个公式是 ITU-R Recommendation BT.709. 标准，是根据人眼对颜色的感知能力制定的
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            // 计算边缘程度
            half GetEdgeValue(v2f input)
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
                
                // 下面是正式计算边缘
                half texColor;
                half edgeX = 0;
                half edgeY = 0;
                for (int it = 0; it < 9; it++)
                {
                    // 计算亮度，然后乘，循环9次就是卷积了
                    texColor = luminance(SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.uvs[it]));
                    edgeX += texColor * Gx[it];
                    edgeY += texColor * Gy[it];
                }
                
                half edge = 1 - abs(edgeX) - abs(edgeY);
                
                return edge;
            }
            
            float4 Edge(v2f input) : SV_Target
            {
                // 取出输入的颜色
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.varyings.texcoord);

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
