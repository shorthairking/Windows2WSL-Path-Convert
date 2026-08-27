#!/usr/bin/env bash
# =============================================================================
# wpc 统一测试入口（隔离运行）
# 全部测试在子进程中运行：任何 export/cd/source 只影响本进程树，父终端零影响。
# 临时文件一律位于仓库内 target/test-tmp/，测试结束自动清理。
# 用法：bash tests/run_all.sh
# =============================================================================
set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

PASS=0
FAIL=0
SKIP=0

# ---- 环境快照（入口） ----
snapshot_env() {
    {
        echo "WPC_DISABLE=${WPC_DISABLE-unset}"
        echo "WPC_FALLBACK=${WPC_FALLBACK-unset}"
        echo "DEBUG=${DEBUG-unset}"
        echo "PWD=$PWD"
        echo "DEBUG_TRAP=$(trap -p DEBUG 2>/dev/null || echo none)"
    } > "$1"
}

# ---- 记录环境快照文件位置（仓库内） ----
SNAP_DIR="$REPO_DIR/target/test-tmp"
mkdir -p "$SNAP_DIR"
SNAP_BEFORE="$SNAP_DIR/env.before"
SNAP_AFTER="$SNAP_DIR/env.after"
: > "$SNAP_BEFORE"
: > "$SNAP_AFTER"
trap 'rm -rf "$SNAP_DIR"' EXIT

snapshot_env "$SNAP_BEFORE"

echo "== 构建 release（测试对象） =="
cargo build --release

# ---- 运行各测试脚本（均为独立子进程） ----
for t in engine_cli hook_integration installer; do
    echo ""
    echo "########## [$t] ##########"
    if bash "tests/${t}_test.sh"; then
        echo "### [$t] PASS"
        PASS=$((PASS + 1))
    else
        # 区分 SKIP 与 FAIL：脚本以 77 表示跳过
        rc=$?
        if [[ $rc -eq 77 ]]; then
            echo "### [$t] SKIP"
            SKIP=$((SKIP + 1))
        else
            echo "### [$t] FAIL"
            FAIL=$((FAIL + 1))
        fi
    fi
done

# ---- 环境快照（出口）比对，证明子进程未污染可观测状态 ----
snapshot_env "$SNAP_AFTER"
echo ""
echo "== 环境快照比对（应无差异） =="
if diff -u "$SNAP_BEFORE" "$SNAP_AFTER"; then
    echo "环境快照一致 ✅"
else
    echo "⚠️ 环境快照存在差异（见上）"
fi

# ---- 仓库外残留检查（抽样） ----
echo ""
echo "== 仓库外残留检查 =="
LEAK=$(find "$HOME" -maxdepth 2 -newer Cargo.toml -name 'wpc*' 2>/dev/null | grep -v '/new_ideas/path_convert/' || true)
if [[ -z "$LEAK" ]]; then
    echo "仓库外无 wpc 相关新增文件 ✅"
else
    echo "⚠️ 发现仓库外新增：$LEAK"
fi

echo ""
echo "========== 汇总 =========="
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
