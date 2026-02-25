<#
.SYNOPSIS
    automation
    cmdlet: 09f6892f-38f7-4ba1-9f78-6e9fa41874bc

.DESCRIPTION
    Jarvis: CI automation script for pwsh.mcp project.

.PARAMETER action
    Action to perform.
    - build: Updates manifest + publishes module to local PSRepository.
    - install: Registers local PSRepository used by build/deploy.
    - deploy: Installs module from the local PSRepository.
    - remove: Uninstalls module from CurrentUser scope.
    - tag: Creates a git annotated tag based on ModuleVersion.
    - clean: Removes local *.log artifacts.
    - hello: Prints basic diagnostics info.

#>
#Requires -Version 7.4
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
#Requires -Modules @{ ModuleName='PSScriptAnalyzer'; ModuleVersion='1.24.0' }
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Used for CI script output.'
)]
[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = 'Low'
)]
param(
    [Parameter(
        HelpMessage = 'Action to perform: build, clean, hello, install, tag...'
    )]
    [validateSet(
        'build',
        'clean',
        'deploy',
        'tag',
        'hello',
        'remove',
        'install'
    )]
    [string]
    $action,

    [Parameter(
        DontShow,
        HelpMessage = 'Stopwatch for measuring elapsed time.'
    )]
    [system.diagnostics.stopwatch]
    $stopWatch = [system.diagnostics.stopwatch]::StartNew()
)
# -- Set Debug and Verbose preferences to Continue --
Get-Item Variable:/DebugPreference, Variable:/VerbosePreference
| Set-Variable -Value ([System.Management.Automation.ActionPreference]::SilentlyContinue) -Verbose -PassThru
| Format-List -Force -Property Name, Value, Description

# -- Determine action to perform --
# $action = ([string]::IsNullOrWhiteSpace($action)) ? 'clean' : $action
Write-Host "action: [$action]"

if (-not $PSBoundParameters.Verbose) {
    Write-Debug -Message (
        [string]::Format(
            '{0} loaded.', $MyInvocation.MyCommand.Name
        )
    )
}

# -- Define script-scoped context variable --
Set-Variable -Name context -Value (
    [ordered]@{

        moduleInfo         = $null

        gitRoot            = Get-Item -Path "$PSScriptRoot" -ErrorAction Stop -Verbose

        src                = Get-Item -Path "$PSScriptRoot/src" -ErrorAction Stop -Verbose
        tests              = Get-Item -Path "$PSScriptRoot/tests" -ErrorAction Stop -Verbose

        localRepoPath      = "$HOME/Projects/.LocalPSRepository"
        localRepoName      = "LocalRepo"

        moduleBase         = Get-Item -Path  "$PSScriptRoot/src/pwsh.mcp" -ErrorAction Stop -Verbose
        moduleManifestPath = Get-Item -Path "$PSScriptRoot/src/pwsh.mcp/pwsh.mcp.psd1" -ErrorAction Stop -Verbose

    }) -Scope Script -Description 'Settings for the pwsh.mcp project.'

# PSCoreUtils | ⚠️ IMPORTANT: force re-import to get the latest version
Write-Verbose "Importing PSCoreUtils ..."
Import-Module "$PSScriptRoot/scripts/PSCoreUtils/PSCoreUtils.psm1" -Force -ErrorAction Stop -Verbose:$false

# PSMCP | ⚠️ IMPORTANT: force re-import to get the latest version
Write-Verbose "Import PSMCP ..."
$context.moduleInfo = Import-Module ($context.moduleManifestPath) -Force -ErrorAction Stop -PassThru -Verbose:$false
$context.moduleInfo
| Select-Object -Property  name, version
| Format-List -Force
| Out-String
| Write-Host -ForegroundColor Cyan

Write-Host "Getting the latest git tag ..."
git --git-dir="$PSScriptRoot/.git" describe --abbrev=0 2>$null

