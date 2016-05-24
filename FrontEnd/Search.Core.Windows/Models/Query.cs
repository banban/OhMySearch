using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.Windows.Models
{
    public class Query
    {
        public Query()
        {
            ChosenOptions = string.Empty;
            From = 0;
            Size = 20;
            QueryOptions = new List<QueryOption>();
        }
        public string QueryTerm { get; set; }
        public string ChosenOptions { get; set; }
        public long Total { get; set; }
        public int? From { get; set; }
        public int? Size { get; set; }

        public IEnumerable<QueryOption> QueryOptions { get; set; }

        public IEnumerable<string> GetOptionGroups()
        {
            var groups = this.QueryOptions.Select(qo => qo.OptionGroup).Distinct();
            return groups;
        }

        public IEnumerable<QueryOption> GetOptions(string OptionGroup)
        {
            var groups = this.QueryOptions
                .Where(qo => qo.OptionGroup == OptionGroup)
                .OrderBy(qo => qo.Key);
            return groups;
        }
    }
}
