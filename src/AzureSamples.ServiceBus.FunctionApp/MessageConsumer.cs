using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
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

        // Read configuration data from app config
        string keyName = "myKey";
        string keyValue = _configuration[keyName];
        _logger.LogInformation("Reading value from app configuration. {key}: {value}", keyName, keyValue);
    }

    [Function(nameof(MessageConsumer))]
    [BlobOutput("archive/{name}-output.json", Connection = "ArchiveBlobConnection")]
	public SampleEvent Run([ServiceBusTrigger("%ServiceBusQueue%", Connection = "ServiceBusConnection")] SampleEvent message,
				   FunctionContext context,
				   CancellationToken cancellationToken)
    {
		_logger.LogInformation("InvocationId: {invocationId}", context.InvocationId);
		if (cancellationToken.IsCancellationRequested)
		{
			_logger.LogInformation("A cancellation token was received, taking precautionary actions.");
			// Take precautions like noting how far along you are with processing the batch
			_logger.LogInformation("Precautionary activities complete.");
		}

		_logger.LogInformation("Message Body: {message}", JsonSerializer.Serialize(message));
        _logger.LogWarning("Message Body Warning: {message}", JsonSerializer.Serialize(message));

		// Blob Output
		return message;
	}
}
