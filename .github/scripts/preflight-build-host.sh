#!/usr/bin/env bash
#
# preflight-build-host.sh —— 云构建前置检查（构建机/runner 是否满足整包构建要求）
#
# 依据 LineageOS 官方构建文档（lineage-21+ 建议 64 GB RAM、400 GB 存储）与
# 本项目 docs/02 的要求。绝不尝试"在不足的机器上硬编"，而是快速失败并给出明确原因。
#
# 环境变量（可选，用于覆盖门槛）：
#   MIN_DISK_GB   默认 350（源码 + out + ccache 的最低可工作值，官方建议 400）
#   MIN_RAM_GB    默认 32（低于官方 64，但 32 才能勉强整包；不足给警告而非失败）
#
# 退出码：0 通过（可能带警告）；1 不满足，必须换 runner。
set -uo pipefail

MIN_DISK_GB="${MIN_DISK_GB:-350}"
MIN_RAM_GB="${MIN_RAM_GB:-32}"
WORKDIR="${WORKDIR:-$PWD}"

fail=0

disk_avail_gb=$(df -BG --output=avail "${WORKDIR}" 2>/dev/null | tail -n 1 | tr -dc '0-9')
ram_mb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
ram_gb=$((ram_mb / 1024 / 1024))
cpus=$(nproc 2>/dev/null || echo 0)

printf 'runner 资源：CPU=%s，RAM=%s GB，可用磁盘=%s GB（%s）\n' \
    "${cpus}" "${ram_gb}" "${disk_avail_gb:-unknown}" "${WORKDIR}"

if [[ -z "${disk_avail_gb}" ]]; then
    printf 'ERROR: 无法读取磁盘可用空间（df 失败）\n'
    exit 1
fi

if (( disk_avail_gb < MIN_DISK_GB )); then
    printf 'ERROR: 可用磁盘 %s GB < 最低要求 %s GB。\n' "${disk_avail_gb}" "${MIN_DISK_GB}"
    printf '       GitHub 托管标准 runner 只有约 14 GB，无法整包构建 LineageOS。\n'
    printf '       请使用 ≥400 GB 磁盘的 self-hosted runner 或 GitHub larger runner，\n'
    printf '       并在 workflow 的 runner 输入里指定其 label。见 docs/12。\n'
    fail=1
fi

if (( ram_gb > 0 && ram_gb < MIN_RAM_GB )); then
    printf 'WARN: RAM %s GB 低于 %s GB，整包构建可能 OOM（官方 21+ 建议 64 GB）。\n' "${ram_gb}" "${MIN_RAM_GB}"
fi

if (( cpus > 0 && cpus < 8 )); then
    printf 'WARN: CPU 核数 %s 偏少，构建会非常慢。\n' "${cpus}"
fi

if (( fail > 0 )); then
    exit 1
fi

printf 'preflight OK\n'
exit 0
