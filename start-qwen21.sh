#!/usr/bin/env bash
set -Eeuo pipefail

MODEL_ROOT="${MODEL_DIR:-/opt/ComfyUI/models}"
REVISION="0217efd1d9c9452e84f6448903d6e21bfa171ffd"
REPO_BASE="https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/${REVISION}"

log() {
  printf '[qwen21-start] %s\n' "$*"
}

download_verified() {
  local relative_path="$1"
  local expected_size="$2"
  local expected_sha256="$3"
  local destination="${MODEL_ROOT}/${relative_path}"
  local partial="${destination}.part"
  local marker="${destination}.sha256-ok"
  local url="${REPO_BASE}/${relative_path}?download=true"

  mkdir -p "$(dirname "${destination}")"

  if [[ -f "${destination}" && -f "${marker}" ]] \
      && [[ "$(stat -c '%s' "${destination}")" == "${expected_size}" ]] \
      && [[ "$(<"${marker}")" == "${expected_sha256}" ]]; then
    log "Using verified cached model: ${relative_path}"
    return
  fi

  if [[ -f "${destination}" ]]; then
    log "Existing unverified model will be replaced: ${relative_path}"
    rm -f "${destination}" "${marker}"
  fi

  log "Downloading ${relative_path} (${expected_size} bytes)"
  curl --location --fail --show-error --silent \
    --retry 8 --retry-delay 5 --retry-all-errors \
    --continue-at - --output "${partial}" "${url}"

  if [[ "$(stat -c '%s' "${partial}")" != "${expected_size}" ]]; then
    log "Size mismatch for ${relative_path}; removing partial file"
    rm -f "${partial}"
    return 1
  fi

  printf '%s  %s\n' "${expected_sha256}" "${partial}" | sha256sum --check --status
  mv -f "${partial}" "${destination}"
  printf '%s' "${expected_sha256}" > "${marker}"
  log "Verified ${relative_path}"
}

mkdir -p "${MODEL_ROOT}"
available_bytes="$(df -PB1 "${MODEL_ROOT}" | awk 'NR==2 {print $4}')"
required_bytes=36000000000
if (( available_bytes < required_bytes )); then
  log "Not enough free disk: ${available_bytes} bytes available, ${required_bytes} required"
  exit 1
fi

download_verified \
  "diffusion_models/qwen_image_2.1_bf16.safetensors" \
  "14230280616" \
  "89f4158d066cc33906a199fca85634f766892dd78f49b6698dabf187ac86c4bc"

download_verified \
  "text_encoders/qwen3vl_8b_bf16.safetensors" \
  "17534334616" \
  "68bdc82bc1b66851162ae656225e7e2068166b603db19bd5d5a3b90eb12669a9"

download_verified \
  "vae/qwen_image_2.1_vae_bf16.safetensors" \
  "675509688" \
  "bb21f7473051e1ac368515dd3f2e15cd44d7a11748ee8823e1ddca3e4876b7c9"

log "All BF16 model files are ready; starting ComfyUI API"
exec /opt/comfyui-api

