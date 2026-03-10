<#
.SYNOPSIS
    Unit tests for the MCP server.

#>

BeforeAll {
    # Dot-source loading to make its functions available for testing
    . $PSCommandPath.Replace('.tests.ps1', '.ps1')

}

Describe 'PSMCP Echo Sample Script' -Tag 'Samples', 'Unit' {

    It 'Should expose get_echo function after dot-sourcing' {
        Get-Command -Name get_echo -CommandType Function | Should -Not -BeNullOrEmpty
    }

    It 'Should return default echo when text is omitted' {
        $result = get_echo
        $result.text | Should -Be 'lorem ipsum'
    }

    It 'Should return echo for provided text' {
        $result = get_echo -text 'Ani'
        $result.text | Should -Be 'Ani'
        $result.id | Should -Not -BeNullOrEmpty
    }

}
