# 建構Option選項
function Initialize-Options($remotConfig) {
    $opts = [ordered]@{}
    $remotConfig.option.GetEnumerator() | ForEach-Object {
        if ($IsWindows -and $_.Value -match '^~[/\\]') {
            $_.Value = $_.Value -replace('^~', ($env:USERPROFILE).Replace('\', '/'))
        }
        $opts[$_.Key] = $_.Value
        # Write-Host "Option: $($_.Key) = $($_.Value)" -ForegroundColor Yellow
    }
    return $opts
}

# 建構Task任務
function Initialize-Task($taskConfig, $remoteConfig) {
    # 預處理路徑成陣列
    $taskConfig.local = $taskConfig.local -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $taskConfig.remote = $taskConfig.remote -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    
    # 遠端路徑前綴加上使用者和主機資訊
    $taskConfig.remote = @($taskConfig.remote) | ForEach-Object {
        "$($remoteConfig.user)@$($remoteConfig.host):$_"
    }
    
    return $taskConfig
}

# 執行SCP命令
function Invoke-ScpCommand($options, $source, $target) {
    # 檢查源和目標是否完整
    if ($null -eq $source -or $null -eq $target) { throw "Source or target incomplete: Source=$source, Target=$target" }
    
    # 組合SCP命令
    $scpCommand = "scp $($options -join ' ') $source $target"
    
    # 執行命令
    if ($WhatIfPreference) {
        Write-Host "WhatIf: $scpCommand" -ForegroundColor DarkCyan
    } else {
        Write-Host "Executing Command: $scpCommand" -ForegroundColor DarkGray
        scp $options $source $target
        if ($LASTEXITCODE -eq 0) {
            Write-Host "└─ SUCC" -ForegroundColor Green
        } else {
            Write-Host "└─ FAIL" -ForegroundColor Red
        }
    }
}

# 執行所有SCP任務
function Invoke-ScpTasks($tasks, $options) {
    foreach ($t in $tasks) {
        # 根據模式決定源和目標
        $source = @(if ($t.mode -eq 'put') { $t.local } else { $t.remote })
        $target = @(if ($t.mode -eq 'put') { $t.remote } else { $t.local })
        
        # 建立基本選項陣列
        $opts = @($options.GetEnumerator() | ForEach-Object { "-o$($_.Key)=$($_.Value)" })
        if ($t.option) { $opts = @($t.option) + $opts }
        
        # 預處理源和檢查目標數量是否相等
        if ($target.Count -eq 1) {
            $source = @(,$source)
        } elseif ($source.Count -ne $target.Count) {
            throw "Source and target count mismatch: Source=$($source.Count), Target=$($target.Count)"
        }
        
        # 執行 SCP 命令
        for ($i = 0; $i -lt $source.Count; $i++) {
            Invoke-ScpCommand -Options $opts -Source $source[$i] -Target $target[$i]
        }
    }
}



# SCP執行器
function ScpExecutor {
    [CmdletBinding(SupportsShouldProcess)] [Alias("scpx")]
    Param(
        [Parameter(Position = 0, Mandatory)]
        [string]$RemoteHost,
        [Parameter(Position = 1, Mandatory, ValueFromRemainingArguments)]
        [string[]]$TaskName,
        [string]$ServerConfigPath,
        [string]$TaskConfigPath
    )
    
    # 設定配置文件路徑優先順序：使用者輸入 > 環境變數 > 預設值
    if (-not $ServerConfigPath) { $ServerConfigPath = if ($env:SCPX_SERVER_CONFIG) { $env:SCPX_SERVER_CONFIG } else { 'serverConfig.yaml' } }
    if (-not $TaskConfigPath) { $TaskConfigPath = if ($env:SCPX_TASK_CONFIG) { $env:SCPX_TASK_CONFIG } else { 'taskConfig.yaml' } }
    
    # 同步 .Net 環境工作目錄
    [IO.Directory]::SetCurrentDirectory(((Get-Location -PSProvider FileSystem).ProviderPath))
    $ServerConfigPath = [IO.Path]::GetFullPath($ServerConfigPath)
    if (-not (Test-Path $ServerConfigPath)) { throw "Server config file not found: $ServerConfigPath" }
    $TaskConfigPath = [IO.Path]::GetFullPath($TaskConfigPath)
    if (-not (Test-Path $TaskConfigPath)) { throw "Task config file not found: $TaskConfigPath" }
    
    # 讀取伺服器設定並建構Options
    $remoteCnf = (ConvertFrom-Yaml -Ordered ((Get-Content $ServerConfigPath -EA Stop) -join "`n")).$RemoteHost
    if (-not $remoteCnf) { throw "Specified server not found in config: $RemoteHost" }
    $opts = Initialize-Options $remoteCnf
    
    # 讀取任務設定並建構Task
    $taskYaml = ConvertFrom-Yaml -Ordered ((Get-Content $TaskConfigPath -EA Stop) -join "`n")
    $tasks = $TaskName | ForEach-Object {
        $taskCnf = $taskYaml.$_
        if (-not $taskCnf) { throw "Specified task not found in task config: $_" }
        Initialize-Task $taskCnf $remoteCnf
    }
    
    # 執行所有SCP任務
    Invoke-ScpTasks $tasks $opts
    
} ScpExecutor RedHat79 Task1 -WhatIf
