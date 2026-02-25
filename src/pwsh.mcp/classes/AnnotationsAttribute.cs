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

    public AnnotationsAttribute()
    {
        Title = string.Empty;
    }

    public AnnotationsAttribute(string title, bool readOnlyHint = false, bool openWorldHint = false)
    {
        if (string.IsNullOrWhiteSpace(title))
            throw new ArgumentException("title must not be empty", nameof(title));
        Title = title;
        ReadOnlyHint = readOnlyHint;
        OpenWorldHint = openWorldHint;
    }

    public override string ToString() {
        return $"Annotations: {Title} (ReadOnly={ReadOnlyHint}, OpenWorld={OpenWorldHint})";
    }
}