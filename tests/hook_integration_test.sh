#!/usr/bin/env bash
# =============================================================================
# hook 集成测试（真实交互，隔离）
# 用 script+pty 模拟真实交互 bash，验证无感转换端到端行为。
# 临时 HOME 与输入/输出文件均在仓库内 target/test-tmp/；不触碰真实 ~/.bashrc。
# 退出码：0=通过 1=失败 77=环境不支持（跳过）
# =============================================================================
set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$REPO_DIR/target/release"
HOOK="$REPO_DIR/shell/wpc.bash"

command -v script >/dev/null 2>&1 || { echo "SKIP: 环境无 script(1)，无法提供 pty"; exit 77; }

TEST_TMP="$REPO_DIR/target/test-tmp/hook_integration"
rm -rf "$TEST_TMP"
mkdir -p "$TEST_TMP"
cleanup() { rm -rf "$TEST_TMP"; }
trap cleanup EXIT

TMP_HOME="$TEST_TMP/home"
mkdir -p "$TMP_HOME"
INPUT="$TEST_TMP/input.txt"
OUT="$TEST_TMP/out.txt"

# ---- 构造交互输入（单引号 heredoc 保留反斜杠） ----
cat > "$INPUT" <<'EOF'
export PATH="__BINDIR__:$PATH"
source "__HOOK__"
echo 盘符: C:\Users\x\a.txt
echo 普通: hello
echo 引号空格: "C:\Program Files\Foo"
WPC_DISABLE=1 echo 禁用: C:\a.txt
ls \\server\share\x
echo 之后正常: C:\ok.txt
exit
EOF
sed -i "s|__BINDIR__|$BIN_DIR|g; s|__HOOK__|$HOOK|g" "$INPUT"

# ---- 真实交互运行 ----
script -qec "env HOME=$TMP_HOME bash --noprofile --norc -i" /dev/null < "$INPUT" > "$OUT" 2>&1 || true

fail=0
check() {
    local desc="$1" needle="$2"
    if grep -qF "$needle" "$OUT"; then
        echo "  ✅ $desc"
    else
        echo "  ❌ $desc（未找到：$needle）"
        fail=1
    fi
}

echo "== hook 集成断言 =="
check "盘符路径无感转换" "盘符: /mnt/c/Users/x/a.txt"
check "普通命令无影响" "普通: hello"
check "引号内空格路径转换" "引号空格: /mnt/c/Program Files/Foo"
check "WPC_DISABLE 禁用" "禁用: C:a.txt"
check "UNC 中文提示" "wpc: 无法转换 Windows UNC 路径"
check "UNC 后 hook 仍正常" "之后正常: /mnt/c/ok.txt"

# 防泄漏：输出中不应出现 DEBUG trap 递归报错
if grep -q "can only \`return'" "$OUT"; then
    echo "  ❌ 检测到 return 上下文错误（hook 异常）"
    fail=1
fi

echo ""
if [[ $fail -eq 1 ]]; then
    echo "hook_integration: FAIL"
    exit 1
fi
echo "hook_integration: PASS"
exit 0
