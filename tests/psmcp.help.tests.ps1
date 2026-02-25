<#
.SYNOPSIS
Validates that public functions from module manifest have complete help documentation.
#>

BeforeAll {
    $script:moduleName = 'pwsh.mcp'
    $script:manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/pwsh.mcp/pwsh.mcp.psd1'

    # Import module and get expected functions from manifest
    $manifest = Import-PowerShellDataFile -Path $script:manifestPath
    $script:expectedFunctions = $manifest.FunctionsToExport

    Import-Module -Name $script:manifestPath -Force -ErrorAction Stop
}

Describe 'Public Functions Help Quality' -Tag HelpQuality {

    It 'Manifest declares at least one function to export' {
        $script:expectedFunctions | Should -Not -BeNullOrEmpty
        $script:expectedFunctions.Count | Should -BeGreaterThan 0
    }

    It 'Every manifest function is accessible and has complete help documentation' {
        foreach ($functionName in $script:expectedFunctions) {
            # Verify function is accessible
            $function = Get-Command -Name $functionName -Module $script:moduleName -ErrorAction Stop
            $function | Should -Not -BeNullOrEmpty -Because "$functionName must be exported"

            # Get help content
            $helpContent = $function.ScriptBlock.Ast.GetHelpContent()
            $helpContent | Should -Not -BeNullOrEmpty -Because "$functionName must have comment-based help"

            # Validate required help sections
            $helpContent.Synopsis | Should -Not -BeNullOrEmpty -Because "$functionName must have .SYNOPSIS"
            $helpContent.Synopsis.Trim() | Should -Not -BeNullOrEmpty

            $helpContent.Description | Should -Not -BeNullOrEmpty -Because "$functionName must have .DESCRIPTION"

            $helpContent.Examples | Should -Not -BeNullOrEmpty -Because "$functionName must have .EXAMPLE"
            $helpContent.Examples.Count | Should -BeGreaterThan 0
        }
    }
}

