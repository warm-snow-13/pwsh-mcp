<#
.SYNOPSIS
    PSScriptAnalyzer configuration
.DESCRIPTION
    file: config.analyzer.psd1
.NOTES
    ---
    For more information about Invoke-ScriptAnalyzer, see:
    https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-scriptanalyzer
    ---
    For more information about PSScriptAnalyzer configuration files, see:
    https://github.com/PowerShell/PSScriptAnalyzer/blob/main/docs/Rules/README.md
    ---
    PSScriptAnalyzer rules reference:
    https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/readme
    https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules-recommendations
    ---
#>
@{
    IncludeRules = @(
        'PSAlignAssignmentStatement',
        'PSAvoidAssignmentToAutomaticVariable',
        'PSAvoidDefaultValueForMandatoryParameter',
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidExclaimOperator',
        'PSAvoidGlobalAliases',
        'PSAvoidGlobalFunctions',
        'PSAvoidGlobalVars',
        'PSAvoidInvokingEmptyMembers',
        'PSAvoidLongLines',
        'PSAvoidMultipleTypeAttributes',
        'PSAvoidNullOrEmptyHelpMessageAttribute',
        'PSAvoidOverwritingBuiltInCmdlets',
        'PSAvoidSemicolonsAsLineTerminators',
        'PSAvoidShouldContinueWithoutForce',
        'PSAvoidTrailingWhitespace',
        'PSAvoidUsingAllowUnencryptedAuthentication',
        'PSAvoidUsingBrokenHashAlgorithms',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingComputerNameHardcoded',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSAvoidUsingDoubleQuotesForConstantString',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSAvoidUsingWMICmdlet',
        'PSAvoidUsingWriteHost',
        'PSMisleadingBacktick',
        'PSMissingModuleManifestField',
        'PSPlaceCloseBrace',
        'PSPlaceOpenBrace',
        'PSPossibleIncorrectComparisonWithNull',
        'PSPossibleIncorrectUsageOfAssignmentOperator',
        'PSPossibleIncorrectUsageOfRedirectionOperator',
        'PSProvideCommentHelp',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSReviewUnusedParameter',
        'PSShouldProcess',
        'PSUseApprovedVerbs',
        'PSUseBOMForUnicodeEncodedFile',
        'PSUseCmdletCorrectly',
        'PSUseCompatibleCmdlets',
        'PSUseCompatibleCommands',
        'PSUseCompatibleSyntax',
        'PSUseCompatibleTypes',
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace',
        'PSUseCorrectCasing',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseLiteralInitializerForHashtable',
        'PSUseOutputTypeCorrectly',
        'PSUseProcessBlockForPipelineCommand',
        'PSUsePSCredentialType',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns',
        'PSUseSupportsShouldProcess',
        'PSUseToExportFieldsInManifest',
        'PSUseUsingScopeModifierInNewRunspaces',
        'PSUseUTF8EncodingForHelpFile'
    )
    Rules        = @{
        PSUseCompatibleSyntax  = @{
            Enable        = $false
            TargetVersion = @(
                '7.5',
                '7.0'
            )
        }
        # https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/providecommenthelp
        PSProvideCommentHelp   = @{
            Enable                  = $true
            ExportedOnly            = $true
            BlockComment            = $true
            VSCodeSnippetCorrection = $false
            Placement               = 'before'
        }
        PSUseCorrectCasing     = @{
            Enable        = $true
            CheckCommands = $true
            CheckKeyword  = $true
            CheckOperator = $true
        }
        PSAvoidLongLines       = @{
            Enable            = $false
            MaximumLineLength = 120
        }
        PSUseCompatibleCmdlets = @{
            Compatibility = @(
                'core-7.5.0',
                'core-7.1.0'
            )
        }
    }
    ExcludeRules = @(

    )
}