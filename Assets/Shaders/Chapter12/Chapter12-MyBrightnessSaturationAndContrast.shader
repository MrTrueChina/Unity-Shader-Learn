// 控制亮度、饱和度和对比度的 Shader
// 外壳和《入门精要》基本没关系了，但是核心的算法是一样的
Shader "Unity Shaders Book/Chapter 12/My Brightness Saturation And Contrast"
{
    Properties
    {
        _Brightness ("Brightness", Float) = 1
        _Saturation ("Saturation", Float) = 1
        _Contrast ("Contrast", Float) = 1
    }
    
    SubShader
    {
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // Blit 包，提供了一些快速的渲染的功能，对于后期处理相当有用
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        ENDHLSL

        Tags {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"
			"Queue" = "Overlay"
        }
        LOD 100
        ZTest Always ZWrite Off Cull Off

        // 调整亮度、饱和度和对比度的通道
        Pass
        {
            Name "BSC"

            HLSLPROGRAM
            
            #pragma vertex Vert // 后期处理都是全屏的不需要什么特殊逻辑，顶点着色器就用 Blit 包里提供的
            #pragma fragment BSC

            float _Brightness;
            float _Saturation;
            float _Contrast;
            
            float4 BSC (Varyings input) : SV_Target
            {
                // 获取颜色，这一整行都是 URP 的 Blit 包提供的，直接用就行
                // 这里只获取了 rgb，这是因为这个后处理是全屏最后的后处理，不会有透明度的问题
                float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgb;

                // 亮度，就是简单的乘以亮度
                float3 finalColor = color * _Brightness;

                // 饱和度
                // 亮度，这是饱和度为 0 时候的颜色
                // 这个公式对应 ITU-R Recommendation BT.709. 标准，是根据人眼对颜色的感知能力制定的
				half luminance = 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
				half3 luminanceColor = half3(luminance, luminance, luminance);
                // 饱和度的调整就是 Lerp，饱和度越低越接近灰度，饱和度 1 就是原图
				finalColor = lerp(luminanceColor, finalColor, _Saturation);

                // 对比度
                // 对比度很简单，对比度到 0 就是完全的中性灰，对比度是 1 则是原图
				half3 avgColor = half3(0.5, 0.5, 0.5);
				finalColor = lerp(avgColor, finalColor, _Contrast);

                // 这个后处理是全屏最终后处理，不需要考虑透明度问题，直接返回不透明颜色
                return float4(finalColor, 1);
            }
            
            ENDHLSL
        }
        
        // 仅用于原样渲染的通道，由于 Unity 的 Blit 不能源和目标相同，处理的时候就需要将源输出到中转纹理中
        // 但是为了最终渲染结果显示出来需要再输出到 Unity 管线本身的那个输出纹理中，这就需要一个原样渲染的通道
        Pass
        {
            Name "JustBlit" // 名字无所谓，在调用的时候是通过索引调用的

            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment SimpleBlit
            
            float4 SimpleBlit (Varyings input) : SV_Target
            {
                float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgb;
                return float4(color.rgb, 1);
            }

            ENDHLSL
        }
    }
}
