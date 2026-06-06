/// Reflection-driven `toJSON` and `fromJSON` with `@Name` and `@Required` UDAs.
module conductor.serialize.json;

import std.conv : to;
import std.json : JSONValue, JSONType;
import std.traits;
import std.typecons : Nullable;

/// UDA to override the JSON field name for a struct member.
struct Name
{
    /// The JSON key to use instead of the field name.
    string value;
}

/// UDA to mark a struct member as required during deserialization.
struct Required { }

/**
 * Serializes a value to JSON using compile-time reflection.
 *
 * Supports structs, enums, arrays, associative arrays, Nullable,
 * and primitive types. String-keyed AAs only.
 *
 * Params:
 *  val = The value to serialize.
 *
 * Returns:
 *  The JSON representation.
 */
JSONValue toJSON(T)(T val)
{
    static if (is(T == JSONValue))
        return val;
    else static if (is(T == typeof(null)))
        return JSONValue(null);
    else static if (is(T == enum))
    {
        static if (is(OriginalType!T == string))
            return JSONValue(cast(string)val);
        else
            return JSONValue(cast(OriginalType!T)val);
    }
    else static if (is(T == string))
        return val is null ? JSONValue(null) : JSONValue(val);
    else static if (__traits(compiles, JSONValue(val)))
        return JSONValue(val);
    else static if (isStaticArray!T || isDynamicArray!T)
    {
        static if (is(T : E[], E) && (is(E == char) || is(E == immutable(char))))
            return val is null ? JSONValue(null) : JSONValue(val);
        else
        {
            JSONValue ret = JSONValue.emptyArray;
            foreach (element; val)
                ret.array ~= toJSON(element);
            return ret;
        }
    }
    else static if (isAssociativeArray!T)
    {
        static assert(is(KeyType!T == string), "Only string-keyed AAs are supported for JSON.");
        JSONValue ret = JSONValue.emptyObject;
        foreach (string key, ValueType!T value; val)
            ret[key] = toJSON(value);
        return ret;
    }
    else static if (isInstanceOf!(Nullable, T))
    {
        if (val.isNull)
            return JSONValue(null);
        return toJSON(val.get);
    }
    else static if (isAggregateType!T)
    {
        JSONValue ret = JSONValue.emptyObject;
        static foreach (string field; FieldNameTuple!T)
        {{
            static if (__traits(compiles, typeof(__traits(getMember, val, field))))
            {{
                alias TYPE = typeof(__traits(getMember, val, field));
                static if (!is(TYPE == void) && __traits(compiles, toJSON(__traits(getMember, val, field))))
                {{
                    enum NAME = jsonFieldName!(T, field);
                    ret[NAME] = toJSON(__traits(getMember, val, field));
                }}
            }}
        }}
        return ret;
    }
    else static if (isPointer!T)
    {
        if (val == null)
            return JSONValue(null);
        return JSONValue(cast(size_t)val);
    }
    else
        static assert(0, "Cannot serialize type"~T.stringof~" to JSON.");
}

/**
 * Deserializes a JSON value to type T using compile-time reflection.
 *
 * Supports the same types as `toJSON`. Missing `@Required` fields throw.
 * Classes must have a default constructor.
 *
 * Params:
 *  json = The JSON value to deserialize.
 *
 * Returns:
 *  The deserialized value.
 *
 * Throws:
 *  Exception if the JSON type does not match T or a required field is missing.
 */
