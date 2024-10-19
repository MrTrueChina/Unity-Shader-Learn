// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 7/Normal Map In Tangent Space" {
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" { }
        _BumpMap ("Normal Map", 2D) = "bump" { }
        _BumpScale ("Bump Scale", Float) = 1.0
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
	SubShader {
		Pass { 
            Tags
            {
                // 使用通用渲染管线（URP）
                "RenderPipeline" = "UniversalPipeline"
                // 渲染类型为不透明
                "RenderType" = "Opaque"
                // 光照模式为 URP前向渲染路径（这个光照模式可以在 URP 允许范围内接收尽可能多的光源）
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            half4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _BumpScale;
            half4 _Specular;
            float _Gloss;
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT; // TANGENT 语义，获取切线
                float4 texcoord : TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                // 两个图的 UV 合并在一个 TEXCOORD 里发送，TEXCOORD 是有限的，不同平台有不同的支持，节约一些
                float4 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };


            v2f vert(a2v v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                
                // 用内置方法处理一下 UV 变化，点进去就能看到效果很简单
                // 不过里面的名字有拼接，命名要求每个图片必须有一个 _ST 配对的价值就出现了
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
                // PS: 这里可以尝试将 _BumpMap 换成 _MainTex，这样纹理图的 ST 就能同时控制两个图，可以提升代码理解
                // 但是我个人不太推荐这种方式，因为从设计上说一个模型的贴图应该在交付开发人员时就正确适配了，模型基础信息的调整应该尽可能放在美术层面，这样修改时只要美术修改即可不需要多方配合
                // 当然在 Shader 这种技美内容里聊美术和开发的职责划分确实有点怪，但是美术、技美、开发还是要各自尽可能独立解决根源在自己的工作，合作的前提是互不干扰而不是一个人动全组都改

                // 创建了一个从世界空间到切线空间的转换矩阵
                // 整个逻辑是固定的，需要一些几何功底才能理解，你要是功底不够就别管细节直接用，不影响
                half3 worldNormal = TransformObjectToWorldNormal(v.normal);
                half3 worldTangent = TransformObjectToWorldDir(v.tangent.xyz);
                float3x3 worldToTangent = CreateTangentToWorld(worldNormal, worldTangent, v.tangent.w);

                // 获取主光源
                Light light = GetMainLight();

                // 将视线和光线都转到切线空间去
                o.lightDir = TransformWorldToTangent(light.direction, worldToTangent);
                // 经典套娃，从世界空间转到切线空间(获取世界空间里看向某个位置的方向(把物体空间转到世界空间(顶点自己的坐标)))
                o.viewDir = TransformWorldToTangent(GetWorldSpaceNormalizeViewDir(TransformObjectToWorld(v.vertex.xyz)), worldToTangent);

                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                // 获取主光源
                Light light = GetMainLight();
                
                // 取出这个片元对应的法线贴图数据
                half4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                // 解包，这一步 U3D 替我们解决了
                half3 tangentNormal = UnpackNormal(packedNormal);
                // xy 轴进行缩放，这两个轴对应的是法线在水平和垂直方向的偏移量
                tangentNormal.xy *= _BumpScale;
                // 根据 xy 轴计算 z 轴，在这个计算里如果 xy 轴的缩放没有超出 -1~1 这个范围的话则这个法线的模就是 1
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

                // 归一化，这个是原版代码没有的，原版代码似乎假定发现强度在 -1~1 之间，对超出的情况没有处理
                tangentNormal = normalize(tangentNormal);
                
                // 计算贴图的漫反射
                half3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
                
                // 环境光
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                
                // 漫反射
                half3 diffuse = light.color.rgb * albedo * max(0, dot(tangentNormal, i.lightDir));

                // 高光
                half3 halfDir = normalize(i.lightDir + i.viewDir);
                half3 specular = light.color.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);
                
                return half4(ambient + diffuse + specular, 1.0);
            }
            
            ENDHLSL
        }
    }
    FallBack "Specular"
}
