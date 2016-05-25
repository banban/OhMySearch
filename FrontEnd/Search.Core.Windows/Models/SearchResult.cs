using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.Windows.Models
{
    public class SearchResult
    {
        public string Id { get; set; }
        public string Index { get; set; }
        public string Parent { get; set; }
        public string Routing { get; set; }
        public double Score { get; set; }
        public string Source { get; set; }
        public long? Timestamp { get; set; }
        public long? Ttl { get; set; }
        public string Type { get; set; }
        public string Path { get; set; }
        public long? Version { get; set; }

        //public IEnumarable<KeyValuePair<string, string>> Hihglights { get; set; }
    }
}
