using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using SendGrid.Helpers.Mail;
using System.Text;
using Twilio.Rest.Api.V2010.Account;
using Twilio.Types;
using Azure.Messaging.ServiceBus;

namespace Sample_NotificationService
{
    public static class NotificationFunctions
    {
        [FunctionName("SendEmail")]
        public static void SendEmail(
         [ServiceBusTrigger("%ServiceBus-EmailQueue%", Connection = "ServiceBus")] ServiceBusReceivedMessage notification,
         [SendGrid(ApiKey = "SendGrid-Key")] out SendGridMessage message,
         ILogger log)
        {
            try
            {
                var email = JsonSerializer.Deserialize<EmailNotification>(Encoding.UTF8.GetString(notification.Body));
                log.LogInformation($"Processing new email notification: {notification.Body}");

                message = new SendGridMessage();
                message.AddTo(email.To);
                message.AddContent("text/html", email.Body);
                message.SetFrom(new EmailAddress(Environment.GetEnvironmentVariable("SendGrid-From")));
                message.SetSubject(email.Subject);
            }
            catch (Exception)
            {
                //TODO: Move message to poison queue
                throw;
            }
           
        }

        [FunctionName("SendMessage")]
        [return: TwilioSms(AccountSidSetting = "Twilio-Sid", AuthTokenSetting = "Twilio-Key", From = "%Twilio-PhoneNo%")]
        public static CreateMessageOptions SendSMS(
            [ServiceBusTrigger("%ServiceBus-SMSQueue%", Connection = "ServiceBus")] ServiceBusReceivedMessage notification,
            ILogger log)
        {
            try
            {
                var sms = JsonSerializer.Deserialize<SMSNotification>(Encoding.UTF8.GetString(notification.Body));
                log.LogInformation($"Processing new SMS notification: {notification.Body}");

                var message = new CreateMessageOptions(new PhoneNumber(sms.PhoneNumber))
                {
                    Body = sms.Text
                };

                return message;
            }
            catch(Exception)
            {
                //TODO: Move message to poison queue
                throw;
            }
        }

    }

}
