# 導入主要腳本
. (Join-Path $PSScriptRoot '../ScpExecutor.ps1')

$testStr = @"
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir1/File1.txt local_dir2/File2.txt chg@192.168.3.53:~/remote_dir/
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir1/File1.txt chg@192.168.3.53:~/remote_dir2/File2.txt local_dir/
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir1/File1.txt local_dir1/File1.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir2/File2.txt local_dir2/File2.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir1/File1.txt chg@192.168.3.53:~/remote_dir1/File1.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir2/File2.txt chg@192.168.3.53:~/remote_dir2/File2.txt
"@ -split "`r`n" 

# 執行 SCP 命令並比對結果
$results = ScpExecutor RedHat79 Task1 Task2 Task3 Task4 -WhatIf

# 比對實際輸出與預期結果
for ($i = 0; $i -lt $results.Count; $i++) {
    $isMatch = $results[$i] -eq $testStr[$i]
    $color = if ($isMatch) { 'Green' } else { 'Red' }
    
    if (-not $isMatch) { Write-Host "預期結果: " -NoNewline -ForegroundColor DarkGray; Write-Host $testStr[$i] -ForegroundColor DarkGray }
    Write-Host "實際結果: " -NoNewline -ForegroundColor DarkGray
    Write-Host $results[$i] -ForegroundColor $color
}
