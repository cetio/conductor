module conductor.oauth.exception;

import std.exception : basicExceptionCtors;


/// Exception thrown when the OAuth provider has any spurious exceptions.
/// Base exception for all OAuth server exceptions.
class OAuthServerException : Exception
{
    mixin basicExceptionCtors;
}

/// Exception thrown when the OAuth provider has returned an authorization error.
class OAuthAuthorizationException : OAuthServerException
{
    mixin basicExceptionCtors;
}

/// Exception thrown when an OAuth client has any spurious exceptions.
/// Base exception for all OAuth client exceptions.
class OAuthClientException : Exception
{
    mixin basicExceptionCtors;
}

/// Exception thrown when an invalid argument is passed to an OAuth (or request).
class OAuthArgumentException : OAuthClientException
{
    mixin basicExceptionCtors;
}
/// Exception thrown when a value is in the incorrect format (or missing required fields).
class OAuthFormatException : OAuthClientException
{
    mixin basicExceptionCtors;
}