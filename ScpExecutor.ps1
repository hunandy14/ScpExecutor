function ScpExecutor {
    [CmdletBinding()] [Alias("scpx")]
    Param(
        [Parameter(Position = 0, Mandatory)]
        [string]$ServerConfigName,
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
    if (-not (Test-Path $ServerConfigPath)) { throw "找不到伺服器設定檔: $ServerConfigPath" }
    if (-not (Test-Path $TaskPath)) { throw "找不到任務設定檔: $TaskPath" }
    $sevr = (ConvertFrom-Yaml -Ordered ((Get-Content $ServerConfigPath) -join "`n")).$ServerConfigName
    if ($null -eq $sevr) { throw "在設定檔中找不到指定的伺服器: $ServerConfigName" }

    # 讀取任務設定
    $task = $TaskName | ForEach-Object {
        $taskConfig = (ConvertFrom-Yaml -Ordered ((Get-Content $TaskPath) -join "`n")).$_
        if ($null -eq $taskConfig) { throw "在任務設定檔中找不到指定的任務: $_" }
        $taskConfig
    }
    
    # 建構 SCP 基本選項
    $scpOptions = $sevr.option.GetEnumerator() | ForEach-Object {
        "-o$($_.Key)=$($_.Value)"
    }
    
    # 處理每個任務
    foreach ($t in $task) {
        switch ($t.mode) {
            'put' {
                # 處理多行的本地檔案路徑
                $localFiles = $t.local -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                
                # 處理遠端路徑
                if ($t.remote -notmatch "`n") {
                    # 單一目標目錄模式
                    $remoteTarget = "$($sevr.user)@$($sevr.host):$($t.remote.Trim())"
                    $scpCommand = "scp $scpOptions $($localFiles -join ' ') $remoteTarget"
                    Write-Verbose $scpCommand
                    Invoke-Expression $scpCommand
                }
                else {
                    # 一對一模式
                    $remoteFiles = $t.remote -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    for ($i = 0; $i -lt $localFiles.Count; $i++) {
                        $remoteTarget = "$($sevr.user)@$($sevr.host):$($remoteFiles[$i])"
                        $scpCommand = "scp $scpOptions $($localFiles[$i]) $remoteTarget"
                        Write-Verbose $scpCommand
                        Invoke-Expression $scpCommand
                    }
                }
            }
            'get' {
                # 處理遠端檔案路徑
                $remoteFiles = $t.remote -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                if ($t.local -notmatch "`n") {
                    # 多檔案到單一目錄模式
                    $localTarget = $t.local.Trim()
                    $remoteFiles = $remoteFiles | ForEach-Object {
                        "$($sevr.user)@$($sevr.host):$_"
                    }
                    $scpCommand = "scp $scpOptions $($remoteFiles -join ' ') $localTarget"
                    Write-Verbose $scpCommand
                    Invoke-Expression $scpCommand
                }
                else {
                    # 一對一模式
                    $localFiles = $t.local -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    for ($i = 0; $i -lt $remoteFiles.Count; $i++) {
                        $remoteSource = "$($sevr.user)@$($sevr.host):$($remoteFiles[$i])"
                        $scpCommand = "scp $scpOptions $remoteSource $($localFiles[$i])"
                        Write-Verbose $scpCommand
                        Invoke-Expression $scpCommand
                    }
                }
            }
        }
    }
}

ScpExecutor RedHat79 Task1 Task2 Task3 Task4 -Verbose
