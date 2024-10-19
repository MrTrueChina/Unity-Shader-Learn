// 只加载一次的写法，没有加载记录时才加载，加载立刻写加载记录
#ifndef SOBELOUTLINES_INCLUDED
#define SOBELOUTLINES_INCLUDED

/// Sobel 边缘检测
///
/// 使用 Sobel 算子进行边缘检测
/// Sobel 算子是如下的矩阵
/// -1 0 1
/// -2 0 2
/// -1 0 1
///
/// 其原理是卷积运算，以深度检测为例：
///
/// 假设一个监测点和周围的深度都是 0.5，则卷积结果是
/// (-0.5 + 0 + 0.5) + (-1 + 0 + 1) + (-0.5 + 0 + 0.5) = 0
///
/// 而如果一个监测点左侧深度是 1，右侧深度是 0，则卷积结果是
/// (-1 + 0 + 0) + (-2 + 0 + 0) + (-1 + 0 + 0) = -4
///
/// 由此可以发现这个算子计算后的绝对值越大则两侧的数值差越大
/// 因此这个算子可以用于计算横向的数值突变，而一般来说连续的面上数值不会产生太大的突变，而不连续的边缘则容易产生数值突变，由此就实现了边缘检测
///
/// 当然边缘检测不是只有水平方向，因此还需要一个旋转 90 度的矩阵作为垂直方向的算子
/// 而如果将两个算子以绝对值叠加就会发现周围八个点的值都是 2，这样就避免了各方向权重不均匀，因此这个矩阵是 1-2-1 而不是 1-1-1 或 2-2-2


// Sobel 边缘检测的监测点的坐标偏移量数组，相对于监测点
// 实际上就是以监测点为中心往外扩增一圈形成九宫格
static float2 sobelSimplePoints[9] = {
    float2(-1, 1), float2(0, 1), float2(1, 1),
    float2(-1, 0), float2(0, 0), float2(1, 0),
    float2(-1, -1), float2(0, -1), float2(1, -1)
};

// Sobel 边缘检测的X方向的算子
static float sobelXMatrix[9] = {
    -1, 0, 1,
    -2, 0, 2,
    -1, 0, 1
};

// Sobel 边缘检测的Y方向的算子
static float sobelYMatrix[9] = {
    1, 2, 1,
    0, 0, 0,
    -1, -2, -1
};

/// 使用 Sobel 算子的深度检测
void DepthSobel_float(float2 UV, float Thickness, out float Out) {
    float2 sobel = 0;

    [unroll] // 这个注解的意思是展开循环，这会让编译器在生成时把这个循环视为写了九遍的代码而不是一个九次的循环，这样可以省下循环本身消耗的一点点计算量
    for(int i = 0; i < 9; i++){
        // 卷积的一步，原理是取出这一步的 UV 偏移量乘上步长得到这个采样点在深度图上的 UV，然后使用 URP 提供的宏取出这个位置的深度
        float depth = SHADERGRAPH_SAMPLE_SCENE_DEPTH(UV + sobelSimplePoints[i] * Thickness);
        // 确认深度后一次对两个算子矩阵进行运算，分别存入到 float2 的两个值里
        sobel += depth * float2(sobelXMatrix[i], sobelYMatrix[i]);
    }

    // 因为卷积把 XY 两个轴的检测一起存起来了，这里可以直接取向量长度，长度不会是负数能省下来取绝对值的计算量
    // 但是相对的，取长度本身的计算量也不低
    Out = length(sobel);
}

/// 使用 Sobel 算子的颜色检测
void ColorSobel_float(float2 UV, float Thickness, out float Out) {
    float2 sobelR = 0;
    float2 sobelG = 0;
    float2 sobelB = 0;

    [unroll] // 展开循环，虽然循环本身占用的计算量比起算法本身只有很小一点，但加一个注解不费力顺带能省则省了
    for(int i = 0; i < 9; i++){
        // 取出颜色
        // SHADERGRAPH_SAMPLE_SCENE_COLOR 这个方法有问题，他只有在 Shader Graph 中使用了 SceneColor 节点并且最终指向了颜色输出时才有效
        float3 rgb = SHADERGRAPH_SAMPLE_SCENE_COLOR(UV + sobelSimplePoints[i] * Thickness);

        // 卷积核，就是两个算子拼一起，因为颜色检测对 RGB 三色各进行一次检测，卷积核提前计算好存下来要比每次都临时计算节约计算量
        float2 kernel = float2(sobelXMatrix[i], sobelYMatrix[i]);

        // 对三个颜色分别计算
        sobelR += rgb.r * kernel;
        sobelG += rgb.g * kernel;
        sobelB += rgb.b * kernel;
    }

    // 取三个颜色中计算结果最大的那个，三原色任何一个产生巨大变化都会导致明显的视觉差异，直接取最大的而不是总和，这样还能降低输出的范围防止范围过大加大精细调整时的难度
    Out = max(length(sobelR), max(length(sobelG), length(sobelB)));
}

/// 使用 Sobel 算子的亮度检测
void LuminanceSobel_float(float2 UV, float Thickness, out float Out) {
    float2 sobel = 0;

    [unroll] // 展开循环，虽然循环本身占用的计算量比起算法本身只有很小一点，但加一个注解不费力顺带能省则省了
    for(int i = 0; i < 9; i++){
        // 取出颜色
        float3 rgb = SHADERGRAPH_SAMPLE_SCENE_COLOR(UV + sobelSimplePoints[i] * Thickness);

        // 卷积核，就是两个算子拼一起，因为颜色检测对 RGB 三色各进行一次检测，卷积核提前计算好存下来要比每次都临时计算节约计算量
        float luminance = Luminance(rgb);

        // 对三个颜色分别计算
        sobel += luminance * float2(sobelXMatrix[i], sobelYMatrix[i]);
    }

    // 取三个颜色中计算结果最大的那个，三原色任何一个产生巨大变化都会导致明显的视觉差异，直接取最大的而不是总和，这样还能降低输出的范围防止范围过大加大精细调整时的难度
    Out = length(sobel);
}

#endif