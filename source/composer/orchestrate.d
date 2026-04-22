module composer.orchestrate;

import composer.http : Response, sendRequest = send;
import composer.query : composeURL = buildURL;
import core.thread : Thread;
import core.time : dur;
import std.datetime : Clock, Duration, SysTime;
import std.net.curl : HTTP;

public:

struct Orchestrator
{
private:
    SysTime lastRequestTime;

public:
    HTTP client;
    string host;
    long minIntervalMs;

    this(string host, long minIntervalMs = 0)
    {
        this.client = HTTP();
        this.host = host;
        this.minIntervalMs = minIntervalMs;
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
