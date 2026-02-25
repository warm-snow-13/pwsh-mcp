<#
.SYNOPSIS
    Validate parameter metadata extraction and classification for `fnSample`.

.DESCRIPTION
    Pester tests that verify extraction of parameter metadata, aliases,
    validation attributes, and classification of PowerShell common parameters
    (including distinguishing internal vs user-visible common parameters)
    using a deterministic sample function `fnSample`.
.NOTES
#>

BeforeAll {

    function fnSample {
        <#
        .SYNOPSIS
            Provides deterministic output for parameter metadata tests.
        .DESCRIPTION
            Sample advanced function used by InputSchema tests to expose
            different parameter attributes, aliases, and validation rules.
            The body intentionally returns a constant so only metadata is asserted.
        .NOTES
            Scope-limited helper for Pester scenarios; not exported by the module.
        .EXAMPLE
            fnSample -Param1 'alpha' -Param2 42
        .EXAMPLE
            fnSample -Param2 7 -id 'legacy-id'
        .PARAMETER Param1
            Optional string (1-10 chars) used to test aliasing and length checks.
        .PARAMETER Param2
            Optional integer (0-100) that exercises ValidateRange metadata.
        .PARAMETER id
            Obsolete identifier kept to validate annotated parameters.
        .INPUTS
            None. Accepts values only through the defined parameters.
        .OUTPUTS
            System.Int32. Always returns 1 to simplify assertions.
        .LINK
            https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core
        .LINK
            https://modelcontextprotocol.io/specification/2025-11-25/server/tools
        .ROLE
            QA.Automation.Author
        .FUNCTIONALITY
            ParameterMetadataExtraction
        #>
        # HelpURI = 'https://modelcontextprotocol.io/specification/2025-11-25/server/tools',
        [Alias('dbgData', 'debugInfo')]
        # [version('1.0.0')]
        # [Definition("Get debug data for analysis.")]
        [outputtype([System.Int32])]
        [CmdletBinding(
            SupportsShouldProcess = $true,
            ConfirmImpact = [System.Management.Automation.ConfirmImpact]::Medium,
            DefaultParameterSetName = 'Default'
        )]
        param(
            [Alias('p1', 'parameterOne', 'firstParam')]
            [Parameter(
                Mandatory = $false,
                Position = 0,
                HelpMessage = 'Description for Param1.'
            )]
            [ValidateLength(1, 10)]
            [ValidateNotNullOrEmpty()]
            [string]
            $Param1,

            [Parameter(
                Mandatory = $false,
                Position = 1,
                HelpMessage = 'Description for Param2.'
            )]
            [ValidateRange(0, 100)]
            [int]
            $Param2,

            [ObsoleteAttribute("This property is obsolete. Use NewProperty instead.")]
            [Parameter(
                Mandatory = $false
            )]
            [string]
            $id
        )
        if ($PSCmdlet.ShouldProcess("fnSample", "Executing function to get debug data.")) {
            Write-Debug -Message (
                [string]::Format('{0} executed with Param1: {1}, Param2: {2}, id: {3}', 'X', $Param1, $Param2, $id)
            )
        }
        return 1
    }

    function fn.getFunctionInfo {
        Get-Item Function:fnSample -OutVariable fi
        | Select-Object -Property * -ExcludeProperty Definition, ScriptBlock
        | Format-List
    }

    function fn.getAllParams {
        <#
        This function should returns:

            Param1
            Param2
            id
            Verbose
            Debug
            ErrorAction
            WarningAction
            InformationAction
            ProgressAction
            ErrorVariable
            WarningVariable
            InformationVariable
            OutVariable
            OutBuffer
            PipelineVariable
            WhatIf
            Confirm

        #>
        Get-Item Function:fnSample -OutVariable fi
        $fi.Parameters.Values
        | Select-Object name -OutVariable commonParams
        $commonParams.Name
    }

    function fn.getInternalCommonParams {
        <#
        This function should returns:

            ErrorVariable
            WarningVariable
            InformationVariable
            OutVariable
            PipelineVariable

        #>
        $attrTypeName = 'System.Management.Automation.Internal.CommonParameters+ValidateVariableName'
        Get-Item Function:fnSample -OutVariable fi
        $fi.Parameters.Values
        | Where-Object {
            $_.Attributes
            | Where-Object {
                $_.GetType().FullName.Equals($attrTypeName)
            }
        }
        | Select-Object name -OutVariable commonParams
        $commonParams.Name
    }

    function fn.getUserParams {
        <#
        This function should returns parameters:

            Param1
            Param2
            id
            Verbose
            Debug
            ErrorAction
            WarningAction
            InformationAction
            ProgressAction
            WarningVariable
            OutBuffer
            WhatIf
            Confirm

        These parameters do not have the internal common parameter attribute:

            ErrorVariable
            InformationVariable
            OutVariable
            PipelineVariable

        $attrTypeName = 'System.Management.Automation.Internal.CommonParameters+ValidateVariableName'

        #>
        $attrTypeName = 'System.Management.Automation.Internal.CommonParameters+ValidateVariableName'
        Get-Item Function:fnSample -OutVariable fi
        $fi.Parameters.Values
        | Where-Object {
            -not (
                $_.Attributes
                | Where-Object { $_.GetType().FullName.Equals($attrTypeName) }
            )
        }
        | Select-Object name -OutVariable userParams
        $userParams.Name
    }

}

