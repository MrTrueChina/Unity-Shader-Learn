// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 8/Alpha Test"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" { }
        _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags
		{
			"Queue" = "AlphaTest"
			"IgnoreProjector" = "True"
			"RenderType" = "TransparentCutout"
        }
        
        Pass
        {
			Tags
			{
				// 光照模式为 URP前向渲染路径（这个光照模式可以在 URP 允许范围内接收尽可能多的光源）
				"LightMode" = "UniversalForward"
			}
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
            
            half4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            half _Cutoff;
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };
            
            v2f vert(a2v v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                
                o.worldPos = TransformObjectToWorld(v.vertex).xyz;
                
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                // 获取主光源
                Light mainLight = GetMainLight();

                half3 worldNormal = normalize(i.worldNormal);
                half3 worldLightDir = mainLight.direction;
                
                half4 texColor = tex2D(_MainTex, i.uv);
                
                // Alpha test
                clip(texColor.a - _Cutoff);
                
                half3 albedo = texColor.rgb * _Color.rgb;
                
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                
                half3 diffuse = mainLight.color.rgb * albedo * max(0, dot(worldNormal, worldLightDir));
                
                return half4(ambient + diffuse, 1.0);
            }
            
            ENDHLSL
		}
	} 
	FallBack "Transparent/Cutout/VertexLit"
}
