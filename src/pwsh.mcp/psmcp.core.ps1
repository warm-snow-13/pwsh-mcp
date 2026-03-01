<#
.SYNOPSIS
    PowerShell module core functions
    for building MCP servers with automatic JSON-schema generation from functions.

.NOTES

    References:

    Microsoft PowerShell Core
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core

    JSON-RPC 2.0 Specification
    https://www.jsonrpc.org/specification

    Model Context Protocol (MCP). Specification.
    https://modelcontextprotocol.io/
    https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
    https://modelcontextprotocol.io/specification/2025-11-25/server/tools
    https://modelcontextprotocol.io/specification/2025-11-25/server/utilities/logging

#>

# Load AnnotationsAttribute class if not already loaded
if (-not ('AnnotationsAttribute' -as [type])) {
    Add-Type -Path $PSScriptRoot/classes/AnnotationsAttribute.cs
}

function mcp.getCmdHelpInfo {
    [Alias("Get-McpCommandHelpInfo")]
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true,
            HelpMessage = "FunctionInfo object for processing."
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.FunctionInfo]
        $functionInfo
    )

    $fallbackSynopsis = 'NO SYNOPSIS AVAILABLE FOR THIS FUNCTION.'
    $fallbackDescription = 'NO DESCRIPTION AVAILABLE FOR THIS FUNCTION.'

    $commandHelpInfo = [PSCustomObject]@{
        Name        = $functionInfo.Name
        Synopsis    = $functionInfo.Synopsis ?? $fallbackSynopsis
        Description = @{
            text = $fallbackDescription
        }
    }
    try {
        $funcName = $functionInfo.Name
        $commandHelpInfo = Get-Help -Name $funcName -ErrorAction SilentlyContinue
    }
    catch {
        # Keep fallback object.
        $null = $_
    }

    return $commandHelpInfo
}

function mcp.getExtendedCmdDescription {
    [Alias("Get-McpExtendedCommandDescription")]
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true,
            HelpMessage = "FunctionInfo object for processing."
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.FunctionInfo]
        $functionInfo
    )

    $cmdHelpInfo = mcp.getCmdHelpInfo -functionInfo $functionInfo

    $extendedDescription = @()

    try {
        # TODO: improve extraction of additional metadata from help
        # .ROLE, .FUNCTIONALITY.

        if ($cmdHelpInfo.Synopsis) {
            $extendedDescription += $cmdHelpInfo.Synopsis.trim()
        }
        if ($cmdHelpInfo.Description) {
            $extendedDescription += $cmdHelpInfo.Description.text
        }
        if ($cmdHelpInfo.Functionality) {
            $extendedDescription += "<functionality>" + $cmdHelpInfo.Functionality.trim() + "</functionality>"
        }
        if ($cmdHelpInfo.Role) {
            $extendedDescription += "<role>" + $cmdHelpInfo.Role.trim() + "</role>"
        }
    }
    catch {
        # Keep fallback object.
        $null = $_
    }

    return ($extendedDescription -join " ") -replace "`n", " " -replace "\s{2,}", " "
}

function mcp.InputSchema.getParams {
    [Alias("Get-McpInputSchemaParams")]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "FunctionInfo object for processing."
        )]
        [System.Management.Automation.FunctionInfo]
        $functionInfo
    )

    $attrTypeName = 'System.Management.Automation.Internal.CommonParameters+ValidateVariableName'

    $excludeNames = @(
        'OutBuffer'
    )
    $excludeParamTypes = @(
        [System.Management.Automation.ActionPreference],
        [System.Management.Automation.ScriptBlock],
        [System.Management.Automation.SwitchParameter]
    )

    $Parameters = $functionInfo.Parameters.Values
    | Where-Object {
        ($_.Name -notin $excludeNames) -and
        ($_.ParameterType -notin $excludeParamTypes) -and
        -not ($_.Attributes | Where-Object { $_.GetType().FullName -eq $attrTypeName })
    }

    return $Parameters
}

