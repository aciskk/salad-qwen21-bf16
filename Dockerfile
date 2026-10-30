ARG BASE_VARIANT=runtime
ARG PYTORCH_VERSION=2.13.0
ARG CUDA_VERSION=13.0

FROM pytorch/pytorch:${PYTORCH_VERSION}-cuda${CUDA_VERSION}-cudnn9-${BASE_VARIANT}

ARG COMFYUI_VERSION=0.42.1
ARG COMFYUI_API_VERSION=1.19.2
ARG CUDA_VERSION=13.0
ARG TORCHAUDIO_VERSION=2.11.0
ARG PHOTO_AESTHETICS_REVISION=a927249f74098c150449ab384ff6ac19137fe029
ARG ANYTHING2REAL_REVISION=c4ab5473bfdf585fc19cfd1e280f79d2b0c79947
ARG THESEALPACAS_REVISION=7c7002be374e75a7b41148ebbae15162c98b2cea
ARG EASTERN_ANATOMY_REVISION=ecb7288cdc4f606643e20fea149c374ceef83525
ARG CHATR_OMNI_REVISION=4c99bdf94798f8c6dfb146ac6d2ff65089aaf563

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    UV_BREAK_SYSTEM_PACKAGES=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir uv \
    && uv pip install --no-cache-dir --system "comfy-cli==1.5.1"

WORKDIR /opt
RUN git clone --depth 1 --branch "v${COMFYUI_VERSION}" https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /opt/ComfyUI
RUN python -c 'import importlib.metadata as m; print("\n".join(f"{p}=={m.version(p)}" for p in ("torch", "torchvision")))' > /opt/pytorch-constraints.txt \
    && uv pip install --no-cache-dir --system -c /opt/pytorch-constraints.txt "torchaudio==${TORCHAUDIO_VERSION}" --index-url "https://download.pytorch.org/whl/cu${CUDA_VERSION//./}" \
    && python -c 'import importlib.metadata as m; print("torchaudio==" + m.version("torchaudio"))' >> /opt/pytorch-constraints.txt \
    && uv pip install --no-cache-dir --system -c /opt/pytorch-constraints.txt -r requirements.txt

ENV COMFY_HOME=/opt/ComfyUI \
    MODEL_DIR=/opt/ComfyUI/models \
    OUTPUT_DIR=/opt/ComfyUI/output \
    INPUT_DIR=/opt/ComfyUI/input \
    WORKFLOW_DIR=/workflows \
    WARMUP_PROMPT_FILE=/opt/qwen21/workflows/qwen21-bf16-warmup-api.json \
    PORT=3000 \
    STARTUP_CHECK_MAX_TRIES=300 \
    CMD="comfy --workspace /opt/ComfyUI launch -- --listen 0.0.0.0" \
    BASE="" \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

RUN comfy --skip-prompt tracking disable \
    && comfy --skip-prompt set-default /opt/ComfyUI

WORKDIR /opt
ADD https://github.com/SaladTechnologies/comfyui-api/releases/download/${COMFYUI_API_VERSION}/comfyui-api /opt/comfyui-api

COPY start-qwen21.sh /opt/qwen21/start-qwen21.sh
COPY model-lock.json /opt/qwen21/model-lock.json
COPY lora-lock.json /opt/qwen21/lora-lock.json
COPY workflows/qwen21-bf16-api.json /opt/qwen21/workflows/qwen21-bf16-api.json
COPY workflows/qwen21-bf16-warmup-api.json /opt/qwen21/workflows/qwen21-bf16-warmup-api.json

