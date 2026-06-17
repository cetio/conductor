module tests.serialize.json.attributes;

import conductor.serialize.json;
import std.json : JSONValue, JSONType;

unittest
{
    struct Renamed
    {
        @Name("custom_name") int value;
    }

    Renamed original = Renamed(5);
    JSONValue json = toJSON(original);
    assert("custom_name" in json);
    assert(("value" in json) is null);
    assert(json["custom_name"].integer == 5);
}

unittest
{
    struct Renamed
    {
        @Name("custom_name") int value;
    }

    JSONValue json = JSONValue(["custom_name": JSONValue(5)]);
    Renamed recovered = fromJSON!Renamed(json);
    assert(recovered.value == 5);
}

unittest
{
    struct RenamedString
    {
        @Name("alias") string value;
    }

    RenamedString original;
    JSONValue json = toJSON(original);
    assert("alias" in json);
    assert(json["alias"].type == JSONType.null_);
}

unittest
{
    struct ManyRenamed
    {
        @Name("a") int alpha;
        @Name("b") int beta;
    }

    ManyRenamed original = ManyRenamed(1, 2);
    JSONValue json = toJSON(original);
    assert("a" in json);
    assert("b" in json);
    assert(("alpha" in json) is null);
    assert(("beta" in json) is null);
    assert(json["a"].integer == 1);
    assert(json["b"].integer == 2);
    assert(fromJSON!ManyRenamed(json) == original);
}

unittest
{
    struct Inner
    {
        int value;
    }

    struct Outer
    {
        @Name("inner_data") Inner inner;
    }

    Outer original = Outer(Inner(7));
    JSONValue json = toJSON(original);
    assert("inner_data" in json);
    assert(("inner" in json) is null);
    assert(json["inner_data"]["value"].integer == 7);
    assert(fromJSON!Outer(json).inner.value == 7);
}

unittest
{
    struct RequiredPresent
    {
        @Required int mandatory;
    }

    JSONValue json = JSONValue(["mandatory": JSONValue(10)]);
    RequiredPresent recovered = fromJSON!RequiredPresent(json);
    assert(recovered.mandatory == 10);
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
    struct RequiredRenamed
    {
        @Required @Name("custom") int value;
    }

    bool threw = false;
    try
        fromJSON!RequiredRenamed(JSONValue.emptyObject);
    catch (Exception)
        threw = true;
    assert(threw);
}

unittest
{
    struct RequiredRenamed
    {
        @Required @Name("custom") int value;
    }

    JSONValue json = JSONValue(["custom": JSONValue(42)]);
    RequiredRenamed recovered = fromJSON!RequiredRenamed(json);
    assert(recovered.value == 42);
}

unittest
{
    struct OptionalOnly
    {
        int alpha;
        int beta;
    }

    JSONValue json = JSONValue(["alpha": JSONValue(1)]);
    OptionalOnly recovered = fromJSON!OptionalOnly(json);
    assert(recovered.alpha == 1);
    assert(recovered.beta == int.init);
}

unittest
{
    struct DualRequired
    {
        @Required int alpha;
        @Required int beta;
    }

    bool threw = false;
    try
        fromJSON!DualRequired(JSONValue.emptyObject);
    catch (Exception)
        threw = true;
    assert(threw);
}
