---
agent_id: pwsh-mcp
version: v1.0.0
description: Repository policy for the pwsh.mcp PowerShell MCP module.
meta:
  role: [developer, maintainer, tester]
priority: highest
responsibility:
  owns:
    - repository implementation, documentation, tests, and analysis
    - MCP stdio and JSON-RPC behavior
  defers_to:
    runtime_policy: .github/copilot-instructions.md
    project_overview: README.md
    developer_guide: docs/pwsh.mcp.dg.md
    user_guide: docs/pwsh.mcp.ug.md
scope:
  applies_to: "**/*"
project:
  name: pwsh.mcp
  purpose: Expose PowerShell functions as MCP tools over JSON-RPC 2.0 stdio transport.
  runtime: PowerShell 7.5+
  tests: Pester 6.1.0
  analysis: PSScriptAnalyzer 1.25+
topology:
  src/: { purpose: module source and example server }
  src/pwsh.mcp/: { purpose: sources }
  tests/: { purpose: Pester tests }
  samples/: { purpose: sample MCP servers }
  scripts/: { purpose: repository utilities and automation }
  docs/: { purpose: user and developer documentation }
  config.tests.psd1: { purpose: Pester configuration and coverage output }
  config.analyzer.psd1: { purpose: PSScriptAnalyzer rules }
  ci.ps1: { purpose: local test, analysis, and build entry point }
---

# pwsh.mcp repository instructions

## Response and language

- Reply in the same language as the user.
- Write documentation, code comments, and commit messages in English.

## Working rules

- Before editing, use the relevant implementation, tests, CI configuration, and documentation as primary evidence; make the smallest reversible change, preserve unrelated work, and update affected documentation.
- Keep MCP protocol behavior on stdout-compatible paths; diagnostics must not corrupt stdio JSON-RPC messages.
- Do not add dependencies or change public exports without an explicit need and corresponding tests.
- New exported PowerShell functions must use approved `Verb-Noun` names, comment-based help, parameter validation, and appropriate error handling; keep tests in `tests/` as `*.tests.ps1` using Arrange-Act-Assert.

## Development workflow

Install missing dependencies:

```powershell
Install-Module -Name Pester -RequiredVersion 6.1.0 -Force
Install-Module -Name PSScriptAnalyzer -Force
```

Run commands from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File ./ci.ps1 -Action test
pwsh -NoLogo -NoProfile -File ./ci.ps1 -Action analyze
pwsh -NoLogo -NoProfile -File ./ci.ps1 -Action analyze -FailOnWarnings
```

For focused checks:

```powershell
Invoke-Pester -Path ./tests/<name>.tests.ps1
Invoke-ScriptAnalyzer -Path ./src -Settings ./config.analyzer.psd1 -Recurse
Test-ModuleManifest -Path ./src/pwsh.mcp/pwsh.mcp.psd1
Import-Module ./src/pwsh.mcp/pwsh.mcp.psd1 -Force
```

Run the relevant focused validation before the full CI command. Report unavailable checks and distinguish local static/load validation from CI, publication, and cross-platform runtime proof.

## CI and side effects

- CI validates the module and runs PSScriptAnalyzer on macOS; Pester runs on macOS, Linux, and Windows.
- Tests write coverage/results and may create a transcript; analysis warnings fail only with `-FailOnWarnings`.
- `ci.ps1 -Action build` publishes to the local `build/` repository; run it only when explicitly requested.

## MCP implementation boundaries

- The implemented transport is stdio; preserve one-request/one-response JSON-RPC behavior and MCP lifecycle handling.
- `tools/list` and `tools/call` derive schemas from PowerShell metadata, help, types, and validation; contract changes require tests. Resources, prompts, and HTTP transports are out of scope unless explicitly requested.

## References

- [JSON-RPC 2.0](https://www.jsonrpc.org/specification)
- [MCP specification](https://modelcontextprotocol.io/specification/2025-11-25/basic)
