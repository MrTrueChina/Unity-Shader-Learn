// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 7/Mask Texture"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" { }
        [NoScaleOffset] _BumpMap ("Normal Map", 2D) = "bump" { } // UV 以主纹理为主，不显示调整缩放偏移的 UI
        _BumpScale ("Bump Scale", Float) = 1.0
        [NoScaleOffset] _SpecularMask ("Specular Mask", 2D) = "white" { } // UV 以主纹理为主，不显示调整缩放偏移的 UI
        _SpecularScale ("Specular Scale", Float) = 1.0
        _Specular ("Specular", Color) = (1, 1, 1, 1)
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
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
            
            half4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float _BumpScale;
            sampler2D _SpecularMask;
            float _SpecularScale;
            half4 _Specular;
            float _Gloss;
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };

            
            v2f vert(a2v v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                
                // o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                
                float3x3 tangentToWorld = CreateTangentToWorldByObject(v.normal, v.tangent);

                // 获取主光源
                Light mainLight = GetMainLight();

                o.lightDir = TransformWorldToTangentDir(mainLight.direction, tangentToWorld);
                o.viewDir = TransformWorldToTangentDir(GetWorldSpaceNormalizeViewDir(TransformObjectToWorld(v.vertex)), tangentToWorld);
                
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                half3 tangentLightDir = normalize(i.lightDir);
                half3 tangentViewDir = normalize(i.viewDir);

                // 获取主光源
                Light light = GetMainLight();

                // half3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uv));
                // tangentNormal.xy *= _BumpScale;
                // tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                half3 tangentNormal = UnpackTangentSpaceNormal(_BumpMap, i.uv, _BumpScale);

                half3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
                
                // 环境光
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                
                half3 diffuse = light.color.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));
                
                half3 halfDir = normalize(tangentLightDir + tangentViewDir);
                // Get the mask value
                half specularMask = tex2D(_SpecularMask, i.uv).r * _SpecularScale;
                // Compute specular term with the specular mask
                half3 specular = light.color.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss) * specularMask;
                
                return half4(ambient + diffuse + specular, 1.0);
            }
            
            ENDHLSL
        }
    }
    FallBack "Specular"
}
