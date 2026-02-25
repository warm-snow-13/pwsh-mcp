---
applyTo: '**/*.ps1'
description: Code Conventions for PowerShell Files
---
## Overview

These instructions provide guidelines for GitHub Copilot to assist with PowerShell script development within this project.

## PowerShell Style Guide

⏺ Name Conventions:
  - Use clear, descriptive names for variables, functions, and scripts.
  - Use PascalCase for internal function names, camelCase for variables.
  - Use verb-noun format for public functions (e.g., `Get-Data`, `Set-Config`).

⏺ Comment Conventions:
  - Create comment-based help for main functions and scripts using the `.SYNOPSIS` format.
  - Always add `.SYNOPSIS` with short description for every new script or function.
  - Write comments in English to explain non-obvious logic, complex algorithms, or important decisions.
  - Ensure comments are descriptive and add value to understanding the code.

⏺ Use PowerShell capabilities and syntax for version 7 or later.

⏺ Prefer single quotes for strings unless variable interpolation is needed.

⏺ Validate input `parameters` using `[Parameter()]` validate attributes and type constraints.

⏺ Use attribute `CmdletBinding()` for advanced functions. With ShouldProcess.

⏺ Handle errors with try/catch/finally and provide meaningful error messages.

⏺ Use Write-Output for standard output, Write-Error for errors.

⏺ Use pipeline input/output where appropriate.

⏺ Avoid hardcoding values when possible.

⏺ Group related functions in modules.

⏺ Use platform-independent approaches (Windows, Linux, macOS).

⏺ Prefer `.NET` classes and methods when it can enhance your scripts:
  - System.Math
  - System.IO.Path
  - System.IO.File
  - System.IO.FileInfo
  - System.IO.Directory
  - System.IO.DirectoryInfo
  - System.Collections
  - System.Guid
  - Enum Constants to ensure valid values.

⏺ Use the null-coalescing operator (`??`) and null-conditional operator (`?.`) for null checks.

### Architecture

**Modularity**:

Group related functions into modules (`.psm1` files) to promote reusability and better organization.

**Advanced Functions**:

Utilize `[CmdletBinding()]` for custom functions.
Prefer pipeline construction for processing.
Incorporate `SupportsShouldProcess` for operations that change system state.
Handle errors in pipeline scenarios using `-ErrorAction` and `try/catch` where appropriate.

**Error Handling**:

Implement robust error handling using `try/catch/finally` blocks. Ensure that errors are caught gracefully and provide meaningful error messages using `Write-Error`.

**Verbose Output**:

Use `Write-Verbose` to provide detailed information about script execution, especially for debugging or troubleshooting. This output should only appear when the `-Verbose` switch is used.

**Collections**:

Prefer generic list collections (e.g., `[System.Collections.Generic.List[object]]`) for dynamic collections where items are frequently added or removed, as they offer better type safety and performance compared to `ArrayList`. Use standard PowerShell arrays (`@()`) for fixed-size or infrequently modified collections. Avoid using simple strings to accumulate collection data.

**UX Considerations**:

- Use `Write-Output` for standard output, `Write-Error` for errors.
- Use `Write-Progress` to display status for long-running operations to provide feedback to the user.
- Use `Write-Error -ErrorAction Stop` with `Category` to handle critical errors that should halt execution.
- Use `Write-Verbose`, `Write-Information` for detailed information about script execution, especially for debugging or troubleshooting.

### Testing

Follow best practices for writing unit tests for PowerShell scripts, primarily using the Pester framework.

**Test Framework:**

- Use [Pester](https://pester.dev) for writing and running tests.
- Structure tests using `Describe`, `Context`, and `It` blocks for clarity.
- Mock dependencies to isolate the code under test using Pester's mocking features.

**Write Unit Tests:** Create unit tests for all critical functions and scripts.

- Focus on testing individual units of code in isolation.
- Use a testing framework like Pester, which is the de facto standard for PowerShell.

**Test Coverage:**

Aim for high test coverage to ensure reliability.

**Test Cases:**

- Include tests for valid and invalid inputs.
- Check positive and negative scenarios.
- Test edge cases and boundary conditions.
- Verify error handling mechanisms.

**Automated Testing:**

Integrate tests into a CI/CD pipeline if applicable, to run automatically on changes.

**Readability of Tests:**

Write tests that are easy to understand and maintain. Test names should clearly describe what is being tested.

**Test-Driven Development (TDD):**

Consider using TDD principles where appropriate: write tests before writing the actual code.

### Security

**Input Validation**:

Sanitize and validate all external inputs to prevent injection attacks (e.g., command injection).
Use specific type constraints and validation attributes for parameters.

**Secrets Management**:

Avoid hardcoding secrets (API keys, passwords, connection strings) directly in scripts.
Utilize secure secret management solutions appropriate for the environment.
Copilot should prompt for placeholder values or guide towards using a secure method.

**Least Privilege**:

Ensure scripts run with the minimum necessary permissions.

**Cmdlet and Command Usage**:

Be cautious with cmdlets and external commands that can modify system state or access sensitive information.

**Error Handling for Security**:

Ensure that error messages do not leak sensitive information.

**Code Signing**:

For scripts deployed in production or shared, consider using code signing to ensure integrity and authenticity.
