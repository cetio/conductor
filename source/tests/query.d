module tests.query;

import conductor.query;
import std.string : indexOf;

unittest
{
    string query = formEncode([
        "a": "b c",
        "plus": "1+1",
    ]);
    assert(query.indexOf("a=b%20c") >= 0);
    assert(query.indexOf("plus=1%2B1") >= 0);
}

unittest
{
    string[string] parsed = parseQuery("a=b%20c&plus=1%2B1");
    assert(parsed["a"] == "b c");
    assert(parsed["plus"] == "1+1");
}
