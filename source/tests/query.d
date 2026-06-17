module tests.query;

import conductor.query;
import unit_threaded;
import std.string : indexOf;

@Name("formEncode percent-encodes spaces and plus signs")
unittest
{
    string query = formEncode([
        "a": "b c",
        "plus": "1+1",
    ]);
    (query.indexOf("a=b%20c") >= 0).should == true;
    (query.indexOf("plus=1%2B1") >= 0).should == true;
}

@Name("parseQuery recovers original values from encoded string")
unittest
{
    string[string] parsed = parseQuery("a=b%20c&plus=1%2B1");
    parsed["a"].should == "b c";
    parsed["plus"].should == "1+1";
}
