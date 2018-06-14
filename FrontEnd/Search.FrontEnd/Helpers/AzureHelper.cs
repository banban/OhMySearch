using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
namespace Search.Core.Windows.Helpers
{
    public class AzureHelper
    {
        // Get the current user's email address from their profile.
/*        public async Task<string> GetMyEmailAddress(string accessToken)
        {

            // Get the current user. 
            // The app only needs the user's email address, so select the mail and userPrincipalName properties.
            // If the mail property isn't defined, userPrincipalName should map to the email for all account types. 
            string endpoint = "https://graph.microsoft.com/v1.0/me";
            string queryParameter = "?$select=mail,userPrincipalName";
            UserInfo me = new UserInfo();

            using (var client = new HttpClient())
            {
                using (var request = new HttpRequestMessage(HttpMethod.Get, endpoint + queryParameter))
                {
                    request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                    request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
                    using (HttpResponseMessage response = await client.SendAsync(request))
                    {
                        if (response.StatusCode == HttpStatusCode.OK)
                        {
                            var json = JObject.Parse(await response.Content.ReadAsStringAsync());
                            me.Address = !string.IsNullOrEmpty(json.GetValue("mail").ToString()) ? json.GetValue("mail").ToString() : json.GetValue("userPrincipalName").ToString();
                        }
                        return me.Address?.Trim();
                    }
                }
            }
        }*/
    }
}
