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
                $source = $t.local
                $target = $t.remote
            }
            'get' {
                $source = $t.remote
                $target = $t.local
            }
        }
        
        switch ($t.mode) {
            'put' {
                # 處理來源檔案路徑
                $sourcePath = $source -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                if ($target -notmatch "`n") {
                    $targetPath = "$($sevr.user)@$($sevr.host):$($target.Trim())"
                    $scpCommand = "scp $scpOptions $($sourcePath -join ' ') $targetPath"
                    Write-Output $scpCommand
                } else {
                    $targetPath = $target -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    for ($i = 0; $i -lt $sourcePath.Count; $i++) {
                        $target = "$($sevr.user)@$($sevr.host):$($targetPath[$i])"
                        $scpCommand = "scp $scpOptions $($sourcePath[$i]) $target"
                        Write-Output $scpCommand
                    }
                }
            }
            'get' {
                # 處理來源檔案路徑
                $sourcePath = $source -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                if ($target -notmatch "`n") {
                    $sourcePath = @($sourcePath) | ForEach-Object { "$($sevr.user)@$($sevr.host):$_" }
                    $targetPath = $target.Trim()
                    $scpCommand = "scp $scpOptions $($sourcePath -join ' ') $targetPath"
                    Write-Output $scpCommand
                } else {
                    $targetPath = $target -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    for ($i = 0; $i -lt $sourcePath.Count; $i++) {
                        $source = "$($sevr.user)@$($sevr.host):$($sourcePath[$i])"
                        $scpCommand = "scp $scpOptions $source $($targetPath[$i])"
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

