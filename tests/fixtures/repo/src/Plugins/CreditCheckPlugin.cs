using Microsoft.Xrm.Sdk;

namespace Contoso.Sales.Plugins
{
    public class CreditCheckPlugin : PluginBase, IPlugin
    {
        public CreditCheckPlugin(string unsecure, string secure) : base(typeof(CreditCheckPlugin)) { }
    }

    public class RecalculateActivity : CodeActivity
    {
    }
}
