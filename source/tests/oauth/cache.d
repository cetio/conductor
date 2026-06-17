module tests.oauth.cache;

import conductor.oauth.cache;
import conductor.oauth.portal;
import conductor.oauth.token : TokenBundle;
import unit_threaded;
import core.time : dur;
import std.conv : to;
import std.datetime : Clock;
import std.file : exists, rmdirRecurse;
import std.path : buildPath;
import std.process : thisProcessID;
import std.file : tempDir;

@Name("TokenCache roundtrips save, load, and clear")
unittest
{
    string directory = buildPath(
        tempDir(),
        "conductor-oauth-test-" ~ thisProcessID.to!string,
    );

    if (exists(directory))
        rmdirRecurse(directory);

    scope (exit)
    {
        if (exists(directory))
            rmdirRecurse(directory);
    }

    TokenCache cache = new TokenCache(directory);
    OAuth oauth = new OAuth(
        "client-id",
        "client-secret",
        "https://example.test/auth",
        "https://example.test/token",
        "https://example.test/revoke",
        (string url) { auto _ = url; },
        null,
        null,
        null,
        null,
        dur!"minutes"(5),
        cache,
    );

    TokenBundle token;
    token.oauth = oauth;
    token.accessToken = "access";
    token.refreshToken = "refresh";
    token.grantedScope = "scope";
    token.tokenType = "Bearer";
    token.expiresIn = 3600;
    token.obtainedAt = Clock.currTime().toUnixTime();

    cache.save(oauth, token);

    TokenBundle loaded = cache.load(oauth);
    loaded.oauth.should == oauth;
    loaded.accessToken.should == "access";
    loaded.refreshToken.should == "refresh";

    cache.clear(oauth);
    cache.load(oauth).empty().should == true;
}
