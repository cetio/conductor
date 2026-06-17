/// Rate-limited request dispatch with reusable HTTP client state.
module conductor.orchestrate;

import conductor.http : Response, sendRequest = send;
import conductor.query : composeURL = buildURL;
import core.thread : Thread;
import core.time : dur;
import std.datetime : Clock, Duration, SysTime;
import std.net.curl : HTTP;

/// Combines host configuration, URL building, and rate limiting for API clients.
struct Orchestrator
{
    /// Base host URL (e.g. "https://api.example.com").
    string host;
    /// Minimum milliseconds between requests. Zero disables rate limiting.
    long minIntervalMs;

private:
    HTTP _http;
    bool _initialized;
    SysTime lastRequestTime;

public:
    /// Lazily initializes and returns a reusable HTTP client.
    ref HTTP client()
    {
        if (!_initialized)
        {
            _http = HTTP();
            _initialized = true;
        }
        return _http;
    }

    /// Sleeps if the minimum interval between requests has not elapsed.
    void rateLimit()
    {
        if (minIntervalMs <= 0)
        {
            lastRequestTime = Clock.currTime();
            return;
        }

        if (lastRequestTime == SysTime.init)
        {
            lastRequestTime = Clock.currTime();
            return;
        }

        Duration minInterval = dur!"msecs"(minIntervalMs);
        Duration elapsed = Clock.currTime() - lastRequestTime;
        if (elapsed < minInterval)
            Thread.sleep(minInterval - elapsed);

        lastRequestTime = Clock.currTime();
    }

    /// Builds a full URL from host, path, and optional query parameters.
    string buildURL(string path, string[string] queryParams = null)
    {
        return composeURL(host, path, queryParams);
    }

    /**
     * Sends a rate-limited HTTP request.
     *
     * Each call creates a fresh HTTP instance; rate limiting is applied
     * globally across the Orchestrator.
     *
     * Params:
     *  method = The HTTP method.
     *  path = The request path appended to host.
     *  query = Optional query parameters.
     *  content = Raw request body.
     *  contentType = The Content-Type header value.
     *  headers = Additional request headers.
     *
     * Returns:
     *  The HTTP response.
     */
    Response send(
        HTTP.Method method,
        string path,
        string[string] query = null,
        const(ubyte)[] content = null,
        string contentType = null,
        string[string] headers = null,
    )
    {
        HTTP http = HTTP();

        rateLimit();
        return sendRequest(
            http,
            method,
            buildURL(path, query),
            content,
            contentType,
            headers,
        );
    }
}
