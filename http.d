module composer.http;

import std.net.curl : HTTP;
import std.string : toLower;

public:

struct Response
{
    ushort status;
    string reason;
    string[string] headers;
    ubyte[] content;
}

Response send(
    ref HTTP http,
    HTTP.Method method,
    string url,
    const(ubyte)[] content = null,
    string contentType = null,
    string[string] headers = null,
)
{
    Response ret;

    http.clearRequestHeaders();
    http.url = url;
    http.method = method;

    foreach (string key, string value; headers)
        http.addRequestHeader(key, value);

    if (contentType != null)
        http.addRequestHeader("Content-Type", contentType);

    if (method == HTTP.Method.post || method == HTTP.Method.put || method == HTTP.Method.patch)
    {
        size_t offset;
        http.contentLength = content.length;
        http.onSend = delegate size_t(void[] buffer) {
            if (offset >= content.length)
                return 0;

            size_t count = content.length - offset;
            if (count > buffer.length)
                count = buffer.length;

            buffer[0..count] = cast(void[])content[offset..offset + count];
            offset += count;
            return count;
        };
    }
    else if (method == HTTP.Method.del)
    {
        http.onSend = (void[] buffer) {
            auto _ = buffer;
            return cast(size_t) 0;
        };
    }
    else
    {
        http.onSend = null;
    }

    http.onReceiveStatusLine = (HTTP.StatusLine line) {
        ret.status = line.code;
        ret.reason = line.reason.idup;
    };

    http.onReceiveHeader = (in char[] key, in char[] value) {
        ret.headers[toLower(key)] = value.idup;
    };

    http.onReceive = (ubyte[] chunk) {
        if (chunk != null)
            ret.content ~= chunk;

        return chunk.length;
    };

    http.perform();

    return ret;
}

void get(
    ref HTTP http,
    string url,
    void delegate(ubyte[]) success,
    void delegate(ubyte[]) failure,
)
{
    Response response = send(http, HTTP.Method.get, url);
    if (response.status >= 200 && response.status < 300)
    {
        if (success !is null)
            success(response.content);
    }
    else if (failure !is null)
        failure(response.content);
}

void post(
    ref HTTP http,
    string url,
    string postData,
    void delegate(ubyte[]) success,
    void delegate(ubyte[]) failure,
)
{
    Response response = send(
        http,
        HTTP.Method.post,
        url,
        cast(const(ubyte)[])postData,
        "application/x-www-form-urlencoded",
    );

    if (response.status >= 200 && response.status < 300)
    {
        if (success !is null)
            success(response.content);
    }
    else if (failure !is null)
        failure(response.content);
}
