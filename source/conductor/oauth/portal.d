module conductor.oauth.portal;

import conductor.http : Response, send;
import conductor.loopback : LoopbackRequest, LoopbackServer;
import conductor.oauth.cache : TokenCache;
import conductor.oauth.token : OAuthError, TokenBundle;
import conductor.query : buildURL, formEncode;
import core.time : Duration, dur;
import std.base64 : Base64URLNoPadding;
import std.conv : to;
import std.digest.sha : sha256Of;
import std.json : JSONType, JSONValue, parseJSON;
import std.net.curl : HTTP;
import std.process : spawnProcess;
import std.random : unpredictableSeed;
import std.string : split;

public:

class OAuth
{
private:
    void delegate(string) onLaunch;
    string delegate(string) onFailure;
    string delegate(string) onMismatch;
    string delegate(string) onIncomplete;
    string delegate(string) onSuccess;
    Duration timeout;

public:
    TokenCache cache;
    string clientId;
    string clientSecret;
    string authorizeUrl;
    string tokenUrl;
    string revokeUrl;

    this(
        string clientId,
        string clientSecret,
        string authorizeUrl,
        string tokenUrl,
        string revokeUrl,
        void delegate(string) onLaunch = null,
        string delegate(string) onFailure = null,
        string delegate(string) onMismatch = null,
        string delegate(string) onIncomplete = null,
        string delegate(string) onSuccess = null,
        Duration timeout = dur!"minutes"(5),
        TokenCache cache = null,
    )
    {
        if (clientId == null)
            throw new OAuthError("OAuth credentials do not include a client ID.");

        if (clientSecret == null)
            throw new OAuthError("OAuth credentials do not include a client secret.");

        if (authorizeUrl == null)
            throw new OAuthError("OAuth credentials do not include an authorization URL.");

        if (tokenUrl == null)
            throw new OAuthError("OAuth credentials do not include a token URL.");

        this.clientId = clientId;
        this.clientSecret = clientSecret;
        this.authorizeUrl = authorizeUrl;
        this.tokenUrl = tokenUrl;
        this.revokeUrl = revokeUrl;
        this.timeout = timeout;
        this.cache = cache is null ? new TokenCache() : cache;
        this.onLaunch = onLaunch is null
            ? (string url) {
                version (Windows)
                    spawnProcess(["cmd", "/c", "start", null, url]);
                else version (OSX)
                    spawnProcess(["open", url]);
                else
                    spawnProcess(["xdg-open", url]);
            }
            : onLaunch;
        this.onFailure = onFailure is null
            ? (string detail) => "<html><body><h1>Login failed</h1><p>"~escapeHtml(detail)~"</p></body></html>"
            : onFailure;
        this.onMismatch = onMismatch is null
            ? (string detail) => "<html><body><h1>State mismatch</h1><p>"~escapeHtml(detail)~"</p></body></html>"
            : onMismatch;
        this.onIncomplete = onIncomplete is null
            ? (string detail) => "<html><body><h1>Missing code</h1><p>"~escapeHtml(detail)~"</p></body></html>"
            : onIncomplete;
        this.onSuccess = onSuccess is null
            ? (string detail) {
                string title = detail == null ? "OAuth" : detail;
                return "<html><body><h1>"~escapeHtml(title)~" login complete</h1></body></html>";
            }
            : onSuccess;
    }

    static OAuth fromJSON(
        JSONValue json,
        void delegate(string) onLaunch = null,
        string delegate(string) onFailure = null,
        string delegate(string) onMismatch = null,
        string delegate(string) onIncomplete = null,
        string delegate(string) onSuccess = null,
        Duration timeout = dur!"minutes"(5),
        TokenCache cache = null,
    )
    {
        if (json.type != JSONType.object)
            throw new OAuthError("OAuth JSON must be an object.");

        if ("web" in json)
            json = json["web"];
        else if ("installed" in json)
            json = json["installed"];

        if (json.type != JSONType.object)
            throw new OAuthError("OAuth JSON must be an object.");

        string revokeUrl = "revoke_uri" in json ? json["revoke_uri"].str : null;
        if (revokeUrl == null &&
            "token_uri" in json &&
            json["token_uri"].type == JSONType.string &&
            json["token_uri"].str == "https://oauth2.googleapis.com/token")
        {
            revokeUrl = "https://oauth2.googleapis.com/revoke";
        }

        return new OAuth(
            "client_id" in json ? json["client_id"].str : null,
            "client_secret" in json ? json["client_secret"].str : null,
            "auth_uri" in json ? json["auth_uri"].str : null,
            "token_uri" in json ? json["token_uri"].str : null,
            revokeUrl,
            onLaunch,
            onFailure,
            onMismatch,
            onIncomplete,
            onSuccess,
            timeout,
            cache,
        );
    }

