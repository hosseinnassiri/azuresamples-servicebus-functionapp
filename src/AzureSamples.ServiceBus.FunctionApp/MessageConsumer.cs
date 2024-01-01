using Azure.Core;
using Azure.Identity;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Azure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Net.Http.Headers;
using System.Text.Json;

namespace AzureSamples.ServiceBus.FunctionApp;

public class MessageConsumer
{
    private readonly ILogger<MessageConsumer> _logger;
    private readonly IConfiguration _configuration;

    public MessageConsumer(ILogger<MessageConsumer> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;

        // read configuration data from app config
        string keyName = "myKey";
        string keyValue = _configuration[keyName];
        _logger.LogDebug("Reading value from app configuration. {key}: {value}", keyName, keyValue);
    }

    [Function(nameof(MessageConsumer))]
	public async Task<MyOutputType> Run([ServiceBusTrigger("%ServiceBusQueue%", Connection = "ServiceBusConnection")] SampleEvent message,
				   FunctionContext context,
				   CancellationToken cancellationToken)
    {
		_logger.LogDebug("InvocationId: {invocationId}", context.InvocationId);
		if (cancellationToken.IsCancellationRequested)
		{
			_logger.LogWarning("A cancellation token was received, taking precautionary actions.");
			// take precautions like noting how far along you are with processing the batch
			_logger.LogDebug("Precautionary activities complete.");
		}

		var apiUrl = "https://apim-sample-dev-01.azure-api.net/helloworld/hello";

		// Use the built in DefaultAzureCredential class to retrieve the managed identity, filtering on client ID if user assigned
		var msiCredentials = new DefaultAzureCredential();
		var scope = "https://management.azure.com/.default";
		// Use the GetTokenAsync method to generate a JWT for use in a HTTP request
		var accessToken = await msiCredentials.GetTokenAsync(new TokenRequestContext(new[] { scope }), cancellationToken);
		var jwt = accessToken.Token;

		var httpClient = new HttpClient();
		// Add the JWT to the request headers as a bearer token (this is the default for the `validate-azure-ad-token` policy, but you could override it and use a different header)
		httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", jwt);

		var result = await httpClient.GetAsync(apiUrl, cancellationToken);

		if (result.IsSuccessStatusCode)
		{
			var content = await result.Content.ReadAsStringAsync(cancellationToken);
			_logger.LogCritical("response of the api call: {apiContent}", content);
		}
		else
		{
			_logger.LogError("could not get resposne from the api");
		}

		_logger.LogDebug("Message Body: {message}", JsonSerializer.Serialize(message));
		// blob & cosmos db multiple output
		return new MyOutputType
		{
			Blob = message
			//document = message
		};
	}

	public class MyOutputType
	{
		[BlobOutput("archive/{name}-{datetime:yyyyMMdd-HHmmss}-output.json", Connection = "ArchiveBlobConnection")]
		public SampleEvent Blob { get; set; }

		//[CosmosDBOutput("%CosmosDbDatabase%", "%CosmosDbContainer%", Connection = "CosmosDBConnection", CreateIfNotExists = true)]
		//public SampleEvent Document { get; set; }
	}
}
