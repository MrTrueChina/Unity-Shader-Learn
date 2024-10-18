// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 11/Vertex Animation With Shadow"
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
			// 不透明类型
			"RenderType" = "Opaque"
			// 几何体队列
			"Queue" = "Geometry"
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
            
            Cull Off
            
            HLSLPROGRAM
            // #pragma vertex vert
            // #pragma fragment frag
            
            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            // #include "../Common/ShaderUtils.hlsl"
            
            // sampler2D _MainTex;
            // float4 _MainTex_ST;
            // half4 _Color;
            // float _Magnitude;
            // float _Frequency;
            // float _InvWaveLength;
            // float _Speed;
            
            // struct a2v
            // {
            //     float4 vertex : POSITION;
            //     float4 texcoord : TEXCOORD0;
            // };
            
            // struct v2f
            // {
            //     float4 pos : SV_POSITION;
            //     float2 uv : TEXCOORD0;
            // };
            
            // v2f vert(a2v v)
            // {
            //     v2f o;
                
            //     float4 offset;
            //     offset.yzw = float3(0.0, 0.0, 0.0);
            //     offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
            //     o.pos = TransformObjectToHClip(v.vertex + offset);
                
            //     o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
            //     o.uv += float2(0.0, _Time.y * _Speed);
                
            //     return o;
            // }
            
            // half4 frag(v2f i) : SV_Target
            // {
            //     half4 c = tex2D(_MainTex, i.uv);
            //     c.rgb *= _Color.rgb;
                
            //     return c;
            // }
            
            ENDHLSL
        }
        
        // 投影通道
        Pass
        {
            Tags
            {
				// 光照模式为投影，这个是 URP 提供的模式，专门用于投影
                "LightMode" = "ShadowCaster"
            }
            
            HLSLPROGRAM
            
            // #pragma vertex vert
            // #pragma fragment frag

            // #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			// #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
			// // #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShadowCasterPass.hlsl"
            // #include "../Common/ShaderUtils.hlsl"
            
            // float _Magnitude;
            // float _Frequency;
            // float _InvWaveLength;
            // float _Speed;
            
            // struct v2f
            // {
            //     float4 pos : SV_POSITION;
            // };

			// PackedVaryings vert(Attributes input)
			// {
			// 	Varyings output = (Varyings)0;
			// 	output = BuildVaryings(input);
			// 	PackedVaryings packedOutput = (PackedVaryings)0;
			// 	packedOutput = PackVaryings(output);
			// 	return packedOutput;
			// }
			
			// // half4 frag(PackedVaryings packedInput) : SV_TARGET
			// // {
			// // 	Varyings unpacked = UnpackVaryings(packedInput);
			// // 	UNITY_SETUP_INSTANCE_ID(unpacked);
			// // 	SurfaceDescription surfaceDescription = BuildSurfaceDescription(unpacked);
			
			// // 	#if defined(_ALPHATEST_ON)
			// // 		clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
			// // 	#endif
			
			// // 	#if defined(LOD_FADE_CROSSFADE) && USE_UNITY_CROSSFADE
			// // 		LODFadeCrossFade(unpacked.positionCS);
			// // 	#endif
			
			// // 	return 0;
			// // }
            
            // // v2f vert(appdata_base v)
            // // {
            // //     v2f o;
                
            // //     float4 offset;
            // //     offset.yzw = float3(0.0, 0.0, 0.0);
            // //     offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
            // //     v.vertex = v.vertex + offset;

            // //     o.pos = TransformObjectToHClip(v.vertex + offset);

            // //     // TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                
            // //     return o;
            // // }
            
            // half4 frag(v2f i) : SV_Target
            // {
            //     return 1;
            // }
            ENDHLSL
        }
    }
    FallBack "VertexLit"
}
