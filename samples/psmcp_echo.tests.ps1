<#
.SYNOPSIS
    Unit tests for sample MCP server.
#>

BeforeAll {
    # Dot-source the sample script to make its functions available for testing
    . "$PSScriptRoot/psmcp_echo.ps1"
}

Describe 'ps mcp echo sample script' -Tag 'Samples', 'Unit' {

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
