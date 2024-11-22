function ScpExecutor {
    [CmdletBinding(SupportsShouldProcess)] [Alias("scpx")]
    Param(
        [Parameter(Position = 0, Mandatory)]
        [string]$ServerNodeName,
        [Parameter(Position = 1, Mandatory, ValueFromRemainingArguments)]
        [string[]]$TaskName,
        [string]$ServerConfigPath = 'serverConfig.yaml',
        [string]$TaskPath = 'task.yaml'
    )
    
    # 同步 .Net 環境工作目錄
    [IO.Directory]::SetCurrentDirectory(((Get-Location -PSProvider FileSystem).ProviderPath))
    $ServerConfigPath = [System.IO.Path]::GetFullPath($ServerConfigPath)
    $TaskPath = [System.IO.Path]::GetFullPath($TaskPath)
    
    # 讀取伺服器設定
    if (-not (Test-Path $ServerConfigPath)) { throw "Server config file not found: $ServerConfigPath" }
    if (-not (Test-Path $TaskPath)) { throw "Task config file not found: $TaskPath" }
    $server = (ConvertFrom-Yaml -Ordered ((Get-Content $ServerConfigPath) -join "`n")).$ServerNodeName
    if ($null -eq $server) { throw "Specified server not found in config: $ServerNodeName" }

    # 讀取任務設定並預處理路徑
    $task = $TaskName | ForEach-Object {
        $taskConfig = (ConvertFrom-Yaml -Ordered ((Get-Content $TaskPath) -join "`n")).$_
        if ($null -eq $taskConfig) { throw "Specified task not found in task config: $_" }
        
        # 預處理路徑
        $taskConfig.local = @($taskConfig.local -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
        $taskConfig.remote = @($taskConfig.remote -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
        
        # 預處理所有遠端路徑，無論是 get 還是 put 模式
        if ($taskConfig.remote.Count -eq 1) {
            $taskConfig.remote = @("$($server.user)@$($server.host):$($taskConfig.remote[0])")
        } else {
            $taskConfig.remote = $taskConfig.remote | ForEach-Object { "$($server.user)@$($server.host):$_" }
        }
        
        $taskConfig
    }
    
    # 建構 SCP 基本選項 (使用有序雜湊表)
    $scpOptions = [ordered]@{}
    $server.option.GetEnumerator() | ForEach-Object {
        $scpOptions[$_.Key] = $_.Value
    }
    
    # 新增輔助函數來處理 SCP 命令執行
    function Invoke-ScpCommand {
        param($Options, $Source, $Target)
        if ($null -eq $Source -or $null -eq $Target) {
            throw "Source or target incomplete: Source=$($Source), Target=$($Target)"
        }
        if ($WhatIfPreference) {
            $scpCommand = "scp $($Options -join ' ') $Source $Target"
            Write-Host "WhatIf: $scpCommand" -ForegroundColor DarkCyan
        } else {
            scp $Options $Source $Target
        }
    }
    
    # 處理每個任務
    foreach ($t in $task) {
        # 根據模式決定源和目標
        $source = @(if ($t.mode -eq 'put') { $t.local } else { $t.remote })
        $target = @(if ($t.mode -eq 'put') { $t.remote } else { $t.local })
        
        # 建立基本選項陣列
        $options = @($scpOptions.GetEnumerator() | ForEach-Object { "-o$($_.Key)=$($_.Value)" })
        
        # 預處理源和檢查目標數量是否相等
        if ($target.Count -eq 1) {
            $source = @(,$source)
        } elseif ($source.Count -ne $target.Count) {
            throw "Source and target count mismatch: Source=$($source.Count), Target=$($target.Count)"
        }
        
        # 執行 SCP 命令
        for ($i = 0; $i -lt $source.Count; $i++) {
            Invoke-ScpCommand -Options $options -Source $source[$i] -Target $target[$i]
        }
    }
} # ScpExecutor RedHat79 Task1 -WhatIf
