module composer.loopback;

import composer.query : parseQuery;
import core.time : Duration;
import std.conv : to;
import std.exception : enforce;
import std.socket;
import std.string : indexOf, split, splitLines;
import std.uni : toLower;

public:

struct LoopbackRequest
{
    string method;
    string path;
    string[string] query;
    string[string] headers;
}

class LoopbackServer
{
private:
    Socket listener;
    Socket connection;
    ushort port_;

public:
    this(string host = "127.0.0.1", ushort port = 0)
    {
        listener = new Socket(AddressFamily.INET, SocketType.STREAM);
        listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        listener.bind(new InternetAddress(host, port));
        listener.listen(1);
        port_ = (cast(InternetAddress)listener.localAddress).port;
    }

    ~this()
    {
        if (connection !is null)
            connection.close();

        if (listener !is null)
            listener.close();
    }

    ushort port() const
        => port_;

    LoopbackRequest waitOnce(Duration timeout)
    {
        SocketSet set = new SocketSet();
        set.add(listener);
        if (Socket.select(set, null, null, timeout) <= 0)
            throw new SocketException("Timed out waiting for loopback callback.");

        connection = listener.accept();

        LoopbackRequest ret;
        ubyte[2048] buffer = void;
        string raw;
        while (raw.indexOf("\r\n\r\n") < 0)
        {
            ptrdiff_t received = connection.receive(buffer[]);
            if (received <= 0)
                break;

            raw ~= cast(string)buffer[0..received].idup;
        }

        ret = parse(raw);
        return ret;
    }

    void respondHtml(string html, ushort status = 200, string reason = "OK")
    {
        enforce(connection !is null, "No loopback client is connected.");

        ubyte[] content = cast(ubyte[])html.dup;
        string header =
            "HTTP/1.1 "~status.to!string~" "~reason~"\r\n" ~
            "Content-Type: text/html; charset=utf-8\r\n" ~
            "Content-Length: "~content.length.to!string~"\r\n" ~
            "Connection: close\r\n\r\n";

        connection.send(cast(const(ubyte)[])header);
        if (content != null)
            connection.send(content);

        connection.close();
        connection = null;
        listener.close();
        listener = null;
    }

private:
    LoopbackRequest parse(string raw)
    {
        LoopbackRequest ret;
        string[] lines = splitLines(raw);
        enforce(lines.length > 0, "Loopback request was empty.");

        string[] requestLine = lines[0].split(" ");
        enforce(requestLine.length >= 2, "Loopback request line was malformed.");

        ret.method = requestLine[0];

        string target = requestLine[1];
        ptrdiff_t questionMark = target.indexOf('?');
        if (questionMark < 0)
        {
            ret.path = target;
        }
        else
        {
            ret.path = target[0..questionMark];
            ret.query = parseQuery(target[questionMark + 1..$]);
        }

        foreach (string line; lines[1..$])
        {
            if (line == "")
                break;

            ptrdiff_t separator = line.indexOf(": ");
            if (separator <= 0)
                continue;

            ret.headers[toLower(line[0..separator])] = line[separator + 2..$];
        }

        return ret;
    }
}
