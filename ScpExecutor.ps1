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
    
    # 讀取設定檔案
    $sevr = (ConvertFrom-Yaml -Ordered ((Get-Content $ServerConfigPath) -join "`n")).$ServerConfigName
    $task = $TaskName | ForEach-Object {
        (ConvertFrom-Yaml -Ordered ((Get-Content $TaskPath) -join "`n")).$_
    }
    
    
}
