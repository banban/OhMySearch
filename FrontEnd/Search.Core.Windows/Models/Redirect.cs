using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.Windows.Models
{
    public class Redirect
    {
        [JsonProperty("Name")]
        public string Name { get; set; }
        [JsonProperty("Title")]
        public string Title { get; set; }
        [JsonProperty("Url")]
        public string Url { get; set; }
    }
}
