using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Principal;
using System.Security.AccessControl;
using System.Threading.Tasks;

namespace Search.Core.Windows.Controllers
{
    public class AccessHelper
    {
        private static void CheckDirectoryACLRights(WindowsPrincipal principal, string path, ref bool canRead, ref bool denied)
        {
            if (string.IsNullOrEmpty(path) || principal == null)
            {
                return;
            }
            /*not implemented in ASP.Net Core yet :(
             
            DirectoryInfo di = new DirectoryInfo(path);
            if (di.Exists)//If system account do not have at a minimum read-only permission to the directory, the Exists method will return false.
            {
                try
                {
                    DirectorySecurity acl = di.GetAccessControl(AccessControlSections.Access);
                    AuthorizationRuleCollection rules = acl.GetAccessRules(true, true, typeof(NTAccount));
                    //Go through the rules returned from the DirectorySecurity
                    foreach (AuthorizationRule rule in rules)
                    {
                        //If we find one that matches the identity we are looking for or member of group
                        if (rule.IdentityReference.Value.Equals(principal.Identity.Name, StringComparison.CurrentCultureIgnoreCase)
                            || principal.IsInRole(rule.IdentityReference.Value))
                        {
                            FileSystemAccessRule currentRule = (FileSystemAccessRule)rule;
                            if (currentRule != null)
                            {
                                AccessControlType accessType = currentRule.AccessControlType;
                                //Copy file cannot be executed for "List Folder/Read Data" and "Read extended attributes" denied permission
                                if (accessType == AccessControlType.Deny && (currentRule.FileSystemRights & FileSystemRights.ListDirectory) == FileSystemRights.ListDirectory)
                                {
                                    //user have deny copy - can't access the files
                                    denied = true;
                                    break;
                                }
                                else if (accessType == AccessControlType.Deny && (currentRule.FileSystemRights & FileSystemRights.Read) == FileSystemRights.Read)
                                {
                                    //user have deny copy - can't access the files
                                    denied = true;
                                    break;
                                }
                                else if (accessType == AccessControlType.Allow && (currentRule.FileSystemRights & FileSystemRights.ListDirectory) == FileSystemRights.ListDirectory)
                                {
                                    //user have access the directory
                                    canRead = true;
                                    //do not break chain!!!
                                }
                                else if (accessType == AccessControlType.Allow && (currentRule.FileSystemRights & FileSystemRights.Read) == FileSystemRights.Read)
                                {
                                    //user have access the directory
                                    canRead = true;
                                    //do not break chain!!!
                                }
                            }

                            ////Cast to a FileSystemAccessRule to check for access rights
                            //if ((((FileSystemAccessRule)rule).FileSystemRights & FileSystemRights.) > 0)
                            //{
                            //    Console.WriteLine(string.Format("{0} has read access to {1}", principal.Identity.Name, path));
                            //}
                            //else if ((((FileSystemAccessRule)rule).FileSystemRights & FileSystemRights.Read) > 0)
                            //{
                            //    Console.WriteLine(string.Format("{0} has read access to {1}", principal.Identity.Name, path));
                            //}
                            //else
                            //{
                            //    Console.WriteLine(string.Format("{0} does not have write access to {1}", principal.Identity.Name, path));
                            //}
                        }
                    }
                }
                catch (UnauthorizedAccessException)
                {
                    canRead = false;
                    denied = true;
                    //throw;
                }
            }
            */
        }
    }
}
