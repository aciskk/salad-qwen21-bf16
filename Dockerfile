ARG BASE_VARIANT=runtime
ARG PYTORCH_VERSION=2.13.0
ARG CUDA_VERSION=13.0

FROM pytorch/pytorch:${PYTORCH_VERSION}-cuda${CUDA_VERSION}-cudnn9-${BASE_VARIANT}

ARG COMFYUI_VERSION=0.42.1
ARG COMFYUI_API_VERSION=1.19.2
ARG CUDA_VERSION=13.0
ARG TORCHAUDIO_VERSION=2.11.0

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
    WARMUP_PROMPT_FILE=/opt/qwen21/workflows/qwen21-bf16-api.json \
    PORT=3000 \
    STARTUP_CHECK_MAX_TRIES=180 \
    CMD="comfy --workspace /opt/ComfyUI launch -- --listen '*'" \
    BASE="" \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

RUN comfy --skip-prompt tracking disable \
    && comfy --skip-prompt set-default /opt/ComfyUI

WORKDIR /opt
ADD https://github.com/SaladTechnologies/comfyui-api/releases/download/${COMFYUI_API_VERSION}/comfyui-api /opt/comfyui-api

COPY start-qwen21.sh /opt/qwen21/start-qwen21.sh
COPY model-lock.json /opt/qwen21/model-lock.json
COPY workflows/qwen21-bf16-api.json /opt/qwen21/workflows/qwen21-bf16-api.json

RUN chmod 0755 /opt/comfyui-api /opt/qwen21/start-qwen21.sh \
    && mkdir -p /opt/ComfyUI/models/diffusion_models /opt/ComfyUI/models/text_encoders /opt/ComfyUI/models/vae /workflows

EXPOSE 3000

CMD ["/opt/qwen21/start-qwen21.sh"]