Describe 'PowerShell Function Parameters - Extraction and Classification' -Tag 'FunctionParameters' {

    Context 'Function and Alias Existence Validation' {
        It 'Should have fnSample function available in current scope' {
            Get-Command fnSample -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Should have dbgData alias pointing to fnSample function' {
            Get-Command dbgData -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameter Helper Functions - Error-Free Execution' {
        It 'Should execute fn.getFunctionInfo without throwing errors' {
            { fn.getFunctionInfo | Out-Null } | Should -Not -Throw
        }

        It 'Should execute fn.getInternalCommonParams without throwing errors' {
            { fn.getInternalCommonParams | Out-Null } | Should -Not -Throw
        }
    }

    It 'Should return only internal common parameters' {
        $result = fn.getInternalCommonParams
        $result | Should -Not -BeNullOrEmpty
        $expected = @(
            'ErrorVariable'
            'WarningVariable'
            'InformationVariable'
            'OutVariable'
            'PipelineVariable'
        )
        foreach ($e in $expected) {
            $result | Should -Contain $e
        }
    }

    It 'Should return all parameters including user-defined and PowerShell common parameters' {
        $result = fn.getAllParams
        $result | Should -Not -BeNullOrEmpty
        $expected = @(
            'Param1'
            'Param2'
            'id'
            'Verbose'
            'Debug'
            'ErrorAction'
            'WarningAction'
            'InformationAction'
            'ProgressAction'
            'ErrorVariable'
            'WarningVariable'
            'InformationVariable'
            'OutVariable'
            'OutBuffer'
            'PipelineVariable'
            'WhatIf'
            'Confirm'
        )
        foreach ($e in $expected) {
            $result | Should -Contain $e
        }
    }

    It 'Should return user-defined and non-internal common parameters only' {
        $result = fn.getUserParams
        $result | Should -Not -BeNullOrEmpty
        $expected = @(
            'Param1'
            'Param2'
            'id'
            'Verbose'
            'Debug'

            'OutBuffer'
            # 'PipelineVariable'

            'WhatIf'
            'Confirm'
        )
        foreach ($e in $expected) {
            $result | Should -Contain $e
        }
        $notExpected = @(
            'ErrorVariable'
            'WarningVariable'
            'InformationVariable'
            'OutVariable'
            'PipelineVariable'
        )
        foreach ($e in $notExpected) {
            $result | Should -Not -Contain $e
        }
    }

    It 'Should explicitly exclude InternalCommon parameters from user parameters' {
        $result = fn.getUserParams
        $result | Should -Not -BeNullOrEmpty
        $notExpected = @(
            'ErrorVariable'
            'WarningVariable'
            'InformationVariable'
            'OutVariable'
            'PipelineVariable'
        )
        foreach ($e in $notExpected) {
            $result | Should -Not -Contain $e
        }
    }

}
