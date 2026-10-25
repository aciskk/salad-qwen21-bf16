# Qwen-Image 2.1 Base BF16 — SaladCloud容器

這個專案只包含ComfyUI、Salad ComfyUI API包裝器、啟動腳本和工作流，不把約32.44GB的模型權重塞進容器映像。

## 固定版本

- ComfyUI：`v0.42.1`
- PyTorch：`2.13.0`
- CUDA：`13.0`
- Salad ComfyUI API：`1.19.2`
- Qwen權重來源：`Comfy-Org/Qwen-Image-2.1`
- Qwen權重Revision：`0217efd1d9c9452e84f6448903d6e21bfa171ffd`

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
   `ghcr.io/<GitHub帳號>/salad-qwen21-bf16:comfy0.42.1-qwen2.1-bf16-r3`
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
