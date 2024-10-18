using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// 红色调自定义通道
/// </summary>
public class RedTintRenderPass : ScriptableRenderPass
{
    /// <summary>
    /// 材质
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
    /// 构造方法，不是什么特别的内部功能指定的方法
    /// </summary>
    /// <param name="material"></param>
    public RedTintRenderPass(Material material)
    {
        this.material = material;

        // 创建一个渲染图片输出器
        // 宽高是屏幕宽高，就是全屏输出
        // 默认颜色格式，这个模式是根据平台变化的，但是它不支持 HDR，也有支持 HDR 的默认颜色格式，但对于这个红色调通道来说没必要
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

    /// <summary>
    /// 执行方法，真正的运行 Pass 进行渲染
    /// </summary>
    /// <param name="context"></param>
    /// <param name="renderingData"></param>
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // 从命令缓冲池里取出命令缓冲
        // 可以理解为这个命令只要执行了流程就会继续走，我们先做自定义的处理，做完后执行这个命令让渲染继续
        CommandBuffer cmd = CommandBufferPool.Get();

        // 取出摄像机的渲染图片
        RTHandle cameraTargetHandle = renderingData.cameraData.renderer.cameraColorTargetHandle;

        // 将摄像机的图片，使用指定材质的 0 号通道，渲染到中转图片
        // 在 Shader 里这个 0 号通道是调色后输出颜色
        // Blit 是一个计算机图形学的词，他指的是从一个图片快速渲染到另一个图片的操作
        Blit(cmd, cameraTargetHandle, textureHandle, material, 0);
        // 将中转图片，使用指定材质的 1 号通道，渲染到摄像机的图片
        // 在 Shader 里这个 1 号通道是直接输出颜色
        Blit(cmd, textureHandle, cameraTargetHandle, material, 1);

        // 上面的逻辑里一定得有一张中转图片，按照 Unity 官方文档的说法 Blit 的源和输出使用同一张图片是未定义行为，这种操作可能导致错误

        // 执行命令，然后释放掉
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Dispose()
    {
    #if UNITY_EDITOR
        // 在编辑器里
        if (EditorApplication.isPlaying)
        {
            // 在游戏中，用普通销毁
            Object.Destroy(material);
        }
        else
        {
            // 没有在游戏中，用立即销毁
            Object.DestroyImmediate(material);
        }
    #else
        // 不是编辑器里，用普通销毁
        Object.Destroy(material);
    #endif

        // 释放中转图片
        if (textureHandle != null)
        {
            textureHandle.Release();
        }
    }
}