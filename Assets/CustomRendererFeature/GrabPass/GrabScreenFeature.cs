using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

/// <summary>
/// 抓取屏幕的自定义渲染功能
/// </summary>
public class GrabScreenFeature : ScriptableRendererFeature
{
    /// <summary>
    /// 设置
    /// </summary>
    [System.Serializable]
    public class Settings
    {
        /// <summary>
        /// 输出到的纹理名称，Shader 中通过这个名称获取抓取的纹理
        /// </summary>
        public string TextureName = "_GrabPassTransparent";
        /// <summary>
        /// 层遮罩
        /// </summary>
        public LayerMask LayerMask;
        /// <summary>
        /// 在这个事件发出时执行
        /// </summary>
        public RenderPassEvent RenderPassEvent;
        /// <summary>
        /// 执行时机偏移，即在这个事件发出时执行的优先级，越小则越靠前
        /// </summary>
        public int Offset;
        /// <summary>
        /// 传递纹理给这个材质
        /// </summary>
        public Material BlitMaterial;
    }

    /// <summary>
    /// 抓取屏幕的自定义渲染通道
    /// </summary>
    class GrabPass : ScriptableRenderPass
    {
        /// <summary>
        /// 抓取到的图片的暂存容器
        /// </summary>
        RenderTargetHandle tempColorTarget;
        /// <summary>
        /// 设置
        /// </summary>
        Settings settings;

        public GrabPass(Settings s)
        {
            settings = s;
            renderPassEvent = settings.RenderPassEvent + settings.Offset;
            tempColorTarget.Init(settings.TextureName);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            var descriptor = cameraTextureDescriptor;
            // 抗锯齿设为 1
            descriptor.msaaSamples = 1;
            // 深度缓冲区位数设为 0，会让深度缓冲失效
            descriptor.depthBufferBits = 0;

            // 获取临时的渲染纹理，即将当前时刻的渲染存入到暂存的这个容器里
            cmd.GetTemporaryRT(tempColorTarget.id, descriptor);
            // 设置全局纹理，将容器里的这个纹理设置到管线的全局变量里，这样 Shader 里就可以通过名字获取到这张纹理
            cmd.SetGlobalTexture(settings.TextureName, tempColorTarget.Identifier());

            // 设置这个自定义通道的渲染目标为这个纹理的容器
            ConfigureTarget(tempColorTarget.Identifier());
            // 似乎是在配置这个自定义通道的清理方案？
            ConfigureClear(ClearFlag.Color, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // 获取当前的命令缓冲区，然后执行它，然后清除了命令缓冲区
            // 相当于让这一步的命令正常执行
            CommandBuffer cmd = CommandBufferPool.Get();
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            if ((int)settings.RenderPassEvent >= (int)RenderPassEvent.BeforeRenderingPostProcessing)
            {
                // 执行时间设置为在后处理之前或者更晚

                // 使用设置的材质的索引为 2 的通道进行渲染并将结果存入容器？
                cmd.Blit(null, tempColorTarget.Identifier(), settings.BlitMaterial, 2);
            }
            else
            {
                // 执行时间设置为 在后处理之前 这个事件再往前


                var cameraTarget = renderingData.cameraData.renderer.cameraColorTarget;
                Blit(cmd, cameraTarget, tempColorTarget.Identifier());
            }

            // 执行缓冲区命令，然后释放，让流程继续
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(tempColorTarget.id);
        }
    }

    /// <summary>
    /// 渲染通道
    /// </summary>
    class RenderPass : ScriptableRenderPass
    {
        Settings settings;
        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();

        FilteringSettings m_FilteringSettings;
        RenderStateBlock m_RenderStateBlock;
        RenderTargetHandle renderTarget;
        RenderTargetIdentifier depthHandle;

        public RenderTargetIdentifier RenderTarget => renderTarget.Identifier();

        public RenderPass(Settings settings)
        {
            this.settings = settings;
            renderPassEvent = settings.RenderPassEvent + settings.Offset + 1;

            m_ShaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
            m_ShaderTagIdList.Add(new ShaderTagId("UniversalForward"));
            m_ShaderTagIdList.Add(new ShaderTagId("UniversalForwardOnly"));

            m_FilteringSettings = new FilteringSettings(RenderQueueRange.all, settings.LayerMask);
            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);

            renderTarget.Init("_GSF_RenderPass");
        }

        public void Setup(RenderTargetIdentifier depthHandle)
        {
            this.depthHandle = depthHandle;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.msaaSamples = 1;
            cmd.GetTemporaryRT(renderTarget.id, desc, FilterMode.Point);

            if ((int)settings.RenderPassEvent >= (int)RenderPassEvent.BeforeRenderingPostProcessing)
            {
                ConfigureTarget(renderTarget.Identifier(), depthHandle);
                ConfigureClear(ClearFlag.Color, Color.clear);
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            DrawingSettings drawSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, SortingCriteria.CommonOpaque);
            context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref m_FilteringSettings, ref m_RenderStateBlock);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(renderTarget.id);
        }
    }

    class CopyDepthPass : ScriptableRenderPass
    {
        RenderTargetHandle depthHandle;
        Settings settings;

        public RenderTargetIdentifier DepthHandle => depthHandle.Identifier();

        public CopyDepthPass(Settings settings)
        {
            this.settings = settings;

            depthHandle.Init("_DepthCopy");
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.msaaSamples = 1;

            cmd.GetTemporaryRT(depthHandle.id, desc, FilterMode.Point);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get("OutlineBlitCMD");
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            cmd.Blit(depthHandle.Identifier(), depthHandle.Identifier(), settings.BlitMaterial, 1);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(depthHandle.id);
        }
    }

    class BlitPass : ScriptableRenderPass
    {
        Settings settings;
        RenderTargetIdentifier renderTarget;

        public BlitPass(Settings settings)
        {
            this.settings = settings;
            renderPassEvent = settings.RenderPassEvent + settings.Offset + 2;
        }

        public void Setup(RenderTargetIdentifier renderTarget)
        {
            this.renderTarget = renderTarget;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            var screenTex = colorAttachment;
            cmd.Blit(null, screenTex, settings.BlitMaterial, 0);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    /// <summary>
    /// 抓取通道
    /// </summary>
    GrabPass grabPass;
    /// <summary>
    /// 渲染通道
    /// </summary>
    RenderPass renderPass;
    /// <summary>
    /// 纹理转存通道
    /// </summary>
    BlitPass blitPass;
    /// <summary>
    /// 复制深度的通道
    /// </summary>
    CopyDepthPass copyDepthPass;
    
    /// <summary>
    /// 设置
    /// </summary>
    [SerializeField]
    Settings settings = new Settings();

    public override void Create()
    {
        grabPass = new GrabPass(settings);
        renderPass = new RenderPass(settings);
        blitPass = new BlitPass(settings);
        copyDepthPass = new CopyDepthPass(settings);
        copyDepthPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if ((int)settings.RenderPassEvent >= (int)RenderPassEvent.BeforeRenderingPostProcessing)
        {
            renderer.EnqueuePass(copyDepthPass);
        }

        renderer.EnqueuePass(grabPass);

        renderPass.Setup(copyDepthPass.DepthHandle);
        renderer.EnqueuePass(renderPass);

        if ((int)settings.RenderPassEvent >= (int)RenderPassEvent.BeforeRenderingPostProcessing)
        {
            blitPass.Setup(renderPass.RenderTarget);
            renderer.EnqueuePass(blitPass);
        }
    }
}