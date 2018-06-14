using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.Models
{
    public class Redirect
    {
        [JsonProperty("Name")]
        public string Name { get; set; }
        [JsonProperty("Title")]
        public string Title { get; set; }
        [JsonProperty("Url")]
        [StringLength(512), Display(Name = "Url"), DataType(DataType.Url)]
        public string Url { get; set; }
    }
}
