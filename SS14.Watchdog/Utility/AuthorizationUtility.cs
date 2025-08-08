using System.Diagnostics.CodeAnalysis;
using Microsoft.AspNetCore.Mvc;

namespace SS14.Watchdog.Utility
{
    public static class AuthorizationUtility
    {
        public static bool TryParseBasicAuthentication(string authorization,
            [NotNullWhen(false)] out IActionResult? failure,
            [NotNullWhen(true)] out string? username,
            [NotNullWhen(true)] out string? password)
        {
            username = null;
            password = null;

            if (!authorization.StartsWith("Basic "))
            {
                failure = new UnauthorizedResult();
                return false;
            }

            var decodedString = Base64Util.Utf8Base64ToString(authorization[6..]);
            var colonIndex = decodedString.IndexOf(':');

            if (colonIndex == -1)
            {
                failure = new BadRequestResult();
                return false;
            }

            username = decodedString[..colonIndex];
            password = decodedString[(colonIndex + 1)..];
            failure = null;
            return true;
        }

    }
}
