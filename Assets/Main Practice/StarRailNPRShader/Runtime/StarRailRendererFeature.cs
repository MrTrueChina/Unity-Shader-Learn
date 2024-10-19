/*
 * StarRailNPRShader - Fan-made shaders for Unity URP attempting to replicate
 * the shading of Honkai: Star Rail.
 * https://github.com/stalomeow/StarRailNPRShader
 *
 * Copyright (C) 2023 Stalo <stalowork@163.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

using System;
using HSR.NPRShader.Passes;
using HSR.NPRShader.PerObjectShadow;
using HSR.NPRShader.Utils;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace HSR.NPRShader
{
    [HelpURL("https://srshader.stalomeow.com/")]
    [DisallowMultipleRendererFeature("Honkai Star Rail")]
    public class StarRailRendererFeature : ScriptableRendererFeature
    {
#if UNITY_EDITOR
        [UnityEditor.ShaderKeywordFilter.ApplyRulesIfNotGraphicsAPI(GraphicsDeviceType.OpenGLES2)]
        [UnityEditor.ShaderKeywordFilter.SelectIf(true, keywordNames: ShaderKeywordStrings.MainLightShadowScreen)]
        private const bool k_RequiresScreenSpaceShadowsKeyword = true;
#endif

        /// <summary>
        /// 屏幕空间阴影的深度位数
        /// </summary>
        [SerializeField] private DepthBits m_SceneShadowDepthBits = DepthBits.Depth16;
        /// <summary>
        /// 屏幕空间阴影的分辨率
        /// </summary>
        [SerializeField] private ShadowTileResolution m_SceneShadowTileResolution = ShadowTileResolution._512;

        /// <summary>
        /// 是否启用自投影
        /// </summary>
        [SerializeField] private bool m_EnableSelfShadow = true;
        /// <summary>
        /// 自投影的深度位数
        /// </summary>
        [SerializeField] private DepthBits m_SelfShadowDepthBits = DepthBits.Depth16;
        /// <summary>
        /// 自投影的分辨率
        /// </summary>
        [SerializeField] private ShadowTileResolution m_SelfShadowTileResolution = ShadowTileResolution._1024;

        /// <summary>
        /// 是否启用刘海阴影
        /// </summary>
        [SerializeField] private bool m_EnableFrontHairShadow = true;
        /// <summary>
        /// 刘海阴影的缩放模式
        /// </summary>
        [SerializeField] private HairDepthOnlyPass.DownscaleMode m_FrontHairShadowDownscale = HairDepthOnlyPass.DownscaleMode.Half;
        /// <summary>
        /// 刘海阴影的深度位数
        /// </summary>
        [SerializeField] private DepthBits m_FrontHairShadowDepthBits = DepthBits.Depth16;

        /// <summary>
        /// 刘海是否允许透明，即可以根据需要不遮挡后面的物体（存疑）
        /// </summary>
        [SerializeField] private bool m_EnableTransparentFrontHair = true;

        /// <summary>
        /// 屏幕空间阴影的投影控制器
        /// </summary>
        [NonSerialized] private ShadowCasterManager m_SceneShadowCasterManager;
        /// <summary>
        /// 自投影的投影控制器
        /// </summary>
        [NonSerialized] private ShadowCasterManager m_SelfShadowCasterManager;

        /// <summary>
        /// 用于启动自投影的通道
        /// </summary>
        [NonSerialized] private SetKeywordPass m_EnableSelfShadowPass;
        /// <summary>
        /// 用于关闭自投影的通道
        /// </summary>
        [NonSerialized] private SetKeywordPass m_DisableSelfShadowPass;
        /// <summary>
        /// 用于启动刘海阴影的通道
        /// </summary>
        [NonSerialized] private SetKeywordPass m_EnableFrontHairShadowPass;
        /// <summary>
        /// 用于关闭刘海阴影的通道
        /// </summary>
        [NonSerialized] private SetKeywordPass m_DisableFrontHairShadowPass;
        [NonSerialized] private PerObjectShadowCasterPass m_ScenePerObjShadowPass;
        [NonSerialized] private PerObjectShadowCasterPreviewPass m_ScenePerObjShadowPreviewPass;
        [NonSerialized] private PerObjectShadowCasterPass m_SelfPerObjShadowPass;
        [NonSerialized] private HairDepthOnlyPass m_HairDepthOnlyPass;
        [NonSerialized] private RequestResourcePass m_ForceDepthPrepassPass;
        /// <summary>
        /// 屏幕空间阴影通道
        /// </summary>
        [NonSerialized] private ScreenSpaceShadowsPass m_ScreenSpaceShadowPass;
        [NonSerialized] private ScreenSpaceShadowsPostPass m_ScreenSpaceShadowPostPass;
        /// <summary>
        /// 前向渲染不透明物体通道 1，提供了不透明物体的前向渲染
        /// </summary>
        [NonSerialized] private ForwardDrawObjectsPass m_DrawOpaqueForward1Pass;
        /// <summary>
        /// 前向渲染不透明物体通道 2，提供了不透明物体的前向渲染，在 1 后面执行
        /// </summary>
        [NonSerialized] private ForwardDrawObjectsPass m_DrawOpaqueForward2Pass;
        /// <summary>
        /// 似乎是不透明头发的渲染通道
        /// </summary>
        [NonSerialized] private ForwardDrawObjectsPass m_DrawSimpleHairPass;
        /// <summary>
        /// 允许透视的头发的渲染通道
        /// </summary>
        [NonSerialized] private ForwardDrawObjectsPass m_DrawTransparentHairPass;
        /// <summary>
        /// 前向渲染不透明物体通道 3，提供了不透明物体的前向渲染，在 2 后面执行
        /// </summary>
        [NonSerialized] private ForwardDrawObjectsPass m_DrawOpaqueForward3Pass;
        /// <summary>
        /// 不透明物体的描边通道
        /// </summary>
        [NonSerialized] private ForwardDrawObjectsPass m_DrawOpaqueOutlinePass;
        /// <summary>
        /// 自定义的半透明渲染通道，和 URP 的半透明渲染并不相同
        /// </summary>
        [NonSerialized] private ForwardDrawObjectsPass m_DrawTransparentPass;
        /// <summary>
        /// 后处理通道
        /// </summary>
        [NonSerialized] private PostProcessPass m_PostProcessPass;

        public override void Create()
        {
            m_SceneShadowCasterManager = new ShadowCasterManager(ShadowUsage.Scene);
            m_SelfShadowCasterManager = new ShadowCasterManager(ShadowUsage.Self);

            // 开关关键字的通道，注入点都是在渲染之前
            m_EnableSelfShadowPass = new SetKeywordPass(KeywordNames._MAIN_LIGHT_SELF_SHADOWS, true, RenderPassEvent.BeforeRendering);
            m_DisableSelfShadowPass = new SetKeywordPass(KeywordNames._MAIN_LIGHT_SELF_SHADOWS, false, RenderPassEvent.BeforeRendering);
            m_EnableFrontHairShadowPass = new SetKeywordPass(KeywordNames._MAIN_LIGHT_FRONT_HAIR_SHADOWS, true, RenderPassEvent.BeforeRendering);
            m_DisableFrontHairShadowPass = new SetKeywordPass(KeywordNames._MAIN_LIGHT_FRONT_HAIR_SHADOWS, false, RenderPassEvent.BeforeRendering);

            m_ScenePerObjShadowPass = new PerObjectShadowCasterPass("MainLightPerObjectSceneShadow");
            m_ScenePerObjShadowPreviewPass = new PerObjectShadowCasterPreviewPass("MainLightPerObjectSceneShadow (Preview)", ShadowUsage.Scene);
            m_SelfPerObjShadowPass = new PerObjectShadowCasterPass("MainLightPerObjectSelfShadow");
            
            m_HairDepthOnlyPass = new HairDepthOnlyPass();
            m_ForceDepthPrepassPass = new RequestResourcePass(RenderPassEvent.AfterRenderingGbuffer, ScriptableRenderPassInput.Depth);
            m_ScreenSpaceShadowPass = new ScreenSpaceShadowsPass();
            m_ScreenSpaceShadowPostPass = new ScreenSpaceShadowsPostPass();
            
            // 自定义的几个通道，也是渲染物体主要用到的通道
            // 第一个不透明的前向渲染通道，对应的 LightMode 是 HSRForward1
            m_DrawOpaqueForward1Pass = new ForwardDrawObjectsPass("DrawStarRailOpaque (1)", true, new ShaderTagId("HSRForward1"));
            m_DrawOpaqueForward2Pass = new ForwardDrawObjectsPass("DrawStarRailOpaque (2)", true, new ShaderTagId("HSRForward2"));
            m_DrawSimpleHairPass = new ForwardDrawObjectsPass("DrawStarRailHair", true, new ShaderTagId("HSRHair"));
            // 这个通道比较特殊，他名字里是透明通道，但其实是指允许后面的内容渲染到上面来，它本身是不透明的
            // 另外它支持 HSRHairPreserveEye 和 HSRHairFakeTransparent 两个 LightMode，它会渲染这两种通道
            m_DrawTransparentHairPass = new ForwardDrawObjectsPass("DrawStarRailHair", true, new ShaderTagId("HSRHairPreserveEye"), new ShaderTagId("HSRHairFakeTransparent"));
            m_DrawOpaqueForward3Pass = new ForwardDrawObjectsPass("DrawStarRailOpaque (3)", true, new ShaderTagId("HSRForward3"));
            m_DrawOpaqueOutlinePass = new ForwardDrawObjectsPass("DrawStarRailOpaqueOutline", true, new ShaderTagId("HSROutline"));
            // 这是个透明通道，参数上设置为透明
            // 它同时支持 HSRTransparent 和 HSRTransparentPreserveEye 两个 LightMode
            // 需要注意的是 HSROutline 两个通道都写了，所以这两个通道都会执行
            // TODO: 这里要确认一下具体的运行情况，两个通道支持同一个标签但是配置不同，需要确认在一次渲染里一个通道是根据需要执行其中一个还是两个都执行
            m_DrawTransparentPass = new ForwardDrawObjectsPass("DrawStarRailTransparent", false, new ShaderTagId("HSRTransparent"), new ShaderTagId("HSROutline"));
            
            // 后处理通道
            m_PostProcessPass = new PostProcessPass();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            // 确认是不是预览视图摄像机，预览视图是当你选择一个可以预览的资源的时候在 Inspector 界面下面会出现的那个小预览窗，一般模型都有预览视图
            bool isPreviewCamera = renderingData.cameraData.isPreviewCamera;
            // 屏幕空间阴影在预览窗口以外的窗口启用
            bool enableSceneShadow = !isPreviewCamera;
            // 自投影在预览窗口以外的窗口根据设置启用
            bool enableSelfShadow = m_EnableSelfShadow && !isPreviewCamera;
            // 刘海阴影在预览窗口以外的窗口根据设置启用
            bool enableFrontHairShadow = m_EnableFrontHairShadow && !isPreviewCamera;
            // 刘海是否可透过根据设置启用
            bool enableTransparentFrontHair = m_EnableTransparentFrontHair;

            // 先注入在渲染之前执行的通道，就是根据有没有自投影、头发能不能透过设置关键字
            // 其实这几个通道已经定了触发事件了，不在最前面传也行，但是按顺序传阅读起来更清晰
            renderer.EnqueuePass(enableSelfShadow ? m_EnableSelfShadowPass : m_DisableSelfShadowPass);
            renderer.EnqueuePass(enableFrontHairShadow ? m_EnableFrontHairShadowPass : m_DisableFrontHairShadowPass);

            // AfterRenderingShadows
            renderer.EnqueuePass(enableSceneShadow ? m_ScenePerObjShadowPass : m_ScenePerObjShadowPreviewPass);

            if (enableSelfShadow)
            {
                renderer.EnqueuePass(m_SelfPerObjShadowPass);
            }

            // AfterRenderingPrePasses
            if (enableFrontHairShadow)
            {
                renderer.EnqueuePass(m_HairDepthOnlyPass);
            }

            // AfterRenderingGbuffer
            renderer.EnqueuePass(m_ForceDepthPrepassPass); // 保证 RimLight、眼睛等需要深度图的效果正常工作
            renderer.EnqueuePass(m_ScreenSpaceShadowPass);

            // AfterRenderingOpaques
            renderer.EnqueuePass(m_ScreenSpaceShadowPostPass);

            // 注入渲染物体的几个自定义通道
            renderer.EnqueuePass(m_DrawOpaqueForward1Pass);
            renderer.EnqueuePass(m_DrawOpaqueForward2Pass);
            renderer.EnqueuePass(enableTransparentFrontHair ? m_DrawTransparentHairPass : m_DrawSimpleHairPass);
            renderer.EnqueuePass(m_DrawOpaqueForward3Pass);
            renderer.EnqueuePass(m_DrawOpaqueOutlinePass);

            // 接着是自定义的渲染透明物体的通道
            renderer.EnqueuePass(m_DrawTransparentPass);

            // BeforeRenderingPostProcessing
            renderer.EnqueuePass(m_PostProcessPass);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            // PreviewCamera 不会执行这部分代码！！！
            base.SetupRenderPasses(renderer, in renderingData);

            m_SceneShadowCasterManager.Cull(in renderingData, PerObjectShadowCasterPass.MaxShadowCount);
            m_ScenePerObjShadowPass.Setup(m_SceneShadowCasterManager, m_SceneShadowTileResolution, m_SceneShadowDepthBits);

            if (m_EnableSelfShadow)
            {
                m_SelfShadowCasterManager.Cull(in renderingData, PerObjectShadowCasterPass.MaxShadowCount);
                m_SelfPerObjShadowPass.Setup(m_SelfShadowCasterManager, m_SelfShadowTileResolution, m_SelfShadowDepthBits);
            }

            if (m_EnableFrontHairShadow)
            {
                m_HairDepthOnlyPass.Setup(m_FrontHairShadowDownscale, m_FrontHairShadowDepthBits);
            }
        }

        protected override void Dispose(bool disposing)
        {
            m_ScenePerObjShadowPass.Dispose();
            m_HairDepthOnlyPass.Dispose();
            m_ScreenSpaceShadowPass.Dispose();
            m_SelfPerObjShadowPass.Dispose();
            m_PostProcessPass.Dispose();

            base.Dispose(disposing);
        }

        private static class KeywordNames
        {
            public static readonly string _MAIN_LIGHT_SELF_SHADOWS = MemberNameHelpers.String();
            public static readonly string _MAIN_LIGHT_FRONT_HAIR_SHADOWS = MemberNameHelpers.String();
        }
    }
}
