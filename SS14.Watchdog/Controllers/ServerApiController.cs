using System.Diagnostics.CodeAnalysis;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using SS14.Watchdog.Components.ServerManagement;
using SS14.Watchdog.Utility;

namespace SS14.Watchdog.Controllers
{
    /// <summary>
    ///     API intended to be used by the instances to communicate back to the watchdog.
    /// </summary>
    [ApiController]
    [Route("/server_api/{key}")]
    public class ServerApiController : ControllerBase
    {
        private readonly IServerManager _serverManager;
        private readonly ILogger<ServerApiController> _logger;

        public ServerApiController(IServerManager serverManager, ILogger<ServerApiController> logger)
        {
            _serverManager = serverManager;
            _logger = logger;
        }

        [HttpPost("ping")]
        public async Task<IActionResult> PingAsync([FromHeader(Name = "Authorization")] string authorization, string key)
        {
            if (!TryAuthorize(authorization, key, out var failure, out var instance))
            {
                return failure;
            }

            await instance.PingReceived();
            return Ok();
        }

        [NonAction]
        public bool TryAuthorize(string authorization,
            string key,
            [NotNullWhen(false)] out IActionResult? failure,
            [NotNullWhen(true)] out IServerInstance? instance)
        {
            instance = null;

            if (string.IsNullOrEmpty(authorization))
            {
                _logger.LogWarning("Authorization header is missing for server API request");
                failure = new UnauthorizedResult();
                return false;
            }

            if (!AuthorizationUtility.TryParseBasicAuthentication(authorization, out failure, out var authKey,
                out var token))
            {
                _logger.LogWarning("Failed to parse Basic authentication from Authorization header for server API request (key: {Key})", key);
                return false;
            }

            if (authKey != key)
            {
                _logger.LogWarning("Authorization key mismatch: expected {ExpectedKey}, got {ActualKey}", key, authKey);
                failure = Forbid();
                return false;
            }

            if (!_serverManager.TryGetInstance(key, out instance))
            {
                _logger.LogWarning("Server instance {Key} not found", key);
                failure = NotFound();
                return false;
            }

            if (string.IsNullOrEmpty(instance.Secret))
            {
                _logger.LogWarning("Server instance {Key} has no secret configured", key);
                failure = new UnauthorizedResult();
                return false;
            }

            // TODO: we probably need constant-time comparisons for this?
            // Maybe?
            if (token != instance.Secret)
            {
                _logger.LogWarning("Secret mismatch for server instance {Key}", key);
                failure = Unauthorized();
                return false;
            }

            _logger.LogDebug("Successfully authorized server API request for {Key}", key);
            return true;
        }
    }
}
