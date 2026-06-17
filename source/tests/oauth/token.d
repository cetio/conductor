module tests.oauth.token;

import conductor.oauth.portal;
import conductor.oauth.token;
import std.json : JSONValue;

unittest
{
    OAuth oauth = new OAuth(
        "client-id",
        "client-secret",
        "https://example.test/auth",
        "https://example.test/token",
        "https://example.test/revoke",
        (string url) { auto _ = url; },
    );

    JSONValue json = JSONValue.emptyObject;
    json["access_token"] = JSONValue("access");
    json["refresh_token"] = JSONValue("refresh");
    json["scope"] = JSONValue("scope-a scope-b");
    json["token_type"] = JSONValue("Bearer");
    json["expires_in"] = JSONValue(3600L);

    TokenBundle token = TokenBundle.fromJson(oauth, json);
    assert(token.oauth == oauth);
    assert(token.accessToken == "access");
    assert(token.refreshToken == "refresh");
    assert(token.grantedScope == "scope-a scope-b");
    assert(token.tokenType == "Bearer");
    assert(token.expiresIn == 3600);
    assert(token.obtainedAt > 0);
    assert(!token.expired());
    assert(token.toJSON()["access_token"].str == "access");
    assert(token.toJSON()["refresh_token"].str == "refresh");

    JSONValue cached = token.toJSON();
    TokenBundle restored = TokenBundle.fromJson(oauth, cached);
    assert(restored.expiresIn == 3600);
    assert(restored.obtainedAt == token.obtainedAt);
    assert(!restored.expired());

    JSONValue tokenResponse = JSONValue.emptyObject;
    tokenResponse["access_token"] = JSONValue("response-access");
    tokenResponse["token_type"] = JSONValue("Bearer");
    tokenResponse["expires_in"] = JSONValue(3600L);

    TokenBundle responseToken = TokenBundle.fromJson(oauth, tokenResponse);
    assert(responseToken.accessToken == "response-access");
    assert(responseToken.tokenType == "Bearer");
    assert(responseToken.expiresIn == 3600);
    assert(responseToken.obtainedAt > 0);
}
