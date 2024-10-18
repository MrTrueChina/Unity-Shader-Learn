using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class MyRendererFeature : ScriptableRendererFeature
{
    /// <summary>
    /// 在这个渲染功能里要使用的 Shader，渲染功能就是 Renderer Feature 的官方翻译，可以理解为一个自定义的步骤
    /// </summary>
    [SerializeField]
    private Shader shader;

    /// <summary>
    /// 材质
    /// </summary>
    private Material material;
    /// <summary>
    /// 红色调渲染通道，实际上和 BiRP 的通道不是一个逻辑，BiRP 的通道顺序依赖于 SubShader，而 URP 的这个基于 ScriptableRendererFeature 的顺序则更依赖于渲染步骤，高于 SubShader
    /// </summary>
    private RedTintRenderPass redTintRenderPass;

    /// <summary>
    /// 创建方法
    /// </summary>
    public override void Create()
    {
        if (shader == null)
        {
            return;
        }

        // 创建材质，然后创建自定义的通道
        material = CoreUtils.CreateEngineMaterial(shader);
        redTintRenderPass = new RedTintRenderPass(material);
        
        // 设定注入点，这里选择了在后期处理之后生效，红色调渲染通道的效果特别霸道适合放到最后面
        redTintRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }

    /// <summary>
    /// 注入通道方法
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // 根据摄像机类型注入，这里给游戏摄像机和场景视图注入，没有注入 VR 和其他的一些类型
        // 此外这里支持给预览界面注入，就是点击一个预制后在 inspector 界面下面会出现的那个预览窗口，但这个渲染功能计划上是后处理，可能干扰预览，不注入到预览界面摄像机
        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.isSceneViewCamera)
        {
            // 注入通道
            renderer.EnqueuePass(redTintRenderPass);
        }
    }

    /// <summary>
    /// 释放方法，或者你要是愿意也可以叫析构函数，反正他的大名叫 Dispose
    /// </summary>
    /// <param name="disposing"></param>
    protected override void Dispose(bool disposing)
    {
        // 销毁材质
        CoreUtils.Destroy(material);
    }
}