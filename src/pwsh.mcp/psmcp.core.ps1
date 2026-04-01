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


enum McpErrorCode {
    ParseError = -32700
    InvalidRequest = -32600
    MethodNotFound = -32601
    InvalidParams = -32602
    InternalError = -32603
}

function mcp.getCmdHelpInfo {
    <#
    .SYNOPSIS
        Extract command help information from a FunctionInfo object.

    .NOTES
        The are multiple ways to provide help information for PowerShell functions:
        - $helpContent = Get-Help -Name $functionInfo.Name -ErrorAction Stop
        - $helpContent = $functionInfo.ScriptBlock?.Ast?.GetHelpContent()

    #>
    [Alias("Get-McpCommandHelpInfo")]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true,
            HelpMessage = "FunctionInfo object for processing."
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.FunctionInfo]
        $functionInfo,

        [parameter(
            HelpMessage = "Whether to return extended help information if available."
        )]
        [switch]$extended
    )

    $fallback = $functionInfo.Name

    $helpContent = try { $functionInfo.ScriptBlock?.Ast?.GetHelpContent() } catch { $null }

    if (-not $helpContent) { return $fallback }

    $synopsis = $helpContent.Synopsis?.ToString().Trim() ?? $fallback

    if (-not $extended) { return $synopsis }

    $parts = $helpContent.PSObject.Properties
    | Where-Object { $_.Name -in 'Synopsis', 'Component', 'Role', 'Functionality' }
    | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Value) }
    | ForEach-Object { [string]::Concat($_.Name, ': ', ([string]$_.Value).Trim()) }

    return ([string]::Join([Environment]::NewLine, $parts)) ?? $fallback

}

function mcp.InputSchema.getParams {
    <#
    .SYNOPSIS
        Extract input parameters for a PowerShell function, excluding common and internal parameters.

    .PARAMETER functionInfo
        FunctionInfo object for processing.

    .OUTPUTS
        Array of ParameterMetadata objects representing the input parameters.
    #>
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

    $attrType = 'System.Management.Automation.Internal.CommonParameters+ValidateVariableName'

    # Exclude certain parameter types
    $excludeNames = @(
        'OutBuffer'
    )
    # Exclude common/internal parameter names
    $excludeTypes = @(
        [System.Management.Automation.ActionPreference],
        [System.Management.Automation.ScriptBlock],
        [System.Management.Automation.SwitchParameter]
    )

    $functionInfo.Parameters.Values | Where-Object {
        ($_.Name -notin $excludeNames) -and
        ($_.ParameterType -notin $excludeTypes) -and
        -not ($_.Attributes.Where({ $_.GetType().FullName -eq $attrType })) -and
        -not ($_.Attributes.Where({ $_.DontShow }))
    }
}

function mcp.InputSchema.getTypeSchema {
    <#
    .SYNOPSIS
        Returns a JSON Schema fragment for a given .NET type (PowerShell parameter type).
    .DESCRIPTION
        Maps .NET/PowerShell types to JSON Schema types for input validation.
        Handles arrays, primitives, objects, and date/time types.
    #>
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, HelpMessage = 'The .NET type of the parameter.')]
        [ValidateNotNull()]
        [System.Type]
        $parameterType
    )

    # Handle array types recursively
    if ($parameterType.IsArray) {
        $elementType = $parameterType.GetElementType() ?? [string]
        return [ordered]@{
            type  = 'array'
            items = mcp.InputSchema.getTypeSchema -parameterType $elementType
        }
    }

    # Map types to JSON schema types
    switch ($parameterType) {
        { $_ -in [string], [System.String], [char], [System.Char] } {
            return [ordered]@{ type = 'string' }
        }
        { $_ -in [byte], [int], [System.Int32], [long], [System.Int64] } {
            return [ordered]@{ type = 'integer' }
        }
        { $_ -in [double], [float], [single], [decimal] } {
            return [ordered]@{ type = 'number' }
        }
        { $_ -in [switch], [bool], [System.Boolean] } {
            return [ordered]@{ type = 'boolean' }
        }
        { $_ -in [datetime], [System.DateTime], [System.DateTimeOffset] } {
            return [ordered]@{ type = 'string'; format = 'date-time' }
        }
        { $_ -in [object], [hashtable], [PSCustomObject] } {
            return [ordered]@{ type = 'object'; additionalProperties = $true }
        }
        default {
            # Treat unknown types as string
            return [ordered]@{ type = 'string' }
        }
    }

}

