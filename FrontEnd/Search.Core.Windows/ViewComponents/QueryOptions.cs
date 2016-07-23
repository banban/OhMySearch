using Microsoft.AspNetCore.Mvc;
using Search.Core.Windows.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.Windows.ViewComponents
{
    public class QueryOptions : ViewComponent
    {
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
                query.QueryOptions = await Controllers.QueryController.GetQueryOptions(query.ChosenOptions);
            }

            return View(query);
        }
    }
}
