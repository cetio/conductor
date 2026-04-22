module conductor.query;

import std.array : join;
import std.string : indexOf, replace, split;
import std.uri : encode;

public:

string encodeQueryComponent(string value)
{
    return encode(value).replace("+", "%2B");
}

string decodeQueryComponent(string value)
{
    char[] ret;
    size_t idx;
    while (idx < value.length)
    {
        char ch = value[idx];
        if (ch == '+')
        {
            ret ~= ' ';
            idx++;
            continue;
        }

        if (ch == '%' && idx + 2 < value.length)
        {
            int hi = hexValue(value[idx + 1]);
            int lo = hexValue(value[idx + 2]);
            if (hi >= 0 && lo >= 0)
            {
                ret ~= cast(char)((hi << 4) | lo);
                idx += 2;
                idx++;
                continue;
            }
        }

        ret ~= ch;
        idx++;
    }

    return ret.idup;
}

string formEncode(string[string] fields)
{
    string[] pairs;

    foreach (string key, string value; fields)
        pairs ~= encodeQueryComponent(key)~"="~encodeQueryComponent(value);

    return pairs.join("&");
}

string buildURL(string baseUrl, string path, string[string] query = null)
{
    string ret = baseUrl~path;
    string encoded = formEncode(query);
    if (encoded != null)
        ret ~= "?"~encoded;

    return ret;
}

string[string] parseQuery(string raw)
{
    string[string] ret;
    if (raw == null)
        return ret;

    foreach (string pair; raw.split("&"))
    {
        if (pair == null)
            continue;

        ptrdiff_t separator = pair.indexOf('=');
        if (separator < 0)
        {
            ret[decodeQueryComponent(pair)] = null;
        }
        else
        {
            ret[decodeQueryComponent(pair[0..separator])] = decodeQueryComponent(pair[separator + 1..$]);
        }
    }

    return ret;
}

private:

int hexValue(char ch)
{
    if (ch >= '0' && ch <= '9')
        return ch - '0';

    if (ch >= 'A' && ch <= 'F')
        return ch - 'A' + 10;

    if (ch >= 'a' && ch <= 'f')
        return ch - 'a' + 10;

    return -1;
}

unittest
{
    string query = formEncode([
        "a": "b c",
        "plus": "1+1",
    ]);
    assert(query.indexOf("a=b%20c") >= 0);
    assert(query.indexOf("plus=1%2B1") >= 0);

    string[string] parsed = parseQuery("a=b%20c&plus=1%2B1");
    assert(parsed["a"] == "b c");
    assert(parsed["plus"] == "1+1");
}
