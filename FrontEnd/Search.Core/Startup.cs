using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Search.Core
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;


        }

        public IConfiguration Configuration { get; }
        
        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            services.AddAuthentication(sharedOptions =>
            {
                sharedOptions.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
                sharedOptions.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
            })
            .AddAzureAd(options => Configuration.Bind("AzureAd", options))
            .AddCookie();

            services.AddMvc();
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env, ILoggerFactory loggerFactory)
        {
            loggerFactory.AddConsole(Configuration.GetSection("Logging"));
            loggerFactory.AddConsole(); //options => options.IncludeScopes = true
            loggerFactory.AddDebug();
            //loggerFactory.AddFile("Logs/OMS-{Date}.txt");

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

            //share some settings without IConfiguration. Another approach could be found in Home controller cunstructor
            Environment.SetEnvironmentVariable("SiteTitle", Configuration["AppSettings:SiteTitle"]);
            Environment.SetEnvironmentVariable("Author", Configuration["AppSettings:Author"]);
            Environment.SetEnvironmentVariable("Wiki", Configuration["AppSettings:Wiki"]);
            Environment.SetEnvironmentVariable("Support", Configuration["AppSettings:Support"]);
            Environment.SetEnvironmentVariable("WebRootPathTemp", tempDir);

            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ElasticUri"))) //check environment variable
            {
                Environment.SetEnvironmentVariable("ElasticUri", Configuration["Data:ElasticSearch:Url"]?.TrimEnd('/'));
            }
            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ElasticUri"))) //check environment variable
            {
                Environment.SetEnvironmentVariable("ElasticUri", "");
            }
            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ElasticUri"))) //check environment variable
            {
                Environment.SetEnvironmentVariable("ElasticUri", "http://localhost:9200");
            }

            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("Google_MapApiKey"))) //check environment variable
            {
                Environment.SetEnvironmentVariable("Google_MapApiKey", Configuration["Data:Google:MapApiKey"]);
            }

            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("MAGICK_HOME"))) //check environment variable
            {
                Environment.SetEnvironmentVariable("MAGICK_HOME", Configuration["Data:ImageMagic:HomePath"]);
            }

            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ACLUrl"))) //check environment variable
            {
                Environment.SetEnvironmentVariable("ACLUrl", Configuration["Data:ACL:Url"]?.TrimEnd('/'));
            }

            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ElasticUser"))) //check environment variable
            {
                Environment.SetEnvironmentVariable("ElasticUser", Configuration["Data:Elastic:User"]);
            }
            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ElasticPassword"))) //check environment variable
            {
                Environment.SetEnvironmentVariable("ElasticPassword", Configuration["Data:Elastic:Password"]);
            }
            var _logger = loggerFactory.CreateLogger("Config"); _logger.LogInformation(string.Format("EnvironmentName: {0}, IsProduction: {1}, ContentRootPath: {2}", env.EnvironmentName, env.IsProduction(), env.ContentRootPath));

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

            app.UseAuthentication();

            app.UseMvc(routes =>
            {
                routes.MapRoute(
                    name: "default",
                    template: "{controller=Home}/{action=Index}/{id?}");
            });
        }
    }
}
