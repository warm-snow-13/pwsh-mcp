<#
.SYNOPSIS
    Pester tests validating the pwsh.mcp module manifest and import behavior.

.DESCRIPTION
    Lightweight, self-contained Pester tests that verify the pwsh.mcp module:
    - Has a valid module manifest (.psd1) and root module (.psm1).
    - Imports and exports expected commands (e.g. New-MCPServer, Add-MCPServer).
    - Contains correct metadata: semantic version, GUID, CompatiblePSEditions, PrivateData tags, LicenseURI.

    Tests are idempotent, clean up module state after run, and target PowerShell 7.4+ for CI and local execution.

#>

BeforeAll {
    Set-Variable -Name data -Scope Script -Option ReadOnly -Value @{
        ModuleName         = 'pwsh.mcp'
        ManifestGuid       = 'e1c2a545-8acd-4493-a80e-bfd3494c001f'
        ModuleManifestPath = "$PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psd1"
        ModulePath         = "$PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psm1"
        ProjectUri         = 'https://github.com/warm-snow-13/pwsh-mcp'
        LicenseUri         = 'https://github.com/warm-snow-13/pwsh-mcp/blob/main/LICENSE'
    }
}

Describe "$($Script:data.moduleName) Module Tests" -Tag 'ModuleStructure' {

    BeforeAll {
        $modulePath = Split-Path -Path $Script:data.ModuleManifestPath -Parent
        $moduleName = Split-Path -Path $Script:data.ModuleManifestPath -LeafBase
        Write-Verbose "Module Name: $moduleName"
        Write-Verbose "Module Path: $modulePath"
    }

    AfterAll {
        # Ensure module is unloaded after all tests to avoid leaking state
        Remove-Module -Name $Script:data.ModuleName -ErrorAction SilentlyContinue
    }

    Context 'Module Setup' {
        It 'Should have a root module' {
            Test-Path $Script:data.ModulePath | Should -Be $true
        }

        It 'Should have an associated manifest' {
            Test-Path $Script:data.ModuleManifestPath | Should -Be $true
        }

        It 'Should be a valid PowerShell code' {
            $psFile = Get-Content -Path $Script:data.ModulePath -Raw -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }

    Context 'Module Control' {
        It 'Should ensure module is not loaded before import in this context' {
            Remove-Module -Name $Script:data.ModuleName -ErrorAction SilentlyContinue
            Get-Module -Name $Script:data.ModuleName | Should -BeNullOrEmpty
        }

        It 'Should import without errors' {
            { Import-Module -Name $Script:data.ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module -Name $Script:data.ModuleName | Should -Not -BeNullOrEmpty
        }

        It 'Should export expected commands' {
            { Import-Module -Name $Script:data.ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
            $commands = Get-Command -Module $Script:data.ModuleName -ErrorAction Stop
            $commands | Should -Not -BeNullOrEmpty
            $commands.Name | Should -Contain 'New-MCPServer'
            $commands.Name | Should -Contain 'Add-MCPServer'
        }

        It 'Should remove without errors' {
            { Remove-Module -Name $Script:data.ModuleName -ErrorAction Stop } | Should -Not -Throw
            Get-Module -Name $Script:data.ModuleName | Should -BeNullOrEmpty
        }
    }
}

Describe 'PSMCP Module Manifest' -Tag 'ModuleManifest' {
    BeforeAll {
        # Cache manifest information to avoid repeated Import/Test calls in each test
        $Script:moduleInformation = Test-ModuleManifest -Path $Script:data.ModuleManifestPath
        $Script:manifestDataFile = Import-PowerShellDataFile -Path $Script:data.ModuleManifestPath
    }

    Context 'Manifest file presence and type' {
        It 'Should have valid module manifest file path' {
            Test-Path $Script:data.ModuleManifestPath | Should -Be $true -Because 'Module manifest path should be defined and exist.'
        }

        It 'Should be a file' {
            $Script:data.ModuleManifestPath | Should -BeOfType 'System.String'
            (Get-Item -Path $Script:data.ModuleManifestPath).PSIsContainer | Should -Be $false
        }

        It 'Should be a valid module manifest' {
            $Script:moduleInformation | Should -BeOfType 'System.Management.Automation.PSModuleInfo'
        }
    }

    Context 'Module Manifest Attributes - Structure and Completeness' {
        It 'Should have valid PowerShell module manifest file structure' {
            {
                $Script:manifestDataFile | Should -Not -BeNullOrEmpty
            } | Should -Not -Throw
        }

        It 'Should have module name matching expected value in manifest' {
            $Script:moduleInformation.Name | Should -Be $Script:data.moduleName
        }

        It 'Should have valid semantic version number in manifest' {
            $Script:moduleInformation.Version -as [Version] | Should -Not -BeNullOrEmpty
            $Script:moduleInformation.Version | Should -Not -BeNullOrEmpty
        }

        It 'Should have non-empty module description in manifest' {
            $Script:moduleInformation.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have correct root module file reference (.psm1)' {
            $Script:moduleInformation.RootModule | Should -Be ($Script:data.moduleName + '.psm1')
        }

        It 'Should have valid GUID matching expected module identifier' {
            $Script:moduleInformation.Guid | Should -Be $Script:data.ManifestGuid
        }

        It 'Should define compatible PowerShell editions' {
            $compatible = @($Script:moduleInformation.CompatiblePSEditions)
            $compatible | Should -Not -BeNullOrEmpty
            $compatible | Should -Contain 'Core'
        }

        It 'Should not export any format files' {
            $Script:moduleInformation.ExportedFormatFiles | Should -BeNullOrEmpty
        }

        It 'Should not have required module dependencies' {
            $Script:moduleInformation.RequiredModules | Should -BeNullOrEmpty
        }

        It 'Should not define a command prefix' {
            $Script:moduleInformation.Prefix | Should -BeNullOrEmpty
        }

        It 'Should have valid copyright information in manifest' {
            $Script:moduleInformation.CopyRight | Should -Not -BeNullOrEmpty
        }

        It 'Should have module author information defined' {
            $Script:moduleInformation.Author | Should -Not -BeNullOrEmpty
        }

        It 'Should have valid license URI in manifest' {
            $Script:moduleInformation.LicenseURI | Should -Not -BeNullOrEmpty
        }

        It 'Should define minimum PowerShell version' {
            $Script:moduleInformation.PowerShellVersion | Should -Not -BeNullOrEmpty
            $PowerShellVersion = $Script:moduleInformation.PowerShellVersion -as [Version]
            $PowerShellVersion | Should -BeOfType 'System.Version'
        }

        It 'Should have expected minimum PowerShellVersion value' {
            ([Version]$Script:moduleInformation.PowerShellVersion) | Should -Be ([Version]'7.4.0')
        }

    }

    Context 'Module Manifest Data - Keys and Values' {
        It 'Should contain required manifest keys' {
            $Script:manifestDataFile | Should -Not -BeNullOrEmpty
            $Script:manifestDataFile.Keys | Should -Contain 'RootModule'
            $Script:manifestDataFile.Keys | Should -Contain 'ModuleVersion'
            $Script:manifestDataFile.Keys | Should -Contain 'Author'
            $Script:manifestDataFile.Keys | Should -Contain 'Description'
        }

        It 'Should have non-empty required values' {
            $Script:manifestDataFile.RootModule | Should -Not -BeNullOrEmpty
            $Script:manifestDataFile.ModuleVersion | Should -Not -BeNullOrEmpty
            $Script:manifestDataFile.Author | Should -Not -BeNullOrEmpty
            $Script:manifestDataFile.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have a valid semantic version' {
            $Script:manifestDataFile.ModuleVersion -as [version] | Should -BeOfType 'System.Version'
        }

        It 'Should return a hashtable from Import-PowerShellDataFile' {
            $Script:manifestDataFile | Should -BeOfType 'System.Collections.Hashtable'
        }

        It 'Should have a valid module manifest' {
            $Script:manifestDataFile | Should -Not -BeNullOrEmpty
            $Script:manifestDataFile.ModuleVersion | Should -Not -BeNullOrEmpty
            $Script:manifestDataFile.RootModule | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Publishing metadata' {
        It 'Should have project URI defined in PrivateData' {
            $Script:moduleInformation.ProjectURI | Should -Not -BeNullOrEmpty
        }

        It 'Should have project URI matching expected GitHub repository URL' {
            $Script:manifestDataFile.PrivateData.PSData.ProjectUri | Should -Be $Script:data.ProjectUri
        }

        It 'Should have license URI matching expected MIT license URL' {
            $Script:manifestDataFile.PrivateData.PSData.LicenseUri | Should -Be $Script:data.LicenseUri
        }

        It 'Should have tags collection defined in PrivateData' {
            $Script:moduleInformation.Tags.count | Should -Not -BeNullOrEmpty
        }

        It 'Should include required discovery tags' {
            $tags = @($Script:manifestDataFile.PrivateData.PSData.Tags)
            $tags | Should -Not -BeNullOrEmpty
            $tags | Should -Contain 'MCP'
            $tags | Should -Contain 'AI'
        }

        It 'Should have non-empty tags array for module categorization' {
            $tags = $Script:manifestDataFile.PrivateData.PSData.Tags
            $tags | Should -Not -BeNullOrEmpty
        }

        It 'Should define non-empty ReleaseNotes when present' {
            $releaseNotes = $Script:manifestDataFile.PrivateData.PSData.ReleaseNotes
            if ($null -ne $releaseNotes) {
                $releaseNotes | Should -Not -BeNullOrEmpty
            }
        }

    }

}

