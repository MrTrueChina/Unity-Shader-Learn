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

using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

namespace HSR.NPRShader.Passes
{
    public class ForwardDrawObjectsPass : DrawObjectsPass
    {
        /// <summary>
        /// 构造
        /// </summary>
        /// <param name="profilerTag">这个通道的标签，也可以理解为名字</param>
        /// <param name="isOpaque">是否是不透明的，如果是不透明的则注入到不透明物体渲染完成后，透明的则注入到透明物体渲染完成后</param>
        /// <param name="shaderTagIds">着色器标签的 ID 列表，这个通道在执行时会调用可执行这个通道的物体的 LightMode 标签为这个 ID 的通道</param>
        public ForwardDrawObjectsPass(string profilerTag, bool isOpaque, params ShaderTagId[] shaderTagIds)
            : this(profilerTag, isOpaque,
                // 放在最后绘制，这样就不需要清理被挡住的角色的 Stencil
                isOpaque ? RenderPassEvent.AfterRenderingOpaques : RenderPassEvent.AfterRenderingTransparents,
                shaderTagIds) { }

        /// <summary>
        /// 构造
        /// </summary>
        /// <param name="profilerTag">这个通道的标签，也可以理解为名字</param>
        /// <param name="isOpaque">是否是不透明的，如果是不透明的则注入到不透明物体渲染完成后，透明的则注入到透明物体渲染完成后</param>
        /// <param name="evt">触发事件，实际上就是注入点</param>
        /// <param name="shaderTagIds">着色器标签的 ID 列表，这个通道在执行时会调用可执行这个通道的物体的 LightMode 标签为这个 ID 的通道</param>
        public ForwardDrawObjectsPass(string profilerTag, bool isOpaque, RenderPassEvent evt, params ShaderTagId[] shaderTagIds)
            : this(profilerTag, isOpaque, -1, evt, shaderTagIds) { }

        /// <summary>
        /// 构造
        /// </summary>
        /// <param name="profilerTag">这个通道的标签，也可以理解为名字</param>
        /// <param name="isOpaque">是否是不透明的，如果是不透明的则注入到不透明物体渲染完成后，透明的则注入到透明物体渲染完成后</param>
        /// <param name="layerMask">有效的渲染层</param>
        /// <param name="evt">触发事件，实际上就是注入点</param>
        /// <param name="shaderTagIds">着色器标签的 ID 列表，这个通道在执行时会调用可执行这个通道的物体的 LightMode 标签为这个 ID 的通道</param>
        public ForwardDrawObjectsPass(string profilerTag, bool isOpaque, LayerMask layerMask, RenderPassEvent evt, params ShaderTagId[] shaderTagIds)
            : base(profilerTag, shaderTagIds, isOpaque, evt,
                isOpaque ? RenderQueueRange.opaque : RenderQueueRange.transparent,
                layerMask, new StencilState(), 0) { }
    }
}
