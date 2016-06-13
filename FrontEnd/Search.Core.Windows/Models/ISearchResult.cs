namespace Search.Core.Windows.Models
{
    public interface ISearchResult
    {
        string Id { get; set; }
        string Index { get; set; }
        string Type { get; set; }
        double Score { get; set; }
        string Source { get; set; }

        //public string Parent { get; set; }
        //public string Routing { get; set; }
        //public long? Timestamp { get; set; }
        //public long? Ttl { get; set; }
        //public long? Version { get; set; }
        //public IEnumarable<KeyValuePair<string, string>> Hihglights { get; set; }
    }
}