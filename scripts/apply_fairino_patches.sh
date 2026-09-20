#!/usr/bin/env bash
# Apply the vendor SDK patches needed by the real dual-arm MoveIt bringup.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
vendor_root="${1:-$repo_root/third_party/frcobot_ros2-v3.0.0_robotV3.9.7}"
vendor_root="$(cd -- "$vendor_root" && pwd)"
package=fairino_hardware_v3_9_7
patch_file="$repo_root/third_party/fairino_dual_arm_ip.patch"
gripper_patch="$repo_root/third_party/fairino_gripper_interface.patch"
shared_patch="$repo_root/third_party/fairino_shared_rpc.patch"
command -v patch >/dev/null
target="$vendor_root/$package/src/fairino_hardware_interface.cpp"
[[ -f "$target" ]] || { echo "Missing vendor source: $target" >&2; exit 1; }

if (cd -- "$vendor_root" && patch --batch --fuzz=0 --dry-run -R -p1 < "$patch_file") >/dev/null 2>&1; then
  echo 'Dual-IP patch is already applied.'
else
  backup="$(mktemp "${TMPDIR:-/tmp}/fr3-driver-before-ip.XXXXXXXX.tar.gz")"
  tar -czf "$backup" -C "$vendor_root/$package" \
    CMakeLists.txt fairino_hardware.xml \
    include/fairino_hardware/fairino_hardware_interface.hpp \
    src/fairino_hardware_interface.cpp
  echo "Source backup: $backup"
  (cd -- "$vendor_root" && \
    patch --batch --fuzz=0 --forward --dry-run -p1 < "$patch_file" && \
    patch --batch --fuzz=0 --forward -p1 < "$patch_file")
fi
(cd -- "$vendor_root" && patch --batch --fuzz=0 --dry-run -R -p1 < "$patch_file")

for extra_patch in "$gripper_patch" "$shared_patch"; do
  if (cd -- "$vendor_root" && patch --batch --fuzz=0 --dry-run -R -p1 < "$extra_patch") >/dev/null 2>&1; then
    continue
  fi
  (cd -- "$vendor_root" && patch --batch --fuzz=0 --forward -p1 < "$extra_patch")
done
echo 'PASS: dual-arm SDK, gripper and shared-RPC patches verified. Rebuild the vendor driver before launching.'
