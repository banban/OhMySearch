using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System.IO;

namespace Search.Core.Windows
{
    public class Startup
    {
        public Startup(IHostingEnvironment env)
        {
            var builder = new ConfigurationBuilder()
                .SetBasePath(env.ContentRootPath)
                .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
                .AddJsonFile($"appsettings.{env.EnvironmentName}.json", optional: true)
                .AddEnvironmentVariables();
            Configuration = builder.Build();

            var tempDir = System.IO.Path.Combine(env.WebRootPath, "temp");
            if (Directory.Exists(tempDir))
            {
                try
                {
                    DirectoryInfo dir = new DirectoryInfo(tempDir);
                    foreach (FileInfo fi in dir.GetFiles())
                    {
                        fi.IsReadOnly = false;
                        fi.Delete();
                    }
                }
                catch (Exception)
                {
                }
            }
            else
            {
                try
                {
                    Directory.CreateDirectory(tempDir);
                }
                catch (Exception)
                {
                }
            }
        }

        public static IConfigurationRoot Configuration { get; set; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            // Add framework services.
            services.AddMvc();
            services.AddMemoryCache();
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env, ILoggerFactory loggerFactory)
        {
            loggerFactory.AddConsole(Configuration.GetSection("Logging"));
            loggerFactory.AddDebug();

            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
                app.UseBrowserLink();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
            }

            app.UseStaticFiles();

            app.UseMvc(routes =>
            {
                routes.MapRoute(
                    name: "default",
                    template: "{controller=Home}/{action=Index}/{id?}");
            });

        }

        public static string GetElasticSearchUrl()
        {
            string result = result = Configuration["Data:ElasticSearch:Url"];
            if (string.IsNullOrEmpty(result))
            {
                result = Environment.GetEnvironmentVariable("ElasticUri");
            }
            if (result == null)
            {
                result = "";
            }
            if (string.IsNullOrEmpty(result))
            {
                result = "http://localhost:9200";
            }
            return result.TrimEnd('/');
        }

        public static string GetGoogleMapKey()
        {
            string result = Configuration["Data:Google:MapApiKey"];
            if (string.IsNullOrEmpty(result))
            {
                result = Environment.GetEnvironmentVariable("Google_MapApiKey");
            }

            return result;
        }

        public static KeyValuePair<string, string> GetElasticCredencials()
        {
            string user = Configuration["Data:Elastic:User"];
            if (string.IsNullOrEmpty(user))
            {
                user = Environment.GetEnvironmentVariable("ElasticUser");
            }
            string password = Configuration["Data:Elastic:Password"];
            if (string.IsNullOrEmpty(password))
            {
                password = Environment.GetEnvironmentVariable("ElasticPassword");
            }
            KeyValuePair<string, string> result = new KeyValuePair<string, string>(user, password);
            return result;
        }

    }
}
