/// Persistent on-disk cache for OAuth token bundles.
module conductor.oauth.cache;

import conductor.oauth.portal : OAuth;
import conductor.oauth.token : TokenBundle;
import std.base64 : Base64URLNoPadding;
import std.datetime : Clock;
import std.digest.sha : sha256Of;
import std.file : exists, mkdirRecurse, readText, remove, write;
import std.json : parseJSON;
import std.path : buildPath, expandTilde;

/// Stores and retrieves OAuth tokens in JSON files keyed by credential hash.
class TokenCache
{
    /// Directory where token files are stored. Defaults to ~/.cache/conductor/oauth.
    string directory;

    /**
     * Constructs a TokenCache.
     *
     * Params:
     *  directory = The cache directory. Null uses the default.
     */
    this(string directory = null)
    {
        if (directory != null)
            this.directory = expandTilde(directory);
        else
            this.directory = defaultCacheDirectory();
    }

    /**
     * Loads a cached token for the given OAuth configuration.
     *
     * Returns an empty bundle if no cache entry exists or if the file
     * is corrupt (in which case it is deleted).
     *
     * Params:
     *  oauth = The OAuth configuration.
     *
     * Returns:
     *  The cached token bundle, or an empty one.
     */
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

    /**
     * Saves a token bundle to disk.
     *
     * Deletes the cache entry if the token is empty.
     *
     * Params:
     *  oauth = The OAuth configuration.
     *  token = The token bundle to cache.
     */
    void save(OAuth oauth, TokenBundle token)
    {
        if (oauth is null || token.empty())
        {
            clear(oauth);
            return;
        }

        mkdirRecurse(directory);
        write(cachePath(oauth), token.toJSON().toString());
    }

    /**
     * Deletes a cached token for the given OAuth configuration.
     *
     * Params:
     *  oauth = The OAuth configuration.
     */
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

