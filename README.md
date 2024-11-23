# ScpExecutor 使用說明文件

## 概述

`ScpExecutor` 是一個 PowerShell 腳本，用於在本地和遠端伺服器之間執行安全文件傳輸（SCP）操作。此腳本使用 YAML 配置檔案來定義伺服器資訊（`serverConfig.yaml`）和任務定義（`taskConfig.yaml`），幫助自動化基於預定義任務的文件傳輸，例如上傳或下載文件或目錄。

## 系統需求

- PowerShell 5.1 或更高版本
- 必須安裝並能夠訪問 OpenSSH 客戶端
- 用於伺服器配置（`serverConfig.yaml`）和任務（`taskConfig.yaml`）的 YAML 檔案

## serverConfig.yaml 文件定義

此檔案包含遠端伺服器的配置資訊。範例：

```yaml
MyServer:
  user: chg
  host: 192.168.1.1
  port: 22
  option:
    IdentityFile: ~/.ssh/id_ed25519
    BatchMode: yes
  log: ./logs/ScpExecutor.log
```

- **user**: 用於連接的 SSH 使用者。
- **host**: 伺服器的主機名稱或 IP 位址。
- **port**: SSH 端口（通常為 22）。
- **option**: 額外的 SSH 選項，例如身份檔案。
- **log**: SCP 操作的日誌檔案存儲路徑。

## taskConfig.yaml 文件定義

此檔案定義了文件傳輸任務。

複數個文件上傳到遠端資料夾：

```yaml
task1:
  mode: put
  local: |-
    local_dir1/File1.txt
    local_dir2/File2.txt
  remote:
    ~/remote_dir/
```

複數個文件下載到本地資料夾：

```yaml
task2:
  mode: get
  local:
    local_dir/
  remote: |-
    ~/remote_dir1/File1.txt
    ~/remote_dir2/File2.txt
```

- **mode**: `put` 表示上傳文件，`get` 表示下載文件。
- **local**: 本地要傳輸的文件或目錄。
- **remote**: SCP 操作的遠端文件或目錄。

此外在 local 與 remote 的多對多設置下，會1對1的將每個文件使用獨立的對話傳輸，可以實現不同資料夾檔案對不同資料夾的傳輸。

```yaml
task4:
  mode: put
  local: |-
    local_dir1/File1.txt
    local_dir2/File2.txt
  remote: |-
    ~/remote_dir1/File1.txt
    ~/remote_dir2/File2.txt
```

> 確保 local 與 remote 的數量是對等的，否則會引發錯誤

## ScpExecutor 使用方式

這個 PowerShell 腳本提供了一個名為 `ScpExecutor` 的函數，其別名為 `scpx`。函數參數包括：

- **ServerNodeName**: 要使用的伺服器配置名稱（必填）。
- **TaskName**: 要執行的任務名稱，這些任務定義在 `taskConfig.yaml` 中（必填）。
- **ServerConfigPath**: 伺服器配置 YAML 檔案的路徑，預設為 `serverConfig.yaml`。
- **TaskConfigPath**: 任務 YAML 檔案的路徑，預設為 `taskConfig.yaml`。

要使用 `ScpExecutor` 函數，請執行以下命令：

```powershell
ScpExecutor -ServerNodeName 'MyServer' -TaskName 'task1'
```

> 該命令將使用名為 `MyServer` 的伺服器配置，來執行 `taskConfig.yaml` 中定義的任務 `task1`。

參數 `TaskName` 也可以接受多個任務名稱，以便一次執行多個任務

```powershell
ScpExecutor -ServerNodeName 'MyServer' -TaskName 'task1','task2'
```

此範例將會執行兩個任務 `task1` 和 `task2`，根據 `taskConfig.yaml` 中的設定上傳或下載相應的文件。
