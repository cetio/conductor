module tests.oauth.portal;

import conductor.oauth.portal;
import std.json : JSONValue;

unittest
{
    JSONValue direct = JSONValue.emptyObject;
    direct["client_id"] = JSONValue("client-id");
    direct["client_secret"] = JSONValue("client-secret");
    direct["auth_uri"] = JSONValue("https://example.test/auth");
    direct["token_uri"] = JSONValue("https://example.test/token");
    direct["revoke_uri"] = JSONValue("https://example.test/revoke");

    OAuth directOAuth = OAuth.fromJSON(direct);
    assert(directOAuth.clientId == "client-id");
    assert(directOAuth.clientSecret == "client-secret");
    assert(directOAuth.authorizeUrl == "https://example.test/auth");
    assert(directOAuth.tokenUrl == "https://example.test/token");
    assert(directOAuth.revokeUrl == "https://example.test/revoke");
}

unittest
{
    JSONValue inner = JSONValue.emptyObject;
    inner["client_id"] = JSONValue("client-id");
    inner["client_secret"] = JSONValue("client-secret");
    inner["auth_uri"] = JSONValue("https://example.test/auth");
    inner["token_uri"] = JSONValue("https://example.test/token");
    inner["revoke_uri"] = JSONValue("https://example.test/revoke");

    JSONValue wrapped = JSONValue.emptyObject;
    wrapped["installed"] = inner;

    OAuth wrappedOAuth = OAuth.fromJSON(wrapped);
    assert(wrappedOAuth.clientId == "client-id");
    assert(wrappedOAuth.clientSecret == "client-secret");
    assert(wrappedOAuth.authorizeUrl == "https://example.test/auth");
    assert(wrappedOAuth.tokenUrl == "https://example.test/token");
    assert(wrappedOAuth.revokeUrl == "https://example.test/revoke");
}

unittest
{
    JSONValue google = JSONValue.emptyObject;
    google["client_id"] = JSONValue("google-client-id");
    google["client_secret"] = JSONValue("google-client-secret");
    google["auth_uri"] = JSONValue("https://accounts.google.com/o/oauth2/auth");
    google["token_uri"] = JSONValue("https://oauth2.googleapis.com/token");

    OAuth googleOAuth = OAuth.fromJSON(google);
    assert(googleOAuth.revokeUrl == "https://oauth2.googleapis.com/revoke");
}
