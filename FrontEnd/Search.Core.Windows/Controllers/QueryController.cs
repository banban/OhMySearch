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

namespace Search.Core.Windows.Controllers
{
    public class QueryController : Controller
    {
        private static IMemoryCache _memoryCache = new MemoryCache(new MemoryCacheOptions() { CompactOnMemoryPressure = true });
        public QueryController()
        {
        }

        private static readonly ElasticClient _elclient = CreateClient(); // = new Nest.ElasticClient(new Nest.ConnectionSettings(new Uri(Startup.GetElasticSearchUrl())));
        public static ElasticClient CreateClient(int maxRetries = 3, int timeoutInMilliseconds = 1000)
        {
            ElasticClient elclient = null;
            if (!_memoryCache.TryGetValue("queryClient", out elclient))
            {
                //var pool = new SniffingConnectionPool(
                //    new List<Uri> { new Uri(Startup.GetElasticSearchUrl()) }
                //    );
                //ConnectionSettings config = new ConnectionSettings(pool);
                ConnectionSettings config = new Nest.ConnectionSettings(new Uri(Startup.GetElasticSearchUrl()))
                    .MaximumRetries(maxRetries)
                    .MaxRetryTimeout(new TimeSpan(0, 0, 0, timeoutInMilliseconds));

                //if x-pack is installed
                if (!string.IsNullOrEmpty(Startup.GetElasticCredencials().Key))
                {
                    config.BasicAuthentication(Startup.GetElasticCredencials().Key, Startup.GetElasticCredencials().Value);
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
        public async Task<IActionResult> Index(string term, string options, int? from, int? page, int? size)
        {
            //if (string.IsNullOrEmpty(term))
            //{
            //    return View(new EmptyResult());
            //}
            Models.Query query = new Models.Query();
            query.ChosenOptions = options;
            query.QueryTerm = term;
            query.Size = (size.HasValue ? size.Value : query.Size);
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

            query.QueryOptions = await GetQueryOptions(query.ChosenOptions);

            var results = await GetSearchResponse(query); //use extra call to get total

            query.Total = results.Total;
            if (query.From > results.Total)
            {
                return View(new EmptyResult());
            }

            if (query.ChosenOptions.Contains("4_2"))
            {
                Models.SearchResults sr = new Models.SearchResults();
                sr.Pager = new Models.Pager(query.Total, page, query.Size.Value);
                sr.Items = GetSearchResults(results, query.QueryTerm);
                query.SearchResults = sr;
            }

            foreach (var aggr in results.Aggs.Aggregations)
            {
                var buckets = results.Aggs.Terms(aggr.Key).Buckets.Where(bct => bct.DocCount > 0)
                    .OrderByDescending(bct =>  bct.DocCount).ThenBy(bct => bct.KeyAsString)
                    .Take(10);
                foreach (var bucket in buckets)
                {
                    query.Aggregations.Add(new Models.Aggregation() { Group = aggr.Key, Key = bucket.Key, Count = bucket.DocCount.Value });
                }
                var buckets2 = results.Aggs.DateHistogram(aggr.Key).Buckets.Where(bct => bct.DocCount > 0)
                    .OrderByDescending(bct => bct.DocCount) //.ThenBy(bct => bct.KeyAsString)
                    .Take(10);
                foreach (var bucket in buckets2)
                {
                    query.Aggregations.Add(new Models.Aggregation() { Group = aggr.Key, Key = bucket.Date.ToString("MMM yyyy"), Count = bucket.DocCount });
                }
                var buckets3 = results.Aggs.Range(aggr.Key).Buckets.Where(bct => bct.DocCount > 0)
                    .OrderByDescending(bct => bct.DocCount)
                    .Take(10);
                foreach (var bucket in buckets3)
                {
                    query.Aggregations.Add(new Models.Aggregation() { Group = aggr.Key, Key = (bucket.From.HasValue ? bucket.From.ToString(): "0") + " - " + (bucket.To.HasValue ? bucket.To.ToString() : "..."), Count = bucket.DocCount });
                }
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

            if (query.QueryOptions.Count() == 0)
            {
                query.QueryOptions = await GetQueryOptions(query.ChosenOptions);
            }
            ViewBag.QueryTerm = query.QueryTerm;
            ViewBag.ChosenOptions = query.ChosenOptions;
            return RedirectToAction("Index", new { term = query.QueryTerm, options = query.ChosenOptions, from = query.From, size = query.Size });
        }

        [HttpGet]
        public async Task<IActionResult> Scroll(int? from, int? size, string term, string options)
        {
            //if (string.IsNullOrEmpty(term))
            //{
            //    return View(new EmptyResult());
            //}
            Models.Query query = new Models.Query();
            query.From = (from.HasValue ? from.Value : 0);
            query.QueryTerm = term;
            query.ChosenOptions = options;
            query.QueryOptions = await GetQueryOptions(query.ChosenOptions);
            if (size.HasValue)
                query.Size = size.Value;

            var results = await GetSearchResponse(query);
            if (query.From > results.Total)
                return View(new EmptyResult());

            ViewBag.From = query.From + query.Size;
            ViewBag.QueryTerm = query.QueryTerm;
            ViewBag.ChosenOptions = query.ChosenOptions;
            return PartialView(GetSearchResults(results, query.QueryTerm));
        }

        public static async Task<List<Models.QueryOption>> GetQueryOptions(string chosenOptions)
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
                            && (string.IsNullOrEmpty(rec.DocsCount) ? "0" : rec.DocsCount) != "0")
                        // && rec.Status == "open"
                        //.Select(rec => new { rec.Index, rec.Status, rec.DocsCount, rec.StoreSize }
                        .OrderBy(rec => rec.Index).ToList();
                }

                //elastic.ConnectionSettings.MaxRetries = 3;
                //_elclient.GetMapping(new GetMappingRequest { Index = "myindex", Type = "mytype" });
                //var response = _elclient.IndicesGetMapping("_all", "_all");
                //var mappings = await _elclient.GetMappingAsync(new GetMappingRequest() { IgnoreUnavailable = true });

                var _mappings = await CURL("GET", "_mapping", null);
                Dictionary<string, List<string>> indexTypes = new Dictionary<string, List<string>>();
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

                //var mapping = _elclient.GetMapping(new GetMappingRequest(Nest.Indices.AllIndices, Nest.Types.AllTypes) { IgnoreUnavailable = true });
                foreach (var item in indexes)
                {
                    //var mapping = _elclient.GetMapping<item>();
                    options.Add(new Models.QueryOption()
                    {
                        OptionGroup = "Indices",
                        Key = "1_" + item.Index,
                        Value = (item.Index.Contains("_") ? item.Index.Split('_')[0] : item.Index)
                            + " (" + (string.IsNullOrEmpty(item.DocsCount) ? "0" : item.DocsCount) + " docs)"
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
                            if (!options.Contains(option))
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

                options.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "3_1", Value = "Term" });
                options.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "3_2", Value = "Fuzzy" });
                options.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "3_3", Value = "Hierarchy" });
                options.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "3_4", Value = "Location" });
                //results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "3_5", Value = "Highlight" });
                //results.Add(new Models.QueryOption() { OptionGroup = "Options", Key = "3_6", Value = "More Like This" }); //hidden option used in QueryDetails controller

                options.Add(new Models.QueryOption() { OptionGroup = "Layout", Key = "4_1", Value = "Scroll" });
                options.Add(new Models.QueryOption() { OptionGroup = "Layout", Key = "4_2", Value = "Page" });
                //results.Add(new Models.QueryOption() { OptionGroup = "Layout", Key = "4_3", Value = "Tile" });

                options.Add(new Models.QueryOption() { OptionGroup = "Aggregation", Key = "5_1", Value = "Terms" });
                options.Add(new Models.QueryOption() { OptionGroup = "Aggregation", Key = "5_2", Value = "Date Histogram" });
                options.Add(new Models.QueryOption() { OptionGroup = "Aggregation", Key = "5_3", Value = "Ranges" });

                _memoryCache.Set("queryOptions", options, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
            }

            if (!string.IsNullOrEmpty(chosenOptions))
            {
                foreach (var option in options)
                {
                    option.Selected = (chosenOptions.Contains(option.Key + ","));
                }
            }
            return options;
        }

        public static async Task<Nest.IGetResponse<dynamic>> GetDocument(string index, string type, string id)
        {
            //var _id = await CURL("GET", index + "/" + type + "/" + id, null);
            var result = await _elclient.GetAsync<dynamic>(new DocumentPath<dynamic>(id).Index(index).Type(type));
            //var searchResult new Models.SearchResult()
            //{
            //    Id = hit.Id,
            //    Index = hit.Index,
            //    Score = hit.Score,
            //    Source = hit.Source.ToString(),
            //    Type = hit.Type,
            //    Path = (string)hit.Source["Path"],
            //    Extension = (hit.Type == "file" ? ((string)hit.Source["Extension"]).ToUpper().TrimStart('.') : "")
            //    //Hihglights = hit.Highlights.Select(hl => new { Key = hl.Key, Value = hl.Value.ToString() })
            //})
            
            return result;
        }

        public static async Task<Nest.ISearchResponse<dynamic>> GetSearchResponse(Models.Query query)
        {
            //indices to search
            Nest.Indices indices = Nest.Indices.AllIndices;
            string keyIndexType = "";
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("1_"))
            {
                var names = query.ChosenOptions.Trim(',').Split(',').AsEnumerable().Where(qo => qo.StartsWith("1_"));
                indices = Nest.Indices.Index(names.Select(qo => new Nest.IndexName() { Name = qo.Replace("1_", "") }));
                foreach (var name in names)
                {
                    keyIndexType += name + ",";
                }
            }
            else
            {
                keyIndexType += "AllIndices,";
            }
            //types to search
            Nest.Types types = Nest.Types.AllTypes;
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("2_"))
            {
                var names = query.ChosenOptions.Trim(',').Split(',').AsEnumerable().Where(qo => qo.StartsWith("2_"));
                types = Nest.Types.Type(names.Select(qo => new Nest.TypeName() { Name = qo.Replace("2_", "") }));
                foreach (var name in names)
                {
                    keyIndexType += name + ",";
                }
            }
            else
            {
                keyIndexType += "AllTypes,";
            }

            //var options = new List<Models.QueryOption>();

            QueryContainer qc = new QueryContainer(); //{q => q.QueryString(qs => qs.Query(query.QueryTerm)};
            if (query.ChosenOptions != null && query.ChosenOptions.Contains("3_1") && query.QueryTerm.Contains("=")) //term Name=Value
            {
                qc = new TermQuery
                {
                    Field = query.QueryTerm.Split('=')[0], //"file.Name"
                    Value = query.QueryTerm.Split('=')[1]
                };
            }
            else if (query.ChosenOptions != null && query.ChosenOptions.Contains("3_2")) //fuzzy
            {
                qc = new FuzzyQuery
                {
                    //Field
                    //Fuzziness
                    Value = query.QueryTerm // DSL equivalent => .Query(q => q.Fuzzy(f => f.Value(query.QueryTerm)))
                };
            }
            else if (query.QueryTerm.Contains(";") && query.ChosenOptions != null && query.ChosenOptions.Contains("3_4")) //location
            {
                string[] data = query.QueryTerm.Split(';');
                qc = new GeoDistanceQuery
                {
                    Boost = 1.1,
                    Location = new GeoLocation(double.Parse(data[0]), double.Parse(data[1])),
                    Distance = data[2],
                    DistanceType = GeoDistanceType.Arc,
                    IgnoreMalformed = true,
                    Coerce = true,
                    ValidationMethod = GeoValidationMethod.Strict,
                    OptimizeBoundingBox = GeoOptimizeBBox.Memory
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
                            foreach (var fieldMapping in typeMapping.Properties)
                            {
                                if (fieldMapping.Value.Type.Name == "text" || fieldMapping.Value.Type.Name == "keyword" || fieldMapping.Value.Type.Name == "string")
                                {
                                    fields.Add(fieldMapping.Key.Name);
                                }
                            }
                        }
                    }
                    _memoryCache.Set("FieldsForMLT:" + fullId[0] + "/" + fullId[1], fields, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
                }

                qc = new Nest.MoreLikeThisQuery
                {
                    Name = "mlt_query",
                    //Fields = fields.ToArray(), //Defaults to the _all field for free text and to all possible fields for document inputs.
                    Like = new List<Like>
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
            else //free text
            {
                qc = new QueryStringQuery
                {
                    Query = query.QueryTerm  //DSL: .Query(q => q.QueryString(qs => qs.Query(query.QueryTerm)))
                };
            }

            var elRequest = new SearchRequest(indices, types)
            {
                Query = qc,
                From = query.From ?? 0, //.Skip()
                Size = query.Size ?? 10 //.Take()
            };

            //Aggregations https://www.elastic.co/guide/en/elasticsearch/client/net-api/master/aggregations.html
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
                            foreach (var fieldMapping in typeMapping.Properties)
                            {
                                if (!termList.Contains(fieldMapping.Key.Name)
                                    && fieldMapping.Value.Type.Name == "keyword" //can't use text fields for terms aggregation
                                    && fieldMapping.Key.Name != "rowguid" && fieldMapping.Key.Name != "id" && fieldMapping.Key.Name != "Path"
                                    )
                                {
                                    termList.Add(fieldMapping.Key.Name);
                                }
                            }
                        }
                    }
                    _memoryCache.Set(key, termList, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
                }

                foreach (var term in termList)
                {
                    aggregations.Add("Top terms: " + term, new AggregationContainer
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
                            foreach (var fieldMapping in typeMapping.Properties)
                            {
                                if (!termList.Contains(fieldMapping.Key.Name) && fieldMapping.Value.Type.Name == "date")
                                {
                                    termList.Add(fieldMapping.Key.Name);
                                }
                            }
                        }
                    }
                    _memoryCache.Set(key, termList, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
                }

                foreach (var term in termList)
                {
                    aggregations.Add("Top Months: " + term, new AggregationContainer
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
                            foreach (var fieldMapping in typeMapping.Properties)
                            {
                                if (!termList.Contains(fieldMapping.Key.Name)
                                    && (fieldMapping.Value.Type.Name == "double" || fieldMapping.Value.Type.Name == "float")
                                    )
                                {
                                    termList.Add(fieldMapping.Key.Name);
                                }
                            }
                        }
                    }
                    _memoryCache.Set(key, termList, new TimeSpan(1, 0, 0)); //new MemoryCacheEntryOptions().AddExpirationToken(new CancellationChangeToken(cts.Token)))
                }

                foreach (var term in termList)
                {
                    aggregations.Add("Top ranges: " + term, new AggregationContainer
                    {
                        Range = new RangeAggregation(term)
                        {
                            Field = term,
                            Ranges = new List<Nest.Range>
                            {
                                { new Nest.Range { To = 10000 } },
                                { new Nest.Range { From = 10000, To = 100000 } },
                                { new Nest.Range { From = 100000, To = 1000000 } },
                                { new Nest.Range { From = 1000000, To = 10000000 } },
                                { new Nest.Range { From = 10000000 } }
                            }
                        }
                    });
                }
            }

            #endregion

            elRequest.Aggregations = aggregations;


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

            #region Highlights. Not working yet :(

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
                            NoMatchSize = 150
                        }
                    },
                }
            };

            #endregion

            Nest.ISearchResponse<dynamic> results = await _elclient.SearchAsync<dynamic>(elRequest);

            return results;
        }

        [HttpGet]
        ///https://www.elastic.co/guide/en/elasticsearch/reference/master/query-dsl-geo-distance-query.html
        public JToken Geo(double lat, double lng, string distance, string options)
        {
            if (!string.IsNullOrEmpty(options)) //remove other query types to avoid conflict in builder
            {
                options = options.Replace("3_1", "").Replace("3_2", "").Replace("3_3", "");
            }
            else
            {
                options = "3_4,";
            }

            if (!options.Contains("3_4,"))
            {
                options += "3_4,";
            }

            Models.Query query = new Models.Query() {
                QueryTerm = lat.ToString() +";"+ lng.ToString() + ";" + distance,
                ChosenOptions = options
            };
            var results = GetSearchResponse(query);
            JArray json = JArray.FromObject(results);
            return json;
        }

        public static List<Models.SearchResult> GetSearchResults(Nest.ISearchResponse<dynamic> nestResults, string queryTerm)
        {
            var results = new List<Models.SearchResult>();
            foreach (var hit in nestResults.Hits)
            {
                string summary = string.Empty;
                foreach (var hh in hit.Highlights)
                {
                    foreach (var hhh in hh.Value.Highlights)
                    {
                        summary += hhh + @"<br>";
                    }
                }
                if (string.IsNullOrEmpty(summary))
                {
                    summary = hit.Source.ToString();
                    if (!string.IsNullOrEmpty(queryTerm))
                    {
                        //full matched highlights;
                        summary = summary.ToLower().Replace(queryTerm.ToLower(), "<em>" + queryTerm + "</em>");
                    }
                }

                results.Add(new Models.SearchResult()
                {
                    Id = hit.Id,
                    Index = hit.Index,
                    Score = hit.Score,
                    Source = hit.Source.ToString(),
                    Type = hit.Type,
                    Path = (string)hit.Source["Path"],
                    //LastModified = (DateTime)hit.Source["LastModified"],
                    Extension = ((hit.Type=="file" || hit.Type == "photo") ? ((string)hit.Source["Extension"]) : ""),
                    Summary = summary
                });

                //var myAgg = nestResults.Aggs.Terms("my_agg");
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
        private static async Task<JObject> CURL(string action, string url, string body)
        {

            string responseBody = string.Empty;
            using (var client = new HttpClient())
            {
                client.BaseAddress = new Uri(Startup.GetElasticSearchUrl().TrimEnd('/'));
                Uri uri = new Uri(client.BaseAddress + url.TrimStart('/'));
                client.DefaultRequestHeaders.Accept.Clear();
                client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                StringContent queryString = null;

                //if x-pack is installed
                string cred = Startup.GetElasticCredencials().Key + ":" + Startup.GetElasticCredencials().Value;
                if (cred != ":")
                {
                    var credentials = System.Text.Encoding.ASCII.GetBytes("elastic:changeme"); 
                    client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", Convert.ToBase64String(credentials));
                }

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
            //JsonNodes resultObj = JsonConvert.DeserializeObject<JsonNodes>(responseBody);
            //var resultObj = JObject.Parse(responseBody);
            return resultObj;
        }
    }
}
