using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using System.Net;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using Newtonsoft.Json;
using Nest;

// For more information on enabling MVC for empty projects, visit http://go.microsoft.com/fwlink/?LinkID=397860

namespace Search.Core.Windows.Controllers
{
    public class QueryController : Controller
    {
        public IActionResult History()
        {
            List<Models.Query> history = new List<Models.Query>();
            //...populate here from db or browser history...
            return View(history);
        }

        [HttpGet]
        public async Task<IActionResult> Index(string term, string options, int? from, int? page, int? size)
        {
            if (string.IsNullOrEmpty(term))
            {
                return View(new EmptyResult());
            }
            Models.Query query = new Models.Query();
            if (options == null)
            {
                options = string.Empty;
            }
            query.ChosenOptions = options;
            query.QueryTerm = term;
            query.Size = (size.HasValue ? size.Value : query.Size);
            if (from.HasValue)
            {
                query.From = from.Value;
            }
            else if (page.HasValue)
            {
                query.From = (page.HasValue && page.Value > 0 ? page.Value -1 : 0) * query.Size;
            }

            if (!page.HasValue && query.Size > 0)
            {
                page = query.From / query.Size + 1;
            }
            if (page == 0)
            {
                page = 1;
            }
            
            query.QueryOptions = await GetQueryOptions(query.ChosenOptions);

            var results = await GetNestResults(query);
            query.Total = results.Total;
            if (query.From > results.Total)
            {
                return View(new EmptyResult());
            }

            if (query.ChosenOptions.Contains("3_2"))
            {
                Models.SearchResults sr = new Models.SearchResults();
                sr.Pager = new Models.Pager(query.Total, page, query.Size.Value);
                sr.Items = GetQueryResults(results);
                query.SearchResults = sr;
            }

            ViewBag.QueryTerm = query.QueryTerm;
            ViewBag.ChosenOptions = query.ChosenOptions;
            return View(query);
        }

        [HttpPost]
        public async Task<IActionResult> Index(Models.Query query)
        {
            if (string.IsNullOrEmpty(query.QueryTerm) && !string.IsNullOrEmpty(Request.Query["term"]))
            {
                query.QueryTerm = Request.Query["term"];
            }
            if (string.IsNullOrEmpty(query.ChosenOptions) && !string.IsNullOrEmpty(Request.Query["options"]))
            {
                query.ChosenOptions = Request.Query["options"];
            }
            if (query.ChosenOptions == null)
            {
                query.ChosenOptions = string.Empty;
            }

            if (query.QueryOptions.Count() == 0)
            {
                query.QueryOptions = await GetQueryOptions(query.ChosenOptions);
            }
            return RedirectToAction("Index", new { term = query.QueryTerm, options = query.ChosenOptions, from = query.From, size = query.Size });
        }

        [HttpGet]
        public async Task<IActionResult> Scroll(int? from, int? size, string term, string options)
        {
            if (string.IsNullOrEmpty(term))
            {
                return View(new EmptyResult());
            }

            if (options == null)
            {
                options = string.Empty;
            }
            Models.Query query = new Models.Query();
            query.From = (from.HasValue ? from.Value : 0);
            query.QueryTerm = term;
            query.ChosenOptions = options;
            query.QueryOptions = await GetQueryOptions(query.ChosenOptions);
            if (size.HasValue)
                query.Size = size.Value;

            var results = await GetNestResults(query);
            if (query.From > results.Total)
                return View(new EmptyResult());

            ViewBag.From = query.From + query.Size;
            ViewBag.QueryTerm = query.QueryTerm;
            ViewBag.ChosenOptions = query.ChosenOptions;
            return PartialView(GetQueryResults(results));
        }


