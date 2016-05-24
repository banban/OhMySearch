using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.Windows.Models
{
    public class QueryOption //: IQueryOption
    {
        public string OptionGroup { get; set; }
        public string Key { get; set; }
        public string Value { get; set; }
        public bool? Selected { get; set; }
    }
}
