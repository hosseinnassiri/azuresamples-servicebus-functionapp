using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Azure.Identity;

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
    .Build();

host.Run();