T fromJSON(T)(JSONValue json)
{
    static if (is(T == JSONValue))
        return json;
    else static if (is(T == typeof(null)))
        return null;
    else static if (is(T == string))
    {
        if (json.type == JSONType.null_)
            return null;
        if (json.type != JSONType.string)
            throw new Exception("Expected string for"~T.stringof~", got"~json.type.to!string);
        return json.str;
    }
    else static if (is(T == bool))
    {
        if (json.type == JSONType.true_)
            return true;
        if (json.type == JSONType.false_)
            return false;
        throw new Exception("Expected bool for"~T.stringof~", got"~json.type.to!string);
    }
    else static if (isIntegral!T)
    {
        switch (json.type)
        {
        case JSONType.integer:
            return cast(T)json.integer;
        case JSONType.uinteger:
            return cast(T)json.uinteger;
        case JSONType.string:
            if (json.str is null)
                throw new Exception("Expected integral for"~T.stringof~", got null string");
            return json.str.to!T;
        default:
            throw new Exception("Expected integral for"~T.stringof~", got"~json.type.to!string);
        }
    }
    else static if (isFloatingPoint!T)
    {
        switch (json.type)
        {
        case JSONType.float_:
            return cast(T)json.floating;
        case JSONType.integer:
            return cast(T)json.integer;
        case JSONType.uinteger:
            return cast(T)json.uinteger;
        case JSONType.string:
            if (json.str is null)
                throw new Exception("Expected float for"~T.stringof~", got null string");
            return json.str.to!T;
        default:
            throw new Exception("Expected float for"~T.stringof~", got"~json.type.to!string);
        }
    }
    else static if (is(T == enum))
    {
        static if (is(OriginalType!T == string))
        {
            if (json.type != JSONType.string)
                throw new Exception("Expected string for enum"~T.stringof);
            static foreach (member; EnumMembers!T)
            {{
                if (json.str == member)
                    return member;
            }}
            throw new Exception("Invalid"~T.stringof~" value: "~json.str);
        }
        else
            return cast(T)fromJSON!(OriginalType!T)(json);
    }
    else static if (isStaticArray!T)
    {
        if (json.type != JSONType.array)
            throw new Exception("Expected array for"~T.stringof);
        else if (json.array.length != T.length)
            throw new Exception("Array length mismatch for"~T.stringof);

        T ret = T.init;
        static foreach (i; 0..T.length)
            ret[i] = fromJSON!(typeof(ret[0]))(json.array[i]);
        return ret;
    }
    else static if (isDynamicArray!T)
    {
        static if (is(T : E[], E) && (is(E == char) || is(E == immutable(char))))
        {
            if (json.type == JSONType.null_)
                return null;
            else if (json.type != JSONType.string)
                throw new Exception("Expected string for"~T.stringof);
            return json.str;
        }
        else
        {
            if (json.type == JSONType.null_)
                return null;
            else if (json.type != JSONType.array)
                throw new Exception("Expected array for"~T.stringof);

            T ret = new typeof(T.init[0])[](json.array.length);
            foreach (i; 0..json.array.length)
                ret[i] = fromJSON!(typeof(T.init[0]))(json.array[i]);
            return ret;
        }
    }
    else static if (isAssociativeArray!T)
    {
        static assert(is(KeyType!T == string), "Only string-keyed AAs are supported for JSON.");
        if (json.type == JSONType.null_)
            return null;
        else if (json.type != JSONType.object)
            throw new Exception("Expected object for"~T.stringof);
        T ret;
        foreach (string key, JSONValue value; json.object)
            ret[key] = fromJSON!(ValueType!T)(value);
        return ret;
    }
    else static if (isInstanceOf!(Nullable, T))
    {
        if (json.type == JSONType.null_)
            return T.init;
        return T(fromJSON!(TemplateArgsOf!T[0])(json));
    }
    else static if (isAggregateType!T)
    {
        if (json.type != JSONType.object)
            throw new Exception("Expected object for"~T.stringof);
        static if (is(T == class))
        {
            static assert(
                __traits(compiles, new T()),
                "Cannot deserialize JSON to class "~T.stringof~" without a default constructor."
            );
            if (json.type == JSONType.null_)
                return null;
            T ret = new T();
        }
        else
            T ret = T.init;
            
        static foreach (string field; FieldNameTuple!T)
        {{
            static if (__traits(compiles, typeof(__traits(getMember, ret, field))))
            {{
                alias TYPE = typeof(__traits(getMember, ret, field));
                static if (!is(TYPE == void) && __traits(compiles, fromJSON!TYPE(JSONValue.init)))
                {{
                    enum NAME = jsonFieldName!(T, field);
                    enum REQUIRED = isRequiredField!(T, field);
                    if (NAME in json)
                        __traits(getMember, ret, field) = fromJSON!TYPE(json[NAME]);
                    else static if (REQUIRED)
                        throw new Exception("Missing required field '"~NAME~"' in"~T.stringof);
                }}
            }}
        }}
        return ret;
    }
    else static if (isPointer!T)
    {
        if (json.type == JSONType.null_)
            return T.init;
        else if (json.type == JSONType.integer)
            return cast(T)json.integer;
        else if (json.type == JSONType.string)
            return cast(T)json.str;
        else
            throw new Exception("Expected integer or string for pointer type"~T.stringof);
    }
    else
        static assert(0, "Cannot deserialize JSON to type"~T.stringof);
}

private:

/// Gets the JSON field name for a struct member, respecting `@Name`.
template jsonFieldName(T, string field)
{
    enum jsonFieldName = (){
        alias ATTRS = getUDAs!(__traits(getMember, T, field), Name);
        static if (ATTRS.length > 0)
            return ATTRS[0].value;
        else
            return field;
    }();
}

/// True if the struct member has the `@Required` UDA.
template isRequiredField(T, string field)
{
    enum isRequiredField = hasUDA!(__traits(getMember, T, field), Required);
}
