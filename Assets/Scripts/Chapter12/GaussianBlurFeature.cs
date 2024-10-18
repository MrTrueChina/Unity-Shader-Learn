using UnityEngine;
using System.Collections;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using System;

/**
    【注意】
    这个自定义渲染功能只给了 HighFidelity 和 Balanced 两个等级，Performant 没给
    这是为了给 URP 的功能做个样例，具体来说是这样的：
    
    URP 的渲染模式的大单位是管线，一个管线就是一种渲染模式，可以理解为整体模式
    管线本身包含了一部分的设置，如光照、阴影、HDR、深度缓冲位数、后处理质量等
    
    但是管线本身不负责渲染，渲染是靠管线中的渲染器进行的，渲染器是管线内的小单位
    一个管线可以有多个渲染器，一个渲染器也可以给多个管线使用，一个管线也可以存储一个渲染器多次，但无论如何对于一次渲染只有一个渲染器来执行（但每一帧不一定只渲染一次，比如可以有两个摄像机这就至少渲染了两次）
    
    每个摄像机使用一个渲染器，这个渲染器是当前管线中的渲染器，非常重要的一点是摄像机具体使用哪个渲染器是根据索引来的
    也就是说如果摄像机使用了高质量管线的二号渲染器，但是此时切到了中质量管线而且中质量管线只有一个零号渲染器，此时这个摄像机因为找不到这个索引的渲染器就会使用默认渲染器
    但如果中质量管线有二号渲染器，哪怕跟高质量的二号渲染器毫不相干，摄像机也会去用二号渲染器，只看索引别的什么都不看
    这可以帮助实现一些很好的功能，例如有一个摄像机要在不同的管线里提供一样的效果就可以在不同管线的同一个索引里用同一个渲染器，如果想要它在不同管线里效果不同的话则可以在相同索引使用不同的渲染器

    由此可以得到一个实现方案：
    对于主摄像机直接使用默认渲染器
    对于副摄像机使用其他索引的渲染器（比如监控视频的那种摄像机就可以用低消耗的渲染器，只渲染一些必要的内容不带后期处理）
    对于每个管线，它们的相同索引的渲染器需要是相同的用途，具体质量可以有所不同
*/

/// <summary>
/// 高斯模糊渲染功能的参数
/// </summary>
[Serializable]
public class GaussianBlurFeatureParams
{
	/// <summary>
	/// 卷积核体积
	/// </summary>
    [Header("卷积核体积")]
    [Tooltip("即一个像素会和多大范围内的其他像素进行颜色混合，这个值越大则模糊范围越大，但相应的性能消耗也会更大")]
	[Range(0.0f, 10.0f)]
	public float kernelSize = 1.0f;
	/// <summary>
	/// 方差
	/// </summary>
    [Header("方差")]
    [Tooltip("一个像素会多大程度受到偏远的像素的影响，方差越小则受到远处像素影响程度越小，视觉上模糊效果就越小")]
	[Range(0.0f, 10.0f)]
	public float standardDeviation = 3.0f;
}

/// <summary>
/// 控制高斯模糊显示的后处理效果
/// 这个自定义效果替换了《入门精要》里的后处理部分的挂载到摄像机上的组件
/// 需要按照 URP 的方式在渲染器数据的资源文件里添加这个功能
/// </summary>
public class GaussianBlurFeature : ScriptableRendererFeature
{
    /// <summary>
    /// 参数
    /// </summary>
    public GaussianBlurFeatureParams edgeParams;

    /// <summary>
    /// 这个渲染效果所使用的渲染通道
    /// </summary>
    private GaussianBlurPass pass;

    public override void Create()
    {
        pass = new GaussianBlurPass(edgeParams);
        
        // 设定注入点，这里选择了在后期处理之后生效
        // 实际上这个功能自己就是后处理，所以在前面在后面取决于想不想让别的后处理影响到这个后处理
        // 为了不被干扰更好地看到效果就放到后头去了
        pass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // 根据摄像机类型注入，这里给游戏摄像机和场景视图注入，没有注入 VR 和其他的一些类型
        // 此外这里支持给预览界面注入，就是点击一个预制后在 inspector 界面下面会出现的那个预览窗口，但这个渲染功能计划上是后处理，可能干扰预览，不注入到预览界面摄像机
        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.isSceneViewCamera)
        {
            // 注入通道
            renderer.EnqueuePass(pass);
        }
    }

    /// <summary>
    /// 释放方法，或者你要是愿意也可以叫析构函数，反正他的大名叫 Dispose
    /// </summary>
    /// <param name="disposing"></param>
    protected override void Dispose(bool disposing)
    {
    }
}