function mcp.getInputSchema {
    <#
    .SYNOPSIS
        Build JSON-schema-like input description for PowerShell functions.
    .DESCRIPTION
        For each supplied FunctionInfo builds an ordered object with:
        - name, description, inputSchema (type/properties/required), returns.
        Returns an array of ordered dictionaries (one per function).
    .PARAMETER functionInfo
        Array of FunctionInfo objects to process.
    #>
    [OutputType([System.Collections.Specialized.OrderedDictionary[]])]
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Array of FunctionInfo objects to be used by the MCP server."
        )]
        [Alias("Get-McpInputSchema")]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.FunctionInfo[]]
        $functionInfo
    )

    $schema = [ordered]@{}

    foreach ($functionInfoItem in $functionInfo) {

        $Parameters = mcp.InputSchema.getParams -functionInfo $functionInfoItem

        $inputSchema = [ordered]@{
            type       = 'object'
            properties = [ordered]@{}
            required   = @()
        }

        foreach ($Parameter in $Parameters) {
            # TODO: param: switch, array, enum, datetime, object, hashtable, ...
            $type = switch ($Parameter.ParameterType) {
                { $_ -in [string], [System.String] } { 'string' }
                { $_ -in [int], [System.Int32], [long], [int64] } { 'integer' }
                { $_ -in [double], [float], [decimal] } { 'number' }
                { $_ -in [bool], [System.Boolean] } { 'boolean' }
                { $_ -eq [switch] } { 'boolean' }
                default { 'string' }
            }

            # Get parameter help: HelpMessage from Parameter attribute
            $paramHelp = $null

            if ($Parameter.Attributes) {
                $paramHelp = $Parameter.Attributes.where({ $_.HelpMessage }).HelpMessage
            }
            $paramHelp = $paramHelp ?? "No description available for this parameter."
            $paramHelp = $paramHelp.Trim()

            $inputSchema.properties[$Parameter.Name] = [ordered]@{
                type        = $type;
                description = $paramHelp
            }

            $paramAttr = $Parameter.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] })

            if ($paramAttr -and $paramAttr.Mandatory) {
                $inputSchema.required += $Parameter.Name
            }
        }

        # Build the final schema for this function (after processing all parameters)

        # $description = mcp.getCmdHelpInfo -functionInfo $functionInfoItem
        $description = mcp.getExtendedCmdDescription -functionInfo $functionInfoItem

        $schema[$functionInfoItem.Name] = [ordered]@{
            name        = $functionInfoItem.Name
            description = $description
            inputSchema = $inputSchema
        }

        $annotations = $functionInfoItem.ScriptBlock.Attributes.Where({ $_ -is [AnnotationsAttribute] })
        if ($annotations) {
            $schema[$functionInfoItem.Name]['annotations'] = [ordered]@{
                title         = $annotations.Title
                readOnlyHint  = $annotations.ReadOnlyHint
                openWorldHint = $annotations.OpenWorldHint
            }
            $schema[$functionInfoItem.Name]['title'] = $annotations.Title
        }
    }

    return (
        [object[]]$schema.Values
    );
}

