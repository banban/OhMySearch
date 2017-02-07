using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
//using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace Search.Core.Windows.Controllers
{
    [Route("api/[controller]/[action]")]
    public class Office365Controller : Controller
    {
        //#region member variables, configs & construction
        //private readonly IOptions<Config> customConfig;

        //// The URL that auth should redirect to after a successful login.
        //Uri loginRedirectUri => new Uri(Url.Action(nameof(Authorize), "Office365", null, HttpContext.Request.Scheme));
        //// The URL to redirect to after a logout.
        //Uri logoutRedirectUri => new Uri(Url.Action(nameof(Index), "Office365", null, HttpContext.Request.Scheme));

        //public Office365Controller(IOptions<Config> cConfig)
        //{
        //    customConfig = cConfig;
        //    Settings.ClientId = customConfig.Value.ClientId;
        //    Settings.ClientSecret = customConfig.Value.ClientSecret;
        //    Settings.MessageSubject = customConfig.Value.MessageSubject;
        //}

        //#endregion

        //[HttpGet]
        //public IEnumerable<string> Index(string address)
        //{
        //    UserProfile user = null;
        //    //return View();
        //    if (address != null)
        //    {
        //        // User has been authenticated & we are returning the email.
        //        // API can pull the access token or update for subsequent calls.
        //        user = GetUser(address);
        //    }
        //    if (!string.IsNullOrEmpty(address) && user != null)
        //        return new string[] { user.Address, user.AccessToken };
        //    else
        //        return new string[] { "user is not authenticated" };
        //}



        //#region Microsoft SharePoint Online Functionality

        //[HttpGet]
        //public async Task<ActionResult> SPSites(string address, string siteId)
        //{
        //    UserProfile user = GetUser(address);
        //    if (user == null)
        //    {
        //        return RedirectToActionPermanent("Login", "Office365");
        //    }
        //    else
        //    {
        //        var sendMessageResult = await ApiHelper.GetSPSites(user.AccessToken);
        //        return Content(sendMessageResult.StatusMessage, "application/json");
        //    }
        //}

        //[HttpGet]
        //public async Task<ActionResult> SPSiteLists(string address, string siteId)
        //{
        //    UserProfile user = GetUser(address);
        //    if (user == null)
        //    {
        //        return RedirectToActionPermanent("Login", "Office365");
        //    }
        //    else
        //    {
        //        var sendMessageResult = await ApiHelper.GetSPSiteLists(user.AccessToken, siteId);
        //        return Content(sendMessageResult.StatusMessage, "application/json");
        //    }
        //}

        //#endregion

        //#region Microsoft Exchange Online Functionality

        //[HttpGet]
        //public async Task<ActionResult> SendMessage(string address)
        //{
        //    // After Index method renders the View, user clicks Send Mail, which comes in here.
        //    UserProfile user = GetUser(address);
        //    if (user == null)
        //    {
        //        return RedirectToActionPermanent("Login", "Office365");
        //    }
        //    else
        //    {

        //        // Send email using the Microsoft Graph API.
        //        var sendMessageResult = await ApiHelper.SendMessageAsync(
        //            user.AccessToken,
        //            GenerateEmail(user));

        //        // Reuse the Index view for messages (sent, not sent, fail) .
        //        // Redirect to tell the browser to call the app back via the Index method.
        //        return RedirectToAction(nameof(Index), new RouteValueDictionary(new Dictionary<string, object>{
        //        { "Status", sendMessageResult.Status },
        //        { "StatusMessage", sendMessageResult.StatusMessage },
        //        { "Address", user.Address },
        //    }));
        //    }
        //}


        //SendMessageRequest GenerateEmail(UserProfile to)
        //{
        //    return CreateEmailObject(
        //        to: to,
        //        subject: Settings.MessageSubject,
        //        body: string.Format(Settings.MessageBody, to.Name)
        //    );
        //}
        //private SendMessageRequest CreateEmailObject(UserProfile to, string subject, string body)
        //{
        //    return new SendMessageRequest
        //    {
        //        Message = new Message
        //        {
        //            Subject = subject,
        //            Body = new MessageBody
        //            {
        //                ContentType = "HTML",
        //                Content = body
        //            },
        //            ToRecipients = new List<Recipient>
        //            {
        //                new Recipient
        //                {
        //                    EmailAddress = new EmailRecipient
        //                    {
        //                         Name =  to.Name,
        //                         Address = to.Address
        //                    }
        //                }
        //            }
        //        },
        //        SaveToSentItems = true
        //    };
        //}

        //#endregion

        //#region Authentication and Authorization for Microsoft Graph
        //public IActionResult Logout()
        //{
        //    HttpContext.Session.Clear();
        //    return Redirect(Settings.LogoutAuthority + logoutRedirectUri.ToString());
        //}

        ///// <summary>
        ///// Authenticate users to Microsoft Graph API
        ///// </summary>
        ///// <returns></returns>
        //public async Task<IActionResult> Login()
        //{
        //    if (string.IsNullOrEmpty(Settings.ClientId) || string.IsNullOrEmpty(Settings.ClientSecret))
        //    {
        //        ViewBag.Message = "Please set your client ID and client secret in the Web.config file";
        //        return View();
        //    }

        //    var authContext = new AuthenticationContext(Settings.AzureADAuthority);

        //    // Generate the parameterized URL for Azure login.
        //    Uri authUri = await authContext.GetAuthorizationRequestUrlAsync(
        //        Settings.GraphAPIResource,
        //        Settings.ClientId,
        //        loginRedirectUri,
        //        UserIdentifier.AnyUser,
        //        null);

        //    // Redirect the browser to the login page, then come back to the Authorize method below.
        //    return Redirect(authUri.ToString());
        //}

        ///// <summary>
        ///// The method that is being called from microsoft login page
        ///// back to the application 
        ///// </summary>
        ///// <returns></returns>
        //public async Task<ActionResult> Authorize()
        //{
        //    var authContext = new AuthenticationContext(Settings.AzureADAuthority);

        //    // Get the token.
        //    var authResult = await authContext.AcquireTokenByAuthorizationCodeAsync(
        //        HttpContext.Request.Query["code"],                              // the auth 'code' parameter from the Azure redirect.
        //        loginRedirectUri,                                               // same redirectUri as used before in Login method.
        //        new ClientCredential(Settings.ClientId, Settings.ClientSecret), // use the client ID and secret to establish app identity.
        //        Settings.GraphAPIResource);


        //    // Get user's info for the logged in user.
        //    var currUserInfo = await ApiHelper.GetUserInfoAsync(authResult.AccessToken);

        //    // set access token in the user info object.
        //    currUserInfo.AccessToken = authResult.AccessToken;

        //    // Create user profile object to be serialized & cached
        //    UserProfile userProfile = new UserProfile();
        //    userProfile.Name = currUserInfo.Name;
        //    userProfile.Address = currUserInfo.Address;
        //    userProfile.AccessToken = currUserInfo.AccessToken;

        //    // Set User Info object in a session
        //    byte[] serObj = System.Text.Encoding.UTF8.GetBytes(new Serializer().ObjectToString(userProfile));
        //    HttpContext.Session.Set(userProfile.Address, serObj);

        //    return RedirectToAction(nameof(Index), "Office365", new { address = userProfile.Address });
        //}

        ///// <summary>
        ///// Use this address to lookup the user if it is authenticated in the session collection
        ///// </summary>
        ///// <param name="address"></param>
        ///// <returns>True or False</returns>
        //private bool EnsureUser(string address)
        //{
        //    var currentUser = new Serializer().StringToObject(System.Text.Encoding.UTF8.GetString(HttpContext.Session.Get(address)));
        //    if (currentUser != null)
        //    {
        //        return true;
        //    }
        //    else
        //    {
        //        return false;
        //    }
        //}

        //private UserProfile GetUser(string address)
        //{
        //    if (string.IsNullOrEmpty(address))
        //        return null;

        //    byte[] temp = HttpContext.Session.Get(address);
        //    if (temp != null)
        //    {
        //        string serUser = System.Text.Encoding.UTF8.GetString(temp);
        //        var currentUser = new Serializer().StringToObject(serUser);
        //        if (currentUser != null)
        //        {
        //            return currentUser;
        //        }
        //        else
        //        {
        //            return null;
        //        }
        //    }
        //    else
        //        return null;
        //}

        //#endregion
    }
}

