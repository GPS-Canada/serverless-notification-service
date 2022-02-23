# serverless-notification-service sample
Demonstrates a serverless architecture to send emails or sms's using Azure Functions, SendGrid and Twilio using a Service Bus Queue

# Proposed architecture

![image](https://user-images.githubusercontent.com/8275679/155341621-846e6acf-2f84-4000-9ef4-e68fc08fb501.png)


# Prerequisites

[dotnet 6](https://dotnet.microsoft.com/en-us/download/dotnet/6.0)

[Azure Functions Core Tools v4](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local)

[az CLI 2.30+](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)



In order to run the sample code, you will also need a Twilio account and a SendGrid account. 

For Twilio configuration, you will need the  SID and Account Key as well as a registered phone number to send messages from.

For Send Grid you need the SendGrid key and a validated sender email. 

# Deployment

You can deploy the infrastructure needed for the sample in your Azure tenant, using the `deploy.ps1` script found in the `.deploy` folder.


```powershell
./deploy.ps1 `
  -AppNamePrefix "test-ns1" `
  -SendGridKey "<KEY>" `
  -SendGridFrom "<EMAIL>"`
  -TwilioSid "<SID>" `
  -TwilioKey "<KEY>" `
  -TwilioPhoneNo "<PHONE (include the country code)" `
```

* make sure to run `az login` before running the script

To deploy the Azure functions code, you can use the `publish.ps1` script in the `.deploy` folder (or push from your favorite IDE)

```powershell
./publish.ps1 -AppNamePrefix "test-ns1"
```

