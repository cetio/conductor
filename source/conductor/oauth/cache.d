module conductor.oauth.cache;

import conductor.oauth.portal : OAuth;
import conductor.oauth.token : TokenBundle;
import std.base64 : Base64URLNoPadding;
import std.digest.sha : sha256Of;
import std.file : exists, mkdirRecurse, readText, remove, write;
import std.json : parseJSON;
import std.path : buildPath, expandTilde;

public:

class TokenCache
{
public:
    string directory;

    this(string directory = null)
    {
        if (directory != null)
            this.directory = expandTilde(directory);
        else
            this.directory = defaultCacheDirectory();
    }

    TokenBundle load(OAuth oauth)
    {
        if (oauth is null)
            return TokenBundle.init;

        string path = cachePath(oauth);
        if (!exists(path))
            return TokenBundle.init;

        try
            return TokenBundle.fromJson(oauth, parseJSON(readText(path)));
        catch (Exception)
        {
            clear(oauth);
            return TokenBundle.init;
        }
    }

    void save(OAuth oauth, TokenBundle token)
    {
        if (oauth is null || token.empty())
        {
            clear(oauth);
            return;
        }

        mkdirRecurse(directory);
        write(cachePath(oauth), token.toJson().toString());
    }

    void clear(OAuth oauth)
    {
        if (oauth is null)
            return;

        string path = cachePath(oauth);
        if (exists(path))
            remove(path);
    }

private:
    string cachePath(OAuth oauth) const
        => buildPath(directory, cacheId(oauth)~".json");

    string cacheId(OAuth oauth) const
    {
        string key =
            oauth.clientId~"\n"~
            oauth.authorizeUrl~"\n"~
            oauth.tokenUrl~"\n"~
            oauth.revokeUrl;

        return Base64URLNoPadding.encode(sha256Of(key)).idup;
    }
}

private:

string defaultCacheDirectory()
{
    return buildPath(expandTilde("~/.cache"), "conductor", "oauth");
}

unittest
{
    import core.time : dur;
    import std.conv : to;
    import std.file : exists, rmdirRecurse;
    import std.path : buildPath;
    import std.process : thisProcessID;

    string directory = buildPath(
        defaultCacheDirectory(),
        "token-cache-test-"~thisProcessID.to!string,
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
        (string url) {
            auto _ = url;
        },
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
    token.expiry = 9999;

    cache.save(oauth, token);

    TokenBundle loaded = cache.load(oauth);
    assert(loaded.oauth is oauth);
    assert(loaded.accessToken == "access");
    assert(loaded.refreshToken == "refresh");

    cache.clear(oauth);
    assert(cache.load(oauth).empty());
}
