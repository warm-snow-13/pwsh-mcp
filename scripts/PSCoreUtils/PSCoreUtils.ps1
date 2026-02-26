<#
.SYNOPSIS
 cmdlet:0a07324e-7b26-4255-a912-ebe43b5022be
#>

function utils.format.tests_result {
    <#
    .SYNOPSIS
        Detailed Test Results Output
    .NOTES
        https://pester.dev/docs/usage/output

        $result.getType().fullname -eq 'Pester.Run'
    #>
    [CmdletBinding()]
    param(
        $data
    )

    Write-Verbose -Message ([string]::Format('{0} started.', $MyInvocation.MyCommand.Name))

    if ($PSBoundParameters.Debug) {
        function fn.get_member {
            $data
            | Get-Member
            | Select-Object TypeName, Name, MemberType, Definition
            | Format-Table -Force -AutoSize
        }
    }

    'TEST RESULTS SUMMARY' | Write-Host -ForegroundColor Blue
    $data
    | Select-Object -Property TotalCount, PassedCount, FailedCount, SkippedCount
    | Format-List -Force
    | Out-String
    | Write-Host -ForegroundColor Blue

    'TEST RESULTS DETAILS' | Write-Host -ForegroundColor Blue
    $data
    | Select-Object -Property *, @{name = '_ContainersList'; expression = { ($_.Containers -split ',') -join "`n" } }
    | Select-Object -Property *, @{name = '_TestList'; expression = { ($_.Tests -split ',') -join "`n" } }
    | Select-Object -Property *, @{name = '_PassedList'; expression = { ($_.Passed -split ',') -join "`n" } }
    | Select-Object -Property *, @{name = '_FailedList'; expression = { ($_.Failed -split ',') -join "`n" } }
    | Format-List -Force

    [PSCustomObject]@{
        Result                = $data.Result
        PassedCount           = $data.PassedCount
        SkippedCount          = $data.SkippedCount
        FailedCount           = $data.FailedCount

        CodeCoverage          = $data.CodeCoverage
        CoveragePercent       = $data.CodeCoverage.CoveragePercent
        CoveragePercentTarget = $data.CodeCoverage.CoveragePercentTarget

        ExecutedAt            = $data.ExecutedAt
    }
    | Format-List -Force

    if ($data.CodeCoverage) {

        $coverage = [math]::Round(($data.CodeCoverage.CoveragePercent), 2)
        $target = $data.CodeCoverage.CoveragePercentTarget

        Write-Output "📈 Code Coverage: $coverage %"
        Write-Output "Target: $target%"

        if ($coverage -lt $target) {
            Write-Warning "⚠️ | Code coverage ($coverage %) is below target ($target%)"
        }
        else {
            Write-Host '✅ | Code coverage target met!' -ForegroundColor Green
        }
    }
}

function utils.format.analysis_result {
    <#
    .SYNOPSIS
        Detailed Static Analysis Results Output

    .NOTES

        https://github.com/PowerShell/PSScriptAnalyzer
        https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-scriptanalyzer

        $result.where({ $_.Severity -eq 'Error' }).Count

    #>
    [CmdletBinding()]
    param(
        [System.Object[]]
        $data
    )

    Write-Host 'STATIC ANALYSIS RESULTS DETAILS' -ForegroundColor Blue
    $data
    | Select-Object -Property *
    | Format-List

    Write-Host 'STATIC ANALYSIS RESULTS SUMMARY' -ForegroundColor DarkMagenta
    $data
    | Group-Object -Property Severity
    | ForEach-Object {
        [PSCustomObject]@{
            Severity = $_.Name
            Count    = $_.Count
        }
    }
    | Format-Table -AutoSize
}

function pwsh.get_pwsh_processes {
    [CmdletBinding()]
    param()
    Write-Verbose -Message ([string]::Format('{0} started.', $MyInvocation.MyCommand.Name))

    Get-Process | Where-Object { $_.ProcessName -like '*pwsh*' } | ForEach-Object {
        [PSCustomObject]@{
            Id               = $_.Id
            ProcessName      = $_.ProcessName
            StartTime        = $_.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
            LifeTime_seconds = (New-TimeSpan -Start  ($_.StartTime) -End (Get-Date)).TotalSeconds
            CPU              = $_.CPU
            WS_MB            = $_.WS / 1MB
            Path             = $_.Path -split [system.io.path]::DirectorySeparatorChar | Select-Object -Last 3
        }
    }
    | Select-Object -Property * -OutVariable pwshProcesses
    | Sort-Object StartTime
    | Format-Table -AutoSize

    $pwshProcesses | Measure-Object | ForEach-Object {
        Write-Host ("Total pwsh processes: {0}" -f $_.Count) -ForegroundColor Yellow
    }
}

