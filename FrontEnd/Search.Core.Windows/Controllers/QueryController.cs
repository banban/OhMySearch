using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Net.Http;
using System.Net.Http.Headers;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Nest;
//using Elasticsearch.Net;
using Newtonsoft.Json.Linq;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Hosting;

/// <summary>
/// How to Build a Search Page with Elasticsearch and .NET https://www.simple-talk.com/dotnet/development/how-to-build-a-search-page-with-elasticsearch-and-.net/
/// How do you debug your Nest queries? http://stackoverflow.com/questions/28139604/how-do-you-debug-your-nest-queries
/// Request Body Search https://www.elastic.co/guide/en/elasticsearch/reference/master/search-request-body.html#search-request-body
/// </summary>
namespace Search.Core.Windows.Controllers
{
    public class QueryController : Controller
    {
        //private IMemoryCache _memoryCache;
        private IMemoryCache _memoryCache;// = new MemoryCache(new MemoryCacheOptions() { CompactOnMemoryPressure = true });
        private readonly ILogger _logger;
        private readonly ElasticClient _elclient = null; //CreateClient(); // = new Nest.ElasticClient(new Nest.ConnectionSettings(new Uri(Startup.GetElasticSearchUrl())));

        //public QueryController() //IMemoryCache memoryCache
        //{
        //}
        public QueryController(ILogger logger = null, IMemoryCache memoryCache = null)
        {
            _logger = logger;
            if (_logger == null)
            {
            }
                //    _logger.LogInformation("Environment.GetEnvironmentVariable:ElasticUri: " + Environment.GetEnvironmentVariable("ElasticUri"));
                //_logger.LogInformation("Startup.GetElasticSearchUrl(): " + Startup.GetElasticSearchUrl());

            _memoryCache = memoryCache;
            if (memoryCache == null)
            {
                _memoryCache = new MemoryCache(new MemoryCacheOptions() { CompactOnMemoryPressure = true });
            }

            _elclient = CreateClient();
        }

