/*

McpToolAttribute: Attribute used to mark methods as MCP-exposed tools.

*/

using System;

[AttributeUsage(AttributeTargets.Method, Inherited = false, AllowMultiple = false)]
/// <summary>Marks a method as an MCP-exposed tool with name and description.</summary>
public sealed class McpToolAttribute : Attribute
{
    /// <summary>Name of the tool exposed to MCP clients.</summary>
    public string Name { get; set; }

    /// <summary>Short description/help text for the tool.</summary>
    public string Description { get; set; }

    public McpToolAttribute()
    {
        Name = string.Empty;
        Description = string.Empty;
    }

    public McpToolAttribute(string name)
        : this(name, string.Empty)
    {
    }

    public McpToolAttribute(string name, string description)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("name must not be empty", nameof(name));
        Name = name;
        Description = description ?? string.Empty;
    }

    public override string ToString()
    {
        return $"McpTool: {Name} - {Description}";
    }
}
