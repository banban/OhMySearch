using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.Windows.Models
{
    public class SearchResult: ISearchResult, IFileResult
    {
        public SearchResult()
        {
            MoreLikeThis = new List<SearchResult>();
        }
        public string Id { get; set; }

        private bool canRead = true;
        public bool CanRead
        {
            get { return canRead; }
            set
            {
                canRead = value;
                if (!canRead)
                {
                    //instead of hiding data I use data masking
                    this.Source = "***";
                    this.Path = "***";
                    this.ThumbnailPath = "***";
                    this.Extension = "***";
                    this.Summary = "***";
                }
            }
        }

        public string Index { get; set; }
        public string Type { get; set; }
        public double Score { get; set; }
        public string Source { get; set; }

        public string Path { get; set; }
        public string ThumbnailPath { get; set; }
        private string myExtension = string.Empty;
        public string Extension
        {
            get { return myExtension; }
            set {
                myExtension = value;
                if (myExtension == null)
                    myExtension = string.Empty;
                myExtension = myExtension.ToUpper().Trim().TrimStart('.');
                if (myExtension.Length > 5)
                {
                    myExtension = mySummary.Substring(0, 5);
                }
            }
        }

        [Display(Name = "Last Modified"), DisplayFormat(DataFormatString = "{0:G}")] 
        public DateTime LastModified { get; set; }

        private string mySummary = string.Empty;
        public string Summary
        {
            get { return mySummary; }
            set {
                mySummary = value;
                if (mySummary == null)
                    mySummary = string.Empty;
                mySummary = mySummary.Trim('{').Trim('}').Replace("\r\n", " ").Replace("  ", " ").Trim();
                if (mySummary.Length > 512)
                {
                    mySummary = mySummary.Substring(0, 512) + "...";
                }
            }
        }

        public byte[] Content { get; set; }
        public IEnumerable<SearchResult> MoreLikeThis { get; set; }
    }

    public class SearchResults
    {

        public IEnumerable<SearchResult> Items { get; set; }
        public Pager Pager { get; set; }
    }
}
