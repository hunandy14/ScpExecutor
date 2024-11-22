# 導入主要腳本
. (Join-Path $PSScriptRoot '../ScpExecutor.ps1')

# 測試字串
$testStrings = @"
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir1/File1.txt local_dir2/File2.txt chg@192.168.3.53:~/remote_dir/
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir1/File1.txt chg@192.168.3.53:~/remote_dir2/File2.txt local_dir/
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir1/File1.txt local_dir1/File1.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir2/File2.txt local_dir2/File2.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir1/File1.txt chg@192.168.3.53:~/remote_dir1/File1.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir2/File2.txt chg@192.168.3.53:~/remote_dir2/File2.txt
"@ -split "`r`n" 

# 執行 SCP 命令並獲取 WhatIf 輸出
$results = ScpExecutor RedHat79 Task1 Task2 Task3 Task4 -WhatIf 6>&1
for ($i = 0; $i -lt $results.Count; $i++) {
    $resultStr = $results[$i] -replace "WhatIf: ", ""
    $testStr = $testStrings[$i]
    if ($resultStr -ne $testStr) {
        $color = 'Red'
        Write-Host "預期結果: " -NoNewline -ForegroundColor DarkGray; Write-Host $testStr -ForegroundColor DarkGray
    } else {
        $color = 'Green'
    }
    Write-Host "實際結果: " -NoNewline -ForegroundColor DarkGray; Write-Host $resultStr -ForegroundColor $color
}
 