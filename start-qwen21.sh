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
  local reserve_bytes=5000000000
  local partial_size=0
  local remaining_bytes=0
  local available_bytes=0

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

  if [[ -f "${partial}" ]]; then
    partial_size="$(stat -c '%s' "${partial}")"
    if (( partial_size > expected_size )); then
      log "Oversized partial file will be discarded: ${relative_path}"
      rm -f "${partial}"
      partial_size=0
    fi
  fi

  remaining_bytes=$((expected_size - partial_size))
  available_bytes="$(df -PB1 "${MODEL_ROOT}" | awk 'NR==2 {print $4}')"
  if (( available_bytes < remaining_bytes + reserve_bytes )); then
    log "Not enough free disk for ${relative_path}: ${available_bytes} bytes available, $((remaining_bytes + reserve_bytes)) required including reserve"
    return 1
  fi

  if (( partial_size < expected_size )); then
    log "Downloading ${relative_path} (${partial_size}/${expected_size} bytes already present)"
    curl --location --fail --show-error --silent \
      --retry 8 --retry-delay 5 --retry-all-errors \
      --continue-at - --output "${partial}" "${url}"
  else
    log "A complete partial file is present; verifying ${relative_path}"
  fi

  if [[ "$(stat -c '%s' "${partial}")" != "${expected_size}" ]]; then
    log "Size mismatch for ${relative_path}; removing partial file"
    rm -f "${partial}"
    return 1
  fi

  if ! printf '%s  %s\n' "${expected_sha256}" "${partial}" | sha256sum --check --status; then
    log "SHA256 mismatch for ${relative_path}; removing corrupt partial file"
    rm -f "${partial}" "${marker}"
    return 1
  fi
  mv -f "${partial}" "${destination}"
  printf '%s' "${expected_sha256}" > "${marker}"
  log "Verified ${relative_path}"
}

verify_baked_file() {
  local relative_path="$1"
  local expected_size="$2"
  local expected_sha256="$3"
  local destination="${MODEL_ROOT}/${relative_path}"

  if [[ ! -f "${destination}" ]]; then
    log "Required baked file is missing: ${relative_path}"
    return 1
  fi
  if [[ "$(stat -c '%s' "${destination}")" != "${expected_size}" ]]; then
    log "Size mismatch for baked file: ${relative_path}"
    return 1
  fi
  if ! printf '%s  %s\n' "${expected_sha256}" "${destination}" | sha256sum --check --status; then
    log "SHA256 mismatch for baked file: ${relative_path}"
    return 1
  fi
  log "Verified baked file: ${relative_path}"
}

mkdir -p "${MODEL_ROOT}"

verify_baked_file \
  "loras/Qwen21_PhotoAesthetics_v2_a927249f.safetensors" \
  "67142272" \
  "7a5f5866911ebb9cdd87a6e647c56389a9e9b014b62d056e3b1dd3bdafabb4b2"

verify_baked_file \
  "loras/Qwen21_Anything2RealCharacters_c4ab5473.safetensors" \
  "318820200" \
  "5db4dd2376e6017812bf1189b2fc46e52aaa2c0b7e688faac75e83e1c4dce849"

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
