using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Search.Core.Models;

namespace Search.Core.Controllers
{
    [Authorize]
    public class HomeController : Controller
    {
        private readonly List<Redirect> _redirects = new List<Models.Redirect>();
        //IConfiguration configuration;
        public HomeController(IConfiguration configuration) //IOptions<AppSettings> configuration
        {
            //this.configuration = configuration;
            foreach (var setting in configuration.GetSection("AppSettings:Redirects")?.GetChildren())
            {
                _redirects.Add(new Models.Redirect()
                {
                    Name = configuration[setting.Path + ":Name"],
                    Title = configuration[setting.Path + ":Title"],
                    Url = configuration[setting.Path + ":Url"]
                });
            }
        }

        public IActionResult Index()
        {
            return View(_redirects);
        }

        public IActionResult About()
        {
            ViewData["Message"] = "Your application description page.";

            return View();
        }

        public IActionResult Contact()
        {
            ViewData["Message"] = "Your contact page.";

            return View();
        }

        [AllowAnonymous]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