function vscode.get_tasks {
    <#
    .SYNOPSIS
        List VSCode tasks for PowerShell Core (pwsh)
    #>
    [Alias('Get-VscodeTasksInfo')]
    [CmdletBinding()]
    param(
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        $path = "$PSScriptRoot/.vscode/tasks.json"
    )
    Write-Verbose -Message ([string]::Format('{0} started.', $MyInvocation.MyCommand.Name))

    Get-Content -Path $path -Raw -ea Stop
    | ConvertFrom-Json
    | Select-Object -ExpandProperty tasks
    | ForEach-Object {
        if ($_.type -eq 'shell') {
            [PSCustomObject]@{
                Label   = $_.label
                Type    = $_.type
                Command = $_.command
                Group   = $_.group
                Args    = ($_.args -join ' ')

            }
        }
    }
    | Format-Table -AutoSize -Force

}

function psmcp.new_module_manifest {
    <#
    .SYNOPSIS
        Create module manifest for PSMCP module
    .NOTES
    ---
    - [REF:](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/new-modulemanifest)
    ---
    Description = @'
        PowerShell Model Control Protocol (PSMCP) module for creating and managing MCP servers.
        AI-code co-pilot.
    '@

    TODO: ps-module-manifest
    - Define module versioning strategy (Semantic Versioning recommended).
    - Automate version updates during build/release process.
    - Create a new version object: new Version(major, minor, build, revision);

    #>
    $moduleManifestParams = @{
        Guid                 = 'e1c2a545-8acd-4493-a80e-bfd3494c001f'
        Path                 = 'src/pwsh.mcp/pwsh.mcp.psd1'
        RootModule           = 'pwsh.mcp.psm1'
        CompanyName          = ''
        Author               = 'igor.stepanushko@gmail.com'
        ModuleVersion        = [version]::new(0, 1, 1).ToString()
        Description          = 'MCP PowerShell module for creating MCP servers'
        ErrorAction          = [System.Management.Automation.ActionPreference]::Stop
        FunctionsToExport    = @('*')
        PrivateData          = @{
            Experimental = @{
                Enabled = $false
            }
            Logging      = @{
                EnableFileLogging = $true
                LogLevel          = 'Verbose'
                # LogPath           = "$env:LOCALAPPDATA\PSMCP\logs"
            }
        }
        Tags                 = @(
            'AI',
            'MCP',
            'MCP Server',
            'PowerShell',
            'Module'
        )
        CompatiblePSEditions = 'Core'
        PowerShellVersion    = '7.5.0'
        LicenseUri           = 'https://github.com/warm-snow-13/pwsh-mcp/blob/main/LICENSE'
        IconUri              = 'https://github.com/warm-snow-13/pwsh-mcp/blob/main/docs/assets/psmcp1.png'
        Prerelease           = 'dev'
        HelpInfoUri          = 'https://github.com/warm-snow-13/pwsh-mcp/blob/main/README.md'
        ProjectUri           = 'https://github.com/warm-snow-13/pwsh-mcp'
        # DefaultCommandPrefix = 'Phoenix.'
    }
    New-ModuleManifest @moduleManifestParams -Verbose -ErrorAction Stop
}

function utils.set_version {
    [OutputType([version])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version] $Version,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Major', 'Minor', 'Build')]
        [string] $Part = 'Build',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $IncrementBy = 1
    )

    $major = $Version.Major
    $minor = $Version.Minor
    $build = $Version.Build

    switch ($Part) {
        'Major' {
            return [version]::new($major + $IncrementBy, 0, 0)
        }
        'Minor' {
            return [version]::new($major, $minor + $IncrementBy, 0)
        }
        'Build' {
            return [version]::new($major, $minor, $build + $IncrementBy)
        }
    }
}

function pwsh.set_local_repository {
    <#
    .SYNOPSIS
        Setup a local PowerShell module repository
    #>
    # fallback path:
    # "$HOME/.local/share/powershell/Modules/LocalRepo"
    # "$HOME/Projects/.LocalPSRepository"
    # [IO.DirectoryInfo]::new($context.localRepoPath).FullName
    [CmdletBinding()]
    param()
    $Repo = "$home/Projects/.LocalPSRepository"
    if (-not (Test-Path $Repo)) {
        Write-Host "Creating local repository at $Repo"
        New-Item $Repo -ItemType Directory -Force -Verbose
    }
    else {
        Write-Host "Local repository already exists at $Repo"
    }
    if (Test-Path $Repo) {
        Write-Host "Creating local repository at $Repo"
        Register-PSRepository -Name LocalRepo -SourceLocation $Repo -PublishLocation $Repo -InstallationPolicy Trusted
    }
    <#
    Unregister-PSRepository -Name LocalRepo
    #>
}

