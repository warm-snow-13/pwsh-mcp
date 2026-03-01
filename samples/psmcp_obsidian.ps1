<#
.SYNOPSIS
    Sample MCP server for managing notes in Obsidian via CLI.

.DESCRIPTION
    This sample demonstrates how to create an MCP server that manages notes in Obsidian
    using the Obsidian CLI (requires Obsidian 1.12+ with CLI enabled).
    Exposes a tool to append content to today's daily note.

.NOTES
    Prerequisites:
    - Obsidian 1.12+ installed with CLI enabled (Settings > General > Command line interface).
    - The 'obsidian' command must be available on PATH.
    - Obsidian app must be running.

    macOS PATH setup: export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"
    Linux:            sudo ln -s /path/to/obsidian /usr/local/bin/obsidian

    Usage:
        - Visual Studio Code:
        #obsidian_append_daily_note content="Hello, this is a note from MCP!"

.LINK
    https://help.obsidian.md/cli

#>

if (-not (Get-Command Obsidian -ErrorAction SilentlyContinue)) {
    throw "The 'Obsidian' CLI was not found on PATH. Enable it in Obsidian Settings > General > Command line interface."
}

function obsidian_append_daily_note {
    <#
    .SYNOPSIS
        Append content to today's daily note in Obsidian.
    .DESCRIPTION
        Appends text content to the current daily note using the Obsidian CLI
        'daily:append' command. The daily note must already exist, or Obsidian
        will create it if it does not.
    .PARAMETER content
        Content to append to the daily note. Supports Markdown formatting.
    .OUTPUTS
        JSON string with append operation result.
    .EXAMPLE
        obsidian_append_daily_note -content "- [ ] Buy groceries"
    .EXAMPLE
        obsidian_append_daily_note -content "## Evening Review\n\nCompleted all tasks."
    #>
    [Annotations(Title = "Append Daily Note", ReadOnlyHint = $false, OpenWorldHint = $true)]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Content to append to the daily note. Supports Markdown. Use literal \n for newlines.'
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $content
    )

    try {

        $output = & Obsidian daily:append "content=$content" 2>&1
        $exitCode = $LASTEXITCODE
        $details = ($output | Out-String).Trim()
        $status = $exitCode -eq 0 ? 'Success' : "Failed (exit code $exitCode)"

        return [PSCustomObject][ordered]@{
            action  = 'daily:append'
            status  = $status
            details = $details
        } | ConvertTo-Json
    }
    catch {
        return [PSCustomObject][ordered]@{
            action  = 'daily:append'
            status  = 'Failed'
            details = $_.Exception.Message
        } | ConvertTo-Json
    }
}


Import-Module -FullyQualifiedName "$PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psd1" -Force -ErrorAction Stop

if ($MyInvocation.InvocationName -ne '.') {
    $tools = Get-Item Function:obsidian_append_daily_note -ErrorAction Stop
    New-MCPServer -functionInfo $tools
}
