# =============================================================================
# wpc.bash —— WSL 路径自动转换 hook（bash DEBUG trap 无感集成）
#
# 原理（方案 §6 执行替换策略）：
#   1. DEBUG trap 在每条命令执行前触发，取 $BASH_COMMAND（即将执行的原文）
#   2. bash 内建模式「快速路径」预筛：无候选特征直接放行（零 fork）
#   3. 有候选特征时调用 `wpc --eval-line "$cmd"` 整体替换
#   4. 启用 `shopt -s extdebug`：hook 返回非零 → 跳过原始命令，改为执行转换后文本
#   5. 防递归：__wpc_in_hook + WPC_DISABLE 双保险
#
# 安装：由 install.sh 注入 ~/.bashrc 的标记块；也可手动 `source` 本文件启用。
# 本文件内容位于 # WPC-HOOK-BEGIN / # WPC-HOOK-END 之间，供安装器定位。
# =============================================================================
# WPC-HOOK-BEGIN

# 仅交互式 bash 生效；非交互（脚本）场景由 wpc CLI 显式转换
case "$-" in
    *i*) ;;
    *) return 0 ;;
esac

# 幂等：已安装时直接返回，避免重复 source 导致 trap 覆盖自身
if [[ "$(trap -p DEBUG 2>/dev/null)" == "trap -- 'wpc_preexec' DEBUG" ]]; then
    return 0
fi

# 保存调用方原有 DEBUG trap（如 VS Code 终端的提示符 hook），处理后链式调用
__wpc_orig_debug_trap="$(trap -p DEBUG 2>/dev/null)"
if [[ "$__wpc_orig_debug_trap" == "trap -- '"*"' DEBUG" ]]; then
    __wpc_orig_debug_handler="${__wpc_orig_debug_trap#trap -- \'}"
    __wpc_orig_debug_handler="${__wpc_orig_debug_handler%\' DEBUG}"
    # 排除自身（防递归）
    [[ "$__wpc_orig_debug_handler" == "wpc_preexec" ]] && __wpc_orig_debug_handler=""
else
    __wpc_orig_debug_handler=""
fi

# 快速路径预筛用的候选特征（bash 内建模式，零 fork）
# 盘符路径特征：`X:` 后跟 `\` 或 `/`；UNC/转义特征：行内两个连续反斜杠
__wpc_drive_pattern='*[A-Za-z]:[\\/]*'
__wpc_unc_pattern='*\\\\*'

wpc_preexec() {
    # 防递归：hook 内部命令（wpc 调用、history、eval）不再进入转换流程
    [[ -n "${__wpc_in_hook:-}" ]] && return 0

    local cmd="$BASH_COMMAND"
    local converted rc
    local __wpc_in_hook __wpc_result=0

    # 零开销快速路径：无候选特征直接放行（不 fork 外部进程）
    if [[ "$cmd" != $__wpc_drive_pattern && "$cmd" != $__wpc_unc_pattern ]]; then
        __wpc_result=0
    elif [[ "${WPC_DISABLE:-}" == "1" || "$cmd" == WPC_DISABLE=1* ]]; then
        # 禁用开关：环境变量 WPC_DISABLE=1，或命令行以 WPC_DISABLE=1 前缀
        __wpc_result=0
    else
        # 进入转换流程：hook 内命令置于防递归保护下
        # （__wpc_in_hook 为局部变量，函数结束自动清理，不污染外层 shell；
        #   WPC_DISABLE=1 仅作为 wpc 调用时的临时环境前缀，同样不污染外层）
        __wpc_in_hook=1
        converted="$(WPC_DISABLE=1 command wpc --eval-line "$cmd" 2>/dev/null)"
        rc=$?

        if [[ $rc -eq 0 && -n "$converted" && "$converted" != "$cmd" ]]; then
            # 转换成功：历史记录保留用户原文，执行转换后命令，跳过原始命令
            history -s "$cmd" 2>/dev/null
            eval "$converted"
            __wpc_result=1
        elif [[ $rc -eq 1 ]]; then
            # 存在无法转换的 UNC 路径：提示并阻止执行（WPC_FALLBACK=raw 可逃生）
            if [[ "${WPC_FALLBACK:-}" == "raw" || "$cmd" == WPC_FALLBACK=raw* ]]; then
                __wpc_result=0
            else
                printf 'wpc: 无法转换 Windows UNC 路径，命令未执行：%s\n' "$cmd" >&2
                __wpc_result=1
            fi
        else
            # wpc 不可用 / 无匹配：原样放行
            __wpc_result=0
        fi
    fi

    # 链式调用调用方原有 DEBUG handler（如 VS Code 终端的提示符逻辑），保持其行为
    if [[ -n "$__wpc_orig_debug_handler" ]]; then
        __wpc_in_hook=1
        eval "$__wpc_orig_debug_handler"
    fi
    return $__wpc_result
}

# 安装 DEBUG trap 并启用 extdebug（返回非零即跳过原命令）
trap wpc_preexec DEBUG
shopt -s extdebug

# WPC-HOOK-END
