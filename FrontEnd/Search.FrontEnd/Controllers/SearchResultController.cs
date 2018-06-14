using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Search.FrontEnd.Models;
using Microsoft.AspNetCore.Hosting;
using System.IO;
using System.Diagnostics;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Caching.Memory;

// For more information on enabling MVC for empty projects, visit http://go.microsoft.com/fwlink/?LinkID=397860

namespace Search.FrontEnd.Controllers
{
    public class SearchResultController : Controller
    {
        private static IMemoryCache _memoryCache;
        //private readonly IHostingEnvironment _hostingEnvironment;
        private readonly ILogger _logger;

        public SearchResultController(ILogger logger = null, IMemoryCache memoryCache = null) //, IHostingEnvironment hostingEnvironment = null
        {
            _logger = logger;
            //if (_logger == null)
            //{
            //    _logger = loggerFactory.CreateLogger("Config");
            //    _logger.LogInformation(string.Format("EnvironmentName: {0}, IsProduction: {1}, ContentRootPath: {2}", env.EnvironmentName, env.IsProduction(), env.ContentRootPath));
            //}
            _memoryCache = memoryCache;
            //_hostingEnvironment = hostingEnvironment;
        }
        // GET: /<controller>/
        public IActionResult Index()
        {
            return View();
        }

        public async Task<ActionResult> Details(string _index, string _type, string _id)
        {
            var qc = new Controllers.QueryController(_logger, _memoryCache);
            var result = await qc.GetDocument(_index, _type, _id);
            Models.SearchResult searchResult = new Models.SearchResult()
            {
                Id = result.Id,
                CanRead = true,
                Index = result.Index,
                Type = result.Type,
                Summary = result.Source.ToString(),
                Source = result.Source.ToString()
            };
            try
            {
                searchResult.Path = ((string)result.Source["Path"]);
                searchResult.ThumbnailPath = ((string)result.Source["ThumbnailPath"]);
            }
            catch (Exception)
            {
            }
            if (!string.IsNullOrEmpty(searchResult.Path))//(searchResult.Type == "directory" || searchResult.Type == "file" || searchResult.Type == "photo")
            {
                searchResult.CanRead = Helpers.QueryHelper.UserHasAccess(User.Identity.Name, searchResult.Path.Substring(0, searchResult.Path.LastIndexOf('/')), _memoryCache);
                if (searchResult.CanRead)
                {
                    //searchResult.Path = searchResult.PrettyPath;
                    try
                    {
                        searchResult.Extension = (string)result.Source["Extension"];
                        DateTime lm = new DateTime();
                        if (DateTime.TryParse((string)result.Source["LastModified"], out lm))
                        {
                            searchResult.LastModified = lm.ToLocalTime(); //convert from UTC
                        }
                    }
                    catch (Exception)
                    {
                    }

                    if (System.IO.File.Exists(searchResult.Path) && result.Type == "photo")
                    {
                        string imageMagicHome = Environment.GetEnvironmentVariable("MAGICK_HOME");
                        if (!string.IsNullOrEmpty(imageMagicHome) && System.IO.Directory.Exists(imageMagicHome))
                        {
                            System.IO.FileInfo fi = new System.IO.FileInfo(searchResult.Path);
                            string localname = fi.FullName.GetHashCode() +  ".png";
                            var localPath = Path.Combine(Environment.GetEnvironmentVariable("WebRootPathTemp"), localname);
                            //var localPath = Path.Combine(_hostingEnvironment.WebRootPath, "temp", localname);
                            searchResult.ThumbnailPath = "temp/" + localname;
                            if (!System.IO.File.Exists(localPath))
                            {
                                ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(imageMagicHome, "magick.exe"), string.Format("\"{0}\" -resize 300x300 \"{1}\"", fi.FullName, localPath));
                                psi.WorkingDirectory = imageMagicHome;
                                //psi.UseShellExecute = true;
                                var p = Process.Start(psi);
                                p.WaitForExit(2000); //needs 2 sec delay before rendering that page
                            }
                        }
                        else //slow !!!
                        {
                            using (Stream str = System.IO.File.OpenRead(searchResult.Path))
                            {
                                using (MemoryStream data = new MemoryStream())
                                {
                                    str.CopyTo(data);
                                    data.Seek(0, SeekOrigin.Begin);
                                    byte[] buf = new byte[data.Length];
                                    data.Read(buf, 0, buf.Length);
                                    searchResult.Content = buf;
                                }
                            }
                        }
                        
                        ///SystemDrawing is NotFound implemented in Core 1 RC2 yet :(
                        //Image image = Image.FromFile(imagePath, false);
                        //Image thumb = image.GetThumbnailImage(100, 100, () => false, IntPtr.Zero);
                        //thumb.Save(localPath, System.Drawing.Imaging.ImageFormat.Png);
                        //thumb.Dispose();
                    }
                }
            }

            //More Like This request
            Models.Query mltQuery = new Models.Query()
            {
                QueryTerm = _index +"/"+ _type + "/" +_id,
                Size = 10,
                ChosenOptions = "1_" + _index + "+2_" + _type + "+3_6+"
            };
            var mltResults = await qc.GetSearchResponse(mltQuery);
            searchResult.MoreLikeThis = qc.GetSearchResults(User.Identity.Name, mltResults, mltQuery.QueryTerm)
                .Where(sr => sr.Id != _id)
                .Take(5);
            //foreach (var item in searchResult.MoreLikeThis)
            //{
            //    if (item.Id == _id)
            //    {
            //        item.Delete()
            //    }
            //}

            if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")//(Request.IsAjaxRequest())
            {
                return PartialView(searchResult);
            }
            return View(searchResult);
        }
    }
}
