BeforeAll {

    # load the script being tested
    # . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    Import-Module  $PSScriptRoot/PSCoreUtils.psm1 -Force -ErrorAction Stop

}

Describe 'Environment Check' {

    Describe 'npx Command Availability' {
        It 'Should fail if npx command does not exist' {
            $npxCommand = Get-Command npx -ErrorAction SilentlyContinue
            $npxCommand | Should -Not -BeNullOrEmpty -Because "npx command is required"

            if ($npxCommand) {
                Write-Debug "OK npx is available at: $($npxCommand.Source)"
            }
        }
    }
}

