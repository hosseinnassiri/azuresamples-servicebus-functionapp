using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
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
    //[BlobOutput("archive/{name}-{datetime:yyyyMMdd-HHmmss}-output.json", Connection = "ArchiveBlobConnection")]
	public MyOutputType Run([ServiceBusTrigger("%ServiceBusQueue%", Connection = "ServiceBusConnection")] SampleEvent message,
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

		_logger.LogDebug("Message Body: {message}", JsonSerializer.Serialize(message));

		// blob output
		//return message;
		return new MyOutputType
		{
			Blob = message,
			Document = message
		};
	}

	public class MyOutputType
	{
		[BlobOutput("archive/{name}-{datetime:yyyyMMdd-HHmmss}-output.json", Connection = "ArchiveBlobConnection")]
		public SampleEvent Blob { get; set; }

		[CosmosDBOutput("%CosmosDb%", "%CosmosContainerOut%", Connection = "CosmosDBConnection", CreateIfNotExists = true)]

		public SampleEvent Document { get; set; }
	}
}
