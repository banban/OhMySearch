using Microsoft.Graph;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using System.Xml.Linq;

namespace Search.Core.Windows.Controllers
{
    public class SharePointController
    {
        public async Task AppendAuthenticationHeaderAsync()
        {
            var authenticationToken = "token";

            var authenticationProvider = new DelegateAuthenticationProvider(
                (requestMessage) =>
                {
                    requestMessage.Headers.Authorization = new AuthenticationHeaderValue(CoreConstants.Headers.Bearer, authenticationToken);
                    return Task.FromResult(0);
                });

            using (var httpRequestMessage = new HttpRequestMessage())
            {
                await authenticationProvider.AuthenticateRequestAsync(httpRequestMessage);
                //Assert.AreEqual(
                //    string.Format("{0} {1}", CoreConstants.Headers.Bearer, authenticationToken),
                //    httpRequestMessage.Headers.Authorization.ToString(),
                //    "Unexpected authorization header set.");
            }
        }

        public async Task AppendAuthenticationHeaderAsync_DelegateNotSet()
        {
            var authenticationProvider = new DelegateAuthenticationProvider(null);

            using (var httpRequestMessage = new HttpRequestMessage())
            {
                await authenticationProvider.AuthenticateRequestAsync(httpRequestMessage);
                //Assert.IsNull(httpRequestMessage.Headers.Authorization, "Unexpected authorization header set.");
            }
        }
    }
    /*public Models.Query SearchOnPrem(Models.Query query)
    {
        List<Models.SearchResult> results = new List<Models.SearchResult>();

        //IntranetSearchService.QueryService queryService = new IntranetSearchService.QueryService();
        //queryService.PreAuthenticate = true;
        //queryService.Credentials = System.Net.CredentialCache.DefaultNetworkCredentials;

        XNamespace ns = "urn:Microsoft.Search.Query"; // XNamespace.Get(@"urn:Microsoft.Search.Query");
        string scope = "All Sites";
        //if (!query.QueryOptions.Contains("5_???"))
        //{
        //    scope = GetSearchFilterValue(query.QueryTerm, "{Scope:", "}");
        //}
        DateTime fromDate = DateTime.MinValue;
        DateTime toDate = DateTime.MaxValue;
        string write = string.Empty;

        XDocument xQuery = new XDocument(
                new XElement(ns + "QueryPacket"
                , new XAttribute("Revision", "1000")
                , new XElement(ns + "Query"
                    , new XAttribute("domain", "QDomain")
                    , new XElement(ns + "SupportedFormats"
                        , new XElement(ns + "Format"
                            , "urn:Microsoft.Search.Response.Document:Document"
                            )
                        )
                    , new XElement(ns + "Context"
                        , new XElement(ns + "QueryText"
                            , new XAttribute("language", "en-us")
                            , new XAttribute("string", "STRING")
                            , RemoveFiltersFromText(query.QueryTerm) + " SCOPE:\"" + scope + "\"" + write
                        )
                    )
                    , new XElement("SortByProperties"
                        , new XElement("SortByProperty"
                            , new XAttribute("name", "Rank")
                            , new XAttribute("direction", "Descending")
                            , new XAttribute("order", "1")
                            )
                        )
                    , new XElement("Range"
                        , new XElement("StartAt", query.From + 1 )
                        , new XElement("Count", query.Size)
                    )
                    , new XElement("EnableStemming", "false")
                    , new XElement("TrimDuplicates", "true")
                    , new XElement("IgnoreAllNoiseQuery", "true")
                    , new XElement("ImplicitAndBehavior", "true")
                    , new XElement("IncludeRelevanceResults", "true")
                    , new XElement("IncludeSpecialTermResults", "true")
                    , new XElement("IncludeHighConfidenceResults", "true")
                  )
            )
        );

        //DataSet ds = queryService.QueryEx(xQuery.ToString());
        DataSet ds = new DataSet();

        query.Total = ds.Tables[0].Rows.Count;
        if (query.Total >= query.Size)
        {
            query.Total = 500; //simple way to avoid havy MOSS request
        }
        foreach (DataRow resultRow in ds.Tables[0].Rows)
        {
            DateTime writeDate = (resultRow["Write"] != null ? ((DateTime)resultRow["Write"]) : DateTime.MinValue);
            if (fromDate <= writeDate && writeDate <= toDate)
            {
                results.Add(new Models.SearchResult()
                {
                    Id = int.Parse(resultRow["WorkId"].ToString()),
                    Path = (string)resultRow["Path"],
                    Score = int.Parse(resultRow["Rank"].ToString()),
                    Summary = ((string)resultRow["HitHighlightedSummary"]).Replace("<c0", "<c0 class='highlight'") ,
                    LastModified = writeDate,
                    //SchemaName = "intranet",
                    //Name = (string)resultRow["Title"],
                    //Author = resultRow["Author"].ToString()
                });
            }
        }
        query.SearchResults = results;
        return query;
    }*/
    /*private static string GetSearchFilterValue(string searchText, string stringPrefix, string suffix)
        {
            int startPos = searchText.IndexOf(stringPrefix);
            if (startPos >= 0)
            {
                startPos = startPos + stringPrefix.Length;
            }
            int endPos = searchText.IndexOf(suffix, startPos);
            if (endPos < 0)
                endPos = startPos;

            searchText = searchText.Substring(startPos, endPos - startPos);
            return searchText.Trim();
        }

        private static string RemoveFilterExpression(string searchText, string stringPrefix, string suffix)
        {
            if (searchText == null)
            {
                searchText = string.Empty;
            }
            if (stringPrefix == null || suffix == null)
            {
                return string.Empty;
            }

            int startPos = searchText.IndexOf(stringPrefix);
            if (startPos < 0)
                startPos = 0;

            int endPos = searchText.IndexOf(suffix, startPos);
            if (endPos < 0)
                endPos = startPos;

            if (startPos < endPos)
                searchText = searchText.Substring(0, startPos).Trim() + searchText.Substring(endPos + 1).Trim();
            return searchText.Trim();
        }

        /// <summary>
        /// Removes the filters from text.
        /// </summary>
        /// <param name="searchText">The search text.</param>
        /// <returns></returns>
        public static string RemoveFiltersFromText(string searchText)
        {
            if (searchText == null)
            {
                searchText = string.Empty;
            }
            //searchText = RemoveFilterExpression(searchText, "{Scope:", "}");
            //searchText = RemoveFilterExpression(searchText, "{Exception:", "}");
            //searchText = RemoveFilterExpression(searchText, "{Modified:", "}");
            while (searchText.Trim() != RemoveFilterExpression(searchText, "{", "}"))
            {
                searchText = RemoveFilterExpression(searchText, "{", "}");
            }
            return searchText.Trim();
        }

        /*public List<string> GetScopesOnPrem()
        {
            IntranetSearchService.QueryService queryService = new IntranetSearchService.QueryService();
            queryService.PreAuthenticate = true;
            queryService.Credentials = System.Net.CredentialCache.DefaultNetworkCredentials;
            //queryService.Credentials = System.Net.CredentialCache.DefaultCredentials;

            XElement xSearchInfo = RemoveAllNamespaces(XElement.Parse(queryService.GetPortalSearchInfo()));
            //XNamespace aw = xSearchInfo.GetDefaultNamespace();
            foreach (var item in xSearchInfo.XPathSelectElements("//Scope/Name"))
            {
                results.Add(new FileProperty()
                {
                    PropertyName = item.Value
                    ,
                    FileCount = 0
                });
            }
            //cache.Add(new CacheItem(key, results), new CacheItemPolicy() { AbsoluteExpiration = DateTimeOffset.Now.AddHours(20) });
        }*/
        //private static XElement RemoveAllNamespaces(XElement xmlDocument)
        //{
        //    if (!xmlDocument.HasElements)
        //    {
        //        XElement xElement = new XElement(xmlDocument.Name.LocalName);
        //        xElement.Value = xmlDocument.Value;

        //        foreach (XAttribute attribute in xmlDocument.Attributes())
        //            xElement.Add(attribute);

        //        return xElement;
        //    }
        //    return new XElement(xmlDocument.Name.LocalName, xmlDocument.Elements().Select(el => RemoveAllNamespaces(el)));
        //}

    //}
}