function mcp.callTool {
    <#
    .SYNOPSIS
        Invoke a registered MCP tool (PowerShell function) with provided arguments.

    .DESCRIPTION
        Validates that the requested tool name exists in the provided tools list,
        invokes the underlying PowerShell function with the supplied arguments,
        and returns a structured ordered hashtable with fields:
        - result: execution output or error message
        - isError: $true when invocation failed

    .PARAMETER request
        JSON-RPC like request object containing at least `params.name` and `params.arguments`.

    .PARAMETER tools
        Array of ordered dictionaries describing available tools (name + input schema).

    .NOTES

    References: Method: tools/call
    https://modelcontextprotocol.io/specification/2025-11-25/server/tools#calling-tools

    SECURITY:
    - Ensure that only allowed tools are invoked
    - When logging, avoid sensitive data exposure (only argument keys, not a values)

    #>
    [OutputType([PSCustomObject])]
    [Alias("Invoke-MCPServerTool")]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "The JSON-RPC request object."
        )]
        [object]
        $request,

        [parameter(
            Mandatory = $true,
            HelpMessage = "The list of tools available to the MCP server."
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Specialized.OrderedDictionary[]]
        $tools
    )

    $toolName = $request.params.name
    $toolArgs = $request.params.arguments

    $executionResult = [string]::Empty
    $isError = $false

    try {
        # Handle errors during tool execution
        # Security: Ensure tool exists
        if (-not($tools.name -contains $toolName)) {
            throw [System.Exception]::new(
                "Unknown tool: $toolName"
            )
        }
        $executionResult = & $toolName @toolArgs
    }
    catch {
        $isError = $true
        $executionResult = $_.Exception.Message
    }


    # Spec §5.2.1: TextContent MUST be a string.
    # If the tool returns a complex object, serialize it to JSON.
    if ($executionResult -isnot [string]) {
        $serializedResult = ConvertTo-Json -InputObject $executionResult -Compress -ErrorAction SilentlyContinue
        $executionResult = $serializedResult ?? [string]$executionResult
    }

    return [PSCustomObject][ordered]@{
        result  = $executionResult
        isError = $isError
    }
}

function mcp.requestHandler {
    <#
    .SYNOPSIS
        Handle incoming MCP JSON-RPC requests and return responses.
    .DESCRIPTION
        Routes known MCP methods (initialize, ping, tools/list, tools/call, notifications)
        to their handlers, formats standard JSON-RPC 2.0 responses and error objects,
        and performs basic sanitization of request shape (jsonrpc/version and id).
    .NOTES
        References:
        - schema    - (https://json-schema.org/2025-11-25/2020-12/schema)
        - basic     - (https://modelcontextprotocol.io/specification/2025-11-25/basic)
        - tools     - (https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
    #>
    [Alias("Invoke-MCPRequestHandler")]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, HelpMessage = 'The JSON-RPC request object.')]
        [ValidateNotNullOrEmpty()]
        [object] $request,

        [Parameter(Mandatory, HelpMessage = 'The list of tools available to the MCP server.')]
        [System.Collections.Specialized.OrderedDictionary[]] $tools
    )

    $response = [ordered]@{
        jsonrpc = '2.0'
        id      = $request.id
        result  = [ordered]@{}
    }

    switch ($request.method) {
        'initialize' {
            # Method: initialize
            # https://modelcontextprotocol.io/specification/versioning
            $response.result = [ordered]@{
                protocolVersion = '2025-11-25'
                serverInfo      = [ordered]@{
                    name    = ($MyInvocation.MyCommand.Module.Name ?? 'PSMCP')
                    version = ([string]($MyInvocation.MyCommand.Module.Version) ?? '0.0.0')
                }
                capabilities    = @{
                    tools = @{
                        listChanged = $false
                    }
                }
            }

            # todo: remove when copilot-cli supports MCP Protocol Version 2025-11-25
            # https://github.com/github/copilot-cli/issues/1490
            # issue: copilot-cli: Support for MCP Protocol Version 2025-11-25 (#1490)
            if ([string]($request.params?.protocolVersion) -eq '2025-06-18') {
                # fallback for older protocol version - adjust response shape if needed
                # workaround for clientInfo":{"name":"github-copilot-developer","version":"1.0.0"}
                $response.result.protocolVersion = '2025-06-18'
            }

            return $response
        }
        'notifications/initialized' {
            # Handle notifications (no response needed)
            # https://modelcontextprotocol.io/docs/learn/architecture#notifications
            $response.result = @{
                message = "Notification received."
            }
            return $response
        }
        'ping' {
            # Method: ping
            # https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/ping#ping
            # Spec: ping response MUST return an empty result object.
            $response.result = @{}
            return $response
        }
        'tools/list' {
            # Method: tools/list
            # https://modelcontextprotocol.io/specification/2025-11-25/server/tools#listing-tools
            $response.result = [ordered]@{
                tools = $tools
            }
            return $response
        }
        'tools/call' {
            # Method: tools/call
            # https://modelcontextprotocol.io/specification/2025-11-25/server/tools#calling-tools

            $executionResult = mcp.callTool -request $request -tools $tools
            $response.result = @{
                content = @(
                    [ordered]@{
                        type = 'text'
                        text = $executionResult.result
                    }
                )
                isError = $executionResult.isError
            }
            return $response
        }
        default {
            # code: 32601 - Method not found
            # REF: JSON-RPC 2.0 Specification
            # https://www.jsonrpc.org/specification#error_object
            return [ordered]@{
                jsonrpc = "2.0"
                id      = $request.id
                error   = [ordered]@{
                    code    = -32601
                    message = "Method not found"
                    data    = "The method '$($request.method)' does not exist or is not available."
                }
            }
        }
    }
}

