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
            Models.Query query = new Models.Query();
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
                query.QueryOptions = await Controllers.QueryController.GetQueryOptions(query.ChosenOptions);
            }

            return View(query);
        }

    }
}