        public ElasticClient CreateClient(int maxRetries = 3, int timeoutInMilliseconds = 1000)
        {
            ElasticClient elclient = null;
            if (!_memoryCache.TryGetValue("queryClient", out elclient))
            {
                //var pool = new SniffingConnectionPool(
                //    new List<Uri> { new Uri(Startup.GetElasticSearchUrl()) }
                //    );
                //ConnectionSettings config = new ConnectionSettings(pool);
                ConnectionSettings config = new Nest.ConnectionSettings(new Uri(Environment.GetEnvironmentVariable("ElasticUri")))
                    .MaximumRetries(maxRetries)
                    .MaxRetryTimeout(new TimeSpan(0, 0, 0, timeoutInMilliseconds));

                //if x-pack is installed
                if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ElasticUser")))
                {
                    config.BasicAuthentication(Environment.GetEnvironmentVariable("ElasticUser"), Environment.GetEnvironmentVariable("ElasticPassword"));
                }
                elclient = new ElasticClient(config);
                _memoryCache.Set("queryClient", elclient, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
            }

            return elclient;
        }

        public IActionResult History()
        {
            List<Models.Query> history = new List<Models.Query>();
            //...populate here from db or browser history...
            return View(history);
        }

        [HttpGet]
        public async Task<IActionResult> Index(string term, string options, string aggregations, int? from, int? page, int? size, double? minScore)
        {
            //if (string.IsNullOrEmpty(term))
            //{
            //    return View(new EmptyResult());
            //}
            Models.Query query = new Models.Query();
            query.ChosenOptions = options;
            query.ChosenAggregations = aggregations;
            query.QueryTerm = term;
            query.Size = (size.HasValue ? size.Value : query.Size);
            query.MinScore = (minScore.HasValue ? minScore.Value : query.MinScore);

            if (from.HasValue)
            {
                query.From = from.Value;
            }
            else if (page.HasValue)
            {
                query.From = (page.HasValue && page.Value > 0 ? page.Value - 1 : 0) * query.Size;
            }

            if (!page.HasValue && query.Size > 0)
            {
                page = query.From / query.Size + 1;
            }
            if (page == 0)
            {
                page = 1;
            }

            //_logger.LogInformation(string.Format("GetQueryOptions. Startup.GetElasticSearchUrl(): {0}", Startup.GetElasticSearchUrl()));
            //_logger.LogInformation(string.Format("GetQueryOptions. Startup.GetACLUrl(): {0}", Startup.GetACLUrl()));
            query.QueryOptions = await GetQueryOptions(query.ChosenOptions);
            //_logger.LogInformation(string.Format("query.QueryOptions.Count {0}", query.QueryOptions.Count));

            var response = await GetSearchResponse(query); //use extra call to get total

            //query.ScrollId = response.ScrollId;
            if (!response.IsValid)
            {
                query.DebugInformation = response.ApiCall.DebugInformation;
                //query.OriginalException = response.ApiCall.OriginalException;
            }
            query.Total = response.Total;
            query.MaxScore = response.MaxScore;
            if (query.From > response.Total)
            {
                return View(new EmptyResult());
            }

            Models.SearchResults sr = new Models.SearchResults();
            if (query.ChosenOptions.Contains("4_2") || query.ChosenOptions.Contains("4_3"))
            {
                sr.Pager = new Models.Pager(query.Total, page, query.Size.Value);
            }

            sr.Items = GetSearchResults(User.Identity.Name, response, query.QueryTerm);
            query.SearchResults = sr;

            foreach (var aggr in response.Aggs.Aggregations)
            {
                try
                {
                    var buckets = response.Aggs.Terms(aggr.Key).Buckets.Where(bct => bct.DocCount > 0)
                        .OrderByDescending(bct => bct.DocCount).ThenBy(bct => bct.KeyAsString)
                        .Take(10);
                    foreach (var bucket in buckets)
                    {
                        query.Aggregations.Add(new Models.Aggregation() { Group = aggr.Key, Key = bucket.Key, Count = bucket.DocCount.Value });
                    }
                }
                catch (Exception)
                {
                }
                try
                {
                    var buckets2 = response.Aggs.DateHistogram(aggr.Key).Buckets.Where(bct => bct.DocCount > 0)
                        .OrderByDescending(bct => bct.DocCount) //.ThenBy(bct => bct.KeyAsString)
                        .Take(10);
                    foreach (var bucket in buckets2)
                    {
                        query.Aggregations.Add(new Models.Aggregation() { Group = aggr.Key, Key = bucket.Date.ToString("MMM yyyy"), Count = bucket.DocCount });
                    }
                }
                catch (Exception)
                {
                }
                try
                {
                    var buckets3 = response.Aggs.Range(aggr.Key).Buckets.Where(bct => bct.DocCount > 0)
                        .OrderByDescending(bct => bct.DocCount)
                        .Take(10);
                    foreach (var bucket in buckets3)
                    {
                        query.Aggregations.Add(new Models.Aggregation() { Group = aggr.Key, Key = (bucket.From.HasValue ? bucket.From.ToString() : "0") + " - " + (bucket.To.HasValue ? bucket.To.ToString() : "..."), Count = bucket.DocCount });
                    }
                }
                catch (Exception)
                {
                }
            }
            ViewBag.QueryTerm = query.QueryTerm;
            ViewBag.ChosenOptions = query.ChosenOptions;
            ViewBag.ChosenAggregations = query.ChosenAggregations;
            ViewBag.MinScore = query.MinScore;
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
            if (string.IsNullOrEmpty(query.ChosenAggregations) && !string.IsNullOrEmpty(Request.Query["aggregations"]))
            {
                query.ChosenAggregations = Request.Query["aggregations"];
            }

            if (query.MinScore == 0 && !string.IsNullOrEmpty(Request.Query["minScore"]))
            {
                query.MinScore = double.Parse(Request.Query["minScore"]);
            }

            if (query.QueryOptions.Count() == 0)
            {
                query.QueryOptions = await GetQueryOptions(query.ChosenOptions);
            }
            ViewBag.QueryTerm = query.QueryTerm;
            ViewBag.ChosenOptions = query.ChosenOptions;
            ViewBag.ChosenAggregations = query.ChosenAggregations;
            ViewBag.MinScore = query.MinScore;

            return RedirectToAction("Index", new { term = query.QueryTerm, options = query.ChosenOptions, aggregations = query.ChosenAggregations, from = query.From, size = query.Size, minScore = query.MinScore});
        }

        [HttpGet]
        public async Task<IActionResult> Scroll(int? from, int? size, string term, string options, string aggregations, int? minScore)
        {
            //if (string.IsNullOrEmpty(term))
            //{
            //    return View(new EmptyResult());
            //}
            Models.Query query = new Models.Query();
            query.From = (from.HasValue ? from.Value : 0);
            query.QueryTerm = term;
            query.ChosenOptions = options;
            query.ChosenAggregations = aggregations;
            query.QueryOptions = await GetQueryOptions(query.ChosenOptions);
            if (size.HasValue)
                query.Size = size.Value;
            if (minScore.HasValue)
                query.MinScore = minScore.Value;

            var response = await GetSearchResponse(query);
            if (!response.IsValid)
            {
                query.DebugInformation = response.ApiCall.DebugInformation;
                //query.OriginalException = response.ApiCall.OriginalException;
            }

            if (query.From > response.Total)
            {
                return View(new EmptyResult());
            }

            if (query.Total == 0)
            {
                query.Total = response.Total;
            }
            //query.ScrollId = response.ScrollId;
            ViewBag.From = query.From + query.Size;
            ViewBag.QueryTerm = query.QueryTerm;
            ViewBag.ChosenOptions = query.ChosenOptions;
            ViewBag.ChosenAggregations = query.ChosenAggregations;
            ViewBag.MinScore = query.MinScore;
            var results = GetSearchResults(User.Identity.Name, response, query.QueryTerm);
            return PartialView(results);
        }

        public async Task<List<Models.QueryOption>> GetQueryOptions(string chosenOptions)
        {
            var options = new List<Models.QueryOption>();
            if (!_memoryCache.TryGetValue("queryOptions", out options))
            {
                options = new List<Models.QueryOption>();
                Nest.CatIndicesRequest cat = new Nest.CatIndicesRequest();
                cat.V = true;
                var catIndices = await _elclient.CatIndicesAsync(cat);
                var indexes = new List<Nest.CatIndicesRecord>();
                if (catIndices.IsValid)
                {
                    indexes = catIndices.Records
                        .Where(rec => !rec.Index.StartsWith(".")  //exclude .kibana, .marvel, .logstash
                            && !rec.Index.StartsWith("winlogbeat-")
                            && (string.IsNullOrEmpty(rec.DocsCount) ? "0" : rec.DocsCount) != "0")
                        // && rec.Status == "open"
                        //.Select(rec => new { rec.Index, rec.Status, rec.DocsCount, rec.StoreSize }
                        .OrderBy(rec => rec.Index).ToList();
                }
                //var indicesSettings = await _elclient.GetIndexSettingsAsync();
                //elastic.ConnectionSettings.MaxRetries = 3;
                //_elclient.GetMapping(new GetMappingRequest { Index = "myindex", Type = "mytype" });
                //var response = _elclient.IndicesGetMapping("_all", "_all");
                //var mappings = await _elclient.GetMappingAsync(new GetMappingRequest() { IgnoreUnavailable = true });
                Dictionary<string, List<string>> indexTypes = new Dictionary<string, List<string>>();

                //var settings = await _elclient.GetIndexSettingsAsync();
                //var mapping = _elclient.GetMapping(new GetMappingRequest(Nest.Indices.AllIndices, Nest.Types.AllTypes) { IgnoreUnavailable = true });
                var _settings = await Helpers.QueryHelper.CURL("GET", "_settings", null);
                var _mappings = await Helpers.QueryHelper.CURL("GET", "_mapping?ignore_unavailable=true", null);
                foreach (var _index in _mappings)
                {
                    if (!indexTypes.ContainsKey(_index.Key))
                    {
                        indexTypes.Add(_index.Key, new List<string>());
                    }
                    var _types = indexTypes[_index.Key];
                    foreach (var _indexMappings in _index.Value)
                    {
                        foreach (var _indexMapping in _indexMappings)
                        {
                            foreach (var _type in _indexMapping.Values())
                            {
                                var typeName = _type.Path.Replace(_indexMapping.Path, "").Trim('.');
                                if (!_types.Contains(typeName))
                                {
                                    _types.Add(typeName);
                                }
                            }
                        }
                    }
                }
                string indexRecords = "";
                foreach (var item in indexes)
                {
                    indexRecords += ","+ item.Index;
                    var alias = _elclient.GetAliasesPointingToIndex(item.Index).FirstOrDefault();
                    //var mapping = _elclient.GetMapping<item>();
                    string creationDateLabel = String.Empty;
                    try
                    {
                        var creationDate = DateTime.MinValue.AddYears(1969).AddMilliseconds(_settings[item.Index]["settings"]["index"]["creation_date"].Value<long>());
                        creationDateLabel = ", as of " + creationDate.ToString("dd/MM/yy");
                    }
                    catch (Exception)
                    {
                    }

                    options.Add(new Models.QueryOption()
                    {
                        OptionGroup = "Indices",
                        Key = "1_" + item.Index,
                        Value = (alias == null ? item.Index : alias.Name) + " (" + (string.IsNullOrEmpty(item.DocsCount) ? "0" : item.DocsCount) + " docs"+ creationDateLabel + ")"
                        //+ (string.IsNullOrEmpty(item.StoreSize) ? "0" : item.StoreSize) + " bites)"
                    });

                    var indTypes = indexTypes[item.Index];
                    {
                        foreach (var indType in indTypes)
                        {
                            var option = new Models.QueryOption()
                            {
                                OptionGroup = "Types",
                                Key = "2_" + indType, //item.Index + "_" + 
                                Value = indType //item.Index + "_" + indType
                            };
                            //do not show the same time from different indexes
                            if (options.Where(op => op.Key == option.Key).FirstOrDefault() == null)
                            {
                                options.Add(option);
                            }
                        }
                    }

                    /*///method IndicesGetMapping does not allow to read type name. So I use workaround with direct request by REST client
                    var mappings = mapping.Mappings
                        .Where(ind => ind.Key == item.Index)
                        .Select(ind => ind.Value);
                    foreach (var types in mappings)
                    {
                        foreach (var indType in types)
                        {
                            var option = new Models.QueryOption()
                            {
                                OptionGroup = "Types",
                                Key = "2_" + indType.TypeName.Name, //item.Index + "_" + 
                                Value = indType.TypeName.Name //item.Index + "_" + indType
                            };
                            if (!options.Contains(option))
                            {
                                options.Add(option);
                            }
                        }
                    }*/
                }
                _memoryCache.Set("AllIndices", indexRecords.Trim(','), new TimeSpan(1, 0, 0));

                options.Add(new Models.QueryOption() { OptionGroup = "Confidence", Key = "3_1", Value = "Suggest" }); //autocomplete, MLT, phonetic, stop words
                options.Add(new Models.QueryOption() { OptionGroup = "Confidence", Key = "3_2", Value = "Fuzzy" }); //misspelling
                options.Add(new Models.QueryOption() { OptionGroup = "Confidence", Key = "3_3", Value = "Raw" }); //raw query
                //options.Add(new Models.QueryOption() { OptionGroup = "Confidence", Key = "3_4", Value = "Location" }); //location internal map calls

                options.Add(new Models.QueryOption() { OptionGroup = "Layout", Key = "4_1", Value = "Scroll" });
                options.Add(new Models.QueryOption() { OptionGroup = "Layout", Key = "4_2", Value = "Page" });
                options.Add(new Models.QueryOption() { OptionGroup = "Layout", Key = "4_3", Value = "Tile" });

                options.Add(new Models.QueryOption() { OptionGroup = "Aggregation", Key = "5_1", Value = "Terms" });
                options.Add(new Models.QueryOption() { OptionGroup = "Aggregation", Key = "5_2", Value = "Date Histogram" });
                options.Add(new Models.QueryOption() { OptionGroup = "Aggregation", Key = "5_3", Value = "Ranges" });

                options.Add(new Models.QueryOption() { OptionGroup = "Filter", Key = "6_1", Value = "Inversed" });
                options.Add(new Models.QueryOption() { OptionGroup = "Filter", Key = "6_2", Value = "Scored" });
                //options.Add(new Models.QueryOption() { OptionGroup = "Analysis", Key = "7_1", Value = "Hierarchy" });
                //options.Add(new Models.QueryOption() { OptionGroup = "Analysis", Key = "7_3", Value = "Metadata" }); //index/type/field metadata

                _memoryCache.Set("queryOptions", options, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
            }

            if (!string.IsNullOrEmpty(chosenOptions))
            {
                chosenOptions = chosenOptions + "+";
                foreach (var option in options)
                {
                    option.Selected = (chosenOptions.Contains(option.Key + "+"));
                }
            }
            return options;
        }

        public async Task<Nest.IGetResponse<dynamic>> GetDocument(string index, string type, string id)
        {
            //var _id = await CURL("GET", index + "/" + type + "/" + id, null);
            var result = await _elclient.GetAsync<dynamic>(new DocumentPath<dynamic>(id).Index(index).Type(type));
            return result;
        }

        public async Task<Nest.ISearchResponse<dynamic>> GetSearchResponse(Models.Query query)
        {
            //indices to search
            Nest.Indices indices = null;
            string keyIndexType = "";
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("1_"))
            {
                var names = query.ChosenOptions.Replace("+"," ").Trim().Split(' ').AsEnumerable()
                    .Where(qo => qo.StartsWith("1_"))
                    .Select(qo => qo.Substring(2).Trim());
                indices = Nest.Indices.Index(names.Select(s => new Nest.IndexName() { Name = s }));
                foreach (var name in names)
                {
                    keyIndexType += name + ",";
                }
            }
            else
            {
                string indexRecords = "";
                if (_memoryCache.TryGetValue("AllIndices", out indexRecords))
                {
                    indices = indexRecords;
                }
                else
                {
                    indices = Nest.Indices.AllIndices;
                }
                keyIndexType += "AllIndices,";
            }
            //types to search
            Nest.Types types = null;
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("2_"))
            {
                var names = query.ChosenOptions.Replace("+", " ").Trim().Split(' ').AsEnumerable()
                    .Where(qo => qo.StartsWith("2_"))
                    .Select(qo => qo.Substring(2).Trim());
                types = Nest.Types.Type(names.Select(s => new Nest.TypeName() { Name = s }));
                foreach (var name in names)
                {
                    keyIndexType += name + ",";
                }
            }
            else
            {
                types = Nest.Types.AllTypes;
                keyIndexType += "AllTypes,";
            }

            //var options = new List<Models.QueryOption>();

            QueryContainer qc = new QueryContainer(); //{q => q.QueryString(qs => qs.Query(query.QueryTerm)};
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("3_1") && query.QueryTerm.Contains("=")) //term Name=Value
            {
                qc = new FuzzyQuery()
                {
                    Field = query.QueryTerm.Split('=')[0], //"file.Name"
                    Value = query.QueryTerm.Split('=')[1]
                };
            }
            else if (query.ChosenOptions != null && query.ChosenOptions.Contains("3_2")) //fuzzy
            {
                qc = new FuzzyQuery()
                {
                    //Field
                    //Fuzziness
                    Value = query.QueryTerm // DSL equivalent => .Query(q => q.Fuzzy(f => f.Value(query.QueryTerm)))
                };
            }
            else if (query.ChosenOptions != null && query.ChosenOptions.Contains("3_3")) //raw
            {
                    qc = new RawQuery()
                {
                    //Name = "RawQuery",
                    Raw = query.QueryTerm
                };
            }

