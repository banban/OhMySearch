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
        public async Task<IViewComponentResult> InvokeAsync()
        {
            Models.Query query = null;
            if (ViewData["Query"] != null)
            {
                query = ViewData["Query"] as Models.Query;
            }

            if (query == null)
            {
                query = new Models.Query();
            }
            if (string.IsNullOrEmpty(query.QueryTerm) && !string.IsNullOrEmpty(Request.Query["term"]))
            {
                query.QueryTerm = Request.Query["term"]; // ~/query/create/?q=term
            }
            if (string.IsNullOrEmpty(query.ChosenOptions) && !string.IsNullOrEmpty(Request.Query["options"]))
            {
                query.ChosenOptions = Request.Query["options"]; // ~/query/create/?o=1,2,3
            }
            if (query.QueryOptions.Count() == 0)
            {
                query.QueryOptions = await Controllers.QueryController.GetQueryOptions(query.ChosenOptions);
            }
            ViewData["Query"] = query;
            return View(query);
        }

    }
}
