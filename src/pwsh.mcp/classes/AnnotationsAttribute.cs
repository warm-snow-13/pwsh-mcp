/*

AnnotationsAttribute: Provides metadata hints for tools/clients (MCP).

“Schema Reference,” Model Context Protocol.
https://modelcontextprotocol.io/specification/draft/schema#toolannotations
(accessed Mar. 03, 2026).

*/

using System;

[AttributeUsage(AttributeTargets.Method, Inherited = false, AllowMultiple = false)]
/// <summary>Annotations: metadata hints for tools/clients (MCP).</summary>
public sealed class AnnotationsAttribute : Attribute
{
    /// <summary>Title/short description of the annotation.</summary>
    public string Title { get; set; }

    /// <summary>Hint that the tool is read-only.</summary>
    public bool ReadOnlyHint { get; set; }

    /// <summary>Hint that the tool may interact with the external world.</summary>
    public bool OpenWorldHint { get; set; }

    /// <summary>Hint that the tool may perform destructive updates.</summary>
    public bool DestructiveHint { get; set; }

    /// <summary>Hint that the tool is idempotent when called repeatedly with the same args.</summary>
    public bool IdempotentHint { get; set; }

    public AnnotationsAttribute()
    {
        Title = string.Empty;
        ReadOnlyHint = false;
        OpenWorldHint = true;
        DestructiveHint = true;
        IdempotentHint = false;
    }

    public AnnotationsAttribute(string title, bool readOnlyHint = false, bool openWorldHint = true, bool destructiveHint = true, bool idempotentHint = false)
    {
        if (string.IsNullOrWhiteSpace(title))
            throw new ArgumentException("title must not be empty", nameof(title));
        Title = title;
        ReadOnlyHint = readOnlyHint;
        OpenWorldHint = openWorldHint;
        DestructiveHint = destructiveHint;
        IdempotentHint = idempotentHint;
    }

    public override string ToString() {
        return $"Annotations: {Title} (ReadOnly={ReadOnlyHint}, Destructive={DestructiveHint}, Idempotent={IdempotentHint}, OpenWorld={OpenWorldHint})";
    }
}
