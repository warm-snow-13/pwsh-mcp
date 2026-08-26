---
name: new-mcp-server
description: Use when creating or refactoring a PowerShell MCP server, exposing functions as MCP tools, or validating a pwsh.mcp stdio server.
argument-hint: "[create mcp server]"
user-invocable: true
---

# PowerShell MCP Server

Create and validate a PowerShell MCP server with the `pwsh.mcp` module.

## When to Use

- Create a new PowerShell MCP server.
- Add or refactor MCP tools.
- Register functions with `New-MCPServer`.
- Validate a stdio server locally.

## Procedure

1. Import `pwsh.mcp` with `-ErrorAction Stop`.
2. Define each tool as a public `Verb-Noun` function with comment-based help, typed parameters, validation, and an output type.
3. Add `[Annotations(...)]` when tool metadata is useful.
4. Return structured objects and keep the protocol stream clean: never write diagnostics or other non-protocol output to stdout. Do not use `Write-Host`, `Write-Verbose`, `Write-Debug`, `Write-Information`, or external commands that print to the JSON-RPC channel; route diagnostics through the repository logger or another channel supported by the client.
5. Register each function with `New-MCPServer`.
6. Guard startup so dot-sourcing does not start the server.
7. Run focused Pester tests and a direct stdio smoke test that sends newline-delimited JSON-RPC requests for `initialize`, `tools/list`, `tools/call`, and `shutdown`; parse every stdout line as JSON-RPC and assert that no non-protocol text is emitted.

## Minimal Template

Use this as a neutral starting point for an MCP tool. Replace
`Invoke-McpTool`, `MCP Tool`, `InputValue`, and the response fields with names
and data from the target skill while preserving the function, validation,
annotation, registration, and direct-startup structure.

```powershell
Import-Module pwsh.mcp -ErrorAction Stop

function Invoke-McpTool {
	<#
	.SYNOPSIS
		Processes input and returns a structured result.
	.PARAMETER InputValue
		Value to process.
	.OUTPUTS
		[PSCustomObject]
	#>
	[Annotations(Title = 'MCP_Tool', ReadOnlyHint = $true)]
	[OutputType([PSCustomObject])]
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $false,
			HelpMessage = 'Value to process. Limited to 100 characters.'
		)]
		[ValidateLength(1, 100)]
		[string]$InputValue = 'value'
	)

	return [PSCustomObject][ordered]@{
		value = $InputValue
	}
}

if ($MyInvocation.InvocationName -ne '.') {
	New-MCPServer -FunctionInfo (Get-Item Function:Invoke-McpTool -ErrorAction Stop)
}
```

## References

- [MCP module](../../../src/pwsh.mcp)
- [Repository samples](../../../samples)
- Agent Skills specification: <https://agentskills.io/>
