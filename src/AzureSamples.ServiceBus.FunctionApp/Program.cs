using Azure.Identity;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

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
	.ConfigureServices(services => {
		services.AddApplicationInsightsTelemetryWorkerService();
		services.ConfigureFunctionsApplicationInsights();
	})
	.Build();

host.Run();
