using Azure.Identity;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var host = new HostBuilder()
    .ConfigureAppConfiguration(builder =>
    {
        builder.AddAzureAppConfiguration(options =>
        {
            var appConfigEndpoint = Environment.GetEnvironmentVariable("AppConfigConnection");
            options.Connect(new Uri(appConfigEndpoint), new DefaultAzureCredential());
        });
    })
    .ConfigureFunctionsWorkerDefaults()
	.ConfigureLogging(c => c.SetMinimumLevel(LogLevel.Trace))
	.ConfigureServices((context, services) => {
		services.AddApplicationInsightsTelemetryWorkerService();
		services.ConfigureFunctionsApplicationInsights();
		services.Configure<Settings>(context.Configuration.GetSection("Settings"));
	})
	.Build();

host.Run();

public sealed class Settings
{
    public required string PingApiUrl { get; init; }
	public required string AuthenticationScope { get; init; }
}
