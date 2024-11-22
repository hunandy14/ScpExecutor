# 導入主要腳本
. (Join-Path $PSScriptRoot '../ScpExecutor.ps1')

Describe 'ScpExecutor 測試' {
    BeforeAll {
        # 測試字串
        $script:expectedCommands = @"
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir1/File1.txt local_dir2/File2.txt chg@192.168.3.53:~/remote_dir/
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir1/File1.txt chg@192.168.3.53:~/remote_dir2/File2.txt local_dir/
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir1/File1.txt local_dir1/File1.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes chg@192.168.3.53:~/remote_dir2/File2.txt local_dir2/File2.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir1/File1.txt chg@192.168.3.53:~/remote_dir1/File1.txt
scp -oIdentityFile=C:/Users/hunan/.ssh/id_ed25519 -oBatchMode=yes local_dir2/File2.txt chg@192.168.3.53:~/remote_dir2/File2.txt
"@ -split "`r`n"
    }

    It '測試 Task1: 本地檔案上傳到遠端' {
        $result = ScpExecutor -ServerNodeName RedHat79 Task1 -WhatIf 6>&1
        $actualCommand = $result -replace "WhatIf: ", ""
        $actualCommand | Should -Be $expectedCommands[0]
    }

    It '測試 Task2: 遠端檔案複製到另一個遠端位置' {
        $result = ScpExecutor -ServerNodeName RedHat79 Task2 -WhatIf 6>&1
        $actualCommand = $result -replace "WhatIf: ", ""
        $actualCommand | Should -Be $expectedCommands[1]
    }

    It '測試 Task3: 從遠端下載檔案到本地' {
        $results = ScpExecutor -ServerNodeName RedHat79 Task3 -WhatIf 6>&1
        $results.Count | Should -Be 2
        
        for ($i = 0; $i -lt $results.Count; $i++) {
            $actualCommand = $results[$i] -replace "WhatIf: ", ""
            $actualCommand | Should -Be $expectedCommands[$i + 2]
        }
    }

    It '測試 Task4: 從本地上傳檔案到遠端' {
        $results = ScpExecutor -ServerNodeName RedHat79 Task4 -WhatIf 6>&1
        $results.Count | Should -Be 2
        
        for ($i = 0; $i -lt $results.Count; $i++) {
            $actualCommand = $results[$i] -replace "WhatIf: ", ""
            $actualCommand | Should -Be $expectedCommands[$i + 4]
        }
    }

    It '測試 Task1, Task2, Task3, Task4: 統合一起是否能正確執行' {
        # 執行 SCP 命令並獲取 WhatIf 輸出
        $results = ScpExecutor -ServerNodeName RedHat79 -TaskName Task1,Task2,Task3,Task4 -WhatIf 6>&1
        
        # 驗證結果數量
        $results.Count | Should -Be $expectedCommands.Count

        # 逐一比對每個命令
        for ($i = 0; $i -lt $results.Count; $i++) {
            $actualCommand = $results[$i] -replace "WhatIf: ", ""
            $actualCommand | Should -Be $expectedCommands[$i]
        }
    }
}
