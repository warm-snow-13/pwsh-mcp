---
name: new-mcp-server
description: Agent Skill to assist with creating MCP (Model Context Protocol) PowerShell servers
argument-hint: "[create mcp server]"
user-invocable: true
---

# New MCP Server Skill

This skill provides guidance for developing MCP servers using PowerShell and the `pwsh.mcp` module.

When to use:
- You need a new PowerShell MCP server.
- You want to add or refactor MCP-exposed tool functions.
- You need a working template for `New-MCPServer` registration.
- You want to reuse proven patterns from the repository samples.

What the skill helps accomplish:
- Create new MCP server files that match repository conventions.
- Expose PowerShell functions as MCP tools with annotations and typed parameters.
- Reuse patterns for simple tools, HTTP calls, caching, and direct-invocation startup.
- Validate the server locally before integrating it into a client workflow.

Use the examples in the [samples](../../../samples) directory as templates.

Workflow

1. Pick the closest sample and copy its structure.
2. Import the module with `Import-Module pwsh.mcp -ErrorAction Stop`.
3. Define one or more MCP-exposed functions.
4. Add comment-based help, output types, and validated parameters, `Annotations(...)` as needed.
5. Register the exposed functions with `New-MCPServer -functionInfo (Get-Item Function:<name> -ErrorAction Stop)`.
6. Guard startup so the server only starts when the script is invoked directly (Optional).
7. Run the script locally and verify the exported tools from an MCP client or from PowerShell.

Restrictions

- Do not use any output to the console, as it will interfere with the stdio MCP protocol.


Skill guidance

- For MCP-exposed functions in this repository, follow the existing sample convention: lowercase snake_case names.
- Use comment-based help with accurate `.SYNOPSIS`, `.PARAMETER`, and `.OUTPUTS` sections.
- Prefer single-quoted strings unless interpolation is required.
- Use typed parameters and PowerShell validation attributes where appropriate.
- Prefer returning structured objects instead of free-form text.
- The `pwsh.mcp` module handles errors during the tools' invocation. The error handling in the public functions can be minimal.


Implementation pattern

```powershell
Import-Module pwsh.mcp -ErrorAction Stop

function get_example {
	[Annotations(Title = 'Example Tool', ReadOnlyHint = $true)]
	[OutputType([PSCustomObject])]
	[CmdletBinding()]
	param(
		[Parameter(
      Mandatory = $false,
      HelpMessage = 'Text to include in the output object. Limited to 100 characters.'
    )]
    [ValidateLength(1, 100)]
		[string]$Text = 'example'
	)

	return [PSCustomObject][ordered]@{
		text = $Text
	}
}

if ($MyInvocation.InvocationName -ne '.') {
	New-MCPServer -functionInfo (Get-Item Function:get_example -ErrorAction Stop)
}
```

References

- MCP module in this repository: `src/pwsh.mcp`
- Repository samples: [../../../samples](../../../samples)
- Agent Skills specification: <https://agentskills.io/>
- Use Agent Skills in VS Code: <https://code.visualstudio.com/docs/copilot/customization/agent-skills>
