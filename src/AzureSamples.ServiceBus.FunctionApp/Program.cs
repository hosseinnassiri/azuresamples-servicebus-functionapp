using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Azure.Identity;

var host = new HostBuilder()
    .ConfigureAppConfiguration(builder =>
    {
        builder.AddAzureAppConfiguration(options =>
        {
            options.Connect(new Uri(Environment.GetEnvironmentVariable("AppConfigConnection")), new DefaultAzureCredential());
        });
    })
    .ConfigureFunctionsWorkerDefaults(app =>
    {
        app.UseAzureAppConfiguration();
    })
    .Build();

host.Run();
