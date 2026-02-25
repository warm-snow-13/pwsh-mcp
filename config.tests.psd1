<#
.SYNOPSIS
    Pester configuration file for the project.

.NOTES
    For more information about Pester configuration,
    see https://pester.dev/docs/v5/usage/configuration/

    OutputFormat: JaCoCo | CoverageGutters

#>
@{
    Version       = '5.0'
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
        OutputFormat          = 'CoverageGutters'
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