    TokenBundle authorize(string applicationName, string requestedScope)
    {
        TokenBundle cached = cache.load(this);
        if (cacheSatisfiesScope(cached, requestedScope))
        {
            if (!cached.expired())
                return cached;

            if (cached.refreshToken != null)
            {
                try
                    return refresh(cached);
                catch (OAuthError)
                    cache.clear(this);
            }
        }

        string verifier = randomToken(32);
        string state = randomToken(32);
        string challenge = Base64URLNoPadding.encode(sha256Of(verifier)).idup;
        LoopbackServer loopback = new LoopbackServer();
        string redirectUri = "http://127.0.0.1:"~to!string(loopback.port());

        string[string] query;
        query["access_type"] = "offline";
        query["client_id"] = clientId;
        query["code_challenge"] = challenge;
        query["code_challenge_method"] = "S256";
        query["prompt"] = "consent";
        query["redirect_uri"] = redirectUri;
        query["response_type"] = "code";
        query["scope"] = requestedScope;
        query["state"] = state;

        onLaunch(buildURL(authorizeUrl, null, query));

        LoopbackRequest request = loopback.waitOnce(timeout);
        string code = request.query.get("code", null);
        string returnedState = request.query.get("state", null);
        string err = request.query.get("error", null);

        if (err != null)
        {
            loopback.respondHtml(onFailure(err), 400, "Bad Request");
            throw new OAuthError("OAuth authorization failed: "~err);
        }

        if (returnedState != state)
        {
            string detail = "Expected "~(state == null ? "<empty>" : state)~
                " but received "~(returnedState == null ? "<empty>" : returnedState)~".";
            loopback.respondHtml(onMismatch(detail), 400, "Bad Request");
            throw new OAuthError("OAuth authorization state did not match the original request.");
        }

        if (code == null)
        {
            string detail = "OAuth authorization did not return a code.";
            loopback.respondHtml(onIncomplete(detail), 400, "Bad Request");
            throw new OAuthError(detail);
        }

        loopback.respondHtml(onSuccess(applicationName));

        TokenBundle ret = requestToken(
            [
                "client_id": clientId,
                "code": code,
                "code_verifier": verifier,
                "grant_type": "authorization_code",
                "redirect_uri": redirectUri,
                "client_secret": clientSecret,
            ],
        );
        if (ret.grantedScope == null && requestedScope != null)
            ret.grantedScope = requestedScope;
        cache.save(this, ret);
        return ret;
    }

    TokenBundle refresh(TokenBundle token)
    {
        if (token.refreshToken == null)
            throw new OAuthError("OAuth refresh requires a refresh token.");

        TokenBundle ret = requestToken(
            [
                "client_id": clientId,
                "grant_type": "refresh_token",
                "refresh_token": token.refreshToken,
                "client_secret": clientSecret,
            ],
        );

        if (ret.refreshToken == null)
            ret.refreshToken = token.refreshToken;

        if (ret.grantedScope == null && token.grantedScope != null)
            ret.grantedScope = token.grantedScope;

        cache.save(this, ret);
        return ret;
    }

