#!/usr/bin/env bash
set -euo pipefail

printf 'Locating chart and creating temporary render directory\n'
chart_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../chart" && pwd)"
render_dir="$(mktemp -d)"
trap 'printf "Removing temporary render directory\n"; rm -rf -- "$render_dir"' EXIT

check_policy() {
    local label="$1" controller_expected="$2" node_expected="$3"
    shift 3
    local component expected actual output
    printf 'Checking policy: %s\n' "$label"
    for component in controller node; do
        expected="$controller_expected"
        if [[ "$component" == node ]]; then
            expected="$node_expected"
        fi
        output="$render_dir/$component.yaml"
        printf '  Rendering %s workload\n' "$component"
        helm template token-renewal "$chart_dir" --kube-version 1.34.0 \
            --show-only "templates/csi_driver_$component.yaml" "$@" > "$output"
        actual="$(sed -n 's/^[[:space:]]*- "\(--token-renewal-[^"]*\)"$/\1/p' "$output")"
        if [[ "$actual" != "$expected" ]]; then
            printf 'FAIL: %s: expected [%s], received [%s]\n' "$component" "$expected" "$actual" >&2
            exit 1
        fi
        printf '  PASS: %s arguments [%s]\n' "$component" "$actual"
    done
}

check_conflict() {
    local label="$1" component="$2"
    shift 2
    printf 'Checking rejected policy: %s\n' "$label"
    if helm template token-renewal "$chart_dir" --kube-version 1.34.0 "$@" > "$render_dir/error.log" 2>&1; then
        printf 'FAIL: conflicting policy rendered successfully\n' >&2
        exit 1
    fi
    if ! rg -F -- "$component tokenRenewal: interval and percentage are mutually exclusive" "$render_dir/error.log"; then
        cat "$render_dir/error.log" >&2
        exit 1
    fi
    printf '  PASS: conflicting policy rejected\n'
}

check_policy defaults '' ''
check_policy 'global interval' --token-renewal-interval=5m --token-renewal-interval=5m \
    --set tokenRenewal.interval=5m
check_policy 'global percentage' --token-renewal-percentage=80 --token-renewal-percentage=80 \
    --set tokenRenewal.percentage=80
check_policy 'controller override switches mode' --token-renewal-interval=5m --token-renewal-percentage=80 \
    --set tokenRenewal.percentage=80 --set csiController.ovirtController.tokenRenewal.interval=5m
check_policy 'node override switches mode' --token-renewal-interval=5m --token-renewal-percentage=75 \
    --set tokenRenewal.interval=5m --set csiNode.ovirtNode.tokenRenewal.percentage=75
check_policy 'independent overrides' --token-renewal-percentage=70 --token-renewal-percentage=75 \
    --set csiController.ovirtController.tokenRenewal.percentage=70 \
    --set csiNode.ovirtNode.tokenRenewal.percentage=75
check_policy 'override returns to driver default' '' --token-renewal-percentage=80 \
    --set tokenRenewal.percentage=80 --set-string csiController.ovirtController.tokenRenewal.interval=
check_policy 'explicit zero reaches driver validation' --token-renewal-percentage=0 --token-renewal-percentage=0 \
    --set tokenRenewal.percentage=0
check_policy 'null fields use driver defaults' '' '' \
    --set tokenRenewal.interval=null --set tokenRenewal.percentage=null
check_conflict global node --set tokenRenewal.interval=5m --set tokenRenewal.percentage=80
check_conflict controller controller --set csiController.ovirtController.tokenRenewal.interval=5m \
    --set csiController.ovirtController.tokenRenewal.percentage=80
check_conflict node node --set csiNode.ovirtNode.tokenRenewal.interval=5m \
    --set csiNode.ovirtNode.tokenRenewal.percentage=80

printf 'All token renewal rendering checks passed\n'
