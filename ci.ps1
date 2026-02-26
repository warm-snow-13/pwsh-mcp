<#
.SYNOPSIS
    CI Script for pwsh.mcp Project

.DESCRIPTION
    Continuous Integration script for PS Graphite project.
    This script performs Continuous Integration (CI) tasks for the pwsh.mcp project, including running tests, static analysis, and build processes.

.NOTES

    References:

    ⏺ Pester Configuration Documentation
    https://pester.dev/docs/usage/configuration

    ⏺ Script Analyzer Rules and Recommendations
    https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules-recommendations

#>
#Requires -Version 7.5
#Requires -Modules PSScriptAnalyzer, Pester
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
#Requires -Modules @{ ModuleName='PSScriptAnalyzer'; ModuleVersion='1.24.0' }
#
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Used for CI script output.'
)]
[CmdletBinding(
    HelpUri = 'https://github.com/warm-snow-13/pwsh-mcp/blob/main/README.md'
)]
param(
    [Parameter(
        Mandatory = $false,
        Position = 0,
        HelpMessage = "Action to perform."
    )]
    [ValidateSet(
        'test',
        'analyze',
        'build',
        "hello"
    )]
    [string]
    $action = 'analyze',

    # TODO: add implementation
    [switch]$FailOnWarnings,

    # TODO: add implementation
    [switch]$Quiet,

    [switch]$CI
)

Invoke-Command {
    # Set Debug and Verbose Preferences
    if (-not $PSBoundParameters.Verbose) {
        Get-Item Variable:/VerbosePreference -ErrorAction Stop
        | Set-Variable -Value ([System.Management.Automation.ActionPreference]::SilentlyContinue) -PassThru
        | Format-Table -Property Name, Value -Force
    }
}

# Context: paths and settings
Set-Variable -Name context -Value (
    [PSCustomObject][ordered]@{
        ModuleName            = 'pwsh.mcp'
        ModulePath            = Get-Item -Path "$PSScriptRoot/src/pwsh.mcp" -ea Stop
        TestsPath             = Get-Item -Path "$PSScriptRoot/tests" -ea  Stop

        Action                = $action.ToLower()
        Runner                = $MyInvocation.MyCommand.Path
        FailOnWarnings        = $FailOnWarnings.IsPresent
        Quiet                 = $Quiet.IsPresent
        CI                    = $env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true' -or $CI.IsPresent

        Diagnostics_Stopwatch = [system.diagnostics.stopwatch]::startNew()
        PSVersion             = $PSVersionTable.PSVersion
    }
) -Scope Script -Option Constant -ErrorAction Stop

# Import-Module core utilities
Import-Module "$PSScriptRoot/scripts/PSCoreUtils/PSCoreUtils.psm1" -Force -ErrorAction Stop -Verbose:$false

Write-Verbose "INFO: ACTION: [$action] SELECTED"

if ($context.CI) {
    Write-Host 'CI environment detected: Adjusting configuration.' -ForegroundColor Green
    # WHEN - ci - Adjust configuration for CI environment if needed
    # ci.log - append
}
else {
    Write-Host 'Local environment detected.' -ForegroundColor Green
}

$Quiet = $Quiet -or $context.CI
Write-Host "Quiet Mode: $Quiet" -ForegroundColor Cyan
Write-Host "FailOnWarnings: $FailOnWarnings" -ForegroundColor Cyan

