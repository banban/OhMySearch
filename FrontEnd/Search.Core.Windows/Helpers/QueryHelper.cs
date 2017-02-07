using Microsoft.Extensions.Caching.Memory;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace Search.Core.Windows.Helpers
{
    public class QueryHelper
    {
        public static string SplitCamelCase(string source)
        {
            var r = new Regex(@"
                (?<=[A-Z])(?=[A-Z][a-z]) |
                 (?<=[^A-Z])(?=[A-Z]) |
                 (?<=[A-Za-z])(?=[^A-Za-z])", RegexOptions.IgnorePatternWhitespace);
            return ToTitleCase(r.Replace(source, " "));
        }

        public static string ToTitleCase(string str)
        {
            string result = str;
            if (!string.IsNullOrEmpty(str))
            {
                var words = str.Split(' ');
                for (int index = 0; index < words.Length; index++)
                {
                    var s = words[index];
                    if (s.Length > 0)
                    {
                        words[index] = s[0].ToString().ToUpper() + s.Substring(1);
                    }
                }
                result = string.Join(" ", words);
            }
            return result;
        }
        /// <summary>
        /// Deligate security check to another web service specific for the domain.
        /// I use AD domain ACL check, but it could be any system
        /// </summary>
        /// <param name="upn">User principal name</param>
        /// <param name="path">path to file</param>
        /// <returns></returns>
        public static bool UserHasAccess(string upn, string path, IMemoryCache memoryCache)
        {
            if (string.IsNullOrEmpty(path))
            {
                return false;
            }
            if (path.StartsWith("http://") || path.StartsWith("https://") || path.StartsWith("ftp://"))
            {
                return true;
            }
            //if (!path.StartsWith("\\\\"))
            //{
            //    return false;
            //}

            string key = string.Format("UserHasAccess:{0}_{1}", upn, path.Replace("/", "\\")); //convert hierarchy notation c:/ to path c:\
            bool hasAccess = false;
            if (!memoryCache.TryGetValue(key, out hasAccess))
            {
                // fetch the value from ACL web service
                string url = Environment.GetEnvironmentVariable("ACLUrl");
                Uri uri = new Uri(url);
                if (string.IsNullOrEmpty(url)) //which means ACL service is not available in current environment
                {
                    return true; //ignore ACL security
                }
                else
                {
                    //ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, sslPolicyErrors) => true;//not supported by ASP.Net Core
                    using (var handler = new HttpClientHandler { UseDefaultCredentials = true })
                    using (var client = new HttpClient(handler))
                    {
                        client.BaseAddress = new Uri(url.Substring(0, url.IndexOf(uri.LocalPath)));
                        client.DefaultRequestHeaders.Accept.Clear();
                        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                        hasAccess = false;
                        try
                        {
                            var result = client.PostAsync(string.Format(url.Substring(url.IndexOf(uri.LocalPath)), upn, path), null).Result;
                            if (result.IsSuccessStatusCode)
                            {
                                string responseBody = result.Content.ReadAsStringAsync().Result;
                                //hasAccess = (responseBody.Contains("\\\"CanRead\\\":true"));
                                var responseJson = JsonConvert.DeserializeObject<dynamic>(responseBody);
                                var responseObj = JValue.Parse(responseJson);
                                hasAccess = (bool)responseObj["CanRead"];
                            }
                        }
                        catch (HttpRequestException) //ACL service is configured but not available
                        {
                        }
                    }
                }

                // store in the cache
                memoryCache.Set(key, hasAccess, new MemoryCacheEntryOptions().SetAbsoluteExpiration(TimeSpan.FromDays(1)));
            }
            //else retrieved from cache
            return hasAccess;
        }

        //private static List<Models.SearchResult> GetQueryAggregations(Nest.ISearchResponse<dynamic> nestResults)
        //{
        //    var myAgg = nestResults.Aggs.Terms("my_agg");
        //    //var results = new Dictionary<string, string>();
        //    //foreach (var agg in NestResults.Aggregations)
        //    //{
        //    //    results.Add(agg.Key, agg.Value.Meta);
        //    //}
        //    //return results;
        //}

        /// <summary>
        /// simple helper for direct access to any REST APIs
        /// var result = await CURL("GET", "/_all/_search?q="+query.QueryTerm, null);
        /// </summary>
        /// <param name="action"></param>
        /// <param name="url"></param>
        /// <param name="body"></param>
        /// <returns></returns>
        public static async Task<JObject> CURL(string action, string url, string body)
        {

            string responseBody = string.Empty;
            using (var client = new HttpClient())
            {
                client.BaseAddress = new Uri(Environment.GetEnvironmentVariable("ElasticUri"));
                Uri uri = new Uri(client.BaseAddress + url.TrimStart('/'));
                client.DefaultRequestHeaders.Accept.Clear();
                client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                StringContent queryString = null;

                //if x-pack is installed
                string cred = Environment.GetEnvironmentVariable("ElasticUser") + ":" + Environment.GetEnvironmentVariable("ElasticPassword");
                if (cred != ":")
                {
                    var credentials = System.Text.Encoding.ASCII.GetBytes("elastic:changeme");
                    client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", Convert.ToBase64String(credentials));
                }

                if (!string.IsNullOrEmpty(body))
                {
                    queryString = new StringContent(body);
                }
                HttpResponseMessage response = null;
                if (action == "POST")
                {
                    response = await client.PostAsync(uri, queryString);
                }
                else if (action == "GET")
                {
                    response = await client.GetAsync(uri);
                }
                else if (action == "PUT")
                {
                    response = await client.PutAsync(uri, queryString);
                }
                else if (action == "DELETE")
                {
                    response = await client.DeleteAsync(uri);
                }
                //response.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
                //response.EnsureSuccessStatusCode();
                if (response.IsSuccessStatusCode)
                {
                    responseBody = await response.Content.ReadAsStringAsync();
                    //DataContractJsonSerializer ser = new DataContractJsonSerializer(typeof(Response));
                }
            }
            var resultObj = JsonConvert.DeserializeObject<dynamic>(responseBody);
            //JsonNodes resultObj = JsonConvert.DeserializeObject<JsonNodes>(responseBody);
            //var resultObj = JObject.Parse(responseBody);
            return resultObj;
        }
    }
}
