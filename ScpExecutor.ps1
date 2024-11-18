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
            $taskConfig.remote = @("$($sevr.user)@$($sevr.host):$($taskConfig.remote[0])")
        } else {
            $taskConfig.remote = $taskConfig.remote | ForEach-Object { "$($sevr.user)@$($sevr.host):$_" }
        }
        
        $taskConfig
    }
    
    # 建構 SCP 基本選項 (使用有序雜湊表)
    $scpOptions = [ordered]@{}
    $sevr.option.GetEnumerator() | ForEach-Object {
        $scpOptions[$_.Key] = $_.Value
    }
    
    # 處理每個任務
    foreach ($t in $task) {
        # 根據模式決定源和目標
        $source = @(if ($t.mode -eq 'put') { $t.local } else { $t.remote })
        $target = @(if ($t.mode -eq 'put') { $t.remote } else { $t.local })
        
        # 處理scp命令
        if ($target.Count -eq 1) {
            # 創建新的有序字典而不是使用Clone
            $newOptions = [ordered]@{}
            $scpOptions.GetEnumerator() | ForEach-Object { $newOptions[$_.Key] = $_.Value }
            
            $scpParams = [ordered]@{
                Options = @($newOptions.GetEnumerator() | ForEach-Object { "-o$($_.Key)=$($_.Value)" })
                Sources = $source
                Target  = $target[0]
            }
            
            # 輸出scp命令
            $scpCommand = "scp $($scpParams.Options -join ' ') $($scpParams.Sources -join ' ') $($scpParams.Target)"
            Write-Output $scpCommand
            
            # 執行scp命令
            # scp @($scpParams.Options) @($scpParams.Sources) @($scpParams.Target)
            
        } else {
            for ($i = 0; $i -lt $source.Count; $i++) {
                # 創建新的有序字典而不是使用Clone
                $newOptions = [ordered]@{}
                $scpOptions.GetEnumerator() | ForEach-Object { $newOptions[$_.Key] = $_.Value }
                
                $scpParams = [ordered]@{
                    Options = @($newOptions.GetEnumerator() | ForEach-Object { "-o$($_.Key)=$($_.Value)" })
                    Source  = $source[$i]
                    Target  = $target[$i]
                }
                
                # 輸出scp命令
                $scpCommand = "scp $($scpParams.Options -join ' ') $($scpParams.Source) $($scpParams.Target)"
                Write-Output $scpCommand
                
                # 執行scp命令
                # scp @($scpParams.Options) @($scpParams.Source) @($scpParams.Target)
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

