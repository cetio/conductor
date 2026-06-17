/// Query string encoding, decoding, form encoding, and URL building.
module conductor.query;

import std.array : join;
import std.string : indexOf, replace, split;
import std.uri : encode;

/**
 * Encodes a query component, ensuring '+' is percent-encoded.
 *
 * The standard `encode` leaves '+' unencoded, which causes ambiguity
 * in form data where '+' represents a space.
 *
 * Params:
 *  value = The raw query component.
 *
 * Returns:
 *  The percent-encoded component.
 */
string encodeQueryComponent(string value)
{
    return encode(value).replace("+", "%2B");
}

/**
 * Decodes a query component, converting '+' to space.
 *
 * Params:
 *  value = The encoded query component.
 *
 * Returns:
 *  The decoded component.
 */
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

/**
 * Encodes an associative array as an application/x-www-form-urlencoded string.
 *
 * Params:
 *  fields = The key-value pairs to encode.
 *
 * Returns:
 *  The encoded form string.
 */
string formEncode(string[string] fields)
{
    string[] pairs;

    foreach (string key, string value; fields)
        pairs ~= encodeQueryComponent(key)~"="~encodeQueryComponent(value);

    return pairs.join("&");
}

/**
 * Builds a full URL from a base URL, path, and optional query parameters.
 *
 * Params:
 *  baseUrl = The base URL (e.g. "https://api.example.com").
 *  path = The request path.
 *  query = Optional query parameters.
 *
 * Returns:
 *  The complete URL with encoded query string.
 */
string buildURL(string baseUrl, string path, string[string] query = null)
{
    string ret = baseUrl~path;
    string encoded = formEncode(query);
    if (encoded != null)
        ret ~= "?"~encoded;

    return ret;
}

/**
 * Parses a raw query string into key-value pairs.
 *
 * Handles missing values and empty pairs gracefully.
 *
 * Params:
 *  raw = The raw query string (e.g. "a=1&b=2").
 *
 * Returns:
 *  An associative array of decoded keys and values.
 */
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

