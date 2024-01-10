using Azure.Core;
using Azure.Identity;
using Microsoft.Extensions.Options;
using System.Net.Http.Headers;

public sealed class AuthorizationMessageHandler : DelegatingHandler
{
	private readonly DefaultAzureCredential _msiCredentials;
	private readonly IOptions<Settings> _settings;

	public AuthorizationMessageHandler(IOptions<Settings> settings)
	{
		_settings = settings;
		_msiCredentials = new DefaultAzureCredential();
	}

	protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
	{
		var accessToken = await _msiCredentials.GetTokenAsync(new TokenRequestContext(new[] { _settings.Value.AuthenticationScope }), cancellationToken);
		var jwt = accessToken.Token;

		request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", jwt);
		return await base.SendAsync(request, cancellationToken);
	}
}