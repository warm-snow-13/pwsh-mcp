# PowerShell script to validate module files

BeforeAll {

    Set-Variable -Name moduleName -Value 'pwsh.mcp' -Scope Script -ErrorAction SilentlyContinue

    $moduleRoot = Join-Path -Path (Get-Location) -ChildPath "src\$moduleName"
    $modulePath = Join-Path -Path $moduleRoot -ChildPath "$moduleName.psm1"

    Get-Item $moduleRoot, $modulePath -ErrorAction Stop

    Write-Verbose "Module Name: $moduleName"
    Write-Verbose "Module Root: $moduleRoot"
    Write-Verbose "Module Path: $modulePath"
}

Describe "pwsh.mcp Module - Code Quality and Compliance" -Tag 'CodeCompliance' {

    Context 'Module Files - Existence and Loadability' {

        It 'Should have module file (.psm1) present in expected location' {
            $true | Should -Be $true
            Test-Path $modulePath | Should -Be $true
        }

        It 'Should load module file without syntax or execution errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }

        It 'Should have module manifest file (.psd1) present' {
            $manifestPath = Join-Path -Path $moduleRoot -ChildPath "$moduleName.psd1"
            Test-Path $manifestPath | Should -Be $true
        }

        It 'Should parse module manifest without errors' {
            $manifestPath = Join-Path -Path $moduleRoot -ChildPath "$moduleName.psd1"
            { Import-PowerShellDataFile $manifestPath } | Should -Not -Throw
        }
    }
}

Describe "pwsh.mcp Project - PowerShell Syntax Validation" -Tag 'CodeCompliance' {

    $scripts = Get-ChildItem $moduleRoot -Include *.ps1, *.psm1, *.psd1 -Recurse

    $testCase = $scripts | ForEach-Object { @{file = $_ } }

    It 'Expected valid PowerShell syntax in <file>' -TestCases $testCase {
        param($file)

        $file.fullname | Should -Exist

        $contents = Get-Content -Path $file.fullname -ErrorAction Stop
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize(
            $contents,
            [ref]$errors
        )
        $errors.Count | Should -Be 0
    }

}
