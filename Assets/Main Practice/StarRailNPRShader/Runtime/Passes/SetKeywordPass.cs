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

using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace HSR.NPRShader.Passes
{
    /// <summary>
    /// 设置关键字的 Pass
    /// </summary>
    public class SetKeywordPass : ScriptableRenderPass
    {
        private readonly string m_Keyword;
        private readonly bool m_State;

        /// <summary>
        /// 构造方法，不是什么内置的特殊方法，但是传入了一个渲染事件，因为这个 Pass 可能是复用的，不一定能直接从管线中获取到应该对应的渲染事件
        /// </summary>
        /// <param name="keyword"></param>
        /// <param name="state"></param>
        /// <param name="evt"></param>
        public SetKeywordPass(string keyword, bool state, RenderPassEvent evt)
        {
            renderPassEvent = evt;

            m_Keyword = keyword;
            m_State = state;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // 获取命令
            CommandBuffer cmd = CommandBufferPool.Get();

            // 设置关键字是否启动
            CoreUtils.SetKeyword(cmd, m_Keyword, m_State);
            
            // 执行并释放命令，让渲染继续
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
