<#
.SYNOPSIS
    Sample MCP server for creating notes in macOS Notes app.

.DESCRIPTION
    This sample demonstrates how to create a simple MCP server that can create notes in the macOS Notes application using AppleScript. It includes functions to get the default Notes account and folder, as well as a function to create a new note with specified text content.

#>
#Requires -Version 7.0

if (-not $IsMacOS) {
    throw "This MCP server is supported only on macOS."
}

if (-not (Get-Command osascript -ErrorAction SilentlyContinue)) {
    throw "The 'osascript' command was not found. Script can only run on macOS with osascript installed."
}

# AppleScript template for creating notes
$appleScriptTemplate = @'
on run argv
    tell application "Notes" to make new note at folder "{0}" of account "{1}" ¬
    with properties {{name:"{2}", body:item 1 of argv}}
end run
'@

function get_default_account {
    [Annotations(Title = "Get default Notes account", ReadOnlyHint = $true)]
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $account = (osascript -e 'tell application "Notes" to name of default account').Trim()
    return $account
}

function get_default_folder {
    [Annotations(Title = "Get default Notes folder", ReadOnlyHint = $true)]
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $folder = (osascript -e 'tell application "Notes" to name of default folder of default account').Trim()
    return $folder
}

function create_note {
    <#
    .SYNOPSIS
        Create a new note in the macOS Notes application via MCP tool.
    .DESCRIPTION
        Creates a new note in the specified Notes account and folder using AppleScript.
    .PARAMETER text
        Text content of the note to create.
    .PARAMETER targetFolder
        Target folder name in Notes app where the note will be created.
    .PARAMETER account
        Account name in Notes app where the note will be created.
    .OUTPUTS
        Object with basic information about note creation.
    #>
    [Annotations(Title = "Create macOS Notes note", ReadOnlyHint = $false)]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Text content of the note to create."
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $text,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Target folder in Notes app. If omitted, uses the account's default folder."
        )]
        [string]
        $targetFolder,
        # = '123',

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Account name in Notes app. If omitted, uses the system default account."
        )]
        [string]
        $account
        # = 'iCloud'
    )

    # 1. Resolve Account
    if ([string]::IsNullOrWhiteSpace($account)) {
        try {
            $account = get_default_account
        }
        catch {
            throw "Could not auto-detect default Notes account. Please specify -account parameter."
        }
    }

    # 2. Resolve Folder
    if ([string]::IsNullOrWhiteSpace($targetFolder)) {
        try {
            $targetFolder = get_default_folder
        }
        catch {
            throw "Could not auto-detect default folder for account '$account'. Please specify -targetFolder parameter."
        }
    }

    $noteTitle = "ai-note: $(Get-Date -Format 'o')"

    $scriptText = $appleScriptTemplate -f $targetFolder, $account, $noteTitle
    $osascriptOutput = $scriptText | osascript - $text 2>&1

    $exitCode = $LASTEXITCODE
    $status = if ($exitCode -eq 0) { 'Success' } else { "Failed (exit code $exitCode)" }
    $details = ($osascriptOutput | Out-String).Trim()

    return [PSCustomObject][ordered]@{
        title   = $noteTitle
        account = $account
        folder  = $targetFolder
        status  = $status
        details = $details
    } | ConvertTo-Json
}

Import-Module -FullyQualifiedName "$PSScriptRoot/../src/pwsh.mcp/pwsh.mcp.psd1" -Force -ErrorAction Stop

$functionInfoArray = (Get-Item Function:create_note, Function:get_default_account, Function:get_default_folder)
New-MCPServer -functionInfo $functionInfoArray
