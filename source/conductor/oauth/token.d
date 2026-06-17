/// OAuth token types and bundle representation.
module conductor.oauth.token;

import conductor.oauth.exception : OAuthArgumentException;
import conductor.oauth.portal : OAuth;
import std.conv : to;
import std.datetime : Clock;
import std.json : JSONType, JSONValue;

/// Holds the tokens and metadata returned by an OAuth flow.
struct TokenBundle
{
    /// The OAuth configuration that issued this token.
    OAuth oauth;
    /// The access token for API requests.
    string accessToken;
    /// The refresh token for obtaining new access tokens.
    string refreshToken;
    /// The scope that was actually granted.
    string grantedScope;
    /// The token type (e.g. "Bearer").
    string tokenType;
    /// Seconds until the access token expires. Zero means unknown.
    long expiresIn;
    /// Unix timestamp when the token was obtained. Zero means unknown.
    long obtainedAt;

    /// True if both access and refresh tokens are null.
    bool empty() const
        => accessToken == null && refreshToken == null;

    /// True if the access token is missing or within 60 seconds of expiry.
    bool expired() const
    {
        if (accessToken == null)
            return true;

        if (expiresIn <= 0 || obtainedAt <= 0)
            return false;

        return Clock.currTime().toUnixTime() >= obtainedAt + expiresIn - 60;
    }

    /**
     * Serializes the bundle to JSON. Null fields are omitted.
     *
     * Writes `expires_in` and `obtained_at` so that cached tokens
     * remain valid across reloads.
     */
    JSONValue toJSON() const
    {
        JSONValue ret = JSONValue.emptyObject;

        if (accessToken != null)
            ret["access_token"] = JSONValue(accessToken);

        if (refreshToken != null)
            ret["refresh_token"] = JSONValue(refreshToken);

        if (grantedScope != null)
            ret["scope"] = JSONValue(grantedScope);

        if (tokenType != null)
            ret["token_type"] = JSONValue(tokenType);

        if (expiresIn > 0)
            ret["expires_in"] = JSONValue(expiresIn);

        if (obtainedAt > 0)
            ret["obtained_at"] = JSONValue(obtainedAt);

        return ret;
    }

    /**
     * Parses a token bundle from JSON.
     *
     * Params:
     *  oauth = The OAuth configuration.
     *  json = The JSON object to parse.
     *
     * Returns:
     *  The parsed token bundle.
     */
    static TokenBundle fromJson(OAuth oauth, JSONValue json)
    {
        TokenBundle ret;
        ret.oauth = oauth;

        if (json.type != JSONType.object)
            return ret;

        if ("access_token" in json && json["access_token"].type == JSONType.string)
            ret.accessToken = json["access_token"].str;

        if ("refresh_token" in json && json["refresh_token"].type == JSONType.string)
            ret.refreshToken = json["refresh_token"].str;

        if ("scope" in json && json["scope"].type == JSONType.string)
            ret.grantedScope = json["scope"].str;

        if ("token_type" in json && json["token_type"].type == JSONType.string)
            ret.tokenType = json["token_type"].str;

        if ("obtained_at" in json && json["obtained_at"].type == JSONType.integer)
            ret.obtainedAt = json["obtained_at"].integer;

        if ("expires_in" in json && json["expires_in"].type == JSONType.integer)
            ret.expiresIn = json["expires_in"].integer;

        if (ret.expiresIn > 0 && ret.obtainedAt <= 0)
            ret.obtainedAt = Clock.currTime().toUnixTime();

        return ret;
    }
}

