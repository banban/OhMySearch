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
            SearchResults = new SearchResults();
            Aggregations = new List<Aggregation>();
        }

        private string myQueryTerm = string.Empty;
        public string QueryTerm
        {
            get {
                return myQueryTerm;
            }
            set {
                if (value == null)
                    value = string.Empty;
                myQueryTerm = value;
            }
        }

        private string myChosenOptions = string.Empty;
        public string ChosenOptions
        {
            get
            {
                return myChosenOptions;
            }
            set {
                if (value == null)
                    value = string.Empty;
                myChosenOptions = value;
            }
        }

        public long Total { get; set; }
        public int? From { get; set; }
        public int? Size { get; set; }

        public SearchResults SearchResults { get; set; }
        public List<QueryOption> QueryOptions { get; set; }
        public List<Aggregation> Aggregations { get; set; }

        public IEnumerable<string> GetOptionGroups()
        {
            var groups = this.QueryOptions.Select(qo => qo.OptionGroup).Distinct();
            return groups;
        }

        public IEnumerable<QueryOption> GetOptions(string OptionGroup)
        {
            var options = this.QueryOptions
                .Where(qo => qo.OptionGroup == OptionGroup)
                .OrderBy(qo => qo.Key);
            return options;
        }

        public IEnumerable<string> GetAggregations()
        {
            var groups = this.Aggregations.OrderBy(gr => gr.Group).Select(qo => qo.Group).Distinct();
            return groups;
        }

        public IEnumerable<Aggregation> GetAggregations(string Group)
        {
            var aggs = this.Aggregations
                .Where(qo => qo.Group == Group && !string.IsNullOrEmpty(qo.Key))
                .OrderByDescending(qo => qo.Count);
            return aggs;
        }
    }

}
