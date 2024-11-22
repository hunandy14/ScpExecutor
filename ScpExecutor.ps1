# 建構Option選項
function Initialize-Options($ServerConfig) {
    $opts = [ordered]@{}
    $ServerConfig.option.GetEnumerator() | ForEach-Object {
        if ($IsWindows -and $_.Value -match '^~[/\\]') {
            $_.Value = $_.Value -replace('^~', ($env:USERPROFILE).Replace('\', '/'))
        }
        $opts[$_.Key] = $_.Value
        # Write-Host "Option: $($_.Key) = $($_.Value)" -ForegroundColor Yellow
    }
    return $opts
}

# 建構Task任務
function Initialize-Task($TaskConfig, $Server) {
    # 處理路徑
    $TaskConfig.local = @($TaskConfig.local -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $TaskConfig.remote = @($TaskConfig.remote -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    
    # 加入使用者和主機資訊到遠端路徑
    if ($TaskConfig.remote.Count -eq 1) {
        $TaskConfig.remote = @("$($Server.user)@$($Server.host):$($TaskConfig.remote[0])")
    } else {
        $TaskConfig.remote = $TaskConfig.remote | ForEach-Object { "$($Server.user)@$($Server.host):$_" }
    }
    
    return $TaskConfig
}

# 執行SCP命令
function Invoke-ScpCommand($Options, $Source, $Target) {
    # 檢查源和目標是否完整
    if ($null -eq $Source -or $null -eq $Target) { throw "Source or target incomplete: Source=$($Source), Target=$($Target)" }
    
    # 組合SCP命令
    $scpCommand = "scp $($Options -join ' ') $Source $Target"
    
    # 執行命令
    if ($WhatIfPreference) {
        Write-Host "WhatIf: $scpCommand" -ForegroundColor DarkCyan
    } else {
        Write-Host "Executing Command: $scpCommand" -ForegroundColor DarkGray
        scp $Options $Source $Target
        if ($LASTEXITCODE -eq 0) {
            Write-Host "└─ SUCC" -ForegroundColor Green
        } else {
            Write-Host "└─ FAIL" -ForegroundColor Red
        }
    }
}

# 執行所有SCP任務
function Invoke-ScpTasks($Tasks, $Options) {
    foreach ($t in $Tasks) {
        # 根據模式決定源和目標
        $source = @(if ($t.mode -eq 'put') { $t.local } else { $t.remote })
        $target = @(if ($t.mode -eq 'put') { $t.remote } else { $t.local })
        
        # 建立基本選項陣列
        $opts = @($Options.GetEnumerator() | ForEach-Object { "-o$($_.Key)=$($_.Value)" })
        
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
        [string]$ServerNodeName,
        [Parameter(Position = 1, Mandatory, ValueFromRemainingArguments)]
        [string[]]$TaskName,
        [string]$ServerConfigPath = 'serverConfig.yaml',
        [string]$TaskConfigPath = 'taskConfig.yaml'
    )
    
    # 同步 .Net 環境工作目錄
    [IO.Directory]::SetCurrentDirectory(((Get-Location -PSProvider FileSystem).ProviderPath))
    $ServerConfigPath = [IO.Path]::GetFullPath($ServerConfigPath)
    $TaskConfigPath = [IO.Path]::GetFullPath($TaskConfigPath)
    
    # 讀取伺服器設定並建構Options
    if (-not (Test-Path $ServerConfigPath)) { throw "Server config file not found: $ServerConfigPath" }
    $servConf = (ConvertFrom-Yaml -Ordered ((Get-Content $ServerConfigPath -EA Stop) -join "`n")).$ServerNodeName
    if (-not $servConf) { throw "Specified server not found in config: $ServerNodeName" }
    $opts = Initialize-Options -ServerConfig $servConf
    
    # 讀取任務設定並建構Task
    if (-not (Test-Path $TaskConfigPath)) { throw "Task config file not found: $TaskConfigPath" }
    $taskYaml = ConvertFrom-Yaml -Ordered ((Get-Content $TaskConfigPath -EA Stop) -join "`n")
    $tasks = $TaskName | ForEach-Object {
        $taskConf = $taskYaml.$_
        if (-not $taskConf) { throw "Specified task not found in task config: $_" }
        Initialize-Task -TaskConfig $taskConf -Server $servConf
    }
    
    # 執行所有SCP任務
    Invoke-ScpTasks -Tasks $tasks -Options $opts

} # ScpExecutor RedHat79 Task1 -WhatIf
