using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

/// <summary>
/// 给《入门精要》配对的自定义渲染通道功能，需要在使用的 URP-Renderer 上添加才能提供功能
/// </summary>
[DisallowMultipleRendererFeature("Unity Shader Book Expand Pass Feature")]
public class ShaderBookExpandPassFeature : ScriptableRendererFeature
{
    /// <summary>
    /// 在渲染完不透明物体后执行的通道
    /// </summary>
    [NonSerialized] private DrawObjectsPass afterOpaquePass;
    /// <summary>
    /// 在渲染完透明物体后执行的通道
    /// </summary>
    [NonSerialized] private DrawObjectsPass afterTransparentPass;

    public override void Create()
    {
        var afterOpaquesShaderTagIdList = new ShaderTagId[]{
            new ShaderTagId("USB-AfterOpaquePass")
        };
        afterOpaquePass = new DrawObjectsPass("afterOpaquePass", afterOpaquesShaderTagIdList, true, RenderPassEvent.AfterRenderingOpaques, RenderQueueRange.opaque, -1, new StencilState(), 0);

        var afterTransparentShaderTagIdList = new ShaderTagId[]{
            new ShaderTagId("USB-AfterTransparentPass")
        };
        afterOpaquePass = new DrawObjectsPass("afterTransparentPass", afterTransparentShaderTagIdList, false, RenderPassEvent.AfterRenderingTransparents, RenderQueueRange.transparent, -1, new StencilState(), 0);
    }
    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(afterOpaquePass);
    }
}
