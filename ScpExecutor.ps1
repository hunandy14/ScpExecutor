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

    # 讀取任務設定並預處理路徑
    $task = $TaskName | ForEach-Object {
        $taskConfig = (ConvertFrom-Yaml -Ordered ((Get-Content $TaskPath) -join "`n")).$_
        if ($null -eq $taskConfig) { throw "在任務設定檔中找不到指定的任務: $_" }
        
        # 預處理路徑
        $taskConfig.local = @($taskConfig.local -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
        $taskConfig.remote = @($taskConfig.remote -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
        
        # 預處理所有遠端路徑，無論是 get 還是 put 模式
        if ($taskConfig.remote.Count -eq 1) {
            # 單一目標目錄
            $taskConfig.remote = @("$($sevr.user)@$($sevr.host):$($taskConfig.remote[0])")
        } else {
            # 多個目標路徑
            $taskConfig.remote = $taskConfig.remote | ForEach-Object { "$($sevr.user)@$($sevr.host):$_" }
        }
        
        $taskConfig
    }
    
    Write-Host $($task | ConvertTo-Json -Depth 10)
    
    # 建構 SCP 基本選項
    $scpOptions = $sevr.option.GetEnumerator() | ForEach-Object {
        "-o$($_.Key)=$($_.Value)"
    }
    
    # 處理每個任務
    foreach ($t in $task) {
        switch ($t.mode) {
            'put' {
                if ($t.remote.Count -eq 1) {
                    # 單一目標目錄
                    $scpCommand = "scp $scpOptions $($t.local -join ' ') $($t.remote[0])"
                    Write-Output $scpCommand
                } else {
                    # 多個目標路徑
                    for ($i = 0; $i -lt $t.local.Count; $i++) {
                        $scpCommand = "scp $scpOptions $($t.local[$i]) $($t.remote[$i])"
                        Write-Output $scpCommand
                    }
                }
            }
            'get' {
                if ($t.local.Count -eq 1) {
                    # 單一目標目錄
                    $scpCommand = "scp $scpOptions $($t.remote -join ' ') $($t.local[0])"
                    Write-Output $scpCommand
                } else {
                    # 多個目標路徑
                    for ($i = 0; $i -lt $t.remote.Count; $i++) {
                        $scpCommand = "scp $scpOptions $($t.remote[$i]) $($t.local[$i])"
                        Write-Output $scpCommand
                    }
                }
            }
        }
    }
}



$testStr = @"
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir1/File1.txt local_dir2/File2.txt chg@192.168.3.53:~/remote_dir/
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir1/File1.txt chg@192.168.3.53:~/remote_dir2/File2.txt local_dir/
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir1/File1.txt local_dir1/File1.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir2/File2.txt local_dir2/File2.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir1/File1.txt chg@192.168.3.53:~/remote_dir1/File1.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir2/File2.txt chg@192.168.3.53:~/remote_dir2/File2.txt
"@ -split "`n" 

ScpExecutor RedHat79 Task1 Task2 Task3 Task4 | ForEach-Object -Begin { $i = 0 } -Process {
    if ($_ -eq $testStr[$i]) {
        Write-Host "$_" -ForegroundColor Green
    } else {
        Write-Host "$_" -ForegroundColor Red
    }
    $i++
}