    void revoke(TokenBundle token)
    {
        string value = token.refreshToken != null ? token.refreshToken : token.accessToken;
        if (value == null)
            return;

        if (revokeUrl == null)
        {
            cache.clear(this);
            return;
        }

        HTTP http = HTTP();
        Response response = send(
            http,
            HTTP.Method.post,
            revokeUrl,
            cast(const(ubyte)[])formEncode(["token": value]),
            "application/x-www-form-urlencoded",
        );

        if (response.status >= 400)
        {
            string message = "OAuth request failed with status "~response.status.to!string~".";

            if (response.content != null)
            {
                JSONValue json = parseJSON(cast(string)response.content);
                if (json.type == JSONType.object)
                {
                    if ("error" in json)
                    {
                        JSONValue error = json["error"];
                        if (error.type == JSONType.string)
                            message = error.str;
                        else if (error.type == JSONType.object)
                        {
                            if ("message" in error)
                                message = error["message"].str;
                        }
                    }

                    if ("message" in json && json["message"].type == JSONType.string)
                        message = json["message"].str;
                }
                else
                    message = cast(string)response.content;
            }

            throw new OAuthError(message);
        }

        cache.clear(this);
    }

private:
    TokenBundle requestToken(string[string] fields)
    {
        HTTP http = HTTP();
        Response response = send(
            http,
            HTTP.Method.post,
            tokenUrl,
            cast(const(ubyte)[])formEncode(fields),
            "application/x-www-form-urlencoded",
        );

        if (response.status >= 400)
        {
            string message = "OAuth request failed with status "~response.status.to!string~".";

            if (response.content != null)
            {
                JSONValue json = parseJSON(cast(string)response.content);
                if (json.type == JSONType.object)
                {
                    if ("error" in json)
                    {
                        JSONValue error = json["error"];
                        if (error.type == JSONType.string)
                            message = error.str;
                        else if (error.type == JSONType.object)
                        {
                            if ("message" in error)
                            {
                                if (error["message"].type == JSONType.string)
                                    message = error["message"].str;
                            }
                        }
                    }

                    if ("message" in json && json["message"].type == JSONType.string)
                        message = json["message"].str;
                }
                else
                    message = cast(string)response.content;
            }

            throw new OAuthError(message);
        }

        JSONValue json = response.content == null ? JSONValue.init : parseJSON(cast(string)response.content);
        TokenBundle ret = TokenBundle.fromJson(this, json);

        if (ret.accessToken == null)
            throw new OAuthError("OAuth token response did not include an access token.");

        return ret;
    }
}

private:

bool cacheSatisfiesScope(TokenBundle token, string requestedScope)
{
    if (token.empty())
        return false;

    if (requestedScope == null)
        return true;

    if (token.grantedScope == null)
        return false;

    bool[string] granted;
    foreach (string scopeName; token.grantedScope.split(" "))
    {
        if (scopeName != null && scopeName != "")
            granted[scopeName] = true;
    }

    foreach (string scopeName; requestedScope.split(" "))
    {
        if (scopeName == null || scopeName == "")
            continue;

        if ((scopeName in granted) is null)
            return false;
    }

    return true;
}

string randomToken(size_t length)
{
    ubyte[] bytes = new ubyte[](length);

    foreach (size_t idx; 0..length)
        bytes[idx] = cast(ubyte)(unpredictableSeed!ulong & 0xFF);

    return Base64URLNoPadding.encode(bytes);
}

string escapeHtml(string value)
{
    string ret;

    foreach (dchar ch; value)
    {
        switch (ch)
        {
        case '&':
            ret ~= "&amp;";
            break;

        case '<':
            ret ~= "&lt;";
            break;

        case '>':
            ret ~= "&gt;";
            break;

        case '"':
            ret ~= "&quot;";
            break;

        case '\'':
            ret ~= "&#39;";
            break;

        default:
            ret ~= cast(string)[cast(char)ch];
            break;
        }
    }

    return ret;
}

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

    JSONValue wrapped = JSONValue.emptyObject;
    wrapped["installed"] = direct;

    OAuth wrappedOAuth = OAuth.fromJSON(wrapped);
    assert(wrappedOAuth.clientId == "client-id");
    assert(wrappedOAuth.clientSecret == "client-secret");
    assert(wrappedOAuth.authorizeUrl == "https://example.test/auth");
    assert(wrappedOAuth.tokenUrl == "https://example.test/token");
    assert(wrappedOAuth.revokeUrl == "https://example.test/revoke");

    JSONValue google = JSONValue.emptyObject;
    google["client_id"] = JSONValue("google-client-id");
    google["client_secret"] = JSONValue("google-client-secret");
    google["auth_uri"] = JSONValue("https://accounts.google.com/o/oauth2/auth");
    google["token_uri"] = JSONValue("https://oauth2.googleapis.com/token");

    OAuth googleOAuth = OAuth.fromJSON(google);
    assert(googleOAuth.revokeUrl == "https://oauth2.googleapis.com/revoke");
}