switch ($action.ToLower()) {
    'deploy' {
        # Get module info before installation
        Get-Module -Name pwsh.mcp -ListAvailable
        | Format-List -Force -Property Name, Version, Path, InstalledLocation

        # Install module from local repo
        Install-Module -Name pwsh.mcp -Repository LocalRepo -Scope CurrentUser -AllowPrerelease -Force -Verbose -PassThru
        | Format-List -Force -Property Name, Version, Path, InstalledLocation

        <#
        Find-Module -Name pwsh.mcp -Repository LocalRepo
        | Install-Module -Repository LocalRepo -Scope CurrentUser -AllowPrerelease -Force -Verbose
        #>
    }
    'remove' {
        # Uninstall module
        Write-Verbose "* Uninstalling module"
        Uninstall-Module -Name pwsh.mcp -AllVersions -Force -ErrorAction SilentlyContinue -Verbose
    }
    'build' {

        # $psmcpModule = Import-Module "$PSScriptRoot/src/pwsh.mcp/pwsh.mcp.psd1" -Force -PassThru -ErrorAction Stop
        # $psmcpModule
        # | Select-Object -Property * -ExcludeProperty Definition
        # | Format-List

        '--- Update Module Manifest ---'
        Import-Module  "$PSScriptRoot/src/pwsh.mcp/pwsh.mcp.psd1" -Force -PassThru -ErrorAction Stop -Verbose:$false
        | psmcp.update_module_manifest -Verbose:$false

        '--- Publish Module to Local Repo ---'
        Import-Module "$PSScriptRoot/src/pwsh.mcp/pwsh.mcp.psd1" -Force -PassThru -ErrorAction Stop -Verbose:$false
        | psmcp.publish_module_to_local_repo -Verbose #:$false

        '--- Contents of Local Repo ---'
        Get-ChildItem -Path $context.localRepoPath -ErrorAction SilentlyContinue
        | Sort-Object -Property LastWriteTime -Descending
        | Format-Table -AutoSize -Force -Property Name, Length, LastWriteTime
    }
    'tag' {

        git diff --staged --quiet --exit-code
        if ($LASTEXITCODE -ne 0) {
            throw 'There are staged changes in the repository. Please commit or reset changes.'
        }

        $moduleManifestData = Import-PowerShellDataFile -Path $context.moduleManifestPath.FullName -ErrorAction Stop
        $moduleManifestData.ModuleVersion -as [version]
        $version = $moduleManifestData.ModuleVersion.ToString()

        $tagString = "v$version"
        $messageString = "Release $tagString"
        git tag -a "$tagString" -m "$messageString"

    }
    'clean' {
        Write-Verbose "Cleaning up artifacts ..."
        Get-ChildItem -Path $PSScriptRoot -Filter *.log -Recurse | Remove-Item -Verbose -ErrorAction Stop
    }
    'hello' {
        "Hello, Jarvis!" | Write-Host -ForegroundColor Green

        Write-Verbose "PSMCP module info:"

        Get-Module -Name pwsh.mcp -ListAvailable
        | Select-Object -Property * -ExcludeProperty Definition
        | Format-List -Force

        # git tag --sort=-creatordate
        try {
            $branch = & git rev-parse --abbrev-ref HEAD 2>$null
            $tag = & git describe --tags --abbrev=0 2>$null
            $desc = & git describe --tags --always 2>$null
        }
        catch {
            $tag = $null
        }

        [PSCustomObject]@{
            branch = ($branch ?? [string]::Empty).Trim()
            desc   = ($desc ?? [string]::Empty).Trim()
            tag    = ($tag ?? [string]::Empty).Trim()
        } | Format-List -Force | Out-String | Write-Host -ForegroundColor Yellow
    }
    default {
        Write-Error -Message ([string]::Format('Action "{0}" is not recognized.', $action))
    }
}


<# status; diagnostics #>
return [PSCustomObject][ordered]@{
    # id             = [guid]::NewGuid().ToString()
    name           = $MyInvocation.MyCommand.Name
    action         = $action
    dateTime       = (Get-Date).ToString('u')
    elapsedSeconds = $stopWatch.Elapsed.TotalSeconds
    lastWriteTime  = (Get-Item -Path $MyInvocation.MyCommand.Path).LastWriteTimeUtc
    <#
    diagnostics    = Invoke-Command {
        Invoke-ScriptAnalyzer -Path $MyInvocation.MyCommand.Path
        | Format-List -GroupBy RuleName -Property Extent -Force
        | Out-String
    }
    #>
}
