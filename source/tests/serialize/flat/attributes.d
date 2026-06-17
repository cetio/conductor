module tests.serialize.flat.attributes;

import conductor.serialize.flat;
import unit_threaded;

@Name("@Endian(Big) field serializes as big-endian")
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
        bytes[0].should == 0xAB;
        bytes[1].should == 0xCD;
    }

    EndianBig recovered = fromBytes!EndianBig(bytes);
    recovered.magic.should == 0xABCD;
}

@Name("@Endian(Little) field serializes as little-endian")
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
        bytes[0].should == 0xCD;
        bytes[1].should == 0xAB;
    }

    EndianLittle recovered = fromBytes!EndianLittle(bytes);
    recovered.magic.should == 0xABCD;
}

@Name("Opposing @Endian fields in same struct serialize independently")
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
        bytes[0].should == 0xAB;
        bytes[1].should == 0xCD;
    }

    OpposingEndian recovered = fromBytes!OpposingEndian(bytes);
    recovered.magic.should == 0xABCD;
    recovered.length.should == 1024;
}

@Name("Mismatched endian recovers wrong value; correct endian recovers original")
unittest
{
    uint original = 0x12345678;
    ubyte[] big = toBytes(original, Endian.Big);
    uint wrong = fromBytes!uint(big, Endian.Little);
    shouldNotEqual(wrong, original);

    uint recovered = fromBytes!uint(big, Endian.Big);
    recovered.should == original;
}

@Name("@StorageKind(Length) dynamic array field serializes with length prefix")
unittest
{
    struct LengthArray
    {
        @StorageKind(StorageKind.Length) int[] payload;
    }

    LengthArray original = LengthArray([10, 20, 30]);
    ubyte[] bytes = toBytes(original);

    bytes.length.should == size_t.sizeof + (3 * int.sizeof);

    LengthArray recovered = fromBytes!LengthArray(bytes);
    recovered.payload.should == [10, 20, 30];
}

@Name("@StorageKind(Length) empty array serializes as length prefix only")
unittest
{
    struct LengthEmpty
    {
        @StorageKind(StorageKind.Length) int[] payload;
    }

    LengthEmpty original;
    ubyte[] bytes = toBytes(original);

    bytes.length.should == size_t.sizeof;

    LengthEmpty recovered = fromBytes!LengthEmpty(bytes);
    recovered.payload.length.should == 0;
}

@Name("@StorageKind(Terminated) uint array appends terminator excluded from result")
unittest
{
    struct TerminatedUint
    {
        @StorageKind(StorageKind.Terminated) uint[] values;
    }

    TerminatedUint original = TerminatedUint([1, 2]);
    ubyte[] bytes = toBytes(original);

    bytes.length.should == 3 * uint.sizeof;

    TerminatedUint recovered = fromBytes!TerminatedUint(bytes);
    recovered.values.should == [1, 2];
}

@Name("@StorageKind(Terminated) unterminated data throws")
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
    threw.should == true;
}

@Name("@StorageKind(None) field consumes all remaining bytes")
unittest
{
    struct NoneArray
    {
        uint header;
        @StorageKind(StorageKind.None) ubyte[] payload;
    }

    NoneArray original = NoneArray(1, [10, 20, 30]);
    ubyte[] bytes = toBytes(original);

    bytes.length.should == uint.sizeof + 3;

    NoneArray recovered = fromBytes!NoneArray(bytes);
    recovered.header.should == 1;
    recovered.payload.should == [10, 20, 30];
}

@Name("@StorageKind(None) empty array produces zero bytes")
unittest
{
    ubyte[] empty;
    ubyte[] bytes = toBytes(empty, Endian.Native, StorageKind.None);

    bytes.length.should == 0;

    ubyte[] recovered = fromBytes!(ubyte[])(bytes, Endian.Native, StorageKind.None);
    recovered.length.should == 0;
}

@Name("@Endian on nested struct field overrides outer default")
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
        bytes[0].should == 0x12;
        bytes[1].should == 0x34;
    }

    Outer recovered = fromBytes!Outer(bytes);
    recovered.inner.value.should == 0x1234;
    recovered.count.should == 42;
}

@Name("Missing @StorageKind on dynamic array field does not compile")
unittest
{
    struct MissingStorageKind
    {
        int[] payload;
    }

    static assert(!__traits(compiles, toBytes(MissingStorageKind.init)));
}
