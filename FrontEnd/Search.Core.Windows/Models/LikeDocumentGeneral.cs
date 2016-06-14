using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Search.Core.Windows.Models
{
    public class LikeDocumentGeneral : Nest.LikeDocumentBase
    {
        public LikeDocumentGeneral(string[] args)
        {
            //string fullId
            //string[] args = fullId.Split(',');
            if (args.Length == 3)
            {
                this.Index = args[0];
                this.Type = args[1];
                this.Id = args[0];
            }
        }
        protected override Type ClrType { get; }
    }
}
