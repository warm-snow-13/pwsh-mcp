# User Guide

## Overview

The PowerShell module lets you build Model Context Protocol (MCP) servers by exposing PowerShell functions as MCP tools. It implements an MCP server using stdio transport and JSON-RPC 2.0, in compliance with the MCP specification.

AI assistants (for example, GitHub Copilot, Gemini CLI, and Copilot CLI) can connect to a PowerShell MCP server to invoke these functions as tools, extending the assistants' capabilities with custom logic written in PowerShell. This guide covers the module's requirements, installation, configuration, and usage.

## Requirements

- PowerShell 7.5 or later (cross-platform)
- Any MCP-capable client (Visual Studio Code with GitHub Copilot or Gemini CLI ...)

## Installation

### From Source

- Clone the repository to a machine running PowerShell 7.5 or later.
- Make sure the module folder (`src/pwsh.mcp`) is on your `PSModulePath`, or import the module directly from its location.

```powershell
git clone https://github.com/warm-snow-13/pwsh-mcp.git
```

### From PowerShell Gallery

Install the module from the PowerShell Gallery using `Install-Module`:

```powershell
# Install the latest stable release for the current user
Install-Module -Name pwsh.mcp -Repository PSGallery -Scope CurrentUser

# Verify installation and check available commands
Get-Module -Name pwsh.mcp -ListAvailable
Get-Command -Module pwsh.mcp
```

## MCP Server Creation

### Minimal Implementation

The repository includes several functional examples in the [samples/](../samples/) directory.
This [example](samples/psmcp_hello_world.ps1) demonstrates a minimal PowerShell MCP server.

```powershell
# Import MCP module
Import-Module pwsh.mcp -Force -ErrorAction Stop

# Define a function to expose as an MCP tool
function get_greeting {
    [Annotations(Title = "Get Greeting", ReadOnlyHint = $true)]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Name to greet")]
        [ValidateLength(1, 25)]
        [string] $Name = "World"
    )
    return "Hello, $Name!"
}

# Start MCP server with your function
New-MCPServer -FunctionInfo (Get-Item Function:get_greeting)
```

The `[ValidateLength(1, 25)]` attribute constrains the `Name` parameter to 1–25 characters, guarding against oversized input. The `[Annotations]` attribute supplies client-facing metadata - in this case, a display title and a read-only hint. The function `New-MCPServer` starts the MCP server and registers `get_greeting` as an available tool via the `FunctionInfo` parameter.