            else if (query.QueryTerm.Contains(";") && query.ChosenOptions != null && query.ChosenOptions.Contains("3_4")) //location
            {
                string[] data = query.QueryTerm.Split(';');
                qc = new GeoDistanceQuery()
                {
                    Boost = 1.1,
                    Location = new GeoLocation(double.Parse(data[0]), double.Parse(data[1])),
                    Distance = data[2],
                    DistanceType = GeoDistanceType.Arc,
                    ValidationMethod = GeoValidationMethod.IgnoreMalformed | GeoValidationMethod.Coerce,
                    OptimizeBoundingBox = GeoOptimizeBBox.Memory
                };
            }
            //else if (query.QueryTerm.Contains(";") && query.ChosenOptions != null && query.ChosenOptions.Contains("3_5")) //suggestions
            //{
            //    var result = _elclient.Suggest<dynamic>(x => x        // use suggest method
            //        .Completion("tag-suggestions", c => c             // use completion suggester and name it
            //            .Prefix(query.QueryTerm)                                  // pass text
            //            //.Field(f => f.Suggest)                        // work against completion field
            //            .Size(20)));                               // limit number of suggestions

            //    return result.Suggestions["tag-suggestions"].SelectMany(x => x.Options)
            //        .Select(y => y.Text);
            //}
            else if (query.QueryTerm.StartsWith("\"") && query.QueryTerm.EndsWith("\"")) //"Match phrase"
            {
                qc = new MatchQuery()
                {
                    //Field = Field<Project>(p => p.Description),
                    Analyzer = "standard",
                    Boost = 1.1,
                    Name = "named_query",
                    CutoffFrequency = 0.001,
                    Query = query.QueryTerm,
                    Fuzziness = Fuzziness.Auto, //The fuzzy query is depricated and replaced by MatchQuery.Fuzziness . Similarity is based on Levenshtein edit distance
                    FuzzyTranspositions = true,
                    MinimumShouldMatch = 2,
                    FuzzyRewrite = RewriteMultiTerm.ConstantScoreBoolean,
                    MaxExpansions = 2,
                    Slop = 2,
                    Lenient = true,
                    Operator = Operator.Or,
                    PrefixLength = 2
                };
            }

