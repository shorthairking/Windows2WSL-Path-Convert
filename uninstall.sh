#!/usr/bin/env bash
# =============================================================================
# wpc 卸载脚本 —— 完整移除（可逆：重新执行 install.sh 即可恢复）
#   1. 移除 systemd user 服务单元
#   2. 移除 ~/.bashrc 中的 hook 加载块
#   3. 删除 hook 文件与二进制
#   4. 保留用户配置 ~/.config/wpc/config.toml（提示手动处理）
# 用法：./uninstall.sh
# =============================================================================
set -eu

BIN_DIR="$HOME/.local/bin"
HOOK_DIR="$HOME/.local/share/wpc"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
BASH_RC="$HOME/.bashrc"

# ---- 1. systemd user 服务 ----
if [[ -f "$SYSTEMD_USER_DIR/wpc-daemon.service" ]]; then
    systemctl --user disable wpc-daemon.service >/dev/null 2>&1 || true
    systemctl --user stop wpc-daemon.service >/dev/null 2>&1 || true
    rm -f "$SYSTEMD_USER_DIR/wpc-daemon.service"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    echo "wpc: 已移除 systemd user 服务"
fi

# ---- 2. ~/.bashrc 标记块 ----
if grep -q "# >>> WPC-HOOK-BEGIN >>>" "$BASH_RC" 2>/dev/null; then
    sed -i '/# >>> WPC-HOOK-BEGIN >>>/,/# <<< WPC-HOOK-END <<</d' "$BASH_RC"
    echo "wpc: 已移除 ~/.bashrc 中的 hook 加载块"
fi

# ---- 3. hook 与二进制 ----
rm -f "$HOOK_DIR/wpc.bash"
rm -f "$BIN_DIR/wpc"
rmdir "$HOOK_DIR" 2>/dev/null || true
echo "wpc: 已删除 hook 与二进制"

# ---- 4. 配置保留提示 ----
echo "wpc: 已保留配置：$HOME/.config/wpc/config.toml（如需删除请手动执行 rm）"

echo "wpc: 卸载完成。新开终端后 hook 不再生效。"
