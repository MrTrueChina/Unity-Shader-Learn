// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 着色器整体
Shader "Unity Shaders Book/Chapter 5/False Color" {

	// 子着色器，着色器本身不进行着色处理，着色处理由子着色器进行。但着色器整体可以进行子着色器的选择，这样有助于在不同硬件情况下使用不同的着色方案
	// 正常情况下一个完整的着色器至少需要有一个子着色器
	SubShader {

		// 通道，需要注意这个通道不是指 RGB 的那个通道，可以把通道理解为步骤
		// 每个通道代表着一个渲染步骤，一个子着色器可以有多个通道，他们会按照代码从前到后的顺序依次渲染
		// 正常情况下一个子着色器至少有一个通道
		Pass {
			CGPROGRAM
			
			// 指定顶点着色器函数，就是下面的 vert
			#pragma vertex vert
			// 指定片元着色器函数，就是下面的 frag，片元着色器就是像素着色器
			#pragma fragment frag
			
			// 显然是导包
			#include "UnityCG.cginc"
			
			// 结构体，意思似乎是 vertex to fragment，就是一个 DTO
			struct v2f {
				// SV_POSITON 是 HLSL 的内置变量，可以理解为顶点位置
				float4 pos : SV_POSITION;
				// 
				fixed4 color : COLOR0;
			};
			
			// 上面指定的顶点着色器，对于一个三角面，理论上会运行三次顶点着色器
			v2f vert(appdata_full v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 将法线输出为颜色
				o.color = fixed4(v.normal * 0.5 + fixed3(0.5, 0.5, 0.5), 1.0);
				
				// // Visualize tangent
				// o.color = fixed4(v.tangent.xyz * 0.5 + fixed3(0.5, 0.5, 0.5), 1.0);
				
				// // Visualize binormal
				// fixed3 binormal = cross(v.normal, v.tangent.xyz) * v.tangent.w;
				// o.color = fixed4(binormal * 0.5 + fixed3(0.5, 0.5, 0.5), 1.0);
				
				// // Visualize the first set texcoord
				// o.color = fixed4(v.texcoord.xy, 0.0, 1.0);
				
				// // Visualize the second set texcoord
				// o.color = fixed4(v.texcoord1.xy, 0.0, 1.0);
				
				// // Visualize fractional part of the first set texcoord
				// o.color = frac(v.texcoord);
				// if (any(saturate(v.texcoord) - v.texcoord)) {
				// 	o.color.b = 0.5;
				// }
				// o.color.a = 1.0;
				
				// // Visualize fractional part of the second set texcoord
				// o.color = frac(v.texcoord1);
				// if (any(saturate(v.texcoord1) - v.texcoord1)) {
				// 	o.color.b = 0.5;
				// }
				// o.color.a = 1.0;
				
				return o;
			}
			
			// 上面指定的片元着色器，需要注意的是对于一个三角面理论上有多少像素就会运行几次片元着色器，所以片元着色器的运算量应该尽量减少，尽可能把运算量交由顶点着色器进行
			fixed4 frag(v2f i) : SV_Target {
				// 只返回了一个颜色
				return i.color;
			}
			
			ENDCG
		}
	}
}
