module conductor.orchestrate;

import conductor.http : Response, sendRequest = send;
import conductor.query : composeURL = buildURL;
import core.thread : Thread;
import core.time : dur;
import std.datetime : Clock, Duration, SysTime;
import std.net.curl : HTTP;

public:

struct Orchestrator
{
    string host;
    long minIntervalMs;

private:
    HTTP _http;
    bool _httpInit;
    SysTime lastRequestTime;

public:
    ref HTTP client()
    {
        if (!_httpInit)
        {
            _http = HTTP();
            _httpInit = true;
        }
        return _http;
    }

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

    string buildURL(string path, string[string] queryParams = null)
    {
        return composeURL(host, path, queryParams);
    }

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