            #region More Like This
            else if (query.QueryTerm != null && query.QueryTerm.Contains("/")
                        && query.ChosenOptions != null && query.ChosenOptions.Contains("3_6"))
            {
                string[] fullId = query.QueryTerm.Split('/');
                //fields to search
                List<string> fields = new List<string>();
                if (!_memoryCache.TryGetValue("FieldsForMLT:" + fullId[0] + "/" + fullId[1], out fields))
                {
                    fields = new List<string>();
                    var mapping = _elclient.GetMapping(new GetMappingRequest(indices, types));
                    foreach (var index in mapping.Mappings)
                    {
                        foreach (var typeMapping in index.Value)
                        {
                            if (typeMapping.Key != null && typeMapping.Value != null && typeMapping.Value.Properties != null)
                            {
                                foreach (var fieldMapping in typeMapping.Value.Properties)
                                {
                                    if (fieldMapping.Value != null 
                                            &&  (fieldMapping.Value.Type.Name == "text" 
                                                || fieldMapping.Value.Type.Name == "keyword" 
                                                || fieldMapping.Value.Type.Name == "string")
                                            )
                                    {
                                        fields.Add(fieldMapping.Key.Name);
                                    }
                                }
                            }
                        }
                    }
                    _memoryCache.Set("FieldsForMLT:" + fullId[0] + "/" + fullId[1], fields, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
                }

                qc = new Nest.MoreLikeThisQuery()
                {
                    Name = "mlt_query",
                    //Fields = fields.ToArray(), //Defaults to the _all field for free text and to all possible fields for document inputs.
                    Like = new List<Like>()
                    {
                        //A list of documents following the same syntax as the Multi GET API.
                        new Like(new Models.LikeDocumentGeneral(fullId))
                    },
                    //Analyzer = "some_analyzer",
                    Boost = 1.1,
                    BoostTerms = 1.1,
                    Include = true,
                    MaxDocumentFrequency = 12,
                    MaxQueryTerms = 12,
                    MaxWordLength = 300,
                    MinDocumentFrequency = 1,
                    MinTermFrequency = 1,
                    MinWordLength = 10,
                    MinimumShouldMatch = 1,
                    StopWords = new[] { "and", "the" },
                    //Unlike = new List<Like>
                    //{
                    //    "not like this text"
                    //}
                };
            }

            #endregion
            else if(!string.IsNullOrEmpty(query.QueryTerm)) //free text
            {
                qc = new QueryStringQuery()
                {
                    Query = query.QueryTerm  //DSL: .Query(q => q.QueryString(qs => qs.Query(query.QueryTerm)))
                };
            }
            else //Match All
            {
                qc = new MatchAllQuery()
                {
                };
            }
            //inverse logic
            if (query.ChosenOptions.Contains("6_1"))
            {
                query.Inversed = true;
            }
            if (query.Inversed.HasValue && query.Inversed.Value == true)
            {
                qc = new BoolQuery()
                {
                    MustNot = new QueryContainer[] { qc }
                };
            }
            var elRequest = new SearchRequest(indices, types)
            {
                Query = qc,
                //Scroll = "1m",
                IgnoreUnavailable = true,
                Explain = true,
                //SearchType = Elasticsearch.Net.SearchType.QueryThenFetch,
                From = query.From ?? 0, //.Skip()
                Size = query.Size ?? 10, //.Take()
                MinScore = query.MinScore ?? 0
            };
            //check if query has aggregation filters
            if (!string.IsNullOrEmpty(query.ChosenAggregations)) //mask: "Group1.Field1.Value1|Group1.Field2.Value2|Group2.Field3.Value3|"
            {
                var filters = query.ChosenAggregations.Trim('|').Split('|').Where(s => !string.IsNullOrEmpty(s))
                   .Select(s => new { Group = s.Substring(0,s.IndexOf('.')).Trim()
                                        , KeyValue = s.Substring(s.IndexOf('.')+1).Trim() } )
                   .Select(s => new { Group = s.Group
                                        , Field = s.KeyValue.Substring(0, s.KeyValue.IndexOf('.')).Trim()
                                        , Value = s.KeyValue.Substring(s.KeyValue.IndexOf('.')+1).Trim() } );

                var groups = filters.Select(qo => qo.Group).Distinct();
                foreach (var group in groups)
                {
                    var groupFilters = filters.Where(qo => qo.Group == group);
                    var groupQuery = new QueryContainer();
                    List<NumericRangeQuery> numGroupQueries = new List<NumericRangeQuery>();
                    foreach (var item in filters)
                    {
                        //NEST v5 introduces operator overloading so complex bool queries become easier to write
                        switch (item.Group)
                        {
                            case "Top terms":
                                //+ special construct, which will cause the term query to be wrapped inside a bool 
                                var termQuery = +new TermQuery
                                {
                                    Field = item.Field,
                                    Value = item.Value
                                };
                                if (filters.Count() == 1)
                                {
                                    groupQuery = groupQuery && termQuery;
                                }
                                else
                                {
                                    groupQuery = groupQuery || termQuery; //inside the group we use OR
                                }
                                break;
                            //case "Stats":
                            //    break;
                            case "Top months":
                                DateTime start = DateTime.Parse(item.Value);
                                var dateRangeQuery = +new DateRangeQuery() {
                                    Field = item.Field,
                                    GreaterThanOrEqualTo = start,
                                    LessThan = start.AddMonths(1)
                                };
                                if (filters.Count() == 1)
                                {
                                    groupQuery = groupQuery && dateRangeQuery;
                                }
                                else
                                {
                                    groupQuery = groupQuery || dateRangeQuery; //inside the group we use OR
                                }
                                break;
                            case "Top ranges": //0 - 100 or 200 - ...
                                var numRangeQuery = +new Nest.NumericRangeQuery()
                                {
                                    Field = item.Field,
                                    GreaterThanOrEqualTo = double.Parse(item.Value.Split('-')[0].Trim()),
                                    LessThanOrEqualTo = ((item.Value.Split('-')[1].Trim() != "...") ? double.Parse(item.Value.Split('-')[1].Trim()) : double.MaxValue)
                                };
                                if (filters.Count() == 1)
                                {
                                    groupQuery = groupQuery && numRangeQuery;
                                }
                                else
                                {
                                    groupQuery = groupQuery || numRangeQuery; //inside the group we use OR
                                }
                                break;
                            default:
                                break;
                        }
                    }
                    
                    elRequest.Query = elRequest.Query && groupQuery; ///outside ogf group we use AND
                }
            }
            ///Aggregations https://www.elastic.co/guide/en/elasticsearch/client/net-api/master/aggregations.html
            var aggregations = new Dictionary<string, IAggregationContainer>();

            #region Terms aggregation
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("5_1"))
            {
                //fields to search
                List<string> termList = new List<string>();
                string key = "FieldsForTermAgg:" + keyIndexType;
                if (!_memoryCache.TryGetValue(key, out termList))
                {
                    termList = new List<string>();
                    var mapping = _elclient.GetMapping(new GetMappingRequest(indices, types));
                    foreach (var index in mapping.Mappings)
                    {
                        foreach (var typeMapping in index.Value)
                        {
                            if (typeMapping.Key != null && typeMapping.Value != null && typeMapping.Value.Properties != null)
                            {
                                foreach (var fieldMapping in typeMapping.Value.Properties)
                                {
                                    var textValue = (fieldMapping.Value as Nest.TextProperty);
                                    if (fieldMapping.Value != null && !termList.Contains(fieldMapping.Key.Name)
                                        //exclude some predefined names
                                        && fieldMapping.Key.Name != "rowguid" && fieldMapping.Key.Name != "id" && fieldMapping.Key.Name != "Path" 
                                        //check metadata has keyword ref
                                        && (
                                            fieldMapping.Value.Type.Name == "keyword" //can't use text fields for terms aggregation
                                            || (textValue != null && textValue.Fields != null && textValue.Fields.Where(f => f.Key == "keyword") != null) //some text fields are keyword in mind
                                            )
                                        )
                                    {
                                        termList.Add(fieldMapping.Key.Name);
                                    }
                                }
                            }
                        }
                    }
                    _memoryCache.Set(key, termList, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
                }

                foreach (var term in termList)
                {
                    aggregations.Add("Top terms." + term, new AggregationContainer
                    {
                        Terms = new TermsAggregation(term)
                        {
                            Field = term,
                            MinimumDocumentCount = 1,
                            Order = new List<TermsOrder>
                            {
                                TermsOrder.TermAscending,
                                TermsOrder.CountDescending
                            }
                        }
                    });
                }
            }

            #endregion

            #region Date Histogram aggregation
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("5_2"))
            {
                List<string> termList = new List<string>();
                string key = "FieldsForDateHistogramAgg:" + keyIndexType;
                if (!_memoryCache.TryGetValue(key, out termList))
                {
                    termList = new List<string>();
                    var mapping = _elclient.GetMapping(new GetMappingRequest(indices, types));
                    foreach (var index in mapping.Mappings)
                    {
                        foreach (var typeMapping in index.Value)
                        {
                            if (typeMapping.Key != null && typeMapping.Value != null && typeMapping.Value.Properties != null)
                            {
                                foreach (var fieldMapping in typeMapping.Value.Properties)
                                {
                                    if (fieldMapping.Value != null && !termList.Contains(fieldMapping.Key.Name) 
                                        && fieldMapping.Value.Type.Name == "date")
                                    {
                                        termList.Add(fieldMapping.Key.Name);
                                    }
                                }
                            }
                        }
                    }
                    _memoryCache.Set(key, termList, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
                }

                foreach (var term in termList)
                {
                    aggregations.Add("Top months." + term, new AggregationContainer
                    {
                        DateHistogram = new DateHistogramAggregation(term)
                        {
                            Field = term,
                            Interval = DateInterval.Month,
                            MinimumDocumentCount = 1,
                            Format = "yyyy-MM-dd",
                            ExtendedBounds = new ExtendedBounds<DateTime>
                            {
                                Minimum = DateTime.Today.AddYears(-10),
                                Maximum = DateTime.Today.AddYears(1),
                            },
                            Order = HistogramOrder.KeyDescending,
                            //Missing = FixedDate,
                            //Aggregations = new NestedAggregation("project_tags")
                            //{
                            //    Path = Field<Project>(p => p.Tags),
                            //    Aggregations = new TermsAggregation("tags")
                            //    {
                            //        Field = Field<Project>(p => p.Tags.First().Name)
                            //    }
                            //}
                        }
                    });
                }
            }

            #endregion

            #region Ranges aggregation
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("5_3"))
            {
                List<string> termList = new List<string>();
                string key = "FieldsForRangesAgg:" + keyIndexType;
                if (!_memoryCache.TryGetValue(key, out termList))
                {
                    termList = new List<string>();
                    var mapping = _elclient.GetMapping(new GetMappingRequest(indices, types));
                    foreach (var index in mapping.Mappings)
                    {
                        foreach (var typeMapping in index.Value)
                        {
                            if (typeMapping.Key != null && typeMapping.Value != null && typeMapping.Value.Properties != null)
                            {
                                foreach (var fieldMapping in typeMapping.Value.Properties)
                                {
                                    if (fieldMapping.Value != null && !termList.Contains(fieldMapping.Key.Name)
                                        && (fieldMapping.Value.Type.Name == "double" || fieldMapping.Value.Type.Name == "float" || fieldMapping.Value.Type.Name == "number" || fieldMapping.Value.Type.Name == "integer" || fieldMapping.Value.Type.Name == "short" || fieldMapping.Value.Type.Name == "long")
                                        )
                                    {
                                        termList.Add(fieldMapping.Key.Name);
                                    }
                                }
                            }
                        }
                    }
                    _memoryCache.Set(key, termList, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
                }

                var stats = new Dictionary<string, IAggregationContainer>();
                foreach (var term in termList)
                {
                    stats.Add("Stats: " + term, new AggregationContainer
                    {
                        Stats = new StatsAggregation(term, term)
                    });
                }
                if (stats.Count > 0)
                {
                    elRequest.Aggregations = stats;
                    Nest.ISearchResponse<dynamic> statsResponse = await _elclient.SearchAsync<dynamic>(elRequest);
                    if (statsResponse.IsValid)
                    {
                        foreach (var agg in statsResponse.Aggregations)
                        {
                            if (agg.Value != null)
                            {
                                var minValue = statsResponse.Aggs.Stats(agg.Key).Min;
                                var maxValue = statsResponse.Aggs.Stats(agg.Key).Max;
                                if (minValue.HasValue && maxValue.HasValue)
                                {
                                    string term = agg.Key.Replace("Stats: ", "");
                                    var ranges = new List<Nest.AggregationRange>();
                                    double step = Math.Round((maxValue.Value - minValue.Value) / 10, 0);
                                    double currValue = minValue.Value;
                                    for (int i = 0; i < 10; i++)
                                    {
                                        if (currValue == minValue.Value)
                                        {
                                            ranges.Add(new Nest.AggregationRange { To = currValue + step });
                                        }
                                        else if (i == 9)
                                        {
                                            ranges.Add(new Nest.AggregationRange { From = currValue + 1 });
                                        }
                                        else
                                        {
                                            ranges.Add(new Nest.AggregationRange { From = currValue + 1, To = currValue + step });
                                        }
                                        currValue += step; 
                                    }

                                    aggregations.Add("Top ranges." + term, new AggregationContainer
                                    {
                                        Range = new RangeAggregation(term)
                                        {
                                            Field = term,
                                            Ranges = ranges
                                        }
                                    });
                                }
                            }
                        }
                    }
                }
            }

            #endregion

            if (aggregations.Count > 0)
            {
                elRequest.Aggregations = aggregations;
            }


            //elRequest.Aggregations = new CardinalityAggregation("state_count", Field<Models.IFileResult>(p => p.Extension))
            //{
            //    PrecisionThreshold = 100
            //};

            //elRequest.Aggregations = new DateHistogramAggregation("projects_started_per_month")
            //{
            //    Field = "startedOn",
            //    Interval = DateInterval.Month,
            //    Aggregations = new SumAggregation("commits", "numberOfCommits") &&
            //        new FilterAggregation("stable_state")
            //        {
            //            Filter = new TermQuery
            //            {
            //                Field = "state",
            //                Value = "Stable"
            //            },
            //            Aggregations = new SumAggregation("commits", "numberOfCommits")
            //        } &&
            //        new BucketScriptAggregation("stable_percentage", new MultiBucketsPath
            //            {
            //                { "totalCommits", "commits" },
            //                { "stableCommits", "stable_state>commits" }
            //            })
            //        {
            //            Script = (InlineScript)"stableCommits / totalCommits * 100"
            //        }
            //};
            //elRequest.Aggregations = new DateRangeAggregation("modified_per_month")
            //{
            //    Field = Field<File>(p => p.LastModified),
            //    Ranges = new List<DateRangeExpression>
            //    {
            //        new DateRangeExpression { From = DateMath.Anchored(FixedDate).Add("2d"), To = DateMath.Now},
            //        new DateRangeExpression { To = DateMath.Now.Add(TimeSpan.FromDays(1)).Subtract("30m").RoundTo(TimeUnit.Hour) },
            //        new DateRangeExpression { From = DateMath.Anchored("2012-05-05").Add(TimeSpan.FromDays(1)).Subtract("1m") }
            //    },
            //    //Aggregations = new TermsAggregation("project_tags") { Field = Field<File>(p => p.Tags) }
            //};

            //elRequest.Aggregations = new DateHistogramAggregation("modified_per_month")
            //{
            //    Field = Field<dynamic>(p => p.LastModified),
            //    Interval = DateInterval.Month,
            //    MinimumDocumentCount = 2,
            //    Format = "yyyy-MM-dd'T'HH:mm:ss",
            //    ExtendedBounds = new ExtendedBounds<DateTime>
            //    {
            //        Minimum = FixedDate.AddYears(-1),
            //        Maximum = FixedDate.AddYears(1),
            //    },
            //    Order = HistogramOrder.CountAscending,
            //    Missing = FixedDate,
            //    Aggregations = new NestedAggregation("project_tags")
            //    {
            //        Path = Field<Project>(p => p.Tags),
            //        Aggregations = new TermsAggregation("tags")
            //        {
            //            Field = Field<Project>(p => p.Tags.First().Name)
            //        }
            //    }
            //}

            #region Highlights. Not working in fuzzy yet :(
            elRequest.Highlight = new Highlight()
            {
                PreTags = new[] { "<em>" },
                PostTags = new[] { "</em>" },
                Fields = new Dictionary<Field, IHighlightField>
                {
                    { "all.standard", new HighlightField
                        {
                            Field = "*",
                            ///https://www.elastic.co/guide/en/elasticsearch/client/net-api/master/highlighting-usage.html
                            Type = HighlighterType.Plain,
                            ForceSource = true,
                            FragmentSize = 150,
                            NumberOfFragments = 3,
                            NoMatchSize = 150,
                            BoundaryMaxScan = 50,
                            HighlightQuery = elRequest.Query
                        }
                    },
                }
            };

            #endregion

            Nest.ISearchResponse<dynamic> response = await _elclient.SearchAsync<dynamic>(elRequest);
            //elRequest.Scroll = new Time("5y");
            //Nest.ISearchResponse<dynamic> results = await _elclient.ScrollAsync<dynamic>(elScroll);

            //depricated
            //var requestURL = response.ConnectionStatus;
            //var jsonBody = Encoding.UTF8.GetString(response.RequestInformation.Request);

            /*if (response.IsValid)
            {
                foreach (var highlightsInEachHit in response.Hits.Select(d => d.Highlights))
                {
                    foreach (var highlightField in highlightsInEachHit)
                    {
                        if (highlightField.Key == "name.standard")
                        {
                            foreach (var highlight in highlightField.Value.Highlights)
                            {
                                if (highlight.Contains("<em>") && highlight.Contains("</em>"))
                                {

                                }
                            }
                        }
                        else if (highlightField.Key == "leadDeveloper.firstName")
                        {
                            foreach (var highlight in highlightField.Value.Highlights)
                            {
                                highlight.Should().Contain("<name>");
                                highlight.Should().Contain("</name>");
                            }
                        }
                        else if (highlightField.Key == "state.offsets")
                        {
                            foreach (var highlight in highlightField.Value.Highlights)
                            {
                                highlight.Should().Contain("<state>");
                                highlight.Should().Contain("</state>");
                            }
                        }
                        else
                        {
                            Assert.True(false, $"highlights contains unexpected key {highlightField.Key}");
                        }
                    }
                }
            }*/
            return response;
        }