> [!IMPORTANT]
> MCP servers use **stdio** transport. Avoid any **non-protocol output** to stdout/stderr (for example, `Write-Host`, `Write-Verbose`, `Write-Debug`, `Write-Information`, or external tools that print), because it can corrupt the JSON-RPC stream. Prefer returning values and use file logging for diagnostics (see the [Logging Configuration](#logging-configuration) section).

### Usage Patterns

Single Function Export

```powershell
Import-Module pwsh.mcp
New-MCPServer -FunctionInfo (Get-Item Function:MyFunction)
```

Multiple Functions Export

```powershell
Import-Module pwsh.mcp
New-MCPServer -FunctionInfo (Get-Item Function:Function1, Function:Function2)
```

or using an array:

```powershell
Import-Module pwsh.mcp

$functions = @(
    Get-Item Function:Function1
    Get-Item Function:Function2
    Get-Item Function:Function3
)

New-MCPServer -FunctionInfo $functions
```

Use standard PowerShell features to enhance functions that will be exposed as an MCP tool:

- **Comment-Based Help** - Provide comprehensive documentation
- **Parameter Attributes** - Use `[Parameter]` attributes for required/optional parameters, help messages, etc.
- **Parameter Validation** - Use attributes like `[ValidateLength]`, `[ValidateRange]`, etc.

**References:**

- [PowerShell Cmdlet Development Guidelines](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- [Validating Parameter Input](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/validating-parameter-input)

### Best Practices

When creating your MCP server, consider the following best practices to ensure security, performance, and maintainability.

**References:**

- [MCP developer guide](https://code.visualstudio.com/api/extension-guides/ai/mcp)
- [MCP specification: Tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [Security considerations](https://modelcontextprotocol.io/legacy/concepts/tools#security-considerations)
- [Annotations](https://modelcontextprotocol.io/legacy/concepts/tools#available-tool-annotations)

Name conventions:

- Use descriptive, action-oriented names (for example, `verb_noun`) in snake_case or PascalCase.
- Tool names SHOULD be between 1 and 128 characters in length (inclusive).
- Tool names SHOULD be treated as case-sensitive.
- The following SHOULD be the allowed characters: ASCII letters, digits, underscore, hyphen, and dot.
- Tool names SHOULD NOT contain spaces, commas, or other special characters.
- Tool names SHOULD be unique within a server.

Usability:

- Use Annotations to provide metadata for better client integration
- Handle missing parameters gracefully with defaults or clear errors

Security:

- Validate input parameters
- Sanitize user-provided data
- Use constrained language mode when appropriate
- Avoid executing arbitrary code from input
- Leverage PowerShell execution policies

Performance:

- Cache function metadata where possible
- Minimize stdio overhead
- Use efficient JSON serialization

Maintainability:

- Keep functions focused and atomic
- Use descriptive variable names
- Add comments for complex logic
- Write comprehensive tests
- Document public APIs
- Write self-documenting code

## MCP Client Configuration

PowerShell MCP servers can be configured for different MCP clients. Each client has its own configuration file and format. Refer to the native documentation for your client for specific configuration options. Below are example configurations for GitHub Copilot (VS Code extension and CLI) and Gemini CLI.

### GitHub Copilot with VS Code Extension

Read the documentation for the GitHub Copilot VS Code extension to understand how to configure MCP servers: [VS Code MCP Servers](https://code.visualstudio.com/docs/copilot/customization/mcp-servers). The document describes several ways to configure MCP servers.

The configuration involves defining a new MCP server in your VS Code workspace settings, pointing to the PowerShell script that starts your MCP server. Use the `stdio` transport type and specify the command to run PowerShell with the appropriate arguments.

Edit VS Code workspace configuration to add a new MCP server definition that points to your PowerShell script.
**Configuration File:** `.vscode/mcp.json` (workspace-level)

```jsonc
{
  "servers": {
    "my-pwsh-server": {
      "type": "stdio",
      "command": "pwsh",
      "args": [
        "-NoLogo",
        "-NoProfile",
        "-File",
        "${workspaceFolder}/my-mcp-server.ps1"
      ],
      "dev": {
        "watch": "src/**/*.ps1"
      }
    }
  }
}
```

**Tech Info:**

- Config can use workspace-relative paths using `${workspaceFolder}`
- Setting `dev.watch` is a VS Code development feature that restarts the server process when files change

The module includes an optional helper function `Add-MCPServer` to generate a VS Code install link for a server script, which can simplify the configuration process.

```powershell
Import-Module pwsh.mcp
Add-MCPServer -McpServerFullName "${pwd}/samples/psmcp_hello_world.ps1"
```

The function `Add-MCPServer` generates a VS Code MCP installation URL of the form `vscode:mcp/install?{urlencoded-json}`. The URL contains a URL-encoded JSON server definition (for example, a stdio server with `name`, `command`, and `args`).

**Open the generated link to start the VS Code MCP server installation flow** (using Extension view). You can install the server in your **workspace** (updates `.vscode/mcp.json`) or in your user **profile** (global configuration).

**References:**

- [Use MCP servers in VS Code](https://code.visualstudio.com/docs/copilot/customization/mcp-servers)
- [MCP developer guide](https://code.visualstudio.com/api/extension-guides/ai/mcp)

### GitHub Copilot CLI

To extend the functionality available to you in Copilot CLI, you can add more [MCP Servers](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli#add-an-mcp-server)

Configuration File: `~/.copilot/mcp-config.json`

```json
{
  "mcpServers": {
    "my-pwsh-server": {
      "type": "local",
      "description": "My PowerShell MCP Server",
      "transport": "stdio",
      "command": "pwsh",
      "tools": ["*"],
      "args": [
        "-NoLogo",
        "-NoProfile",
        "-File",
        "/absolute/path/to/my-mcp-server.ps1"
      ]
    }
  }
}
```

**Tech Info:**

- Tool filtering — `"tools": ["*"]` enables all tools; list specific names to restrict access
- Absolute paths are required at user level
- Use '-NoLogo' and '-NoProfile' to minimize non-protocol output from PowerShell, which can interfere with the JSON-RPC communication

**Reference:** [Copilot CLI](https://github.com/features/copilot/cli).

As an alternative to editing the config file manually, run the following command to start the interactive server registration dialog: `/mcp add`

> [!IMPORTANT]
> Copilot CLI can write its own session logs.
> Session log files are stored at `~/.copilot/session-state/`.

### Gemini CLI

The Gemini CLI uses the mcpServers configuration in your settings.json file to locate and connect to MCP servers.

**Reference:** [Gemini CLI MCP Servers](https://geminicli.com/docs/tools/mcp-server/)

**User-level.** Configuration File: `~/.gemini/settings.json`

```jsonc
{
  "mcpServers": {
    "my-pwsh-server": {
      "command": "pwsh",
      "args": [
        "-NoLogo",
        "-NoProfile",
        "-File",
        "/absolute/path/to/my-mcp-server.ps1"
      ]
    }
  }
}
```

**Tech Info:**

- Absolute paths are required for global configuration
- Servers defined here are available to all Gemini CLI projects on the machine

As an alternative to manual configuration, you can configure servers using the Gemini CLI:

```bash
# Add server using CLI command
gemini mcp add my-server "pwsh" \
  --args "-NoLogo" "-NoProfile" "-File" "/path/to/server.ps1"

# List configured servers
gemini mcp list

# Remove server
gemini mcp remove my-server
```

**Workspace-level.** Configuration File: `.gemini/settings.json`
Local server definitions for a specific Gemini CLI project in a workspace.
Use a relative path to the server script to allow sharing the configuration across different environments.

```jsonc
{
  "mcpServers": {
    "my-pwsh-server": {
      "command": "pwsh",
      "args": [
        "-NoLogo",
        "-NoProfile",
        "-File",
        "Folder/my-mcp-server.ps1"
      ]
    }
  }
}
```

## Testing MCP Server

You can test the server by using @modelcontextprotocol/inspector, any stdio-compatible client, or sending JSON-RPC messages to stdin.

Use MCP Inspector for interactive testing and debugging of your MCP server. It provides a CLI interface to send JSON-RPC requests and inspect responses, making it easier to test your server's functionality without needing a full client setup.

```bash
# Test server with inspector CLI
npx @modelcontextprotocol/inspector pwsh -NoProfile -File src/server1.ps1
```

Example interactive testing tool for MCP servers:

```bash

# General help
npx @modelcontextprotocol/inspector --help

# Run server in CLI mode
npx @modelcontextprotocol/inspector \
pwsh -NoProfile -File /path/to/server.ps1 --cli

# List available tools
npx @modelcontextprotocol/inspector \
pwsh -NoProfile -File ./server.ps1 --cli --method tools/list

# Call specific tool
npx @modelcontextprotocol/inspector \
pwsh -NoProfile -File ./server.ps1 --cli \
--method tools/call \
--tool-name my_tool \
--tool-arg param1=value1 \
--tool-arg param2=value2

# Run in CLI mode
npx @modelcontextprotocol/inspector pwsh -NoProfile -File src/server1.ps1 --cli

# Test specific tool
npx @modelcontextprotocol/inspector pwsh -NoProfile -File src/server1.ps1 \
--cli --method tools/call --tool-name my_tool --tool-arg param=value

```

**Reference:** [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector)

## Debug MCP Server

Enable hot-reload for faster development iterations. When `dev.watch` is configured, the MCP server will automatically restart when changes are detected in the specified files or directories.

The [MCP developer guide](https://code.visualstudio.com/api/extension-guides/ai/mcp) describes how to create and register MCP servers in VS Code.

```jsonc
  "dev": {
    "watch": "samples/**/*.ps1"
  }
```

## Logging Configuration

The module includes a file logging subsystem that can be configured using environment variables. Logs can help with debugging and monitoring your MCP server.

MCP PWSH server supports environment variables for runtime configuration:

- `PWSH_MCP_SERVER_LOG_LEVEL` - Set the minimum logging level (e.g., DEBUG, INFO)
- `PWSH_MCP_SERVER_LOG_FILE_PATH` - Specify the file path for log output

**Example:** `.vscode/mcp.json`

```jsonc
"env": {
  "PWSH_MCP_SERVER_LOG_LEVEL": "DEBUG",
  "PWSH_MCP_SERVER_LOG_FILE_PATH": "${workspaceFolder}/logs/server.log"
}
```

> [!NOTE]
> Copilot CLI can write its own session logs.
> Log files for Copilot CLI sessions are stored at `~/.copilot/session-state/`.

## Annotations

Annotations for MCP tool metadata are optional but recommended to provide better descriptions and hints for clients.

**Reference:**

- [VS Code Tool Annotations](https://code.visualstudio.com/api/extension-guides/ai/mcp#tool-annotations)
- [MCP Tools Annotations](https://modelcontextprotocol.io/legacy/concepts/tools#available-tool-annotations)

> [!NOTE]
> The module supports **Tool Annotations** to extend function descriptions with metadata.

The example below demonstrates how to use the `[Annotations()]` attribute to provide metadata for MCP clients:

```powershell
[Annotations(
    Title = "Human-readable tool name",
    ReadOnlyHint = $true
)]
function Get-Data { ... }
```

**Attributes:**

- `Title` - Displayed in the Chat view when the tool is invoked
- `ReadOnlyHint` - Indicates a read-only tool (no confirmation prompt in VS Code)
- `OpenWorldHint` - Indicates the tool may interact with an “open world” of external entities

Visual Studio Code recognizes only Title and ReadOnlyHint annotations.

**Best practices:**

- Use descriptive, action-oriented titles
- Keep under 50 characters
- Use title case
- Set `ReadOnlyHint = $true` for tools that do not modify state

## Docker Configuration

Running the MCP server in a Docker container isolates the server process from the host. This can improve security and simplify dependency management. Below is an _example configuration for running a PowerShell MCP server in a Docker container_, with volume mounts for development files.

**Example Configuration:** file `.vscode/mcp.json` (workspace-level)

```jsonc
{
  "servers": {
    "mcp-pwsh-docker": {
      "type": "stdio",
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-v",
        "${workspaceFolder}/src:/app/src",
        "-v",
        "${workspaceFolder}/samples:/app/samples",
        "mcr.microsoft.com/powershell:mariner-2.0-arm64",
        "pwsh",
        "-NoLogo",
        "-NoProfile",
        "-File",
        "/app/src/server1.ps1"
      ]
    }
  }
}
```

The folders are mounted via volumes, enabling development without rebuilding the container.

**Tech Info:**

- The image `mcr.microsoft.com/powershell:mariner-2.0-arm64` targets Apple Silicon (ARM64); replace it with an image that matches your target architecture (e.g., `mcr.microsoft.com/powershell:latest` for multi-arch support)
- Use `--rm` to automatically clean up the container after it exits to prevent resource leaks
- Use `${workspaceFolder}` to reference workspace-relative paths

## Resources

### Essential Resources

- [MCP Specification](https://modelcontextprotocol.io/specification/2025-11-25)
- [JSON-RPC 2.0](https://www.jsonrpc.org/specification)
- [PowerShell Documentation](https://learn.microsoft.com/powershell/)
- [Cmdlet Development Guidelines](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)

### MCP Specification

- [MCP Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/basic) - Core protocol specification
- [MCP Transports](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) - Transport layer details
- [MCP Server](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle) - Server lifecycle
- [MCP Tools](https://modelcontextprotocol.io/specification/2025-11-25/basic/tools) - Tool protocol

### JSON-RPC

- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification) - Protocol specification
- [JSON-RPC Error Codes](https://www.jsonrpc.org/specification#error_object) - Standard error codes

### PowerShell

- [PowerShell 7.5+ Documentation](https://learn.microsoft.com/powershell/) - Official documentation
- [Comment-Based Help](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comment_based_help) - Help system
- [Parameter Validation](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters) - Parameter attributes
- [Cmdlet Development Guidelines](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines) - Best practices

### MCP Clients

- [VS Code MCP Servers](https://code.visualstudio.com/docs/copilot/customization/mcp-servers) - VS Code configuration
- [VS Code Extension API](https://code.visualstudio.com/api/extension-guides/ai/mcp) - Extension development
- [Gemini CLI](https://geminicli.com/docs/tools/mcp-server/) - Gemini CLI documentation
- [Copilot CLI](https://github.com/features/copilot/cli) - Copilot CLI features

### Testing & Analysis

- [Pester Documentation](https://pester.dev/docs/quick-start) - Testing framework
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) - Static analyzer
- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/docs/Rules/README.md) - Rule documentation
- [Use Compatible Syntax](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/docs/Rules/UseCompatibleSyntax.md) - Compatibility rule

### Project Links

- [GitHub Repository](https://github.com/warm-snow-13/pwsh-mcp) - Source code
- [Issue Tracker](https://github.com/warm-snow-13/pwsh-mcp/issues) - Bug reports & features
- [CHANGELOG](../CHANGELOG.md) - Version history
- [LICENSE](../LICENSE) - MIT License
