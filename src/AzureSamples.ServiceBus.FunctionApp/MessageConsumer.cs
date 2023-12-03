using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

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
    [BlobOutput("test-samples-output/{name}-output.txt")]
	public string Run([ServiceBusTrigger("%ServiceBusQueue%", Connection = "ServiceBusConnection")] ServiceBusReceivedMessage message,
				 FunctionContext context,
				 CancellationToken cancellationToken)
    {
		if (cancellationToken.IsCancellationRequested)
		{
			_logger.LogInformation("A cancellation token was received, taking precautionary actions.");
			// Take precautions like noting how far along you are with processing the batch
			_logger.LogInformation("Precautionary activities complete.");
		}

		_logger.LogInformation("Message ID: {id}", message.MessageId);
        _logger.LogInformation("Message Body: {body}", message.Body);
        _logger.LogInformation("Message Content-Type: {contentType}", message.ContentType);

		// Blob Output
		return message.Body.ToString();
    }
}
