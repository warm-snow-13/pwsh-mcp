function Add-MCPServer {
    <#
    .SYNOPSIS
        Generate link to register an MCP server in VSCode

    .DESCRIPTION
        This script generates a link that can be used to register a Multi-Channel PowerShell (MCP) server in Visual Studio Code.
        The generated link contains the server definition encoded in the URL format.

    .NOTES
        The 'MCP developer guide' describes how to create and register MCP servers in VSCode.
        For more information, visit: https://code.visualstudio.com/api/extension-guides/ai/mcp

    .EXAMPLE
        Add-MCPServer -McpServerFullName '/full/path/to/mcp-fs-srv.ps1'
        Generates a VS Code MCP install link for the specified server script.

    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', ''
    )]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Full path to the MCP server script file.'
        )]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [Alias('Path')]
        [string]
        $mcpServerFullName
    )

    Write-Verbose 'GENERATE VSCODE MCP INSTALL LINK'

    $fileInfo = Get-Item -Path $mcpServerFullName

    $path = $fileInfo.FullName
    $name = $fileInfo.BaseName

    $mcpSrvDefinition = [ordered]@{
        name    = $name
        type    = "stdio"
        command = "pwsh"
        args    = @(
            "-NoLogo",
            "-NoProfile",
            "-File",
            "$path"
        )
    }

    $mcpServerJson = ConvertTo-Json -InputObject $mcpSrvDefinition -Compress
    $mcpServerJsonEncoded = [System.Uri]::EscapeDataString($mcpServerJson)
    $vscodeMcpInstallLink = "vscode:mcp/install?$mcpServerJsonEncoded"

    $vscodeMcpInstallLink | Write-Host -ForegroundColor DarkRed -BackgroundColor Gray
    Write-Host "Copy the above link and paste it into the browser or run it in the terminal to register the MCP server in VSCode." -ForegroundColor Yellow

    # Attempt to open the link in the default handler.
    try {
        if ($IsMacOS) {
            open $vscodeMcpInstallLink
        }
        if ($IsWindows) {
            Start-Process $vscodeMcpInstallLink
        }
    }
    catch {
        Write-Error "Failed to open MCP install link: $($_.Exception.Message)"
    }
}