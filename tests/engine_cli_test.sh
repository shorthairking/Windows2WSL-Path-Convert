#!/usr/bin/env bash
# =============================================================================
# 引擎/CLI 真实路径测试（隔离）
# 用 release 二进制对「实际存在的 Windows 路径」做转换，断言结果真实存在，
# 并与 wslpath 对照一致。临时文件仅位于仓库内 target/test-tmp/。
# 退出码：0=通过 1=失败 77=素材缺失（跳过）
# =============================================================================
set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_DIR/target/release/wpc"

[[ -x "$BIN" ]] || { echo "❌ 未找到 $BIN，请先构建（cargo build --release）"; exit 1; }

TEST_TMP="$REPO_DIR/target/test-tmp/engine_cli"
rm -rf "$TEST_TMP"
mkdir -p "$TEST_TMP"
cleanup() { rm -rf "$TEST_TMP"; }
trap cleanup EXIT

# ---- 真实素材探测 ----
declare -a MATERIALS=(
    "file|/mnt/c/AMFTrace.log|C:\\AMFTrace.log"
    "dir|/mnt/c/Windows/System32|C:\\Windows\\System32"
    "dir_space|\"C:\\Program Files\"|C:\\Program Files"
    "dir|/mnt/c/Windows|C:\\Windows"
)

fail=0
skip=0
run_case() {
    local kind="$1" real="$2" win="$3"
    if [[ ! -e "$real" ]]; then
        echo "SKIP: 素材不存在 $real"
        skip=1
        return 0
    fi
    # wpc 逐参数转换
    local conv
    conv="$("$BIN" "$win")"
    echo "  $win -> $conv"
    # 断言：转换结果真实存在
    if [[ "$kind" == "file" ]]; then
        [[ -f "$conv" ]] || { echo "  ❌ 期望为真实文件：$conv"; fail=1; return 0; }
    elif [[ "$kind" == "dir" ]]; then
        [[ -d "$conv" ]] || { echo "  ❌ 期望为真实目录：$conv"; fail=1; return 0; }
    fi
    # 断言：与 wslpath 对照一致
    local ref
    ref="$(wslpath -u "$win")"
    if [[ "$conv" != "$ref" ]]; then
        echo "  ❌ 与 wslpath 不一致：wpc=$conv wslpath=$ref"
        fail=1
        return 0
    fi
    echo "  ✅ 真实路径存在且与 wslpath 一致"
}

# 含空格路径：wslpath 也需引号传入，单独处理
echo "== 用例 1：真实文件 C:\\AMFTrace.log =="
run_case "file" "/mnt/c/AMFTrace.log" 'C:\AMFTrace.log'

echo "== 用例 2：真实目录 C:\\Windows\\System32 =="
run_case "dir" "/mnt/c/Windows/System32" 'C:\Windows\System32'

echo "== 用例 3：含空格真实目录 \"C:\\Program Files\" =="
if [[ -d "/mnt/c/Program Files" ]]; then
    conv="$("$BIN" 'C:\Program Files')"
    echo "  C:\Program Files -> $conv"
    [[ -d "$conv" ]] || { echo "  ❌ 期望为真实目录：$conv"; fail=1; }
    ref="$(wslpath -u 'C:\Program Files')"
    [[ "$conv" == "$ref" ]] || { echo "  ❌ 与 wslpath 不一致：$conv vs $ref"; fail=1; }
    echo "  ✅ 含空格真实目录存在且与 wslpath 一致"
else
    echo "SKIP: 素材不存在 /mnt/c/Program Files"
    skip=1
fi

echo "== 用例 4：真实目录与 wslpath 对照（C:\\Windows） =="
run_case "dir" "/mnt/c/Windows" 'C:\Windows'

echo "== 用例 5：UNC 真实行为（应退出码 1） =="
set +e
"$BIN" '\\server\share\x' >/dev/null 2>&1
rc=$?
set -e
if [[ $rc -eq 1 ]]; then
    echo "  ✅ UNC 返回退出码 1"
else
    echo "  ❌ 期望退出码 1，实际 $rc"
    fail=1
fi

echo "== 用例 6：转义形态 \\\\* 不应判为 UNC（退出码 0） =="
set +e
out="$( "$BIN" --eval-line '[[ $cmd == \\* ]]' 2>&1 )"
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
    echo "  ✅ 转义反斜杠不判为 UNC，退出码 0"
    echo "  输出：$out"
else
    echo "  ❌ 期望退出码 0，实际 $rc"
    echo "  输出：$out"
    fail=1
fi

echo ""
if [[ $fail -eq 1 ]]; then
    echo "engine_cli: FAIL"
    exit 1
fi
if [[ $skip -eq 1 ]]; then
    echo "engine_cli: PASS（含 SKIP 素材）"
fi
echo "engine_cli: PASS"
exit 0
