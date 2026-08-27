#!/usr/bin/env bash
# =============================================================================
# 安装器测试（隔离）
# 在仓库内 target/test-tmp/ 的临时 HOME 中执行 install/uninstall，
# 验证落位、幂等、可逆；不触碰真实 HOME。systemd 在无用户会话时优雅跳过。
# 退出码：0=通过 1=失败 77=跳过
# =============================================================================
set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$REPO_DIR/install.sh"
UNINSTALL="$REPO_DIR/uninstall.sh"
[[ -x "$INSTALL" ]] || { echo "SKIP: 未找到 $INSTALL"; exit 77; }

TEST_TMP="$REPO_DIR/target/test-tmp/installer"
rm -rf "$TEST_TMP"
mkdir -p "$TEST_TMP"
cleanup() { rm -rf "$TEST_TMP"; }
trap cleanup EXIT

TMP_HOME="$TEST_TMP/home"
mkdir -p "$TMP_HOME"

fail=0
echo "== 安装器断言 =="

# 1. 首次安装
env HOME="$TMP_HOME" bash "$INSTALL" > "$TEST_TMP/install1.log" 2>&1
echo "  首次 install 退出码=$?"
[[ -x "$TMP_HOME/.local/bin/wpc" ]] || { echo "  ❌ 二进制未落位"; fail=1; }
[[ -f "$TMP_HOME/.local/share/wpc/wpc.bash" ]] || { echo "  ❌ hook 未落位"; fail=1; }
[[ -f "$TMP_HOME/.config/wpc/config.toml" ]] || { echo "  ❌ 配置骨架未生成"; fail=1; }
grep -q "# >>> WPC-HOOK-BEGIN >>>" "$TMP_HOME/.bashrc" || { echo "  ❌ bashrc 标记块未注入"; fail=1; }
echo "  ✅ 首次安装落位正确"

# 2. 幂等：二次安装不重复注入
env HOME="$TMP_HOME" bash "$INSTALL" > "$TEST_TMP/install2.log" 2>&1
n=$(grep -c "# >>> WPC-HOOK-BEGIN >>>" "$TMP_HOME/.bashrc" || true)
if [[ "$n" == "1" ]]; then
    echo "  ✅ 二次 install 幂等（标记块仅 1 组）"
else
    echo "  ❌ 二次 install 重复注入（标记块 $n 组）"
    fail=1
fi

# 3. 新交互 shell 自动激活（用临时 HOME）
ACTIVATE="$TEST_TMP/activate.txt"
cat > "$ACTIVATE" <<'EOF'
type wpc_preexec >/dev/null 2>&1 && echo HOOK_ACTIVE || echo HOOK_MISSING
exit
EOF
AOUT="$TEST_TMP/activate.out"
script -qec "env HOME=$TMP_HOME bash --noprofile -i" /dev/null < "$ACTIVATE" > "$AOUT" 2>&1 || true
if grep -q "HOOK_ACTIVE" "$AOUT"; then
    echo "  ✅ 新 bash -i 中 hook 自动激活"
else
    echo "  ❌ 新 bash -i 中 hook 未激活"
    fail=1
fi

# 4. 卸载：全部移除
env HOME="$TMP_HOME" bash "$UNINSTALL" > "$TEST_TMP/uninstall.log" 2>&1
[[ ! -e "$TMP_HOME/.local/bin/wpc" ]] || { echo "  ❌ 二进制未删除"; fail=1; }
[[ ! -e "$TMP_HOME/.local/share/wpc/wpc.bash" ]] || { echo "  ❌ hook 未删除"; fail=1; }
if grep -q "# >>> WPC-HOOK-BEGIN >>>" "$TMP_HOME/.bashrc"; then
    echo "  ❌ bashrc 标记块未移除"
    fail=1
else
    echo "  ✅ uninstall 全部移除"
fi

echo ""
if [[ $fail -eq 1 ]]; then
    echo "installer: FAIL"
    exit 1
fi
echo "installer: PASS"
exit 0
