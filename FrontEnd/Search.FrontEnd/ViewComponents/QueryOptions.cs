using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Search.FrontEnd.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.FrontEnd.ViewComponents
{
    public class QueryOptions : ViewComponent
    {
        private static IMemoryCache _memoryCache;// = new MemoryCache(new MemoryCacheOptions() { CompactOnMemoryPressure = true });
        private readonly ILogger _logger;
        public QueryOptions(ILogger logger = null, IMemoryCache memoryCache = null)
        {
            _logger = logger;
            //    _logger.LogInformation("Environment.GetEnvironmentVariable:ElasticUri: " + Environment.GetEnvironmentVariable("ElasticUri"));
            //_logger.LogInformation("Startup.GetElasticSearchUrl(): " + Startup.GetElasticSearchUrl());
            _memoryCache = memoryCache;
        }

        public async Task<IViewComponentResult> InvokeAsync(Models.Query query)
        {
            if (query == null)
            {
                query = new Models.Query();
            }
            //Models.Query query = new Models.Query();
            if (string.IsNullOrEmpty(query.QueryTerm) && !string.IsNullOrEmpty(Request.Query["term"]))
            {
                query.QueryTerm = Request.Query["term"];
            }
            if (string.IsNullOrEmpty(query.ChosenOptions))
            {
                if (!string.IsNullOrEmpty(Request.Query["options"]))
                {
                    query.ChosenOptions = Request.Query["options"].ToString();
                }
                else
                {
                    query.ChosenOptions = ""; //this is required to remove previous chosen options which are not used anymore
                }
            }
            if (string.IsNullOrEmpty(query.ChosenAggregations) && !string.IsNullOrEmpty(Request.Query["aggregations"]))
            {
                query.ChosenAggregations = Request.Query["aggregations"];
            }
            if (query.QueryOptions.Count() == 0)
            {
                var qc = new Controllers.QueryController(_logger, _memoryCache);
                query.QueryOptions = await qc.GetQueryOptions(query.ChosenOptions);
            }

            return View(query);
        }
    }
}
