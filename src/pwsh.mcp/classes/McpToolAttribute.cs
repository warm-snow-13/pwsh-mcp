/*

McpToolAttribute: Attribute used to mark methods as MCP-exposed tools.

*/

using System;

[AttributeUsage(AttributeTargets.Method, Inherited = false, AllowMultiple = false)]
/// <summary>Marks a method as an MCP-exposed tool</summary>
public sealed class McpToolAttribute : Attribute
{

    public McpToolAttribute() {
    }

    public override string ToString() {
        return "McpToolAttribute";
    }
}
