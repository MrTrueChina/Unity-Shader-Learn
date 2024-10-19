// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 10/Glass Refraction"
{
    Properties
    {
        /// 主纹理
        _MainTex ("Main Tex", 2D) = "white" { }
        /// 法线贴图
        _BumpMap ("Normal Map", 2D) = "bump" { }
        /// 折射环境贴图
        _Cubemap ("Environment Cubemap", Cube) = "_Skybox" { }
        // 折射的折射率
        _Distortion ("Distortion", Range(0, 100)) = 10
        // 折射颜色占最终颜色的百分比
        _RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0
    }
    SubShader
    {
        // 由于 URP 的兼容性考虑，BiRP 的 GrabPass 被移除了，导致《入门精要》原版的这个 Shader 的代码基本完全报废
        // 这个 Shader 基本可以看做是一个全新的 Shader

        // 为了实现类似的效果使用了 _CameraOpaqueTexture，这要求在 Universal Render Pipeline Asset 里勾选 Opaque Texture 选项
        // 从更精细的角度控制实际上是在摄像机上的 Rendering -> Opaque Texture 设置，这里可以控制 启动/禁用/跟随渲染管线设置
        // 如果有需要的话可以进行精确控制，没有的话出于易于控制和修改的角度建议跟随渲染管线设置

        Tags
        {
            // 使用通用渲染管线（URP）
            "RenderPipeline" = "UniversalPipeline"
			// 不透明类型，折射虽然是一种透明效果但是它的原理是获得原始纹理处理后渲染，物体本身实际上是完全不透明的
			"RenderType" = "Opaque"
			// 透明队列，折射物体虽然实际上完全不透明，但是他的效果是透明的，需要在不透明物体渲染完毕后再渲染才能正常显示
			"Queue" = "Transparent"
        }
        
        // // BiRP 的 GrabPass，在 URP 里移除了，这段代码没用了
        // GrabPass
        // {
        //     "_RefractionTex"
        // }
        
        Pass
        {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "../Common/ShaderUtils.hlsl"
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            samplerCUBE _Cubemap;
            float _Distortion;
            half _RefractAmount;
            /// 摄像机渲染的不透明物体的渲染图
            sampler2D _CameraOpaqueTexture;
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord : TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;
            };
            
            v2f vert(a2v v)
            {
                v2f o;
                
                // 获取位置信息
                VertexPositionInputs positions = GetVertexPositionInputs(v.vertex.xyz);

                // 必须要有的裁剪空间坐标
                o.pos = positions.positionCS;
                
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);

                // 创建一个切线空间到世界空间转换的矩阵，Unity 给这个矩阵提供了一正一反两个方法，这两个方法的参数都是这个矩阵但是一个是切线空间转到世界空间一个是世界空间转到切线空间
                float3x3 tangentToWorld = CreateTangentToWorldByObject(v.normal, v.tangent);

                // 转换矩阵是 3x3，需要三个 TEXCOORD，正好世界空间坐标是 3 个数字可以分开存入到 TEXCOORD 的 W 轴
                // 这个写法很丑，但是能节约 TEXCOORD，为了兼容性最好不要超过 8 个，有些低端机只支持 4 个
                o.TtoW0 = float4(tangentToWorld[0].xyz, positions.positionWS.x);
                o.TtoW1 = float4(tangentToWorld[1].xyz, positions.positionWS.y);
                o.TtoW2 = float4(tangentToWorld[2].xyz, positions.positionWS.z);
                
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                // // 测试输出：直接输出屏幕空间的值
                // // 测试结果：
                // // z 是距离摄像机的距离，摄像机越远则 z 越大
                // // xy 是在屏幕上的上下左右位置，总是以屏幕中间为 0，但是摄像机越远值的范围越大
                // // w 作用不明，根据说明是透视校正值，摄像机越远 w 越大
                // return half4(i.pos.z,i.pos.z,i.pos.z, 1) * 1;
                // return half4(i.pos.xyz, 1) * 0.1;

                // // 测试输出：直接输出屏幕宽高
                // // 测试结果：毫无疑问屏幕宽高就是像素数
                // return half4(_ScreenSize.xy, 0, 1) / 1000;

                // 把世界空间和矩阵重新拼出来
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                float3x3 tangentToWorld = float3x3(i.TtoW0.xyz, i.TtoW1.xyz, i.TtoW2.xyz);

                
                // 解包法线
                half3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
                
                // 计算折射，这是一个既不经验也不模拟的算法，但是他又简单又快看起来还很像是对的
                // 用法线的 xy 轴和偏移量计算一个偏移量，然后乘上屏幕宽高来对应上 URP 的 _CameraOpaqueTexture 的分辨率
                float2 offset = bump.xy * _Distortion * _ScreenSize.xy;
                // 将偏移量加到位置的 xy 轴上，这里乘以 z 轴，z 轴是深度，也就是物体到摄像机的距离，这样可以让各个距离的折射效果都看起来正确
                // 这里的坐标就是裁剪空间坐标，裁剪空间 = 齐次空间 = 屏幕空间
                // 【注意】书中原版单独使用了一个叫 scrPos 的变量来传递屏幕空间，但这在 URP 里是不可以的，URP 中想要正确传递这个空间信息必须是 SV_POSITION 语义，这个语义必须有且只能有一个
                i.pos.xy = offset * i.pos.z + i.pos.xy;
                // 再读取摄像机渲染的不透明图片的颜色，这里用了 _ScreenSize.zw，zw 是 1/xy，就是用来将屏幕分辨率转到 0-1 的 UV 范围的
                half3 refrCol = tex2D(_CameraOpaqueTexture, i.pos.xy * _ScreenSize.zw).rgb;


                
                // 计算反光
                // Unity 提供的这个方法默认是不归一化的，推测是因为矩阵是单位的、切线空间法线是归一的所以不用归一化
                bump = TransformTangentToWorld(bump, tangentToWorld);
                // 世界空间的视线
                half3 worldViewDir = GetWorldSpaceViewDir(worldPos);
                half3 reflDir = reflect(-worldViewDir, bump);
                half4 texColor = tex2D(_MainTex, i.uv.xy);
                half3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb;
                
                half3 finalColor = reflCol * (1 - _RefractAmount) + refrCol * _RefractAmount;
                
                return half4(finalColor, 1);
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Diffuse"
}
