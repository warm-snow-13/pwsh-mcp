---
title: AGENTS
---

MCP PowerShell Module implementing the MCP server over stdio transport, exposing PowerShell functions as MCP tools.

## Response Style

- Begin each reply with badge: `[(◉) agents ❱ pwshmcp]`
- ALWAYS respond in the same language I use.
- ALWAYS use English — when writing documentation, or code comments, or commit messages.

## Project Structure

MCP PowerShell Module implementing the MCP server over stdio transport, exposing PowerShell functions as MCP tools.

- [src](./src) — source code
- [tests](./tests) — Pester tests
- [docs](./docs) — documentation & guides
- [scripts](./scripts) — automation scripts

## Tech Stack

- Shell: PowerShell version 7.5
- Unit Testing: Pester
- Static Analysis: PSScriptAnalyzer

## References

- [JSON-RPC 2.0](https://www.jsonrpc.org/specification)
- [MCP Specification](https://modelcontextprotocol.io/specification/2025-11-25/basic)

## CI/CD

GitHub Workflow: `.github/workflows/ci.yml` — triggers on push. Jobs: test and analyze.

CI script: [`./ci.ps1`](./ci.ps1)

- `pwsh -noLogo -NoProfile -file ./ci.ps1 -action analyze` (Run static analysis)
- `pwsh -noLogo -NoProfile -file ./ci.ps1 -action test` (Run tests)
