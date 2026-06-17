module tests.oauth.token;

import conductor.oauth.portal;
import conductor.oauth.token;
import unit_threaded;
import std.json : JSONValue;

@Name("TokenBundle roundtrips JSON and expiry")
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
    token.oauth.should == oauth;
    token.accessToken.should == "access";
    token.refreshToken.should == "refresh";
    token.grantedScope.should == "scope-a scope-b";
    token.tokenType.should == "Bearer";
    token.expiresIn.should == 3600;
    (token.obtainedAt > 0).should == true;
    token.expired().should == false;
    token.toJSON()["access_token"].str.should == "access";
    token.toJSON()["refresh_token"].str.should == "refresh";

    JSONValue cached = token.toJSON();
    TokenBundle restored = TokenBundle.fromJson(oauth, cached);
    restored.expiresIn.should == 3600;
    restored.obtainedAt.should == token.obtainedAt;
    restored.expired().should == false;

    JSONValue tokenResponse = JSONValue.emptyObject;
    tokenResponse["access_token"] = JSONValue("response-access");
    tokenResponse["token_type"] = JSONValue("Bearer");
    tokenResponse["expires_in"] = JSONValue(3600L);

    TokenBundle responseToken = TokenBundle.fromJson(oauth, tokenResponse);
    responseToken.accessToken.should == "response-access";
    responseToken.tokenType.should == "Bearer";
    responseToken.expiresIn.should == 3600;
    (responseToken.obtainedAt > 0).should == true;
}
