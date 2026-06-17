module tests.serialize.flat.attributes;

import conductor.serialize.flat;

unittest
{
    struct EndianBig
    {
        @Endian(Endian.Big) ushort magic;
    }

    EndianBig original = EndianBig(0xABCD);
    ubyte[] bytes = toBytes(original);

    version (LittleEndian)
    {
        assert(bytes[0] == 0xAB);
        assert(bytes[1] == 0xCD);
    }

    EndianBig recovered = fromBytes!EndianBig(bytes);
    assert(recovered.magic == 0xABCD);
}

unittest
{
    struct EndianLittle
    {
        @Endian(Endian.Little) ushort magic;
    }

    EndianLittle original = EndianLittle(0xABCD);
    ubyte[] bytes = toBytes(original);

    version (BigEndian)
    {
        assert(bytes[0] == 0xCD);
        assert(bytes[1] == 0xAB);
    }

    EndianLittle recovered = fromBytes!EndianLittle(bytes);
    assert(recovered.magic == 0xABCD);
}

unittest
{
    struct OpposingEndian
    {
        @Endian(Endian.Big) ushort magic;
        @Endian(Endian.Little) uint length;
    }

    OpposingEndian original = OpposingEndian(0xABCD, 1024);
    ubyte[] bytes = toBytes(original);

    version (LittleEndian)
    {
        assert(bytes[0] == 0xAB);
        assert(bytes[1] == 0xCD);
    }

    OpposingEndian recovered = fromBytes!OpposingEndian(bytes);
    assert(recovered.magic == 0xABCD);
    assert(recovered.length == 1024);
}

unittest
{
    uint original = 0x12345678;
    ubyte[] big = toBytes(original, Endian.Big);
    uint wrong = fromBytes!uint(big, Endian.Little);
    assert(wrong != original);

    uint recovered = fromBytes!uint(big, Endian.Big);
    assert(recovered == original);
}

unittest
{
    struct LengthArray
    {
        @StorageKind(StorageKind.Length) int[] payload;
    }

    LengthArray original = LengthArray([10, 20, 30]);
    ubyte[] bytes = toBytes(original);

    assert(bytes.length == size_t.sizeof + (3 * int.sizeof));

    LengthArray recovered = fromBytes!LengthArray(bytes);
    assert(recovered.payload == [10, 20, 30]);
}

unittest
{
    struct LengthEmpty
    {
        @StorageKind(StorageKind.Length) int[] payload;
    }

    LengthEmpty original;
    ubyte[] bytes = toBytes(original);

    assert(bytes.length == size_t.sizeof);

    LengthEmpty recovered = fromBytes!LengthEmpty(bytes);
    assert(recovered.payload.length == 0);
}

unittest
{
    struct TerminatedUint
    {
        @StorageKind(StorageKind.Terminated) uint[] values;
    }

    TerminatedUint original = TerminatedUint([1, 2]);
    ubyte[] bytes = toBytes(original);

    assert(bytes.length == 3 * uint.sizeof);

    TerminatedUint recovered = fromBytes!TerminatedUint(bytes);
    assert(recovered.values == [1, 2]);
}

unittest
{
    struct TerminatedUbyte
    {
        @StorageKind(StorageKind.Terminated) ubyte[] name;
    }

    ubyte[] data = [0x48, 0x69];
    bool threw = false;
    try
        fromBytes!TerminatedUbyte(data);
    catch (Exception)
        threw = true;
    assert(threw);
}

unittest
{
    struct NoneArray
    {
        uint header;
        @StorageKind(StorageKind.None) ubyte[] payload;
    }

    NoneArray original = NoneArray(1, [10, 20, 30]);
    ubyte[] bytes = toBytes(original);

    assert(bytes.length == uint.sizeof + 3);

    NoneArray recovered = fromBytes!NoneArray(bytes);
    assert(recovered.header == 1);
    assert(recovered.payload == [10, 20, 30]);
}

unittest
{
    ubyte[] empty;
    ubyte[] bytes = toBytes(empty, Endian.Native, StorageKind.None);

    assert(bytes.length == 0);

    ubyte[] recovered = fromBytes!(ubyte[])(bytes, Endian.Native, StorageKind.None);
    assert(recovered.length == 0);
}

unittest
{
    struct Inner
    {
        @Endian(Endian.Big) ushort value;
    }

    struct Outer
    {
        Inner inner;
        uint count;
    }

    Outer original = Outer(Inner(0x1234), 42);
    ubyte[] bytes = toBytes(original);

    version (LittleEndian)
    {
        assert(bytes[0] == 0x12);
        assert(bytes[1] == 0x34);
    }

    Outer recovered = fromBytes!Outer(bytes);
    assert(recovered.inner.value == 0x1234);
    assert(recovered.count == 42);
}

unittest
{
    struct MissingStorageKind
    {
        int[] payload;
    }

    static assert(!__traits(compiles, toBytes(MissingStorageKind.init)));
}