        [HttpGet]
        public async Task<JToken> Suggest(string queryTerm) //, string options
        {
            if (string.IsNullOrEmpty(queryTerm))
                return null;
            if (!queryTerm.Contains("="))
                return null;
            if (queryTerm.Length < 3)
                return null;

            var field = queryTerm.Split('=')[0]; //"Name"
            var value = queryTerm.Split('=')[1]; //

            if (string.IsNullOrEmpty(field) || string.IsNullOrEmpty(value))
                return null;
            //if (!string.IsNullOrEmpty(options)) //remove other query types to avoid conflict in builder
            //{
            //    options = options.Replace("3_2", "").Replace("3_3", "").Replace("3_4", "");
            //}
            //else
            //{
            //    options = "3_1,";
            //}

            //if (!options.Contains("3_1,"))
            //{
            //    options += "3_1,";
            //}

            Models.Query query = new Models.Query()
            {
                QueryTerm = queryTerm,
                ChosenOptions = "3_1"
            };
            var response = await GetSearchResponse(query);
            if (!response.IsValid)
            {
                query.DebugInformation = response.ApiCall.DebugInformation;
                //query.OriginalException = response.ApiCall.OriginalException;
            }
            var results = new List<string>();
            foreach (var hit in response.Hits)
            {
                value = (string)hit.Source[field];
                if (!string.IsNullOrEmpty(value) && !results.Contains(value))
                {
                    results.Add(value);
                }
            }
            JArray json = JArray.FromObject(results);
            return json;
        }

