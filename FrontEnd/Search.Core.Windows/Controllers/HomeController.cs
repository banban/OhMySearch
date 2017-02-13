using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Search.Core.Windows.Models;
using Newtonsoft.Json;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Configuration;

namespace Search.Core.Windows.Controllers
{
    public class HomeController : Controller
    {
        private readonly List<Redirect> _redirects = new List<Models.Redirect>();
        //IConfiguration configuration;
        public HomeController(IConfiguration configuration) //IOptions<AppSettings> configuration
        {
            //this.configuration = configuration;
            foreach (var setting in configuration.GetSection("AppSettings:Redirects")?.GetChildren())
            {
                _redirects.Add(new Models.Redirect() {
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
            ViewData["Message"] = "Application description page.";

            return View();
        }

        public IActionResult Contact()
        {
            ViewData["Message"] = "Contact page.";

            return View();
        }

        public IActionResult Error()
        {
            return View();
        }

    }
}
