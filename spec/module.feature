# Behavior-driven development, Gherkin syntax for PowerShell module quality assurance
# Gherkin is a language for describing software behaviors in a human-readable format.
# References:
# https://smartiqa.ru/blog/bdd_gherkin_cucumber
# https://cucumber.io/docs/guides/

Feature: A proper community module
  As a module owner
  In order to have a good community module
  I want to make sure everything works and the quality is high

  Background: we have a module
    Given the module was named pwsh.mcp

  Scenario: Should have correct project structure and files
    Given we use the project root folder
    Then it will have a README.md file for general information
    And it will have a LICENSE file
    And it will have a tests/*.tests.ps1 file for Pester
    And it will have a spec/*.feature file for Gherkin
    And it will have a ci.ps1 file for builds
    And it will have a jarvis.ps1 file for automation
    And it will have a .gitignore file to ignore build artifacts
    And it will have a .github/workflows/ci.yml file for build automation (github actions)

  Scenario: Should have correct module structure in source
    Given we use the ModuleSource root folder
    Then it will have a pwsh.mcp.psd1 file for module manifest
    And it will have a pwsh.mcp.psm1 file for module
    And it will have psmcp.*.ps1 files for module implementation
    And it will have a public folder
    And it will have a private folder
    And it will have a classes folder

  Scenario: Build should produce local output
    Given we use the project root folder
    When we run the build action
    Then it will create a build folder for local publishing

  Scenario: the module source should import
    Given we use the ModuleSource root folder
    And it had a *.psd1 file
    When the module is imported
    Then Get-Module will show the module
    And Get-Command will list functions

  Scenario: The built module should be importable
    Given we use the project root folder
    When we run the build action
    Then the module will be available as a published artifact

  Scenario: Public function features
    Given the module is imported
    And we have public functions
    Then all public functions will be listed in module manifest
    And all public functions will contain 'CmdletBinding'
    And all public functions will have comment based help

  Scenario: Should be well documented
    Given the module is imported
    And we use the project root folder
    And we have public functions
    Then it will have a README.md file for general information
    And it will have a docs folder with development notes
    And all public functions will have comment based help
    And exported functions will have a pester test

  @PSScriptAnalyzer @Slow
  Scenario: Should pass PSScriptAnalyzer rules
    Given we use the ModuleSource root folder
    And all script files pass PSScriptAnalyzer rules

  @Slow
  Scenario: Should be publish-ready
    Given the module can be imported
    Then module manifest will contain PSGallery metadata
