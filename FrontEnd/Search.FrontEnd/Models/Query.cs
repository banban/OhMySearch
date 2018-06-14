using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.FrontEnd.Models
{
    public class Query
    {
        public Query()
        {
            From = 0;
            Size = 20;
            MinScore = 0;
            MaxScore = 0;
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

                if (value == "|")
                    value = string.Empty;

                ///mask: "Group1.Field1.Value1|Group1.Field2.Value2|Group2.Field3.Value3|..."
                var arr = value.Replace("||","|").Trim('|').Split('|');
                if (arr.Length > 1)
                {
                    for (int i = arr.Length - 1; i >= 0; i--) //from left to right, i.g. from bottom to top
                    {
                        if (!string.IsNullOrEmpty(arr[i]))
                        {
                            var childGroup = arr[i].Substring(0, arr[i].IndexOf('.')).Trim();
                            var childFieldRange = arr[i].Substring(arr[i].IndexOf('.') + 1).Trim();
                            var childField = childFieldRange.Substring(0, childFieldRange.IndexOf('.')).Trim();
                            var childRange = childFieldRange.Substring(childFieldRange.IndexOf('.') + 1).Trim();

                            if (childGroup == "Top ranges")
                            {
                                var childGreaterThanOrEqualTo = double.Parse(childRange.Split('-')[0].Trim());
                                var childLessThanOrEqualTo = ((childRange.Split('-')[1].Trim() != "...") ? double.Parse(childRange.Split('-')[1].Trim()) : double.MaxValue);
                                ///We need to exclude parent ranges influencing on current range
                                ///For example, ChosenAggregations="Top ranges.budget.7000002 - 14000001|Top ranges.budget.8540001 - 8980000|Top ranges.budget.8980001 - 9420000|"
                                ///, which means hierarchy like this: wide range 1 > narrow range1 > narrower range2, narrower range3
                                ///Top ranges.budget.7000002 - 14000001
                                ///     Top ranges.budget.8540001 - 8980000
                                ///     Top ranges.budget.8980001 - 9420000
                                ///So, we can ignore parent range 7000002 - 14000001 as a filter, as far as children have more specific scope
                                for (int j = i - 1; j >= 0; j--)
                                {
                                    var parentGroup = arr[j].Substring(0, arr[j].IndexOf('.')).Trim();
                                    var parentFieldRange = arr[j].Substring(arr[j].IndexOf('.') + 1).Trim();
                                    var parentField = parentFieldRange.Substring(0, parentFieldRange.IndexOf('.')).Trim();
                                    var parentRange = parentFieldRange.Substring(parentFieldRange.IndexOf('.') + 1).Trim();
                                    var parentGreaterThanOrEqualTo = double.Parse(parentRange.Split('-')[0].Trim());
                                    var parentLessThanOrEqualTo = ((parentRange.Split('-')[1].Trim() != "...") ? double.Parse(parentRange.Split('-')[1].Trim()) : double.MaxValue);
                                    ///Check if parent range (left) overlaps with current one (right), e.g. 7000002 < 8540001 and 8540001 < 14000001
                                    if (childGroup == parentGroup && childField == parentField 
                                        && (
                                                (parentGreaterThanOrEqualTo <= childGreaterThanOrEqualTo && childGreaterThanOrEqualTo <= parentLessThanOrEqualTo)
                                                || (parentGreaterThanOrEqualTo <= childLessThanOrEqualTo && childLessThanOrEqualTo <= parentLessThanOrEqualTo)

                                                || (childGreaterThanOrEqualTo <= parentGreaterThanOrEqualTo && parentGreaterThanOrEqualTo <= childLessThanOrEqualTo)
                                                || (childGreaterThanOrEqualTo <= parentLessThanOrEqualTo && parentLessThanOrEqualTo <= childLessThanOrEqualTo)
                                            )
                                        )
                                    {
                                        //inherit left border from parent
                                        if (childGreaterThanOrEqualTo < parentGreaterThanOrEqualTo)
                                        {
                                            childGreaterThanOrEqualTo = parentGreaterThanOrEqualTo;
                                        }

                                        //inherit right border from parent
                                        if (childLessThanOrEqualTo > parentLessThanOrEqualTo)
                                        {
                                            childLessThanOrEqualTo = parentLessThanOrEqualTo;
                                        }

                                        //remove overlapping parent
                                        value = value.Replace(arr[j], "");
                                    }
                                }
                                //update child, if applicable
                                value = value.Replace(arr[i], childGroup + "." + childField + "." + childGreaterThanOrEqualTo.ToString() + " - " + (childLessThanOrEqualTo == double.MaxValue ? "..." : childLessThanOrEqualTo.ToString()));
                            }
                        }
                    }
                }

                myChosenAggregations = value.Replace("||", "|").TrimStart('|');
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

                if (!value.Contains("5_")) //check if Aggregation is used
                    this.ChosenAggregations = string.Empty;

                if (value.Contains("6_1")) //check if inversed filter condition is defined
                    this.Inversed = true;

                myChosenOptions = value;//.Replace("+"," ");
            }
        }

        public double? MinScore { get; set; }
        public double? MaxScore { get; set; }
        public long Total { get; set; }
        public int? From { get; set; }
        public int? Size { get; set; }
        public bool? Inversed { get; set; }

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