function mcp.core.stdio.main {
    <#
    .SYNOPSIS
        Main stdio loop for the MCP server - reads JSON lines and writes responses.
    .DESCRIPTION
        Reads lines from a provided TextReader, parses JSON-RPC requests,
        delegates to `mcp.requestHandler`, and writes compressed JSON responses
        to the provided TextWriter. Exits gracefully on EOF or when receiving
        a 'shutdown' method.
    .PARAMETER tools
        Array of tool descriptors (ordered dictionaries) available to the server.
    .PARAMETER In
        TextReader to read incoming messages (defaults to Console.In).
    .PARAMETER Out
        TextWriter to write outgoing messages (defaults to Console.Out).

    .NOTES

    Technical considerations:

    1. Testing: Use -In/-Out parameters with StringReader/StringWriter to simulate stdio in unit tests
       without requiring actual process pipes.

    2. Logging: Direct console output interferes with stdio protocol. For debugging, write JSON to stderr
       or use external logging mechanisms. The VS Code MCP debugger extension can capture stderr output.

    3. Encoding: Ensure UTF-8 encoding is set before calling this function (handled by New-MCPServer).

    Debugging examples:

        # Log to stderr without breaking stdio protocol
        [Console]::Error.WriteLine((ConvertTo-Json @{ debug = "message"; data = $value } -Compress))

        # Inspect call stack for troubleshooting
        [Console]::Error.WriteLine((ConvertTo-Json @{ callstack = (Get-PSCallStack).ScriptName } -Compress))

    #>
    param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = "The list of tools available to the MCP server."
        )]
        [System.Collections.Specialized.OrderedDictionary[]]
        [ValidateNotNullOrEmpty()]
        $tools = $null,

        [Parameter(
            DontShow = $true,
            Mandatory = $false,
            HelpMessage = "The TextReader to read incoming messages from."
        )]
        [System.IO.TextReader]
        $In = [Console]::In,

        [Parameter(
            DontShow = $true,
            Mandatory = $false,
            HelpMessage = "The TextWriter to write outgoing messages to."
        )]
        [System.IO.TextWriter]
        $Out = [Console]::Out

    )

    while ($true) <# WaitForExit #> {

        # NOTE: $line = [Console]::In.ReadLine()
        $line = $In.ReadLine();

        if ($null -eq $line) {
            break;
            # exit loop on null input (end of input stream)
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue;
            # skip empty input lines
        }

        try {

            $request = ConvertFrom-Json -InputObject $line -Depth 10 -AsHashtable -ErrorAction Stop

            # Log parsed method/id (non-sensitive)
            # try {
            #     psmcp.writeLog -LogEntry ([ordered]@{ WHAT = '[PARSED_REQUEST]'; METHOD = $request.method; ID = $request.id })
            # }
            # catch { }

            if ($null -eq $request.jsonrpc -or $request.jsonrpc -ne '2.0') {
                continue;
                # skip processing - invalid jsonrpc version
            }

            if ($null -eq $request.id) {
                continue;
                # skip processing - notifications have no id, so no response can be sent
            }

            if ($request.method -eq 'shutdown') {
                break;
                # Method: shutdown (Graceful shutdown)
                # https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle#shutdown
            }

            $response = mcp.requestHandler -request $request -tools $tools
            $Out.WriteLine((ConvertTo-Json -Compress -Depth 10 -InputObject $response -ErrorAction Stop))

        }
        catch {
            $err = [ordered]@{
                input_line = $line
                error      = $_.Exception.Message
            }
            [Console]::Error.WriteLine((ConvertTo-Json -InputObject $err -Depth 10 -Compress))
        }

    }
}

