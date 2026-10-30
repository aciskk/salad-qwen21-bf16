# Qwen-Image 2.1 Base BF16 — SaladCloud容器

這個專案包含ComfyUI、Salad ComfyUI API包裝器、啟動腳本、工作流，以及已鎖定並校驗的Qwen LoRA（r5＝風格／轉真人＋三個成人解剖／姿勢候選）；不把約32.44GB的Qwen主模型權重塞進容器映像。

## 固定版本

- ComfyUI：`v0.42.1`
- PyTorch：`2.13.0`
- CUDA：`13.0`
- Salad ComfyUI API：`1.19.2`
- Qwen權重來源：`Comfy-Org/Qwen-Image-2.1`
- Qwen權重Revision：`0217efd1d9c9452e84f6448903d6e21bfa171ffd`

## 映像內建LoRA（r5）

風格／轉真人（沿用 r4）：

- `Qwen21_PhotoAesthetics_v2_a927249f.safetensors`：67,142,272 bytes，SHA256 `7a5f5866911ebb9cdd87a6e647c56389a9e9b014b62d056e3b1dd3bdafabb4b2`
- `Qwen21_Anything2RealCharacters_c4ab5473.safetensors`：318,820,200 bytes，SHA256 `5db4dd2376e6017812bf1189b2fc46e52aaa2c0b7e688faac75e83e1c4dce849`

成人解剖／姿勢候選（r5 新增；**預設工作流仍無 LoRA**）：

- `Qwen21_TheseAlpacas_NSFW_V2_7c7002be.safetensors`：79,744,352 bytes，SHA256 `83aba822ad8ee10a1e836828f5088259d93bce7b5f3419b46dbc0258c2be46a9`（建議強度約 0.8）
- `Qwen21_EasternFemaleAnatomy_v2.1_ecb7288c.safetensors`：318,819,912 bytes，SHA256 `1578418092fd0d82f25478acdc6603d24bd42c52d5098830f884de975dd9f095`（Qwen 2.1 專用檔；**非商用授權**，正式量產前須再核授權）
- `Qwen21_ChatR_UncensoredOmni_v0.1_4c99bdf9.safetensors`：671,151,136 bytes，SHA256 `5991a9845bc5251240febf944f653505a00966515b77073f2c639c4dfcba672a`（作者常用 CFG 4／25 steps，與現行 CFG 1 工作流差異大，先 A/B）

五個檔案固定在`/opt/ComfyUI/models/loras/`。它們在GitHub Actions建置映像時下載並校驗，容器每次啟動只做本地大小與SHA256核對，不會再從網路下載。預設工作流仍為無LoRA；只有測試／正式凍稿明確加入 LoRA Loader 時才會套用。不下載 Noct-Q 完整微調版。

模型檔案的大小和SHA256記錄在`model-lock.json`。容器每次分配到新節點時會直接下載到ComfyUI模型目錄，下載完成後必須通過大小與SHA256校驗才會啟動API。中斷下載會續傳；若大小正確但雜湊錯誤，會刪除壞檔後由容器重啟重新下載。

## 畫質設定

- 圖像模型：BF16，沒有INT8／FP8／NVFP4量化。
- 文字編碼器：BF16。
- VAE：BF16。
- KV Cache：`dtype=default`，即無損精度。
- 採樣：40 steps、CFG 1、Euler、Simple。
- 輸出尺寸：直圖832×1088、橫圖1088×832。
- 啟動暖機：使用同尺寸、2 steps的專用工作流；正式生圖仍為40 steps。

## 建置方式

本機沒有Docker，因此使用GitHub Actions遠端建置：

1. 建立GitHub Repository。
2. 將此資料夾內容上傳到Repository根目錄。
3. Actions會建立`linux/amd64`映像並推送到：
   `ghcr.io/<GitHub帳號>/salad-qwen21-bf16:comfy0.42.1-qwen2.1-bf16-r5`
4. 第一次完成後把Package設為Public，Salad才能在不保存Registry密碼的情況下拉取。

映像內不含Qwen權重，所以不會超過Salad 35GB壓縮映像限制。模型授權仍是Qwen Research License；測試可以進行，網站商用前須另取得授權。

## Salad建議配置

- RTX 5090 32GB
- High Priority
- 4 vCPU
- 64GB系統記憶體
- 100GB暫存磁碟
- 1 Replica
- AMD64

不要覆蓋原本的`avababy-comfyui-test`。正式部署時另外建立`avababy-qwen21-bf16-test`容器群組。

依使用者要求，任何啟動、停止、重啟或副本變更之前，都必須先告知並等待確認；測試完成後也不能自行關機。

批次腳本默認只做 dry-run。實際送出生圖任務時必須同時提供`--execute`與`--user-confirmed`；遇到OOM會立即停止，其他錯誤連續兩次會停止，已有尺寸正確的PNG可斷點續跑。