        [HttpGet]
        ///https://www.elastic.co/guide/en/elasticsearch/reference/master/query-dsl-geo-distance-query.html
        public async Task<JToken> Geo(double lat, double lng, string distance, string options)
        {
            if (!string.IsNullOrEmpty(options)) //remove other query types to avoid conflict in builder
            {
                options = options.Replace("3_1", "").Replace("3_2", "").Replace("3_3", "");
            }
            else
            {
                options = "3_4,";
            }

            if (!options.Contains("3_4+"))
            {
                options += "3_4+";
            }

            Models.Query query = new Models.Query() {
                QueryTerm = lat.ToString() +";"+ lng.ToString() + ";" + distance,
                ChosenOptions = options
            };
            var response = await GetSearchResponse(query);
            if (!response.IsValid)
            {
                query.DebugInformation = response.ApiCall.DebugInformation;
                //query.OriginalException = response.ApiCall.OriginalException;
            }
            //query.ScrollId = response.ScrollId;
            var results = GetSearchResults(User.Identity.Name, response, query.QueryTerm)
                //.Select(r => new {Lat = r.Lat, Lng = r.Lng })
                ;
            JArray json = JArray.FromObject(results);
            return json;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="userName"></param>
        /// <param name="nestResults"></param>
        /// <param name="queryTerm"></param>
        /// <returns></returns>
        public List<Models.SearchResult> GetSearchResults(string userName, Nest.ISearchResponse<dynamic> nestResults, string queryTerm)
        {
            var results = new List<Models.SearchResult>();
            foreach (var hit in nestResults.Hits)
            {
                string summary = string.Empty;
                //get elastic highlights
                foreach (var hh in hit.Highlights)
                {
                    foreach (var hhh in hh.Value.Highlights)
                    {
                        summary += hhh + @"<br>";
                    }
                }

                if (string.IsNullOrEmpty(summary) && !string.IsNullOrEmpty(queryTerm))
                {
                    //get direct highlights
                    summary = hit.Source.ToString();

                    int firstHLIndex = summary.IndexOf(queryTerm);
                    if (firstHLIndex > 0)
                    {
                        //full matched highlights;
                        summary = summary.Replace(queryTerm, "<em>" + queryTerm + "</em>");
                    }
                    else if (summary.ToLower().IndexOf(queryTerm.ToLower()) > 0)
                    {
                        //full matched lower case highlights;
                        summary = summary.ToLower().Replace(queryTerm.ToLower(), "<em>" + queryTerm.ToLower() + "</em>");
                    }
                    else //highight every word
                    {
                        foreach (var word in queryTerm.Trim().Split(' '))
                        {
                            summary = summary.ToLower().Replace(word.ToLower(), "<em>" + word + "</em>");
                        }
                    }
                    firstHLIndex = summary.IndexOf("<em>");
                    if (firstHLIndex > 100) //adjust summary to begin from highlighted area
                    {
                        summary = "..." + summary.Substring(firstHLIndex - 20);
                    }
                }
                else if (string.IsNullOrEmpty(summary))
                {
                    summary = hit.Source.ToString();
                }

                Models.SearchResult result = new Models.SearchResult()
                {
                    Id = hit.Id,
                    CanRead = true,
                    Index = hit.Index,
                    Score = hit.Score,
                    Source = hit.Source.ToString(),
                    Type = hit.Type,

                    /// File path is represented as Elastic hierarchy type with notation: c:\Temp -> c:/Temp. 
                    /// So we use / as folder separator
                    Path = (string)hit.Source["Path"],
                    ThumbnailPath = (string)hit.Source["ThumbnailPath"],
                    //LastModified = (DateTime)hit.Source["LastModified"],
                    Extension = ((hit.Type == "file" || hit.Type == "photo") ? ((string)hit.Source["Extension"]) : ""),
                    Summary = summary
                };
                
                if (!string.IsNullOrEmpty(result.Path)) //((result.Type == "directory" || result.Type == "file" || result.Type == "photo") && result.Path.Contains("/"))
                {
                    result.CanRead = Helpers.QueryHelper.UserHasAccess(userName, result.Path.Substring(0, result.Path.LastIndexOf('/')), _memoryCache);
                }
                results.Add(result);

                //var myAgg = nestResults.Aggs.Terms("my_agg");
            }
            return results;
        }


    }
}
