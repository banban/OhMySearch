using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Search.Core.Windows.Models;
using Microsoft.AspNetCore.Hosting;
using System.IO;

// For more information on enabling MVC for empty projects, visit http://go.microsoft.com/fwlink/?LinkID=397860

namespace Search.Core.Windows.Controllers
{
    public class SearchResultController : Controller
    {
        private readonly IHostingEnvironment _hostingEnvironment;

        public SearchResultController(IHostingEnvironment hostingEnvironment)
        {
            _hostingEnvironment = hostingEnvironment;
        }
        // GET: /<controller>/
        public IActionResult Index()
        {
            return View();
        }

        public async Task<ActionResult> Details(string _index, string _type, string _id)
        {
            var result = await QueryController.GetDocument(_index, _type, _id);
            Models.SearchResult searchResult = new Models.SearchResult()
            {
                Id = result.Id,
                Index = result.Index,
                Type = result.Type,
                Summary = result.Source.ToString()
            };
            if (result.Type == "file" || result.Type == "photo")
            {
                try
                {
                    searchResult.Path = (string)result.Source["Path"];
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

                    ///SystemDrawing is NotFound implemented in Core 1 RC2 :(
                    //System.IO.FileInfo fi = new System.IO.FileInfo(searchResult.Path);
                    //System.IO.File.Copy(fi.FullName, _hostingEnvironment.WebRootPath + "\\temp\\" + fi.Name);
                    //searchResult.Path = "~/temp/" + fi.Name;

                    //Image image = Image.FromFile(imagePath, false);
                    //Image thumb = image.GetThumbnailImage(100, 100, () => false, IntPtr.Zero);
                    //thumb.Save(localPath, System.Drawing.Imaging.ImageFormat.Png);
                    //thumb.Dispose();
                }
            }

            if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")//(Request.IsAjaxRequest())
            {
                return PartialView(searchResult);
            }
            return View(searchResult);
        }
    }
}
