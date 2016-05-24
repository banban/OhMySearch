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

// For more information on enabling MVC for empty projects, visit http://go.microsoft.com/fwlink/?LinkID=397860

namespace Search.Core.Windows.Controllers
{
    public class QueryController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Create(Models.Query query)
        {
            if (string.IsNullOrEmpty(query.QueryTerm) && !string.IsNullOrEmpty(Request.Query["term"]))
            {
                query.QueryTerm = Request.Query["term"]; // ~/query/create/?q=term
            }

            if (string.IsNullOrEmpty(query.ChosenOptions) && !string.IsNullOrEmpty(Request.Query["options"]))
            {
                query.ChosenOptions = Request.Query["options"]; // ~/query/create/?o=1,2,3
            }
            if (query.ChosenOptions == null)
            {
                query.ChosenOptions = string.Empty;
            }

            if (query.QueryOptions.Count() == 0)
            {
                query.QueryOptions = await GetQueryOptions(query.ChosenOptions);
            }
            ViewBag.QueryTerm = query.QueryTerm;
            ViewBag.ChosenOptions = query.ChosenOptions;
            var results = await GetSearchResults(query);
            query.Total = results.Total;
            return View(query);
        }

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
            query.QueryOptions = await GetQueryOptions(options);
            if (size.HasValue)
                query.Size = size.Value;

            var results = await GetSearchResults(query);
            if (query.From > results.Total)
                return View(new EmptyResult());

            ViewBag.From = query.From + query.Size;
            ViewBag.QueryTerm = term;
            ViewBag.ChosenOptions = options;
            return PartialView(GetQueryResults(results));
        }

        [HttpGet]
        //public ActionResult Index(int? page)
        //{
        //    var dummyItems = Enumerable.Range(1, 150).Select(x => "Item " + x);
        //    var pager = new Pager(dummyItems.Count(), page);

        //    var viewModel = new SearchResults
        //    {
        //        Items = dummyItems.Skip((pager.CurrentPage - 1) * pager.PageSize).Take(pager.PageSize),
        //        Pager = pager
        //    };

        //    return View(viewModel);
        //}
        // GET: /<controller>/
        public async Task<IActionResult> Page(int? page, string term, string options)
        {
            ViewBag.Page = (page.HasValue ? page.Value : 0);
            Models.Query query = new Models.Query()
            {
                ChosenOptions = options,
                QueryTerm = term,
            };
            query.QueryOptions = await Controllers.QueryController.GetQueryOptions(options);

            ViewData["Query"] = query;

            return PartialView();
            //return PartialView();
            //return ViewComponent("SearchResults", pageNumber);
        }

        public static async Task<List<Models.QueryOption>> GetQueryOptions(string ChosenOptions)
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
            if (ChosenOptions == null)
            {
                ChosenOptions = "";
            }
            var results = new List<Models.QueryOption>();
            foreach (var item in indexes)
            {
                results.Add(new Models.QueryOption()
                {
                    OptionGroup = "Scope",
                    Key = "1_" + item.Index,
                    Value = (item.Index.Contains("_") ? item.Index.Split('_')[0] : item.Index)
                        + "(" + (string.IsNullOrEmpty(item.DocsCount) ? "0" : item.DocsCount) + " records, "
                            + (string.IsNullOrEmpty(item.StoreSize) ? "0" : item.StoreSize) + " bites)",
                    Selected = (ChosenOptions.Contains("1_" + item.Index + ","))
                });

            }
            results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_1", Value = "Exact text", Selected = (ChosenOptions.Contains("2_1,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_2", Value = "Fuzzy logic", Selected = (ChosenOptions.Contains("2_2,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_3", Value = "Hierarchy", Selected = (ChosenOptions.Contains("2_3,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_4", Value = "Geo location", Selected = (ChosenOptions.Contains("2_4,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "2_5", Value = "Highlight", Selected = (ChosenOptions.Contains("2_5,")) });

            results.Add(new Models.QueryOption() { OptionGroup = "Types", Key = "3_1", Value = "File", Selected = (ChosenOptions.Contains("3_1,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Types", Key = "3_2", Value = "Photo", Selected = (ChosenOptions.Contains("3_2,")) });
            results.Add(new Models.QueryOption() { OptionGroup = "Types", Key = "3_2", Value = "Acronym", Selected = (ChosenOptions.Contains("3_3,")) });
            return results;
        }

        private static Nest.ElasticClient elastic = new Nest.ElasticClient(new Nest.ConnectionSettings(new Uri(Startup.GetElasticSearchUrl())));
        public static async Task<Nest.ISearchResponse<dynamic>> GetSearchResults(Models.Query query)
        {
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

        private static List<Models.SearchResult> GetQueryResults(Nest.ISearchResponse<dynamic> NestResults)
        {
            var results = new List<Models.SearchResult>();
            foreach (var hit in NestResults.Hits)
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
                
                //foreach (var highlight in hit.Highlights)
                //{
                //    highlight.
                //}
            }
            return results;
        }

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
