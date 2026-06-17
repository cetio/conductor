module tests.serialize.json.attributes;

import conductor.serialize.json;
import unit_threaded.assertions;
import unit_threaded.runner.attrs : TestName = Name;
import std.json : JSONValue, JSONType;

@TestName("@Name replaces field name as JSON key")
unittest
{
    struct Renamed
    {
        @Name("custom_name") int value;
    }

    Renamed original = Renamed(5);
    JSONValue json = toJSON(original);
    ("custom_name" in json).shouldNotBeNull;
    ("value" in json).shouldBeNull;
    json["custom_name"].integer.should == 5;
}

@TestName("@Name field roundtrips: deserialize from renamed key recovers value")
unittest
{
    struct Renamed
    {
        @Name("custom_name") int value;
    }

    JSONValue json = JSONValue(["custom_name": JSONValue(5)]);
    Renamed recovered = fromJSON!Renamed(json);
    recovered.value.should == 5;
}

@TestName("@Name on string field: null string serializes as JSON null under custom key")
unittest
{
    struct RenamedString
    {
        @Name("alias") string value;
    }

    RenamedString original;
    JSONValue json = toJSON(original);
    ("alias" in json).shouldNotBeNull;
    json["alias"].type.should == JSONType.null_;
}

@TestName("Multiple @Name fields in one struct: each uses its own key")
unittest
{
    struct ManyRenamed
    {
        @Name("a") int alpha;
        @Name("b") int beta;
    }

    ManyRenamed original = ManyRenamed(1, 2);
    JSONValue json = toJSON(original);
    ("a" in json).shouldNotBeNull;
    ("b" in json).shouldNotBeNull;
    ("alpha" in json).shouldBeNull;
    ("beta" in json).shouldBeNull;
    json["a"].integer.should == 1;
    json["b"].integer.should == 2;
    fromJSON!ManyRenamed(json).should == original;
}

@TestName("@Name on nested struct field: key renamed at outer level only")
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
    ("inner_data" in json).shouldNotBeNull;
    ("inner" in json).shouldBeNull;
    json["inner_data"]["value"].integer.should == 7;
    fromJSON!Outer(json).inner.value.should == 7;
}

@TestName("@Required field present: deserializes without throwing")
unittest
{
    struct RequiredPresent
    {
        @Required int mandatory;
    }

    JSONValue json = JSONValue(["mandatory": JSONValue(10)]);
    RequiredPresent recovered = fromJSON!RequiredPresent(json);
    recovered.mandatory.should == 10;
}

@TestName("@Required field absent: throws with informative exception")
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
    threw.should == true;
}

@TestName("@Required + @Name: missing custom-named required field throws")
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
    threw.should == true;
}

@TestName("@Required + @Name: present custom-named required field deserializes")
unittest
{
    struct RequiredRenamed
    {
        @Required @Name("custom") int value;
    }

    JSONValue json = JSONValue(["custom": JSONValue(42)]);
    RequiredRenamed recovered = fromJSON!RequiredRenamed(json);
    recovered.value.should == 42;
}

@TestName("Non-required field absent: defaults to T.init, no exception")
unittest
{
    struct OptionalOnly
    {
        int alpha;
        int beta;
    }

    JSONValue json = JSONValue(["alpha": JSONValue(1)]);
    OptionalOnly recovered = fromJSON!OptionalOnly(json);
    recovered.alpha.should == 1;
    recovered.beta.should == int.init;
}

@TestName("Multiple @Required fields: missing any throws")
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
    threw.should == true;
}
