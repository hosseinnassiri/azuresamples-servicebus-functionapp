using Azure.Core;
using Azure.Identity;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Net.Http.Headers;
using System.Text.Json;

namespace AzureSamples.ServiceBus.FunctionApp;

public class MessageConsumer
{
    private readonly ILogger<MessageConsumer> _logger;
    private readonly IConfiguration _configuration;
	private readonly IOptions<Settings> _settings;

	public MessageConsumer(ILogger<MessageConsumer> logger, IConfiguration configuration, IOptions<Settings> settings)
    {
        _logger = logger;
        _configuration = configuration;
		_settings = settings;
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

		//TODO: read from app config
		//var apiUrl = "https://apim-sample-dev-01.azure-api.net/helloworld/hello";

		var msiCredentials = new DefaultAzureCredential();

		//TODO: read from app config
		//var scope = "https://management.azure.com/.default";
		var accessToken = await msiCredentials.GetTokenAsync(new TokenRequestContext(new[] { _settings.Value.AuthenticationScope }), cancellationToken);
		var jwt = accessToken.Token;

		//TODO: use http client factory
		var httpClient = new HttpClient();
		httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", jwt);

		var result = await httpClient.GetAsync(_settings.Value.PingApiUrl, cancellationToken);

		if (result.IsSuccessStatusCode)
		{
			var content = await result.Content.ReadAsStringAsync(cancellationToken);
			_logger.LogInformation("response of the api call: {apiContent}", content);
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
