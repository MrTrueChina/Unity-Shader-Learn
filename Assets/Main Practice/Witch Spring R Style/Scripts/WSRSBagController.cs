using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 仿魔女之泉的背包控制器
/// </summary>
public class WSRSBagController : MonoBehaviour
{
    /// <summary>
    /// 动画机
    /// </summary>
    [SerializeField]
    private Animator animator;

    /// <summary>
    /// 传送到达，调用则播放传送到达的动画效果
    /// </summary>
    public void TeleportationArrival()
    {
        animator.SetTrigger("Teleportation Arrival");
    }
}