try {

    Write-Verbose "$((Get-Date).TimeOfDay) [BEGIN  ] Starting $($MyInvocation.MyCommand)"

    Write-Progress -Activity "INIT" -Status "INIT"

    Start-Transcript -Force -UseMinimalHeader -Path (
        [io.path]::ChangeExtension(
            $MyInvocation.MyCommand.path,
            ".log"
        )
    ) -ErrorAction silentlyContinue -Verbose

    # automation.git.info : Get git info: branch, commit, status
    $manifest = Import-PowerShellDataFile  "$PSScriptRoot/src/pwsh.mcp/pwsh.mcp.psd1" -ErrorAction Stop
    $manifest
    | Select-Object -Property ModuleName, ModuleVersion, Description, HelpInfoURI
    | Format-List -Force

    switch ($action.ToLower()) {
        'test' {

            Write-Host "🟧 Running Unit Tests with Pester"
            Write-Progress -Activity "RUN TESTS ..."

            $pesterParams = @{
                Configuration = Import-PowerShellDataFile "$PSScriptRoot/config.tests.psd1"
            }
            $testResult = Invoke-Pester @pesterParams -Verbose:$false

            utils.format.tests_result -data $testResult

            if ($testResult.FailedCount) { throw "Test.Result: Failed" }

            Write-Host '✅ All tests passed successfully' # -Level Success
        }
        'analyze' {

            Write-Host "🟧 Running Static Analysis with PSScriptAnalyzer..."
            Write-Progress -Activity "RUN STATIC ANALYSIS ..."

            $analyzerParams = @{
                Settings = Get-Item $PSScriptRoot/config.analyzer.psd1 -Verbose -ErrorAction Stop
                Path     = Get-Item $PSScriptRoot/src -Verbose -ErrorAction Stop
                Recurse  = $true
            }
            [array]$analyzerResult = Invoke-ScriptAnalyzer @analyzerParams

            utils.format.analysis_result -data $analyzerResult

            if ($analyzerResult.where({ $_.Severity -eq 'Error' }).Count) {
                '❌ Static Analysis found issues'
                $analyzerResult.where({ $_.Severity -eq 'Error' })
                | Select-Object -Property *
                | Format-List
                Write-Error "Static Analysis: Failed due to Errors" -ErrorAction Stop
            }

            if ($analyzerResult.where({ $_.Severity -eq 'Warning' }).Count -and $FailOnWarnings.IsPresent) {
                '❌ Static Analysis found Warnings and FailOnWarnings is set'
                $analyzerResult.where({ $_.Severity -eq 'Warning' })
                | Select-Object -Property *
                | Format-List
                Write-Error "Static Analysis: Failed due to Warnings" -ErrorAction Stop
            }

            Write-Host '✅ Static analysis completed successfully with no errors.' # -Level Success
        }
        'build' {
            #0. Prepare Build Directory
            if (-not(Test-Path "$PSScriptRoot/build" -PathType Container)) {
                New-Item -Path "$PSScriptRoot/build" -ItemType Directory -ea Stop
            }
            #1. Update Module Manifest, Increment Version
            $moduleInfo = Import-Module  "$PSScriptRoot/src/pwsh.mcp/pwsh.mcp.psd1" -Force -PassThru -ErrorAction Stop -Verbose:$false
            psmcp.update_module_manifest -moduleInfo $moduleInfo -Verbose
            #2. Publish Module to Local Repo
            Register-PSRepository -Name psmcpRepo -SourceLocation $PSScriptRoot/build -PublishLocation $PSScriptRoot/build -InstallationPolicy Trusted
            Publish-Module -Path "$PSScriptRoot/src/pwsh.mcp" -Repository psmcpRepo
            Unregister-PSRepository -Name psmcpRepo
        }
        'promote' {
            Write-Error -Category NotImplemented "Promote to stable release is not implemented yet."
            # promote.to.stable.release ...
        }
        'docker' {
            Write-Error -Category NotImplemented "Docker build process is not implemented yet."
            # TODO: implement Docker build process
            # docker run -v ${fullDirectory}:${fullDirectory}
        }
        'hello' {
            Write-Host 'PowerShell CI Script' -ForegroundColor Green
        }
        default {
            Write-Warning "Unknown action: $action"
        }
    }
}
catch {
    Write-Warning "ERROR : $($_.Exception.Message)"
    if ($_.InvocationInfo -and $_.InvocationInfo.ScriptLineNumber) {
        Write-Warning "Error Line Number: $($_.InvocationInfo.ScriptLineNumber)"
    }
}
finally {
    <#Do this after the try block regardless of whether an exception occurred or not#>

    Write-Progress -Completed "DONE ..."

    Write-Verbose "[$((Get-Date).TimeOfDay) END    ] Ending $($MyInvocation.MyCommand)"

    Write-Information -MessageData (
        'INFO: Activity Completed in [{0}s].' -f ([int]$context.stopwatch.Elapsed.TotalSeconds)
    ) -InformationAction continue

    $Context | Select-Object -Property * | Format-List -Force

    Stop-Transcript -ea SilentlyContinue

    [array](
        [string]::Format('{0}', $MyInvocation.MyCommand.HelpUri),
        [System.Uri]::new($MyInvocation.MyCommand.Path).AbsoluteUri
    ) | Write-Host -ForegroundColor DarkCyan

    [PSCustomObject]@{
        ID          = [guid]::NewGuid().ToString()
        Description = 'Build Script Execution Completed'
    } | Format-List -Force
}
