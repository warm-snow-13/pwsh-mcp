---
agent: agent
model: GPT-5 mini
name: 'psmcp-srv1'
tools: [read/readFile, search, 'pwsh.mcp.server1/*']
description: 'Test the PowerShell MCP Server by calling the tool `abc` with specific parameters and showing the result.'
---

# PowerShell MCP Server: Coding Prompt

Use mcp server pwsh.mcp.server1 and call the tool `abc` with parameters:
- text: "Hello13"
- number: 13

Show the result of the call.
Emphasize the output of the tool call in your response.
