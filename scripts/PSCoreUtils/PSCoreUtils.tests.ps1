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

Describe 'utils.set_version' {
    It 'Should increment build by 1 by default' {
        $result = utils.set_version -Version ([version]'1.2.3')

        $result | Should -Be ([version]'1.2.4')
    }

    It 'Should increment major and reset minor/build' {
        $result = utils.set_version -Version ([version]'1.2.3') -Part 'Major'

        $result | Should -Be ([version]'2.0.0')
    }

    It 'Should increment minor and reset build' {
        $result = utils.set_version -Version ([version]'1.2.3') -Part 'Minor'

        $result | Should -Be ([version]'1.3.0')
    }

    It 'Should increment build when part is Build' {
        $result = utils.set_version -Version ([version]'1.2.3') -Part 'Build'

        $result | Should -Be ([version]'1.2.4')
    }

    It 'Should increment by custom value' {
        $result = utils.set_version -Version ([version]'1.2.3') -Part 'Build' -IncrementBy 5

        $result | Should -Be ([version]'1.2.8')
    }

    It 'Should throw when part is invalid' {
        { utils.set_version -Version ([version]'1.2.3') -Part 'Patch' } | Should -Throw
    }

    It 'Should throw when increment is less than 1' {
        { utils.set_version -Version ([version]'1.2.3') -IncrementBy 0 } | Should -Throw
    }
}
