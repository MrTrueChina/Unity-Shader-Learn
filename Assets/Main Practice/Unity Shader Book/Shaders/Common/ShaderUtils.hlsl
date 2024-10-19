#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

/// 获取附加光源产生的光照颜色，所有能够产生影响的附加光源都会计算在内
/// @param worldSpacePosition 世界空间位置
/// @param worldSpaceNormal 世界空间法线
/// @return 光照颜色
half3 GetAdditionalLighting(float3 worldSpacePosition, half3 worldSpaceNormal)
{
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        // 附加光源为逐顶点模式，使用 URP 内置的方法处理
        return VertexLighting(worldSpacePosition, worldSpaceNormal);
    #elif defined(_ADDITIONAL_LIGHTS)
        // 附加光源为逐像素模式

        half3 additionalLighting = (0, 0, 0);

        // 这里是一个普通的遍历，但是用了 LIGHT_LOOP_BEGIN 这个 define，就是 URP 提供的获取附加光源的循环的前半段代码
        uint lightsCount = GetAdditionalLightsCount();
        LIGHT_LOOP_BEGIN(lightsCount)
        Light light = GetAdditionalLight(lightIndex, worldSpacePosition);
        
        #ifdef _LIGHT_LAYERS
            // 如果启用了渲染层则添加一个渲染层的判断，括号不需要包含在 #if 里面，多一对括号不影响运行
            uint meshRenderingLayers = GetMeshRenderingLayer();
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
        {
            half3 lightColor = light.color * light.distanceAttenuation;
            additionalLighting += LightingLambert(lightColor, light.direction, worldSpaceNormal);
        }

        // 这也是个 define，是 URP 提供的获取附加光源的循环的后半段代码
        LIGHT_LOOP_END

        return additionalLighting;
    #else
        // 附加光源被禁用了，直接返回纯黑
        return (0, 0, 0);
    #endif
}

/// 获取附加光源产生的高光颜色，所有能够产生影响的附加光源都会计算在内，但是不包含附加光源产生的阴影
/// @param worldSpacePosition 世界空间位置
/// @param worldSpaceNormal 世界空间法线
/// @param specular 高光颜色
/// @param gloss 高光集中程度
/// @return 高光颜色
half3 GetAdditionalSpecularColor(float3 worldSpacePosition, half3 worldSpaceNormal, half4 specular, float gloss)
{
    #if defined(_ADDITIONAL_LIGHTS_VERTEX) || defined(_ADDITIONAL_LIGHTS)
        // 附加光源开启，进行逻辑处理

        half3 additionalSpecular = (0, 0, 0);

        // 这里是一个普通的遍历，但是用了 LIGHT_LOOP_BEGIN 这个 define，就是 URP 提供的获取附加光源的循环的前半段代码
        uint lightsCount = GetAdditionalLightsCount();
        LIGHT_LOOP_BEGIN(lightsCount)
        Light light = GetAdditionalLight(lightIndex, worldSpacePosition);
        
        #ifdef _LIGHT_LAYERS
            // 如果启用了渲染层则添加一个渲染层的判断，括号不需要包含在 #if 里面，多一对括号不影响运行
            uint meshRenderingLayers = GetMeshRenderingLayer();
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
        {
            half3 lightColor = light.color * light.distanceAttenuation;
            additionalSpecular += LightingSpecular(lightColor, light.direction, worldSpaceNormal, GetWorldSpaceViewDir(worldSpacePosition), specular, gloss);
        }

        // 这也是个 define，是 URP 提供的获取附加光源的循环的后半段代码
        LIGHT_LOOP_END

        return additionalSpecular;
    #else
        // 附加光源被禁用了，直接返回纯黑
        return (0, 0, 0);
    #endif
}

/// 【弃用】这段代码有 bug，没有考虑光衰减问题
/// 计算漫反射亮度
/// @param normal 法线
/// @param lightDirection 光线方向
/// @return 漫反射亮度
half GetDiffuseBrightness(half3 normal, half3 lightDirection)
{
    // 简单的点积，当向量垂直后点积就从 0 逐渐变为负数，正好可以计算光照受到角度影响的效果
    return max(0, dot(normal, lightDirection));
}

/// 计算漫反射颜色
/// @param color 物体本身的漫反射颜色
/// @param normal 法线
/// @param lightDirection 光线方向
/// @return 漫反射颜色
half3 GetDiffuseColor(half3 color, half3 normal, half3 lightDirection)
{
    // 简单的点积，当向量垂直后点积就从 0 逐渐变为负数，正好可以计算光照受到角度影响的效果
    return color.rgb * GetDiffuseBrightness(normal, lightDirection);
}

