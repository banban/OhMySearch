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
            From = 0;
            Size = 20;
            QueryOptions = new List<QueryOption>();
            SearchResults = new SearchResults();
            Aggregations = new List<Aggregation>();
        }

        /////The method will return a collection of terms that match the query. 
        /////The result of particular suggestion is a collection of suggestion options. 
        /////We may order them by frequency or weight (which we did not defined) and return the suggested text.
        //[Nest.Completion]
        //public IEnumerable<string> Suggest { get; set; }

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

        private string myChosenAggregations = string.Empty;
        public string ChosenAggregations
        {
            get
            {
                return myChosenAggregations;
            }
            set
            {
                if (value == null)
                    value = string.Empty;
                myChosenAggregations = value;
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
        public string ScrollId { get; internal set; }
        public string DebugInformation { get; internal set; }

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
            var groups = this.Aggregations
                .Where(qo => !string.IsNullOrEmpty(qo.Key) && qo.Count > 0)
                .OrderBy(gr => gr.Group).Select(qo => qo.Group).Distinct();
            return groups;
        }

        public IEnumerable<Aggregation> GetAggregations(string Group)
        {
            var aggs = this.Aggregations
                .Where(qo => qo.Group == Group && !string.IsNullOrEmpty(qo.Key) && qo.Count > 0)
                .OrderByDescending(qo => qo.Count);
            return aggs;
        }
    }

}