        public static async Task<List<Models.QueryOption>> GetQueryOptions(string chosenOptions)
        {
            Nest.CatIndicesRequest cat = new Nest.CatIndicesRequest();
            cat.V = true;
            var catResponse = await elastic.CatIndicesAsync(cat);
            var indexes = new List<Nest.CatIndicesRecord>();
            if (catResponse.IsValid)
            {
                indexes = catResponse.Records
                    .Where(rec => rec.Index != ".kibana" && !rec.Index.StartsWith(".marvel") && (string.IsNullOrEmpty(rec.DocsCount) ? "0" : rec.DocsCount) != "0")
                    // && rec.Status == "open"
                    //.Select(rec => new { rec.Index, rec.Status, rec.DocsCount, rec.StoreSize })
                    .OrderBy(rec => rec.Index).ToList();
            }
            if (chosenOptions == null)
            {
                chosenOptions = "";
            }
            var results = new List<Models.QueryOption>();
            foreach (var item in indexes)
            {
                results.Add(new Models.QueryOption()
                {
                    OptionGroup = "Scope",
                    Key = "1_" + item.Index,
                    Value = (item.Index.Contains("_") ? item.Index.Split('_')[0] : item.Index)
                        + " (" + (string.IsNullOrEmpty(item.DocsCount) ? "0" : item.DocsCount) + " docs)"
                            //+ (string.IsNullOrEmpty(item.StoreSize) ? "0" : item.StoreSize) + " bites)"
                            ,
                    Selected = (chosenOptions.Contains("1_" + item.Index + ","))
                });

            }
            results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_1", Value = "Exact text", Selected = (chosenOptions.Contains("2_1,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_2", Value = "Fuzzy logic", Selected = (chosenOptions.Contains("2_2,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_3", Value = "Hierarchy", Selected = (chosenOptions.Contains("2_3,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_4", Value = "Geo location", Selected = (chosenOptions.Contains("2_4,")) });
            //results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_5", Value = "Highlight", Selected = (ChosenOptions.Contains("2_5,")) });

            results.Add(new Models.QueryOption() { OptionGroup = "Layout", Key = "3_1", Value = "Scroll", Selected = (chosenOptions.Contains("3_1,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Layout", Key = "3_2", Value = "Page", Selected = (chosenOptions.Contains("3_2,")) });
            //results.Add(new Models.QueryOption() { OptionGroup = "Layout", Key = "3_3", Value = "Tile", Selected = (ChosenOptions.Contains("3_3,")) });
            return results;
        }

        private static Nest.ElasticClient elastic = new Nest.ElasticClient(new Nest.ConnectionSettings(new Uri(Startup.GetElasticSearchUrl())));

        public static async Task<Nest.ISearchResponse<dynamic>> GetNestResults(Models.Query query)
        {
            //var searchRequest = new SearchRequest
            //{
            //    Aggregations = new Dictionary<string, IAggregationContainer>
            //    {
            //        { "my_agg", new AggregationContainer
            //            {
            //                Terms = new TermsAggregation //TermsAggregator
            //                {
                                
            //                    Field = "content",
            //                    Size = 10,
            //                    ExecutionHint = TermsAggregationExecutionHint.Ordinals
            //                }
            //            }
            //        }
            //    }
            //};

            Nest.ISearchResponse<dynamic> results = null;
            Nest.Indices indices = Nest.Indices.AllIndices;
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("1_"))
            {
                indices = Nest.Indices.Index(query.ChosenOptions.Trim(',').Split(',').AsEnumerable()
                    .Where(qo => qo.StartsWith("1_"))
                    .Select(qo => new Nest.IndexName() { Name = qo.Replace("1_", "") }));
            }
            else if (query.QueryOptions.Count() > 0)
            {
                indices = Nest.Indices.Index(query.QueryOptions
                    .Where(qo => qo.Key.StartsWith("1_"))
                    .Select(qo => new Nest.IndexName() { Name = qo.Key.Replace("1_", "") }));
            }

            if (query.ChosenOptions != null && query.ChosenOptions.Contains("2_2"))
            {
                results = await elastic.SearchAsync<dynamic>(d => d
                    .Index(indices)
                    .AllTypes()
                    .From(query.From ?? 0) //.Skip()
                    .Size(query.Size ?? 10) //.Take()
                    .Query(q => q.Fuzzy(f => f.Value(query.QueryTerm)))
                    .Highlight(h => h
                        .Fields(f => f
                        .OnAll() //.Field("*")
                        .PreTags("<em>")
                        .PostTags("</em>")))
                );
            }
            else
            {
                results = await elastic.SearchAsync<dynamic>(body => body
                    .Index(indices)
                    .AllTypes()
                    .From(query.From ?? 0)
                    .Size(query.Size ?? 10)
                    .Query(q => q.QueryString(qs => qs.Query(query.QueryTerm)))
                    .Highlight(h => h
                        .Fields(f => f
                        .OnAll() //.Field("*")
                        .PreTags("<b style='color:black'>")
                        .PostTags("</b>")))
                //.Highlight(h => h
                //    .PreTags("<em>")
                //    .PostTags("</em>"))
                );
            }
            ///SearchAll
            //var queryResult = elastic.Search<dynamic>(d => d
            //    .Index(index)
            //    .AllIndices()
            //    .AllTypes()
            //    .Query(q => q.Term(t => t.Value(queryTerm)))
            //    //.QueryString(queryTerm)
            //    );
            //return queryResult
            //  .Hits
            //  .Select(c => new Tuple<string, string>(c.Index, c.Source.Path?.Value))
            //  .Distinct()
            //  .ToList();

            return results;
        }

        private static List<Models.SearchResult> GetQueryResults(Nest.ISearchResponse<dynamic> nestResults)
        {
            var results = new List<Models.SearchResult>();
            foreach (var hit in nestResults.Hits)
            {
                results.Add(new Models.SearchResult()
                {
                    Id = hit.Id,
                    Index = hit.Index,
                    Score = hit.Score,
                    Source = hit.Source.ToString(),
                    Type = hit.Type,
                    Path = (string)hit.Source["Path"]
                    //Hihglights = hit.Highlights.Select(hl => new { Key = hl.Key, Value = hl.Value.ToString() })
                });

                var myAgg = nestResults.Aggs.Terms("my_agg");

                //foreach (var highlight in hit.Highlights)
                //{
                //    highlight.
                //}
            }
            return results;
        }

        //private static List<Models.SearchResult> GetQueryAggregations(Nest.ISearchResponse<dynamic> nestResults)
        //{
        //    var myAgg = nestResults.Aggs.Terms("my_agg");
        //    //var results = new Dictionary<string, string>();
        //    //foreach (var agg in NestResults.Aggregations)
        //    //{
        //    //    results.Add(agg.Key, agg.Value.Meta);
        //    //}
        //    //return results;
        //}

        /// <summary>
        /// simple helper for direct access to any REST APIs
        /// var result = await CURL("GET", "/_all/_search?q="+query.QueryTerm, null);
        /// </summary>
        /// <param name="action"></param>
        /// <param name="url"></param>
        /// <param name="body"></param>
        /// <returns></returns>
        private async Task<dynamic> CURL(string action, string url, string body)
        {
            string responseBody = string.Empty;
            using (var client = new HttpClient())
            {
                client.BaseAddress = new Uri(Startup.GetElasticSearchUrl().TrimEnd('/'));
                Uri uri = new Uri(client.BaseAddress + "/" + url.TrimStart('/'));
                client.DefaultRequestHeaders.Accept.Clear();
                client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                StringContent queryString = null;
                if (!string.IsNullOrEmpty(body))
                {
                    queryString = new StringContent(body);
                }
                HttpResponseMessage response = null;
                if (action == "POST")
                {
                    response = await client.PostAsync(uri, queryString);
                }
                else if (action == "GET")
                {
                    response = await client.GetAsync(uri);
                }
                else if (action == "PUT")
                {
                    response = await client.PutAsync(uri, queryString);
                }
                else if (action == "DELETE")
                {
                    response = await client.DeleteAsync(uri);
                }
                //response.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
                //response.EnsureSuccessStatusCode();
                if (response.IsSuccessStatusCode)
                {
                    responseBody = await response.Content.ReadAsStringAsync();
                    //DataContractJsonSerializer ser = new DataContractJsonSerializer(typeof(Response));
                }
            }
            var resultObj = JsonConvert.DeserializeObject<dynamic>(responseBody);
            return resultObj;
        }
    }
}
