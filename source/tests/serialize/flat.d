module tests.serialize.flat;

import conductor.serialize.flat;

unittest
{
    int original = 0x12345678;
    ubyte[] bytes = toBytes(original);
    assert(bytes.length == int.sizeof);
    assert(fromBytes!int(bytes) == original);

    ushort originalShort = 0xABCD;
    ubyte[] shortBytes = toBytes(originalShort);
    assert(shortBytes.length == ushort.sizeof);
    assert(fromBytes!ushort(shortBytes) == originalShort);
}

unittest
{
    ushort original = 0x0102;

    version (LittleEndian)
    {
        ubyte[] native = toBytes(original, Endian.Native);
        assert(native[0] == 0x02);
        assert(native[1] == 0x01);

        ubyte[] big = toBytes(original, Endian.Big);
        assert(big[0] == 0x01);
        assert(big[1] == 0x02);

        ubyte[] little = toBytes(original, Endian.Little);
        assert(little[0] == 0x02);
        assert(little[1] == 0x01);
    }
    else version (BigEndian)
    {
        ubyte[] native = toBytes(original, Endian.Native);
        assert(native[0] == 0x01);
        assert(native[1] == 0x02);

        ubyte[] big = toBytes(original, Endian.Big);
        assert(big[0] == 0x01);
        assert(big[1] == 0x02);

        ubyte[] little = toBytes(original, Endian.Little);
        assert(little[0] == 0x02);
        assert(little[1] == 0x01);
    }

    assert(fromBytes!ushort(big, Endian.Big) == original);
    assert(fromBytes!ushort(little, Endian.Little) == original);
}

unittest
{
    struct PacketHeader
    {
        ushort magic;
        uint length;
    }

    PacketHeader original = PacketHeader(0xABCD, 1024);
    ubyte[] bytes = toBytes(original);
    assert(fromBytes!PacketHeader(bytes) == original);
}

unittest
{
    ubyte[4] original = [0x89, 0x50, 0x4E, 0x47];
    ubyte[] bytes = toBytes(original);
    assert(bytes.length == 4);
    assert(fromBytes!(ubyte[4])(bytes) == original);
}

unittest
{
    struct Message
    {
        @StorageKind(StorageKind.Length)
        ubyte[] payload;
    }

    Message original = Message([1, 2, 3]);
    ubyte[] bytes = toBytes(original);

    assert(bytes.length == size_t.sizeof + 3);

    Message recovered = fromBytes!Message(bytes);
    assert(recovered.payload == [1, 2, 3]);
}

unittest
{
    struct EmptyMessage
    {
        @StorageKind(StorageKind.Length)
        ubyte[] payload;
    }

    EmptyMessage original;
    ubyte[] bytes = toBytes(original);
    assert(bytes.length == size_t.sizeof);

    EmptyMessage recovered = fromBytes!EmptyMessage(bytes);
    assert(recovered.payload.length == 0);
}

unittest
{
    struct TerminatedMessage
    {
        @StorageKind(StorageKind.Terminated)
        ubyte[] name;
    }

    TerminatedMessage original = TerminatedMessage([0x48, 0x69]);
    ubyte[] bytes = toBytes(original);

    assert(bytes.length == 3);

    TerminatedMessage recovered = fromBytes!TerminatedMessage(bytes);
    assert(recovered.name == [0x48, 0x69]);
}

unittest
{
    int[] original = [10, 20, 30];
    ubyte[] bytes = toBytes(original, Endian.Native);

    size_t expectedLength = size_t.sizeof + (original.length * int.sizeof);
    assert(bytes.length == expectedLength);

    ubyte[] raw;
    foreach (element; original)
        raw ~= toBytes(element, Endian.Native);
    int[] recovered = fromBytes!(int[])(raw, Endian.Native, StorageKind.None);
    assert(recovered == original);
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
    ubyte[] bytes = toBytes(original);
    Outer recovered = fromBytes!Outer(bytes);
    assert(recovered.inner.value == 7);
    assert(recovered.count == 99);
}

class Node
{
    int value;

    this()
    {
    }

    this(int v)
    {
        value = v;
    }
}

unittest
{
    Node original = new Node(5);
    ubyte[] bytes = toBytes(original);
    Node recovered = fromBytes!Node(bytes);
    assert(recovered.value == 5);
}

unittest
{
    struct Packet
    {
        @Endian(Endian.Big) ushort magic;
        uint length;
    }

    version (LittleEndian)
    {
        Packet original = Packet(0xABCD, 1024);
        ubyte[] bytes = toBytes(original);

        assert(bytes[0] == 0xAB);
        assert(bytes[1] == 0xCD);

        Packet recovered = fromBytes!Packet(bytes);
        assert(recovered.magic == 0xABCD);
        assert(recovered.length == 1024);
    }
}

unittest
{
    ubyte[] tooShort = [0x01];
    bool threw = false;
    try
        fromBytes!ushort(tooShort);
    catch (Exception)
        threw = true;
    assert(threw);
}

unittest
{
    double original = 3.14159;
    ubyte[] bytes = toBytes(original);
    assert(bytes.length == double.sizeof);
    double recovered = fromBytes!double(bytes);
    assert(recovered == original);
}
