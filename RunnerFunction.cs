using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Azure.Messaging.ServiceBus;

namespace Sample_NotificationService
{
    public static class RunnerFunction
    {
        [FunctionName("RunnerFunction")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)] HttpRequest req,
            [ServiceBus("%ServiceBus-EmailQueue%", Connection = "ServiceBus")] IAsyncCollector<ServiceBusMessage> emailMessage,
            [ServiceBus("%ServiceBus-SMSQueue%", Connection = "ServiceBus")] IAsyncCollector<ServiceBusMessage> smsMessage,
            ILogger log)
        {
            var messageType = req.Query["type"].ToString().ToLower();
            var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
           
            switch (messageType)
            {
                case "email": await emailMessage.AddAsync(new ServiceBusMessage(requestBody)); return new OkObjectResult("Email Queued");
                case "sms": await smsMessage.AddAsync(new ServiceBusMessage(requestBody)); return new OkObjectResult("SMS Queued");
                default: return new BadRequestObjectResult("please use type 'sms' or 'email'");
            }
        }
    }
}
