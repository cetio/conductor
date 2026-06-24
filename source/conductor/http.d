/// HTTP request/response helpers and thin wrappers over std.net.curl.
module conductor.http;

public import std.json : JSONValue, JSONOptions, JSONType, JSONException;
// I don't like this import being here but it will probably break things without.
public import conductor.serialize.json : toJSON;

static import std.json;
import std.net.curl : HTTP;
import std.string : toLower;

/// Response data from an HTTP request.
struct Response
{
    /// HTTP status code.
    ushort status;
    /// HTTP reason phrase.
    string reason;
    /// Response headers keyed by lower-cased name.
    string[string] headers;
    /// Raw response body content.
    ubyte[] content;
}

/**
 * Sends an HTTP request with serialized JSON data.
 *
 * Params:
 *  http = The curl HTTP instance.
 *  method = The HTTP method.
 *  url = The request URL.
 *  data = The payload to serialize to JSON.
 *  contentType = The Content-Type header value.
 *
 * Returns:
 *  The HTTP response.
 */
Response send(T)(
    ref HTTP http,
    HTTP.Method method,
    string url,
    T data,
    string contentType = "application/json"
)
    if (!is(T : const(ubyte)[]))
    => send(http, method, url, cast(const(ubyte)[])data.toJSON().toString(), contentType);

/**
 * Sends a POST request with serialized JSON data and delegates for success/failure.
 *
 * Params:
 *  http = The curl HTTP instance.
 *  url = The request URL.
 *  data = The payload to serialize to JSON.
 *  success = Delegate called on a 2xx response.
 *  failure = Delegate called on a non-2xx response.
 */
void post(T)(
    ref HTTP http,
    string url,
    T data,
    void delegate(ubyte[]) success,
    void delegate(ubyte[]) failure,
)
    if (!is(T == string))
    => post(http, url, data.toJSON().toString(), success, failure, "application/json");


/**
 * Sends an HTTP request with raw byte content.
 *
 * Handles GET, POST, PUT, PATCH, and DELETE with appropriate onSend behavior.
 * Response headers are lower-cased for consistent lookup.
 *
 * Params:
 *  http = The curl HTTP instance.
 *  method = The HTTP method.
 *  url = The request URL.
 *  content = Raw request body. May be null for GET/DELETE.
 *  contentType = The Content-Type header value.
 *  headers = Additional request headers. Overwrites http headers if set.
 *
 * Returns:
 *  The HTTP response.
 */
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

    if (headers != null)
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
            return cast(size_t)0;
        };
    }
    else
        http.onSend = null;

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

/**
 * Sends a GET request and dispatches to success or failure delegates.
 *
 * Params:
 *  http = The curl HTTP instance.
 *  url = The request URL.
 *  success = Delegate called on a 2xx response.
 *  failure = Delegate called on a non-2xx response.
 */
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

/**
 * Sends a POST request with raw string data and delegates for success/failure.
 *
 * Params:
 *  http = The curl HTTP instance.
 *  url = The request URL.
 *  postData = The raw request body.
 *  success = Delegate called on a 2xx response.
 *  failure = Delegate called on a non-2xx response.
 *  contentType = The Content-Type header value.
 */
void post(
    ref HTTP http,
    string url,
    string postData,
    void delegate(ubyte[]) success,
    void delegate(ubyte[]) failure,
    string contentType = "application/x-www-form-urlencoded",
)
{
    Response response = send(
        http,
        HTTP.Method.post,
        url,
        cast(const(ubyte)[])postData,
        contentType,
    );

    if (response.status >= 200 && response.status < 300)
    {
        if (success !is null)
            success(response.content);
    }
    else if (failure !is null)
        failure(response.content);
}