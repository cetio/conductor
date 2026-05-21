module tests.serialize.json;

import conductor.serialize.json;
import std.json : JSONValue, JSONType;
import std.typecons : Nullable;

unittest
{
    assert(toJSON(42) == JSONValue(42));
    assert(fromJSON!int(JSONValue(42)) == 42);

    assert(toJSON(123456789L) == JSONValue(123456789L));
    assert(fromJSON!long(JSONValue(123456789L)) == 123456789L);

    assert(toJSON(3.14f) == JSONValue(3.14f));
    double recoveredFloat = fromJSON!double(JSONValue(3.14f));
    assert(recoveredFloat > 3.13 && recoveredFloat < 3.15);

    assert(toJSON(true) == JSONValue(true));
    assert(fromJSON!bool(JSONValue(true)) == true);

    assert(toJSON(false) == JSONValue(false));
    assert(fromJSON!bool(JSONValue(false)) == false);
}

unittest
{
    assert(toJSON("hello") == JSONValue("hello"));
    assert(fromJSON!string(JSONValue("hello")) == "hello");

    string nullString;
    assert(toJSON(nullString) == JSONValue(null));
    assert(fromJSON!string(JSONValue(null)) is null);
}

unittest
{
    enum Color
    {
        Red,
        Green,
        Blue,
    }

    assert(toJSON(Color.Green) == JSONValue(1));
    assert(fromJSON!Color(JSONValue(1)) == Color.Green);
    assert(fromJSON!Color(JSONValue(0)) == Color.Red);
}

unittest
{
    enum Browser : string
    {
        Chrome = "chrome",
        Firefox = "firefox",
    }

    assert(toJSON(Browser.Chrome) == JSONValue("chrome"));
    assert(fromJSON!Browser(JSONValue("chrome")) == Browser.Chrome);
    assert(fromJSON!Browser(JSONValue("firefox")) == Browser.Firefox);
}

unittest
{
    enum Status : string
    {
        Active = "active",
    }

    bool threw = false;
    try
        fromJSON!Status(JSONValue("unknown"));
    catch (Exception)
        threw = true;
    assert(threw);
}

unittest
{
    struct Point
    {
        int x;
        int y;
    }

    Point original = Point(3, 4);
    JSONValue json = toJSON(original);
    assert(json["x"].integer == 3);
    assert(json["y"].integer == 4);
    assert(fromJSON!Point(json) == original);
}

unittest
{
    struct Inner
    {
        int value;
    }
    struct Outer
    {
        Inner inner;
        int count;
    }

    Outer original = Outer(Inner(7), 99);
    JSONValue json = toJSON(original);
    assert(json["inner"]["value"].integer == 7);
    assert(json["count"].integer == 99);
    assert(fromJSON!Outer(json) == original);
}

unittest
{
    struct Named
    {
        @Name("custom_name") int value;
    }

    Named original = Named(5);
    JSONValue json = toJSON(original);
    assert("custom_name" in json);
    assert(json["custom_name"].integer == 5);
    assert("value" !in json);
    assert(fromJSON!Named(json).value == 5);
}

unittest
{
    struct BestFit
    {
        int a;
        int b;
    }

    JSONValue partial = JSONValue(["a": JSONValue(1)]);
    BestFit result = fromJSON!BestFit(partial);
    assert(result.a == 1);
    assert(result.b == int.init);
}

unittest
{
    struct RequiredPresent
    {
        @Required int mandatory;
        int optional_;
    }

    JSONValue json = JSONValue(["mandatory": JSONValue(10), "optional_": JSONValue(20)]);
    RequiredPresent result = fromJSON!RequiredPresent(json);
    assert(result.mandatory == 10);
    assert(result.optional_ == 20);
}

unittest
{
    struct RequiredMissing
    {
        @Required int mandatory;
    }

    bool threw = false;
    try
        fromJSON!RequiredMissing(JSONValue.emptyObject);
    catch (Exception)
        threw = true;
    assert(threw);
}

unittest
{
    Nullable!int present = 10;
    assert(toJSON(present) == JSONValue(10));
    assert(fromJSON!(Nullable!int)(JSONValue(10)).get == 10);

    Nullable!int absent;
    assert(toJSON(absent) == JSONValue(null));
    assert(fromJSON!(Nullable!int)(JSONValue(null)).isNull);
}

unittest
{
    int[3] original = [1, 2, 3];
    JSONValue json = toJSON(original);
    assert(json.array.length == 3);
    assert(fromJSON!(int[3])(json) == original);
}

unittest
{
    int[] original = [1, 2, 3];
    JSONValue json = toJSON(original);
    assert(json.array.length == 3);
    assert(fromJSON!(int[])(json) == original);

    int[] empty;
    assert(toJSON(empty) == JSONValue.emptyArray);
    assert(fromJSON!(int[])(JSONValue.emptyArray) == empty);
    assert(fromJSON!(int[])(JSONValue(null)) is null);
}

unittest
{
    string original = "hello";
    JSONValue json = toJSON(original);
    assert(json.str == "hello");
    assert(fromJSON!string(json) == original);

    string nullString;
    assert(toJSON(nullString) == JSONValue(null));
    assert(fromJSON!string(JSONValue(null)) is null);
}

unittest
{
    int[string] original = ["a": 1, "b": 2];
    JSONValue json = toJSON(original);
    assert(json["a"].integer == 1);
    assert(json["b"].integer == 2);
    assert(fromJSON!(int[string])(json) == original);

    int[string] empty;
    assert(toJSON(empty) == JSONValue.emptyObject);

    int[string] nullMap;
    assert(toJSON(nullMap) == JSONValue.emptyObject);
    assert(fromJSON!(int[string])(JSONValue(null)) is null);
}

unittest
{
    JSONValue original = JSONValue(["nested": JSONValue(42)]);
    assert(toJSON(original) == original);
    assert(fromJSON!JSONValue(original) == original);
}

unittest
{
    struct Wrapper(T)
    {
        T value;
    }

    Wrapper!int original = Wrapper!int(5);
    JSONValue json = toJSON(original);
    assert(json["value"].integer == 5);
    assert(fromJSON!(Wrapper!int)(json).value == 5);
}
