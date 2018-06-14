using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.Models
{
    public class Aggregation //: IAggregation
    {
        public string Group { get; set; }
        public string Key { get; set; }
        public long? Count { get; set; }
        //public bool? Selected { get; set; }
    }
}
