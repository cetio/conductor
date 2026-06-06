module conductor.serialize.flat;

import std.algorithm.mutation : reverse;
import std.traits;

enum Endian
{
    Native,
    Big,
    Little,
}

enum StorageKind
{
    None,
    Length,
    Terminated,
}

ubyte[] toBytes(T)(T val, Endian endian = Endian.Native)
{
    ubyte[] ret;

    static if (isAggregateType!T)
    {
        static foreach (string field; FieldNameTuple!T)
        {{
            static if (__traits(compiles, typeof(__traits(getMember, val, field))))
            {
                alias TYPE = typeof(__traits(getMember, val, field));
                static if (!is(TYPE == void) && __traits(compiles, toBytes(__traits(getMember, val, field))))
                {
                    Endian fieldEndian = endian;
                    static if (hasUDA!(__traits(getMember, T, field), Endian))
                        fieldEndian = getUDAs!(__traits(getMember, T, field), Endian)[0];

                    static if (isDynamicArray!TYPE)
                    {
                        StorageKind kind = fieldStorageKind!(T, field);
                        ret ~= toBytes(__traits(getMember, val, field), fieldEndian, kind);
                    }
                    else
                    {
                        ret ~= toBytes(__traits(getMember, val, field), fieldEndian);
                    }
                }
            }
        }}
    }
    else static if (isStaticArray!T)
    {
        foreach (i; 0..val.length)
            ret ~= toBytes(val[i], endian);
    }
    else static if (isDynamicArray!T)
    {
        ret ~= toBytes(cast(size_t)val.length, Endian.Native);
        foreach (element; val)
            ret ~= toBytes(element, endian);
    }
    else
    {
        ret = (cast(ubyte*)reference!val)[0..T.sizeof].dup.endianize(endian);
    }

    return ret;
}

T fromBytes(T)(ref ubyte[] data, Endian endian = Endian.Native)
{
    size_t offset;
    return fromBytesAt!T(data, endian, offset);
}

T fromBytes(T)(ref ubyte[] data, Endian endian, StorageKind kind)
    if (isDynamicArray!T)
{
    size_t offset;
    return fromBytesAt!T(data, endian, kind, offset);
}

private:

ubyte[] toBytes(T)(T val, Endian endian, StorageKind kind)
    if (isDynamicArray!T)
{
    ubyte[] ret;

    if (kind == StorageKind.Length)
    {
        ret ~= toBytes(cast(size_t)val.length, Endian.Native);
        foreach (element; val)
            ret ~= toBytes(element, endian);
    }
    else if (kind == StorageKind.Terminated)
    {
        foreach (element; val)
            ret ~= toBytes(element, endian);
        ret ~= toBytes!(typeof(T.init[0]))(typeof(T.init[0]).init, endian);
    }
    else if (kind == StorageKind.None)
    {
        foreach (element; val)
            ret ~= toBytes(element, endian);
    }

    return ret;
}

T fromBytesAt(T)(ref ubyte[] data, Endian endian, ref size_t offset)
{
    Unqual!T ret = factory!(Unqual!T)();

    static if (isAggregateType!T)
    {
        static foreach (string field; FieldNameTuple!T)
        {{
            static if (__traits(compiles, typeof(__traits(getMember, ret, field))))
            {
                alias TYPE = typeof(__traits(getMember, ret, field));
                static if (!is(TYPE == void) && __traits(compiles, fromBytesAt!TYPE(data, endian, offset)))
                {
                    Endian fieldEndian = endian;
                    static if (hasUDA!(__traits(getMember, T, field), Endian))
                        fieldEndian = getUDAs!(__traits(getMember, T, field), Endian)[0];

                    static if (isDynamicArray!TYPE)
                    {
                        StorageKind kind = fieldStorageKind!(T, field);
                        __traits(getMember, ret, field) = fromBytesAt!TYPE(data, fieldEndian, kind, offset);
                    }
                    else
                    {
                        __traits(getMember, ret, field) = fromBytesAt!TYPE(data, fieldEndian, offset);
                    }
                }
            }
        }}
    }
    else static if (isStaticArray!T)
    {
        static foreach (i; 0..T.length)
            ret[i] = fromBytesAt!(typeof(ret[0]))(data, endian, offset);
    }
    else static if (isDynamicArray!T)
    {
        ret = fromBytesAt!T(data, endian, StorageKind.Length, offset);
    }
    else
    {
        if (offset + T.sizeof > data.length)
            throw new Exception("Insufficient data for"~T.stringof);

        (cast(ubyte*)reference!ret)[0..T.sizeof] = data[offset..offset + T.sizeof].endianize(endian);
        offset += T.sizeof;
    }

    return cast(T)ret;
}

T fromBytesAt(T)(
    ref ubyte[] data,
    Endian endian,
    StorageKind kind,
    ref size_t offset,
)
    if (isDynamicArray!T)
{
    alias ELEM = typeof(T.init[0]);
    Unqual!T ret = factory!(Unqual!T)();

    if (kind == StorageKind.Length)
    {
        size_t len = fromBytesAt!size_t(data, Endian.Native, offset);
        ret = new ELEM[](len);
        foreach (i; 0..len)
            ret[i] = fromBytesAt!ELEM(data, endian, offset);
    }
    else if (kind == StorageKind.Terminated)
    {
        ELEM[] elements;
        while (true)
        {
            if (offset + ELEM.sizeof > data.length)
                throw new Exception("Unterminated array for"~T.stringof);

            ELEM current = fromBytesAt!ELEM(data, endian, offset);
            if (current == ELEM.init)
                break;

            elements ~= current;
        }
        ret = elements;
    }
    else if (kind == StorageKind.None)
    {
        size_t remaining = data.length - offset;
        size_t len = remaining / ELEM.sizeof;
        ret = new ELEM[](len);
        foreach (i; 0..len)
            ret[i] = fromBytesAt!ELEM(data, endian, offset);
    }

    return cast(T)ret;
}

template fieldStorageKind(T, string field)
{
    enum fieldStorageKind = (){
        alias ATTRS = getUDAs!(__traits(getMember, T, field), StorageKind);
        static assert(ATTRS.length > 0, "Dynamic array field '"~field~"' in"~T.stringof~"must have @StorageKind");
        return ATTRS[0];
    }();
}

enum isReferenceType(A) = is(A == class) || is(A == interface) || isPointer!A || isDynamicArray!A;

pragma(inline, true)
@trusted scope void* reference(alias V)()
{
    static if (isReferenceType!(typeof(V)))
        return cast(void*)V;
    else
        return cast(void*)&V;
}

ubyte[] endianize(ubyte[] arr, Endian endian)
{
    version (BigEndian)
    {
        if (endian == Endian.Little)
            (cast(byte*)reference!arr)[0..arr.length].reverse();
    }
    version (LittleEndian)
    {
        if (endian == Endian.Big)
            (cast(byte*)reference!arr)[0..arr.length].reverse();
    }
    return arr;
}

// This could be used elsewhere, but generally it only lives here for simplicity.
pragma(inline, true)
T factory(T, ARGS...)(ARGS args)
{
    static if (isDynamicArray!T)
    {
        static if (ARGS.length == 0)
            return new T(0);
        else
            return new T(args);
    }
    else static if (isReferenceType!T)
    {
        static if (ARGS.length == 0)
            return new T();
        else
            return new T(args);
    }
    else
    {
        static if (ARGS.length != 0)
            return T(args);
        else
            return T.init;
    }
}