function psmcp.update_module_manifest {
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/update-psmodulemanifest
    [CmdletBinding()]
    param (
        [Parameter(
            ValueFromPipeline = $true,
            Mandatory = $true,
            HelpMessage = 'Module info object to update the manifest for.'
        )]
        [System.Management.Automation.PSModuleInfo]
        $moduleInfo,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Prerelease label to set in the module manifest.'
        )]
        [string]
        $Prerelease = $null
    )
    process {
        Write-Verbose -Message ([string]::Format('{0} started.', $MyInvocation.MyCommand.Name))
        $moduleInfo | Select-Object -Property name, version | Format-List -Force | Out-String | Write-Verbose

        $updateModuleManifestParams = [ordered]@{

            Path          = [io.path]::ChangeExtension($moduleInfo.Path, '.psd1')

            ModuleVersion = utils.set_version -version ($moduleInfo.Version) -part 'build'

            Prerelease    = ($PSBoundParameters.Prerelease) ? $Prerelease : $null

            # PrivateData
        }
        Write-Verbose -Message "Update-ModuleManifest parameters: $($updateModuleManifestParams | Out-String)"
        Update-ModuleManifest @updateModuleManifestParams

        # $moduleInfo.Version = $data.ModuleVersion
        # $moduleInfo.Path = $data.Path
        # $moduleInfo
    }
}

function psmcp.publish_module_to_local_repo {
    # -- Publish the PSMCP module to the local repository
    [outputType([void])]
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Base path of the module to publish.',
            ValueFromPipeline = $true
        )]
        $moduleInfo
    )
    process {

        Write-Verbose -Message ([string]::Format('{0} started.', $MyInvocation.MyCommand.Name))
        Write-Verbose "Module: $($moduleInfo.Name)"
        Write-Verbose "Version: $($moduleInfo.Version)"
        Write-Verbose "ModuleBase: $($moduleInfo.ModuleBase) |INFO ⚠️"

        # $moduleInfo
        # | Select-Object -Property * -ExcludeProperty Definition
        # | Format-List -Force
        # | Out-String
        # | Write-Verbose

        $parameters = @{
            Path       = $moduleInfo.ModuleBase
            Repository = "LocalRepo"
        }
        $parameters
        | Format-List -Force
        | Out-String
        | Write-Verbose

        Write-Progress -Activity "Publishing module $($moduleInfo.Name) to LocalRepo" -Status "In Progress"

        Publish-Module @parameters -Verbose:$false -ErrorAction Stop

        Write-Progress -Activity "Publishing module $($moduleInfo.Name) to LocalRepo" -Completed
    }
}

function vscode.get_mcp_servers {
    [Alias('Get-McpServerInfo')]
    [CmdletBinding()]
    param(
        [Alias('Path')]
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Path to the MCP servers configuration file.'
        )]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]
        $ConfigPath = (Join-Path -Path $pwd -ChildPath '.vscode/mcp.json')
    )

    $json = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop

    if (-not $json.servers) {
        Write-Verbose -Message 'No servers found in configuration.'
        return $null
    }

    foreach ($serverName in $json.servers.PSObject.Properties.Name) {

        $server = $json.servers.$serverName

        $serverObject = [ordered]@{
            Name = $serverName
        }

        foreach ($property in $server.PSObject.Properties) {
            $serverObject[$property.Name] = $property.Value
        }

        [PSCustomObject]$serverObject | Write-Output
    }
}

function vscode.add_mcp_server {
    <#
    .SYNOPSIS
        Generate link to register an MCP server in VSCode

    .DESCRIPTION
        This script generates a link that can be used to register a Multi-Channel PowerShell (MCP) server in Visual Studio Code.
        The generated link contains the server definition encoded in the URL format.

    .NOTES

        MCP developer guides describe how to create and register MCP servers in VSCode. The guide allows to use relative to workspace path.
        Example: '${workspaceFolder}/assets/mcp-srv1.ps1'

        For more information, visit:
        https://code.visualstudio.com/api/extension-guides/ai/mcp

    #>
    [Alias('Add-McpServer')]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Full path to the MCP server script file.'
        )]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [Alias('Path')]
        [string]
        $mcpServerFullName
    )

    Write-Verbose "GENERATE VSCODE MCP INSTALL LINK"

    $fileInfo = Get-Item -Path $mcpServerFullName

    $path = $fileInfo.FullName
    $name = $fileInfo.BaseName

    $mcpSrvDefinition = [ordered]@{
        name    = $name
        type    = "stdio"
        command = "pwsh"
        args    = @(
            "-NoLogo",
            "-NoProfile",
            "-File",
            "$path"
        )
    }

    $mcpServerJson = ConvertTo-Json -InputObject $mcpSrvDefinition -Compress
    $mcpServerJsonEncoded = [System.Uri]::EscapeDataString($mcpServerJson)
    $vscodeMcpInstallLink = "vscode:mcp/install?$mcpServerJsonEncoded"

    $vscodeMcpInstallLink | Write-Host -ForegroundColor DarkRed -BackgroundColor Gray

    if ($IsMacOS) {
        open $vscodeMcpInstallLink
    }
    if ($IsWindows) {
        Start-Process $vscodeMcpInstallLink
    }

}


