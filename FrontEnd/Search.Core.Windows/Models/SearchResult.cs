using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text.RegularExpressions;
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
        public double? Score { get; set; }
        [Display(Name = "Details", Description ="This content is compressed and optimised for Elastic Search engine and do not reflect original content directly.")]
        public string Source { get; set; }

        public string PrettySource {
            get {
                //remove new lines
                string result = this.Source.Replace("\r\n", "");
                // http/https addresses are replaced with Open link
                result = Regex.Replace(result, "\"(http[s]?://.[^\"]+)\"", "<a href='$1' target='_self'>Open</a>", RegexOptions.IgnoreCase | RegexOptions.Multiline);
                // unc paths are replaced with Open link
                result = Regex.Replace(result, "\"(//.[^\"]+)\"", "<a href='file:///$1' target='_self'>Open</a>", RegexOptions.IgnoreCase | RegexOptions.Multiline);

                //field names without values
                result = Regex.Replace(result, "\"(.[^\"]+)\":\\s+\"\"", "", RegexOptions.IgnoreCase | RegexOptions.Multiline);
                result = Regex.Replace(result, "\"(.[^\"]+)\":\\s+,", "", RegexOptions.IgnoreCase | RegexOptions.Multiline);

                //field names without quotes
                result = Regex.Replace(result, "\"(.[^\"]+)\":\\s+", "<label class='search-details-label'>$1</label>: ", RegexOptions.IgnoreCase | RegexOptions.Multiline);
                //field values with quotes
                result = Regex.Replace(result, ":\\s+\"(.[^\"]+)\"", ": <label class='search-details-value'>\"$1\"</label>", RegexOptions.IgnoreCase | RegexOptions.Multiline);
                //field values without quotes
                result = Regex.Replace(result, ":\\s+((\\d{1,10}.?(\\d{1,6})?))", ": <label class='search-details-value'>$1</label>", RegexOptions.IgnoreCase | RegexOptions.Multiline);
                //compress
                result = result.Trim().TrimStart('{').TrimEnd('}').Trim();
                result = Regex.Replace(result, "\"(.[^\"]+)\":\\s?[,$]", "", RegexOptions.IgnoreCase | RegexOptions.Multiline);
                result = result.Replace(",  ,", ",").TrimEnd(',').Trim();
                return result;
            }
        }

        public string PrettyTitle
        {
            get
            {
                var source = Newtonsoft.Json.JsonConvert.DeserializeObject<dynamic>(this.Source);
                string result = (string)source["Title"];
                if (string.IsNullOrEmpty(result))
                {
                    result = (string)source["Name"];
                }
                if (string.IsNullOrEmpty(result))
                {
                    result = (string)source["DisplayName"];
                }
                if (string.IsNullOrEmpty(result))
                {
                    result = (string)source["Project_Title"];
                }
                if (string.IsNullOrEmpty(result))
                {
                    result = (string)source["FileName"];
                }
                if (string.IsNullOrEmpty(result))
                {
                    var path = (string)source["Path"];
                    if (path.StartsWith("//"))
                    {
                        if (this.CanRead && path.TrimEnd('/').LastIndexOf('/') > 0)
                        {
                            result = path.Substring(path.TrimEnd('/').LastIndexOf('/')+1);
                        }
                    }
                }

                return result;
            }
        }

        public string Path { get; set; }
        public string NavigatePath {
            get {
                string path = this.Path;
                if ( !string.IsNullOrEmpty(this.Path) && (path.StartsWith("//") || path.StartsWith("\\\\")) )
                {
                    path = "file:///" + path;
                }
                //else if ( !string.IsNullOrEmpty(this.Path) && (path.StartsWith("http")) )
                //{
                //    path = System.Net.WebUtility.HtmlDecode(path);
                //}
                return path;
            }
        }
        public string PrettyPath
        {
            get
            {
                string path = this.Path;
                if (!string.IsNullOrEmpty(this.Path) && (path.StartsWith("//")))
                {
                    path = path.Replace("/", "\\");
                }
                return path;
            }
        }

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
