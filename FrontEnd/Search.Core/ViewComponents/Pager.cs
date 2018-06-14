using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Search.Core.Controllers;
using Search.Core.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.ViewComponents
{
    public class Pager : ViewComponent
    {
        private static IMemoryCache _memoryCache;
        private readonly ILogger _logger;

        public Pager(ILogger logger = null, IMemoryCache memoryCache = null)
        {
            _memoryCache = memoryCache;
            _logger = logger;
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
                var qc = new QueryController(_logger, _memoryCache);
                query.QueryOptions = await qc.GetQueryOptions(query.ChosenOptions);
            }

            return View(query);
        }
    }
}