RUN set -eux \
    && chmod 0755 /opt/comfyui-api /opt/qwen21/start-qwen21.sh \
    && mkdir -p /opt/ComfyUI/models/diffusion_models /opt/ComfyUI/models/text_encoders /opt/ComfyUI/models/vae /opt/ComfyUI/models/loras /workflows \
    && curl --location --fail --show-error --silent --retry 8 --retry-delay 5 --retry-all-errors \
      --output /opt/ComfyUI/models/loras/Qwen21_PhotoAesthetics_v2_a927249f.safetensors.part \
      "https://huggingface.co/SimpleTuner/Qwen-Image-2.1-LoRA-photo-aesthetics-v2/resolve/${PHOTO_AESTHETICS_REVISION}/pytorch_lora_weights.safetensors?download=true" \
    && test "$(stat -c '%s' /opt/ComfyUI/models/loras/Qwen21_PhotoAesthetics_v2_a927249f.safetensors.part)" = "67142272" \
    && printf '%s  %s\n' \
      '7a5f5866911ebb9cdd87a6e647c56389a9e9b014b62d056e3b1dd3bdafabb4b2' \
      '/opt/ComfyUI/models/loras/Qwen21_PhotoAesthetics_v2_a927249f.safetensors.part' | sha256sum --check --status \
    && mv /opt/ComfyUI/models/loras/Qwen21_PhotoAesthetics_v2_a927249f.safetensors.part \
      /opt/ComfyUI/models/loras/Qwen21_PhotoAesthetics_v2_a927249f.safetensors \
    && curl --location --fail --show-error --silent --retry 8 --retry-delay 5 --retry-all-errors \
      --output /opt/ComfyUI/models/loras/Qwen21_Anything2RealCharacters_c4ab5473.safetensors.part \
      "https://huggingface.co/WarmBloodAban/Qwen-Image-2.1-LoRAs/resolve/${ANYTHING2REAL_REVISION}/Qwen2.1_Anything2RealCharacters.safetensors?download=true" \
    && test "$(stat -c '%s' /opt/ComfyUI/models/loras/Qwen21_Anything2RealCharacters_c4ab5473.safetensors.part)" = "318820200" \
    && printf '%s  %s\n' \
      '5db4dd2376e6017812bf1189b2fc46e52aaa2c0b7e688faac75e83e1c4dce849' \
      '/opt/ComfyUI/models/loras/Qwen21_Anything2RealCharacters_c4ab5473.safetensors.part' | sha256sum --check --status \
    && mv /opt/ComfyUI/models/loras/Qwen21_Anything2RealCharacters_c4ab5473.safetensors.part \
      /opt/ComfyUI/models/loras/Qwen21_Anything2RealCharacters_c4ab5473.safetensors \
    && curl --location --fail --show-error --silent --retry 8 --retry-delay 5 --retry-all-errors \
      --output /opt/ComfyUI/models/loras/Qwen21_TheseAlpacas_NSFW_V2_7c7002be.safetensors.part \
      "https://huggingface.co/Oliver577/NSFW-Qwen-by-TheseAlpacas-V2/resolve/${THESEALPACAS_REVISION}/NSFW%20Qwen%20by%20TheseAlpacas%20V2.safetensors?download=true" \
    && test "$(stat -c '%s' /opt/ComfyUI/models/loras/Qwen21_TheseAlpacas_NSFW_V2_7c7002be.safetensors.part)" = "79744352" \
    && printf '%s  %s\n' \
      '83aba822ad8ee10a1e836828f5088259d93bce7b5f3419b46dbc0258c2be46a9' \
      '/opt/ComfyUI/models/loras/Qwen21_TheseAlpacas_NSFW_V2_7c7002be.safetensors.part' | sha256sum --check --status \
    && mv /opt/ComfyUI/models/loras/Qwen21_TheseAlpacas_NSFW_V2_7c7002be.safetensors.part \
      /opt/ComfyUI/models/loras/Qwen21_TheseAlpacas_NSFW_V2_7c7002be.safetensors \
    && curl --location --fail --show-error --silent --retry 8 --retry-delay 5 --retry-all-errors \
      --output /opt/ComfyUI/models/loras/Qwen21_EasternFemaleAnatomy_v2.1_ecb7288c.safetensors.part \
      "https://huggingface.co/perpetual3x/Eastern-European-Female-Anatomy-NSFW-LoRA-v2/resolve/${EASTERN_ANATOMY_REVISION}/easternfemale_v2.1.safetensors?download=true" \
    && test "$(stat -c '%s' /opt/ComfyUI/models/loras/Qwen21_EasternFemaleAnatomy_v2.1_ecb7288c.safetensors.part)" = "318819912" \
    && printf '%s  %s\n' \
      '1578418092fd0d82f25478acdc6603d24bd42c52d5098830f884de975dd9f095' \
      '/opt/ComfyUI/models/loras/Qwen21_EasternFemaleAnatomy_v2.1_ecb7288c.safetensors.part' | sha256sum --check --status \
    && mv /opt/ComfyUI/models/loras/Qwen21_EasternFemaleAnatomy_v2.1_ecb7288c.safetensors.part \
      /opt/ComfyUI/models/loras/Qwen21_EasternFemaleAnatomy_v2.1_ecb7288c.safetensors \
    && curl --location --fail --show-error --silent --retry 8 --retry-delay 5 --retry-all-errors \
      --output /opt/ComfyUI/models/loras/Qwen21_ChatR_UncensoredOmni_v0.1_4c99bdf9.safetensors.part \
      "https://huggingface.co/chatrlabs/Qwen-Image-2.1-Uncensored-Omni-LoRA-v0.1/resolve/${CHATR_OMNI_REVISION}/chatrlabs-omni-lora-v0.1-bf16.safetensors?download=true" \
    && test "$(stat -c '%s' /opt/ComfyUI/models/loras/Qwen21_ChatR_UncensoredOmni_v0.1_4c99bdf9.safetensors.part)" = "671151136" \
    && printf '%s  %s\n' \
      '5991a9845bc5251240febf944f653505a00966515b77073f2c639c4dfcba672a' \
      '/opt/ComfyUI/models/loras/Qwen21_ChatR_UncensoredOmni_v0.1_4c99bdf9.safetensors.part' | sha256sum --check --status \
    && mv /opt/ComfyUI/models/loras/Qwen21_ChatR_UncensoredOmni_v0.1_4c99bdf9.safetensors.part \
      /opt/ComfyUI/models/loras/Qwen21_ChatR_UncensoredOmni_v0.1_4c99bdf9.safetensors

EXPOSE 3000

CMD ["/opt/qwen21/start-qwen21.sh"]
