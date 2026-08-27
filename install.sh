#!/usr/bin/env bash
# =============================================================================
# wpc 安装脚本 —— 用户级部署（无需 sudo，幂等，可逆）
#   1. 构建/定位 release 二进制，部署到 ~/.local/bin/wpc
#   2. 部署 hook 到 ~/.local/share/wpc/wpc.bash
#   3. 生成配置骨架 ~/.config/wpc/config.toml（若不存在）
#   4. 向 ~/.bashrc 注入带标记的加载块（幂等）
#   5. 可选 systemd user 服务（仅当 systemd 可用，不可用时静默提示）
# 用法：./install.sh
# =============================================================================
set -eu

# 仓库根目录（脚本位于仓库根）
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_DIR/target/release/wpc"
HOOK_SRC="$REPO_DIR/shell/wpc.bash"
UNIT_SRC="$REPO_DIR/deploy/wpc-daemon.service"

BIN_DIR="$HOME/.local/bin"
HOOK_DIR="$HOME/.local/share/wpc"
CONFIG_DIR="$HOME/.config/wpc"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
BASH_RC="$HOME/.bashrc"

# ---- 0. 安装环境检查（发布处理：明确依赖，缺失即中止并给出指引） ----
echo "wpc: 检查安装环境..."
missing=()

# 平台：wpc 面向 WSL 环境（非 WSL 仅警告，不阻断）
if ! uname -r 2>/dev/null | grep -qi microsoft; then
    echo "wpc: 警告：未检测到 WSL 内核，wpc 为 WSL 专用工具"
fi

# 标准工具（必需）
for t in install grep sed mkdir rm cat; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
done

# 构建工具（仅当 release 二进制缺失时需要）
if [[ ! -x "$BIN_SRC" ]]; then
    command -v cargo >/dev/null 2>&1 || missing+=("cargo（Rust 构建工具）")
    command -v rustc >/dev/null 2>&1 || missing+=("rustc（Rust 编译器）")
fi

# 参考工具（WSL 内置；缺失仅提示，不阻断）
command -v wslpath >/dev/null 2>&1 || \
    echo "wpc: 警告：未找到 wslpath（WSL 自带路径转换参考，通常无需安装）"

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "wpc: 错误：安装环境缺少以下依赖，请先安装：" >&2
    for m in "${missing[@]}"; do
        echo "  - $m" >&2
    done
    echo "wpc: 安装指引：Rust 工具链见 README.md「环境要求」章节。" >&2
    exit 1
fi
echo "wpc: 环境检查通过"

# ---- 1. 定位或构建 release 二进制 ----
if [[ ! -x "$BIN_SRC" ]]; then
    echo "wpc: 未找到 release 二进制，开始构建（cargo build --release）..."
    (cd "$REPO_DIR" && cargo build --release)
fi
if [[ ! -x "$BIN_SRC" ]]; then
    echo "wpc: 错误：构建失败，未找到 $BIN_SRC" >&2
    exit 1
fi
if [[ ! -f "$HOOK_SRC" || ! -f "$UNIT_SRC" ]]; then
    echo "wpc: 错误：hook 或服务单元文件缺失（$HOOK_SRC / $UNIT_SRC）" >&2
    exit 1
fi

# ---- 2. 创建部署目录 ----
mkdir -p "$BIN_DIR" "$HOOK_DIR" "$CONFIG_DIR"

# ---- 3. 部署二进制与 hook ----
install -m 0755 "$BIN_SRC" "$BIN_DIR/wpc"
install -m 0644 "$HOOK_SRC" "$HOOK_DIR/wpc.bash"
echo "wpc: 已部署二进制：$BIN_DIR/wpc"
echo "wpc: 已部署 hook：$HOOK_DIR/wpc.bash"

# ---- 4. 生成配置骨架（仅首次，不覆盖用户配置） ----
if [[ -f "$CONFIG_DIR/config.toml" ]]; then
    echo "wpc: 配置已存在，保留：$CONFIG_DIR/config.toml"
else
    cat > "$CONFIG_DIR/config.toml" <<'EOF'
# wpc 配置文件（TOML）
# 挂载根目录：Windows 盘符映射到 WSL 的根（默认 /mnt/）
# 优先级：/etc/wsl.conf [automount] root > 此处 mount_root > 默认 /mnt/
# mount_root = "/mnt/"
EOF
    echo "wpc: 已生成配置骨架：$CONFIG_DIR/config.toml"
fi

# ---- 5. 注入 ~/.bashrc 加载块（幂等） ----
if grep -q "# >>> WPC-HOOK-BEGIN >>>" "$BASH_RC" 2>/dev/null; then
    echo "wpc: ~/.bashrc 已注入，跳过"
else
    {
        echo ""
        echo "# >>> WPC-HOOK-BEGIN >>>"
        echo '[ -n "$WPC_DISABLE" ] || . "$HOME/.local/share/wpc/wpc.bash"'
        echo "# <<< WPC-HOOK-END <<<"
    } >> "$BASH_RC"
    echo "wpc: 已向 ~/.bashrc 注入 hook 加载块"
fi

# ---- 6. systemd user 服务（可选，不可用则提示不失败） ----
if command -v systemctl >/dev/null 2>&1; then
    mkdir -p "$SYSTEMD_USER_DIR"
    install -m 0644 "$UNIT_SRC" "$SYSTEMD_USER_DIR/wpc-daemon.service"
    if systemctl --user daemon-reload >/dev/null 2>&1 \
        && systemctl --user enable wpc-daemon.service >/dev/null 2>&1; then
        systemctl --user start wpc-daemon.service >/dev/null 2>&1 || true
        echo "wpc: systemd user 服务已启用：wpc-daemon.service"
    else
        echo "wpc: 提示：systemd user 实例不可用，已跳过服务启用（不影响 hook 生效）"
    fi
else
    echo "wpc: 提示：未检测到 systemd，跳过服务（hook 已随 shell 自动生效）"
fi

echo ""
echo "wpc: 安装完成。请执行：source ~/.bashrc（或重开终端）使 hook 生效。"