/// <summary>
/// 控制高斯模糊显示的后处理效果使用的自定义通道
/// </summary>
public class GaussianBlurPass : ScriptableRenderPass, IDisposable
{
    /// <summary>
    /// 参数
    /// </summary>
    [Header("参数")]
    public GaussianBlurFeatureParams edgeParams;

	/// <summary>
	/// 材质，后处理本质是一次渲染，要进行渲染就需要有材质
	/// </summary>
	private Material material;
    /// <summary>
    /// 渲染图片描述符，用于指定管线输入给这个通道的图片的详细要求，用于实现类似 BiRP 的 GrabPass 的功能
    /// </summary>
    private RenderTextureDescriptor textureDescriptor;
    /// <summary>
    /// 渲染图片数据，作为中转存在
    /// </summary>
    private RTHandle textureHandle;

	/// <summary>
	/// 构造方法，并不是什么特别的方法
	/// </summary>
	public GaussianBlurPass(GaussianBlurFeatureParams edgeParams)
	{
        // 只是一个 log，确认了一下对于 URP 每次修改功能里的设置都会导致重新构造一次 Pass，所以传参用传值还是传对象都不影响生效
        // 这个构造不是传对象就能避免的，甚至就算你修改的参数实际上是个不会传进 Pass 的参数都会导致构造
        // Debug.Log("亮度等自定义渲染功能的通道构造了");

		// 这个通道也就只负责使用这个 Shader，可以直接固定用名字获取 Shader 创建材质
		material = CoreUtils.CreateEngineMaterial("Unity Shaders Book/Chapter 12/My Gaussian Blur");

        // 保存参数
        this.edgeParams = edgeParams;

        // 创建一个渲染图片输出器
        // 宽高是屏幕宽高，就是全屏输出
        // 默认颜色格式，这个模式是根据平台变化的，但是它不支持 HDR，也有支持 HDR 的默认颜色格式，但在现在这个教程里先不用
        // 深度缓冲区的位数为 0，即不要深度缓冲区信息
        textureDescriptor = new RenderTextureDescriptor(Screen.width, Screen.height, RenderTextureFormat.Default, 0);
	}

    /// <summary>
    /// 配置方法，这个方法会在这个通道正式调用前调用，这个方法不是必须覆写的，根据需要覆写
    /// </summary>
    /// <param name="cmd"></param>
    /// <param name="cameraTextureDescriptor"></param>
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        // 设置图片输出的宽高为摄像机的宽高
        textureDescriptor.width = cameraTextureDescriptor.width;
        textureDescriptor.height = cameraTextureDescriptor.height;

        // 在必要的时候创建一个 RTHandle
        // 按照文档所述如果没有 RTHandle 或者 RTHandle 发生了需要重新创建的变化则会创建新的 RTHandle
        // 总是会传递 RTHandle 给 ref 参数
        RenderingUtils.ReAllocateIfNeeded(ref textureHandle, textureDescriptor);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // 从命令缓冲池里取出命令缓冲
        // 可以理解为这个命令只要执行了流程就会继续走，我们先做自定义的处理，做完后执行这个命令让渲染继续
        CommandBuffer cmd = CommandBufferPool.Get();

        // 取出摄像机的渲染图片
        RTHandle cameraTargetHandle = renderingData.cameraData.renderer.cameraColorTargetHandle;

        // 给材质设置各项属性值，就是普通的给材质球设置属性值的方式
        material.SetFloat("_KernelSize", edgeParams.kernelSize);
        material.SetFloat("_StandardDeviation", edgeParams.standardDeviation);

        // 将摄像机的图片，使用指定材质的 0 号通道，渲染到中转图片
        // 在 Shader 里这个 0 号通道是后处理通道，输出处理后的纹理
        // Blit 是一个计算机图形学的词，他指的是从一个图片快速渲染到另一个图片的操作
        Blit(cmd, cameraTargetHandle, textureHandle, material, 0);
        // 将中转图片，使用指定材质的 1 号通道，渲染到摄像机的图片
        // 在 Shader 里这个 1 号通道是直接输出颜色
        // 这一步操作对画面没有任何修改，保留这一步操作的原因是 Blit 的源和目标使用相同纹理是一个未定义操作，会导致不确定的错误，为了防止这个情况就需要分两步来添加一个中转纹理
        Blit(cmd, textureHandle, cameraTargetHandle, material, 1);

        // 执行命令，然后释放掉
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Dispose()
    {
		// 销毁材质
		CoreUtils.Destroy(material);
    }
}
