---
description: Changelog file for the project
tags:
  - changelog
  - documentation
---

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- markdownlint-disable-file MD024 -->

## [Unreleased]

### Added

- Agent skill for creating PowerShell MCP servers

## [0.1.4] - 2026-03-09

### Added

- Gemini MCP client configuration for launching `src/server1.ps1`
- Sample self-aware MCP server exposing runtime context information with optional location lookup
- Unit tests for the echo sample and for version increment helper behavior in `PSCoreUtils`
- PowerShell Gallery badges and links in the README

### Changed

- Renamed the minimal sample server from `psmcp_hello` to `psmcp_echo` and refreshed its implementation
- Simplified logging payload generation and console notification structure for MCP diagnostics
- Enhanced the user guide with clearer server implementation guidance, parameter schema notes.
- Improved CI and automation scripts for better workflow and artifact management.
- Refreshed project metadata and developer configuration, editor settings, and spelling dictionary updates

### Removed

- Legacy `psmcp_hello` sample script and its associated tests

## [0.1.3] - 2026-03-04

### Added

- Sample MCP server for managing notes in Obsidian via CLI
- Enhanced JSON schema tests for additional parameter types and annotations metadata
- Clean-jarvis target to Makefile and artifact cleanup in jarvis.ps1

### Changed

- Refactored input schema functions and enhanced JSON schema generation for PowerShell parameters
- Improved parameter handling in schema generation and updated test for fallback description
- Enhanced AnnotationsAttribute with additional metadata hints and constructor parameters
- Enhanced Add-MCPServer function: added silent mode parameter and improved output messaging
- Enhanced mcp.getCmdHelpInfo: extended output and improved test cases for command help retrieval
- Updated user guide: enhanced server implementation section
- Refactored samples directory
- Streamlined tool response handling and updated related tests
- Updated VSCode settings for improved editor configuration and documentation clarity
- Updated .gitignore to clarify AI assistant data sections
- Updated watch pattern to include additional file types in dev configuration

## [0.1.2] - 2026-02-27

### Changed

- Completed packaging and metadata verification.
- Published module [pwsh.mcp](https://www.powershellgallery.com/packages/pwsh.mcp/0.1.2) to PowerShell Gallery.

## [0.1.1] - 2026-02-27

### Changed

- Updated CI workflow
- Updated MCP protocol version from `2025-06-18` to `2025-11-25`
- Enhanced user guide documentation with additional details
- Documentation references in `New-MCPServer` function description

## [0.1.0] - 2026-02-25

### Added

- Automatic JSON schema generation from PowerShell function metadata
- Support for basic parameter types (string, integer, boolean)
- Structured logging with file output
- Tool invocation via the MCP protocol
- Example server implementation (`server1.ps1`) with demo tools
- Sample MCP servers in the `samples/` directory
- Comprehensive test suite using Pester
- PSScriptAnalyzer integration for code quality
- CI via GitHub Actions (Ubuntu, macOS)
- User and Developer documentation guides