function utils.get_ai_client_data {
    <#
    .SYNOPSIS
        COPILOT-CLI, GEMINI-CLI logs collector

    .NOTES

        PATH:
        $env:HOME/.copilot/logs/
        $env:HOME/.gemini/tmp

        Uri:
        copilot | log  : file:///$env:HOME/.copilot/logs/session-7074ca81-7262-4515-a7ae-90f8cf920534.log
        gemini  | log  : file:///$env:HOME/.gemini/tmp/00deaffb...94cc5d2d4189/logs.json
        gemini  | chat : file:///$env:HOME/.gemini/tmp/00deaffb...94cc5d2d4189/chats/session-2025-12-15T08-42-12.json

        Get-Item Variable:/DebugPreference, Variable:/VerbosePreference
        | Set-Variable -Value ([System.Management.Automation.ActionPreference]::SilentlyContinue) -PassThru
        | Format-Table -Property name, Value

    #>
    [OutputType([PSCustomObject])]
    [Alias('Get-AiClientData')]
    [CmdletBinding()]
    param()

    function IsAiClientLogFile {
        <#
        .SYNOPSIS
            Determines whether a file should be treated as AI client data/log file.
        #>
        param(
            [Parameter(Mandatory)]
            [System.IO.FileInfo]$File
        )

        $validExtensions = '.log', '.txt', '.json', '.session', '.jsonl'
        $specialBaseNames = 'AGENTS', 'GEMINI'

        if ($File.Extension -in $validExtensions) {
            return $true
        }

        if ($File.BaseName -in $specialBaseNames) {
            return $true
        }

        return $false
    }

    Write-Verbose -Message ([string]::Format('{0} started.', $MyInvocation.MyCommand.Name))

    $path = [string[]]@()
    # check user home directory
    $path += Join-Path -Path $env:HOME -ChildPath ".copilot"
    $path += Join-Path -Path $env:HOME -ChildPath ".gemini"
    $path += Join-Path -Path $env:HOME -ChildPath ".codex"
    # also check parent directory of the script location
    $path += Join-Path -Path "$pwd" -ChildPath ".copilot"
    $path += Join-Path -Path "$pwd" -ChildPath ".gemini"
    $path += Join-Path -Path "$pwd" -ChildPath ".codex"

    $path
    | Select-Object -Unique
    | ForEach-Object {

        if (-not (Test-Path -Path $_)) {
            Write-Warning "Path not found: $_"
            return
        }

        Get-ChildItem -Path $_ -Recurse -File
        | Where-Object { $_.DirectoryName -notmatch '.copilot/pkg' }
        | Where-Object { IsAiClientLogFile -File $_ }
        | ForEach-Object {
            # define client by path segment type ".copilot", ".gemini", ".codex"
            $matched = ($_.FullName -split ([System.IO.Path]::DirectorySeparatorChar)).where({ $_ -match '(copilot|gemini|codex)$' })
            $clientSegment = $matched | Select-Object -First 1
            $client = if ($clientSegment) { $clientSegment.TrimStart('.') } else { 'unknown' }

            $type = ($_.BaseName.StartsWith('session')) ? 'session' : $null
            $type = ($_.BaseName -match 'config|settings|preferences') ? 'config' : $type
            $type = ($_.BaseName -in ('AGENTS', 'GEMINI')) ? 'agents' : $type
            $type = ($_.Extension -in ('.log', '.jsonl')) -and (-not $type) ? 'log' : $type

            [PSCustomObject][ordered]@{
                Who           = $client
                Type          = $type
                prefix        = $_.Directory.Name.Substring(0, [math]::Min( $_.Directory.Name.Length, 8))
                LastWriteTime = [string]::Format('{0:yyyy-MM-dd HH:mm:ss}', $_.LastWriteTime)
                Age_Hours     = [math]::Round((Get-Date).Subtract($_.LastWriteTime).TotalHours, 1)
                Length_KB     = [math]::Round($_.Length / 1KB, 2)
                Uri           = [System.Uri]::new($_.FullName).AbsoluteUri.ToLower()
            }
        }

    }

}