function mcp.InputSchema.getSchema {
    <#
    .SYNOPSIS
        Build JSON-schema-like input description for PowerShell functions.

    .DESCRIPTION
        For each supplied FunctionInfo builds an ordered object with:
        - name
        - description
        - inputSchema (type/properties/required)
        Returns an array of ordered dictionaries (one per function).

    .PARAMETER functionInfo
        Array of FunctionInfo objects to process.

    .NOTES
        Supported complex types:
        - Arrays: type=array + items
        - DateTime/DateTimeOffset: type=string + format=date-time
        - Hashtable/object-like: type=object + additionalProperties=true
    #>
    [Alias("Get-McpInputSchema")]
    [OutputType([System.Collections.Specialized.OrderedDictionary[]])]
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Array of FunctionInfo objects to be used by the MCP server."
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.FunctionInfo[]]
        $functionInfo
    )

    $schema = [ordered]@{}

    foreach ($functionInfoItem in $functionInfo) {
        # Extract parameters for this function
        $Parameters = mcp.InputSchema.getParams -functionInfo $functionInfoItem

        # Build input schema for parameters
        $inputSchema = [ordered]@{
            type       = 'object'
            properties = [ordered]@{}
            required   = @()
        }

        foreach ($parameter in $Parameters) {
            # Build schema for each parameter
            $paramSchema = mcp.InputSchema.getTypeSchema -parameterType $parameter.ParameterType

            # Add parameter help as description
            $paramHelp = ($parameter.Attributes.Where({ $_.HelpMessage }).HelpMessage) ?? [string]::Empty
            $paramSchema['description'] = $paramHelp

            # Add parameter to schema properties
            $inputSchema.properties[$parameter.Name] = $paramSchema

            # Add to required if parameter is mandatory
            if ($parameter.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory) {
                $inputSchema.required += $parameter.Name
            }
        }

        # Build the final schema for this function
        $description = mcp.getCmdHelpInfo -functionInfo $functionInfoItem -extended

        $schema[$functionInfoItem.Name] = [ordered]@{
            name        = $functionInfoItem.Name
            description = $description
            inputSchema = $inputSchema
        }

        # Add annotations if present
        $annotations = $functionInfoItem.ScriptBlock.Attributes.Where({ $_ -is [AnnotationsAttribute] })
        if ($annotations) {
            $schema[$functionInfoItem.Name]['annotations'] = [ordered]@{
                title           = $annotations.Title
                readOnlyHint    = $annotations.ReadOnlyHint
                destructiveHint = $annotations.DestructiveHint
                idempotentHint  = $annotations.IdempotentHint
                openWorldHint   = $annotations.OpenWorldHint
            }
            if ($annotations.Title) {
                $schema[$functionInfoItem.Name]['title'] = $annotations.Title
            }
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
        Ensures that the requested tool exists in the provided tools collection,
        then executes the corresponding PowerShell function with the supplied arguments.

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
    try {
        # Extract tool name and arguments from request
        $toolName = $request.params?.name
        $toolArgs = $request.params?.arguments ?? @{}

        # Security: Ensure tool exists in allowed list
        if (-not($tools.name -contains $toolName)) {
            throw [System.Exception]::new(
                "Unknown tool: $toolName"
            )
        }

        $result = & $toolName @toolArgs

        # Serialize result if not string
        $result = ($result -is [string]) ? $result : (ConvertTo-Json $result -Compress)

        return [PSCustomObject][ordered]@{
            text    = $result
            isError = $false
        }
    }
    catch {
        # Return error message in result
        return [PSCustomObject][ordered]@{
            text    = $_.Exception.Message
            isError = $true
        }
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

    # Build base response object
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
                    name    = ([string]($MyInvocation.MyCommand.Module.Name))
                    version = ([string]($MyInvocation.MyCommand.Module.Version))
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
            $response.result = [ordered]@{
                content = @(
                    [ordered]@{
                        type = 'text'
                        text = $executionResult.text
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
                    code    = [int][McpErrorCode]::MethodNotFound
                    message = "Request method not found"
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
            break # Exit loop on null input (end of input stream)
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue # Skip empty input lines
        }

        try {
            # Parse JSON-RPC request
            $request = ConvertFrom-Json -InputObject $line -Depth 10 -AsHashtable -ErrorAction Stop

            if ($request.jsonrpc -ne '2.0') { continue } # Skip invalid jsonrpc version
            if ($null -eq $request.id) { continue }     # Skip notifications (no id)

            if ($request.method -eq 'shutdown') {
                break;
                # Method: shutdown (Graceful shutdown)
                # https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle#shutdown
            }

            # Handle request and write response
            $response = mcp.requestHandler -request $request -tools $tools
            $Out.WriteLine((ConvertTo-Json -Compress -Depth 10 -InputObject $response -ErrorAction Stop))

        }
        catch {
            # Log error to stderr as JSON
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
            name        = ($MyInvocation.MyCommand.Module.Name)
            version     = ($MyInvocation.MyCommand.Module.Version ?? [System.Version]::Parse("0.0.0")).ToString()
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
        ConfirmImpact = [System.Management.Automation.ConfirmImpact]::Low
    )]
    [OutputType([void], [string])]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Array of FunctionInfo objects to be used by the MCP server."
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.FunctionInfo[]]
        $functionInfo
    )

    # MCP/stdio and common JSON-RPC usage expect UTF-8; enforce UTF-8 for stdin/stdout.
    [Console]::OutputEncoding = [Console]::InputEncoding = [System.Text.Encoding]::UTF8

    # Set output rendering to PlainText
    $PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

    # Initialize server settings and configuration
    mcp.settings.initialize

    $schema = mcp.InputSchema.getSchema -functionInfo $functionInfo

    if ($PSCmdlet.ShouldProcess("MCP Server", "ensure functions: $($functionInfo.name)")) {
        # Create and start MCP server
        # Create and start MCP server
        mcp.core.stdio.main -tools $schema
        return
    }

    # Dry run: return server status and schema as JSON
    return [ordered]@{
        jsonrpc = "2.0"
        method  = "notifications"
        params  = [ordered]@{
            level = "info"
        }
        psmcp   = @{
            path    = ($MyInvocation.MyCommand.Module.path)
            version = ($MyInvocation.MyCommand.Module.Version)?.ToString()
        }
        caller  = Get-PSCallStack | Select-Object -ExpandProperty Command -Skip 1
        schema  = $schema
    } | ConvertTo-Json -Compress -Depth 10

}
