// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 11/Water"
{
    Properties
    {
        _MainTex ("Main Tex", 2D) = "white" { }
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _Magnitude ("Distortion Magnitude", Float) = 1
        _Frequency ("Distortion Frequency", Float) = 1
        _InvWaveLength ("Distortion Inverse Wave Length", Float) = 10
        _Speed ("Speed", Float) = 0.5
    }
    SubShader
    {
        Tags
        {
            // 使用通用渲染管线（URP）
            "RenderPipeline" = "UniversalPipeline"
			// 透明类型
			"RenderType" = "Transparent"
			// 透明队列
			"Queue" = "Transparent"
			// 不接受投影
			"IgnoreProjector" = "True"
			// 禁止合批
			"DisableBatching" = "True"
        }
        
        Pass
        {
            Tags
            {
                // 光照模式为 URP前向渲染路径（这个光照模式会产生光照贡献，即可以写入光照信息）
                "LightMode" = "UniversalForward"
            }
            
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            half4 _Color;
            float _Magnitude;
            float _Frequency;
            float _InvWaveLength;
            float _Speed;
            
            struct a2v
            {
                float4 vertex : POSITION;
                float4 texcoord : TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            v2f vert(a2v v)
            {
                v2f o;
                
				// 计算顶点偏移量
                float4 offset;
                offset.yzw = float3(0.0, 0.0, 0.0);
                offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
                o.pos = TransformObjectToHClip(v.vertex + offset);
                
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv += float2(0.0, _Time.y * _Speed);
                
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                half4 c = tex2D(_MainTex, i.uv);
                c.rgb *= _Color.rgb;
                
                return c;
            }
            
            ENDHLSL
        }
    }
    FallBack "Transparent/VertexLit"
}
