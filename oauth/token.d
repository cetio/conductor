module composer.oauth.token;

import composer.oauth.portal : OAuth;
import std.conv : to;
import std.datetime : Clock;
import std.json : JSONType, JSONValue;

public:

class OAuthError : Exception
{
    this(string message)
    {
        super(message);
    }
}

struct TokenBundle
{
    OAuth oauth;
    string accessToken;
    string refreshToken;
    string grantedScope;
    string tokenType;
    long expiry;

    bool empty() const
        => accessToken == null && refreshToken == null;

    bool expired() const
    {
        if (accessToken == null)
            return true;

        if (expiry <= 0)
            return false;

        return Clock.currTime().toUnixTime() >= expiry - 60;
    }

    JSONValue toJson() const
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

        if (expiry > 0)
            ret["expiry"] = JSONValue(expiry);

        return ret;
    }

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

        if ("expiry" in json)
        {
            JSONValue expiry = json["expiry"];
            switch (expiry.type)
            {
            case JSONType.integer:
                ret.expiry = expiry.integer;
                break;

            case JSONType.uinteger:
                ret.expiry = cast(long)expiry.uinteger;
                break;

            case JSONType.string:
                if (expiry.str != null)
                    ret.expiry = expiry.str.to!long;
                break;

            default:
                break;
            }
        }
        else if ("expires_in" in json)
        {
            JSONValue expiresIn = json["expires_in"];
            long seconds;

            switch (expiresIn.type)
            {
            case JSONType.integer:
                seconds = expiresIn.integer;
                break;

            case JSONType.uinteger:
                seconds = cast(long)expiresIn.uinteger;
                break;

            case JSONType.string:
                if (expiresIn.str != null)
                    seconds = expiresIn.str.to!long;
                break;

            default:
                break;
            }

            if (seconds > 0)
                ret.expiry = Clock.currTime().toUnixTime() + seconds;
        }

        return ret;
    }
}

unittest
{
    OAuth oauth = new OAuth(
        "client-id",
        "client-secret",
        "https://example.test/auth",
        "https://example.test/token",
        "https://example.test/revoke",
        (string url) {
            auto _ = url;
        },
    );

    JSONValue json = JSONValue.emptyObject;
    json["access_token"] = JSONValue("access");
    json["refresh_token"] = JSONValue("refresh");
    json["scope"] = JSONValue("scope-a scope-b");
    json["token_type"] = JSONValue("Bearer");
    json["expiry"] = JSONValue(1234L);

    TokenBundle token = TokenBundle.fromJson(oauth, json);
    assert(token.oauth is oauth);
    assert(token.accessToken == "access");
    assert(token.refreshToken == "refresh");
    assert(token.grantedScope == "scope-a scope-b");
    assert(token.tokenType == "Bearer");
    assert(token.expiry == 1234);
    assert(token.toJson()["access_token"].str == "access");
    assert(token.toJson()["refresh_token"].str == "refresh");

    JSONValue tokenResponse = JSONValue.emptyObject;
    tokenResponse["access_token"] = JSONValue("response-access");
    tokenResponse["token_type"] = JSONValue("Bearer");
    tokenResponse["expires_in"] = JSONValue(3600L);

    TokenBundle responseToken = TokenBundle.fromJson(oauth, tokenResponse);
    assert(responseToken.accessToken == "response-access");
    assert(responseToken.tokenType == "Bearer");
    assert(responseToken.expiry > Clock.currTime().toUnixTime());
}
