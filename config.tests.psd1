<#
.SYNOPSIS
    Pester configuration file for the project.

.NOTES
    For more information about Pester configuration,
    see https://pester.dev/docs/usage/configuration

    OutputFormat: JaCoCo

#>
@{
    Version       = '6.0'
    TestDirectory = 'tests'
    Parameters    = @{
        Include = @('*.tests.ps1')
        Exclude = @('*.ignore.tests.ps1')
    }
    Output        = @{
        Verbosity = 'Normal'
        # None, Normal, Detailed
        # CIFormat = 'GithubActions'
    }
    CodeCoverage  = @{
        Enabled               = $true
        Path                  = 'src/pwsh.mcp'
        OutputPath            = 'coverage/TestCoverage.xml'
        OutputFormat          = 'JaCoCo'
        OutputEncoding        = 'UTF8'
        CoveragePercentTarget = 75
        ExcludeTests          = $true
        RecursePaths          = $true
    }
    TestResult    = @{
        Enabled        = $true
        OutputPath     = 'coverage/TestResult.xml'
        OutputFormat   = 'NUnitXml'
        OutputEncoding = 'UTF8'
    }
    Run           = @{
        PassThru = $true
    }
}