function mcp.settings.initialize {
    [CmdletBinding()]
    param()

    # Disable verbose and debug output for the MCP server
    # to avoid interfering with stdio communication
    Get-Item Variable:/DebugPreference, Variable:/VerbosePreference
    | Set-Variable -Value ([System.Management.Automation.ActionPreference]::SilentlyContinue)

    Set-Variable -Name settings -Value (
        [PSCustomObject][ordered]@{
            name        = ($MyInvocation.MyCommand.Module.Name) ?? 'pwsh.mcp'
            version     = ($MyInvocation.MyCommand.Module.Version).ToString() ?? '0.0.0'
            logFilePath = ($env:PWSH_MCP_SERVER_LOG_FILE_PATH) ?? [System.IO.Path]::ChangeExtension($MyInvocation.MyCommand.Module.Path, ".log")
        }
    ) -Option Constant -Scope Script -Visibility Private
}

function New-MCPServer {
    <#
    .SYNOPSIS
        Initialize and start a new MCP server exposing provided functions.

    .DESCRIPTION
        Prepares server settings, builds tool schemas from FunctionInfo array and starts the stdio main loop.
        Read more:
        - https://github.com/warm-snow-13/pwsh-mcp/blob/main/README.md
        - https://github.com/warm-snow-13/pwsh-mcp/blob/main/docs/pwsh.mcp.ug.md

    .PARAMETER functionInfo
        Array of FunctionInfo objects representing PowerShell functions to expose as tools.

    .EXAMPLE
        New-MCPServer -FunctionInfo (Get-Item Function:FunctionName1)

        Creates and starts an MCP server exposing a single PowerShell function as an MCP tool.
        The server will listen on stdio and handle incoming JSON-RPC requests from MCP clients.

        New-MCPServer -FunctionInfo (Get-Item Function:FunctionName1, Function:FunctionName2)
        Creates an MCP server exposing multiple PowerShell functions as tools.

        New-MCPServer -FunctionInfo (Get-Item Function:FunctionName1) -WhatIf

        Performs a dry run without starting the server. Returns JSON output containing the generated schema and server configuration for validation purposes.

    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'low'
    )]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Array of FunctionInfo objects to be used by the MCP server."
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.FunctionInfo[]]
        $functionInfo
    )

    # JSON-RPC messages MUST be UTF-8 encoded.
    [Console]::OutputEncoding = [Console]::InputEncoding = [System.Text.Encoding]::UTF8

    mcp.settings.initialize

    if ($PSCmdlet.ShouldProcess("MCP Server", "ensure functions: $($functionInfo.name)")) {
        # Create and start MCP server
        $toolList = mcp.getInputSchema -functionInfo $functionInfo
        mcp.core.stdio.main -tools $toolList
    }
    else {
        # Dry run mode - return server status and schema as JSON string
        return [ordered]@{
            jsonrpc = "2.0"
            method  = "notifications"
            params  = [ordered]@{
                level = "info"
            }
            psmcp   = @{
                path    = ($MyInvocation.MyCommand.Module.path)
                version = ($MyInvocation.MyCommand.Module.Version ?? '0.0.0').ToString()
            }
            caller  = Get-PSCallStack | Select-Object -ExpandProperty Command -Skip 1
            schema  = mcp.getInputSchema -functionInfo $functionInfo
        } | ConvertTo-Json -Compress -Depth 10
    }
}
