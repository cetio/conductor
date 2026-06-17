module tests.oauth.portal;

import conductor.oauth.portal;
import unit_threaded;
import std.json : JSONValue;

@Name("OAuth.fromJSON parses direct object")
unittest
{
    JSONValue direct = JSONValue.emptyObject;
    direct["client_id"] = JSONValue("client-id");
    direct["client_secret"] = JSONValue("client-secret");
    direct["auth_uri"] = JSONValue("https://example.test/auth");
    direct["token_uri"] = JSONValue("https://example.test/token");
    direct["revoke_uri"] = JSONValue("https://example.test/revoke");

    OAuth directOAuth = OAuth.fromJSON(direct);
    directOAuth.clientId.should == "client-id";
    directOAuth.clientSecret.should == "client-secret";
    directOAuth.authorizeUrl.should == "https://example.test/auth";
    directOAuth.tokenUrl.should == "https://example.test/token";
    directOAuth.revokeUrl.should == "https://example.test/revoke";
}

@Name("OAuth.fromJSON parses wrapped object")
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
    wrappedOAuth.clientId.should == "client-id";
    wrappedOAuth.clientSecret.should == "client-secret";
    wrappedOAuth.authorizeUrl.should == "https://example.test/auth";
    wrappedOAuth.tokenUrl.should == "https://example.test/token";
    wrappedOAuth.revokeUrl.should == "https://example.test/revoke";
}

@Name("OAuth.fromJSON infers Google revoke URL")
unittest
{
    JSONValue google = JSONValue.emptyObject;
    google["client_id"] = JSONValue("google-client-id");
    google["client_secret"] = JSONValue("google-client-secret");
    google["auth_uri"] = JSONValue("https://accounts.google.com/o/oauth2/auth");
    google["token_uri"] = JSONValue("https://oauth2.googleapis.com/token");

    OAuth googleOAuth = OAuth.fromJSON(google);
    googleOAuth.revokeUrl.should == "https://oauth2.googleapis.com/revoke";
}
