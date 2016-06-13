using System;

namespace Search.Core.Windows.Models
{
    public interface IFileResult
    {
        string Path { get; set; }
        string Extension { get; set; }
        byte[] Content { get; set; }
        DateTime LastModified { get; set; }
    }
}