/*
 * StarRailNPRShader - Fan-made shaders for Unity URP attempting to replicate
 * the shading of Honkai: Star Rail.
 * https://github.com/stalomeow/StarRailNPRShader
 *
 * Copyright (C) 2023 Stalo <stalowork@163.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

Shader "Hidden/Honkai Star Rail/Post Processing/Bloom"
{
    Properties
    {
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        ZTest Always
        ZWrite Off
        Cull Off

        HLSLINCLUDE
        #pragma multi_compile_local _ _USE_RGBM

        #define MAX_KERNEL_SIZE 32
        #define MAX_MIP_DOWN_BLUR_COUNT 4

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
        #include "../Character/Shared/CharRenderingHelpers.hlsl"

        float4 _BlitTexture_TexelSize;

        float _BloomThreshold;
        float4 _BloomUVMinMax[MAX_MIP_DOWN_BLUR_COUNT];

        int _BloomUVIndex;
        int _BloomKernelSize;
        float _BloomKernel[MAX_KERNEL_SIZE];

        half4 EncodeHDR(half3 color)
        {
        #if _USE_RGBM
            half4 outColor = EncodeRGBM(color);
        #else
            half4 outColor = half4(color, 1.0);
        #endif

        #if UNITY_COLORSPACE_GAMMA
            return half4(sqrt(outColor.xyz), outColor.w); // linear to γ
        #else
            return outColor;
        #endif
        }

        half3 DecodeHDR(half4 color)
        {
        #if UNITY_COLORSPACE_GAMMA
            color.xyz *= color.xyz; // γ to linear
        #endif

        #if _USE_RGBM
            return DecodeRGBM(color);
        #else
            return color.xyz;
        #endif
        }

        half4 FragPrefilter(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            float2 uv = UnityStereoTransformScreenSpaceTex(input.texcoord);

#if defined(SUPPORTS_FOVEATED_RENDERING_NON_UNIFORM_RASTER)
            UNITY_BRANCH if (_FOVEATED_RENDERING_NON_UNIFORM_RASTER)
            {
                uv = RemapFoveatedRenderingLinearToNonUniform(uv);
            }
#endif

            float3 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv).rgb;
            color = max(0, color - _BloomThreshold.rrr);
            return EncodeHDR(color);
        }

        // 降采样的顶点着色器
        void VertMipDown(
            Attributes input,
            out Varyings output,
            out float4 uv1 : TEXCOORD3,
            out float4 uv2 : TEXCOORD4)
        {
            output = Vert(input);

            // 采样中间像素，抗闪烁
            float4 texelSize = _BlitTexture_TexelSize;
            float4 offset1 = float4(-0.5, -0.5, -0.5, +0.5);
            float4 offset2 = float4(+0.5, -0.5, +0.5, +0.5);
            uv1 = texelSize.xyxy * offset1 + output.texcoord.xyxy;
            uv2 = texelSize.xyxy * offset2 + output.texcoord.xyxy;
        }

        // 降采样的片元着色器
        half4 FragMipDown(
            Varyings input,
            float4 uv1 : TEXCOORD3,
            float4 uv2 : TEXCOORD4) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            half3 c1 = DecodeHDR(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv1.xy));
            half3 c2 = DecodeHDR(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv1.zw));
            half3 c3 = DecodeHDR(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv2.xy));
            half3 c4 = DecodeHDR(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv2.zw));
            return EncodeHDR(0.25 * (c1 + c2 + c3 + c4));
        }

        half4 FragBlurV(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            float texelSize = _BlitTexture_TexelSize.y;
            float halfKernelSize = (_BloomKernelSize - 1) * 0.5;
            float2 uv = UnityStereoTransformScreenSpaceTex(input.texcoord);

            half3 color = 0;
            for (int i = 0; i < _BloomKernelSize; i++)
            {
                float2 offset = float2(0.0, texelSize * (i - halfKernelSize));
                half3 c = DecodeHDR(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv + offset));
                color += c * _BloomKernel[i];
            }
            return EncodeHDR(color);
        }

        half4 FragBlurH(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            float texelSize = _BlitTexture_TexelSize.x;
            float halfKernelSize = (_BloomKernelSize - 1) * 0.5;

            // 从第一个图集中采样的 uv
            float4 uvMinMax = _BloomUVMinMax[_BloomUVIndex];
            float2 uv = lerp(uvMinMax.xy, uvMinMax.zw, UnityStereoTransformScreenSpaceTex(input.texcoord));

            half3 color = 0;
            for (int i = 0; i < _BloomKernelSize; i++)
            {
                float2 offset = float2(texelSize * (i - halfKernelSize), 0.0);
                half3 c = DecodeHDR(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, clamp(uv + offset, uvMinMax.xy, uvMinMax.zw)));
                color += c * _BloomKernel[i];
            }
            return EncodeHDR(color);
        }

        half4 FragCombine(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            float2 uv = UnityStereoTransformScreenSpaceTex(input.texcoord);

            half3 color = 0;
            UNITY_UNROLL for (int i = 0; i < MAX_MIP_DOWN_BLUR_COUNT; i++)
            {
                float2 atlasUV = lerp(_BloomUVMinMax[i].xy, _BloomUVMinMax[i].zw, uv);
                color += DecodeHDR(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, atlasUV));
            }
            return EncodeHDR(color);
        }
        ENDHLSL

        Pass
        {
            Name "Bloom Prefilter"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragPrefilter
            ENDHLSL
        }

        // 降采样通道，对高亮区域提取后通过这个通道进行像素的压缩
        // 从原理上说 Bloom 的具体步骤是：提取高亮部分 -> 模糊高亮部分 -> 合并到主输出上
        //
        // 已知高斯模糊的算法有两种方式
        // 1. 精准逐像素采样，优点是在任何分辨率的屏幕上都是完美逐像素，缺点是为了保证不同分辨率效果相同越是大的屏幕所需的计算量就越大
        // 2. 按百分比步长采样，优点是不管屏幕大小计算量都一样，缺点是步长太大会被看出来重影，如果步长恰好和有规律的画面对齐了会导致奇怪的效果（例如步长是 1%，正好画面是 1% 宽度的垂直相间红蓝线，则这个模糊会毫无作用，因为垂直是纯色模糊无效，水平正好每一个像素都和左右步长的像素一个颜色）
        //
        // 为了保证效果，我个人倾向于逐像素采样，能用高分辨率电脑的玩家肯定也会有更好的设备，除非他不懂电脑被人骗了或者自己异想天开
        // 在逐像素上存在一个方案：对高亮部分进行降采样，例如降低到原来的 1/4 面积，则可以节约 3/4 的模糊计算量，节约的量远大于降采样消耗的量
        //
        // 这种方案实际上利用了 Bloom 是模糊后和原图混合的逻辑，本来模糊的图即使降采样更加模糊也不会产生很明显的变化
        Pass
        {
            Name "Bloom Mip Down"

            HLSLPROGRAM
            #pragma vertex VertMipDown
            #pragma fragment FragMipDown
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Blur Vertical"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragBlurV
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Blur Horizontal"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragBlurH
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Combine"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragCombine
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Blit Character Color"

            // 角色的 Stencil
            Stencil
            {
                Ref 1
                ReadMask 1
                Comp Equal
                Pass Keep
                Fail Keep
            }

            HLSLPROGRAM
            #pragma vertex Vert
            // #pragma fragment FragNearest

            // https://docs.unity3d.com/Manual/SL-SamplerStates.html
            // 和 PostProcessPass 中声明的 RT 保持一致，不然 OpenGL ES 上效果不一致
            #pragma fragment FragBilinear
            ENDHLSL
        }
    }

    Fallback Off
}