/// 获取高光颜色，Blinn-Phong 模型
/// @param lightDirection 光线方向
/// @param normal 法线
/// @param viewDirection 视线方向
/// @param specularColor 高光颜色
/// @param lightColor 光线颜色
/// @param gloss 高光集中程度
/// @return 高光颜色
half3 GetSpecualrColorBlinnPhong(half3 lightDirection, half3 normal, half3 viewDirection, half3 specularColor, half3 lightColor, half gloss)
{
    // Blinn-Phong 模型的高光计算，用视线和光线的中间方向和法线进行计算
    // 比起传统 Blinn 模型的优点是不用计算反射，效率上一般会更好一些
    // 因为 Blinn 模型也是经验模型，大部分情况下两个模型视觉效果不同但都 “看上去对”
    half3 halfDir = normalize(lightDirection + viewDirection);
    return lightColor.rgb * specularColor.rgb * pow(max(dot(normal, halfDir), 0.0), gloss);
}

/// 使用物体空间的向量创建世界空间到切线空间的向量转换矩阵
/// @param objectSpaceNormal 物体空间法线
/// @param objectSpaceTangent 物体空间切线
/// @return 世界空间到切线空间的转换矩阵
float3x3 CreateTangentToWorldByObject(half3 objectSpaceNormal, half4 objectSpaceTangent)
{
    // 具体的算法需要一些几何功底才能理解，你要是功底不够就别管细节直接用，不影响
    return CreateTangentToWorld(TransformObjectToWorldNormal(objectSpaceNormal), TransformObjectToWorldDir(objectSpaceTangent.xyz), objectSpaceTangent.w);
}

/// 使用物体空间的向量创建物体空间到切线空间的向量转换矩阵
/// @param objectSpaceNormal 物体空间法线
/// @param objectSpaceTangent 物体空间切线
/// @return 物体空间到切线空间的转换矩阵
float3x3 CreateObjectToTangent(half3 objectSpaceNormal, half4 objectSpaceTangent)
{
    // 具体的算法需要一些几何功底才能理解，你要是功底不够就别管细节直接用，不影响
    float3 binormal = cross(normalize(objectSpaceNormal), normalize(objectSpaceTangent.xyz)) * objectSpaceTangent.w;
    return float3x3(objectSpaceTangent.xyz, binormal, objectSpaceNormal);
}

/// 解包切线空间法线贴图并返回法线，能够进行不准确的法线强度调整【注意】如果可以获取到不需要调整的法线贴图请尽可能直接使用 UnpackNormal
/// @param normalMap 法线贴图
/// @param uv 贴图坐标
/// @param scale 法线强度调整
half3 UnpackTangentSpaceNormal(sampler2D normalMap, float2 uv, float scale)
{
    // 先取出并解包，法线是需要解包的，具体的 U3D 帮我们做了
    half3 tangentNormal = UnpackNormal(tex2D(normalMap, uv));
    // 调整法线强度，如果发现足够可靠可以不要这一步，省一些计算量
    tangentNormal.xy *= scale;
    // 根据 xy 轴法线算出 z 轴，这个算法只能保证法线不小于 1，一旦 xy 轴调整强度后的绝对值超过了 1 就会有计算误差，所以非常不推荐在 U3D 环节调整法线强度
    tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
    // 最后归一化一下，实际上属于一种找补，如果上面的计算强度没出问题的话则自然归一，如果强度出了问题的话……都出问题了还用这套法线图？让美术出一张没问题不用调的啊！
    return normalize(tangentNormal);
}

/// Unity 生成的抖动方法，有一些修改
/// @param In 输入值
/// @param ScreenPosition 屏幕坐标
/// @return 抖动值
float UnityDitherFloat(float In, float2 ScreenPosition)
{
    float2 uv = ScreenPosition.xy * _ScreenParams.xy;
    float DITHER_THRESHOLDS[16] =
    {
        1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
        13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
        4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
        16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
    };
    uint index = (uint(uv.x) % 4) * 4 + uint(uv.y) % 4;
    return In - DITHER_THRESHOLDS[index];
}

/// 计算亮度
/// @param color 颜色
/// @return 亮度
half Luminance(half3 color) {
    // 这个公式是 ITU-R Recommendation BT.709. 标准，是根据人眼对颜色的感知能力制定的
    return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b; 
}
