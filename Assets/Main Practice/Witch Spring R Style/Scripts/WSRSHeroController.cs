using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 仿魔女之泉的玩家角色控制器
/// </summary>
public class WSRSHeroController : MonoBehaviour
{
    // 这里更合适的方式是作为动态的变量而不是拖拽的变量，这样能和换装备机制匹配。但这只是简单做个效果就直接拖拽了
    /// <summary>
    /// 背包控制器
    /// </summary>
    [SerializeField]
    private WSRSBagController bagController;
    /// <summary>
    /// 武器控制器
    /// </summary>
    [SerializeField]
    private WSRSWeaponController weaponController;

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

        // 分发给武器和背包
        bagController.TeleportationArrival();
        weaponController.TeleportationArrival();
    }
}
