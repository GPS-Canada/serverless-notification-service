using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Sample_NotificationService
{

    public record SMSNotification(string Text, string PhoneNumber);
    public record EmailNotification(string To, string Subject, string Body);

}
