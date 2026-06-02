# Conductor

Conductor is a D library for HTTP, OAuth, serialization, and network orchestration. It is intended to provide small, direct utilities for API integrations without pulling in a large framework.

## Modules

| Module | Description |
|--------|-------------|
| `conductor.http` | HTTP request/response types and thin `std.net.curl` wrappers with JSON-aware overloads. |
| `conductor.oauth` | OAuth 2.0 authorization, token management, caching, and revocation. |
| `conductor.query` | Query string encoding, decoding, form encoding, and URL building. |
| `conductor.serialize.json` | Reflection-driven `toJSON` and `fromJSON` with `@Name` and `@Required` UDAs. |
| `conductor.serialize.flat` | Struct-to-byte serialization with `@Endian` and `@StorageKind` UDAs. |
| `conductor.loopback` | Lightweight local HTTP server for catching OAuth redirects. |
| `conductor.orchestrate` | Rate-limited request dispatch with reusable HTTP client state. |

## Usage

### HTTP

Conductor wraps `std.net.curl` to make requests less verbose. `send` handles GET, POST, PUT, PATCH, and DELETE with automatic JSON serialization for structs.

```d
import conductor.http;
import std.net.curl : HTTP;

HTTP http;
Response response = send(http, HTTP.Method.get, "https://api.example.com/data");
writeln(response.status);
writeln(cast(string)response.content);
```

Structs serialize automatically:

```d
struct Payload
{
    string name;
    int value;
}

HTTP http;
Payload payload = Payload("test", 42);
Response response = send(http, HTTP.Method.post, "https://api.example.com/data", payload);
```

### OAuth

Conductor implements the full OAuth 2.0 authorization-code flow with PKCE (S256). It spins up a local loopback server to catch the redirect, launches the user's browser automatically, and caches tokens to disk.

```d
import conductor.oauth;
import std.file : readText;
import std.json : parseJSON;

auto oauth = OAuth.fromJSON(parseJSON(readText("oauth_client.json")));
auto token = oauth.authorize("MyApp", "https://www.googleapis.com/auth/drive.readonly");
```

Tokens are cached under `~/.cache/conductor/oauth`. Valid cached tokens are reused; expired ones are refreshed automatically. Revoke when done:

```d
oauth.revoke(token);
```

### URL Building

`buildURL`, `parseQuery`, `formEncode`, and `encodeQueryComponent` handle the tedious parts of URL construction without surprises around `+` or spaces.

```d
import conductor.query;

string url = buildURL("https://api.example.com", "/search", [
    "q": "hello world",
    "limit": "10"
]);

string[string] parsed = parseQuery("q=hello%20world&limit=10");
```

### JSON Serialization

`toJSON` and `fromJSON` are reflection-driven. They handle structs, enums, arrays, associative arrays, and `Nullable`. Use `@Name` to override field names and `@Required` to enforce presence during deserialization.

```d
import conductor.serialize.json;

struct User
{
    @Name("user_name")
    string name;

    @Required
    int id;
}

User user = User("alice", 1);
JSONValue json = toJSON(user);
User restored = fromJSON!User(json);
```

### Flat Binary Serialization

`toBytes` and `fromBytes` serialize structs to raw bytes with configurable endianness per field. Dynamic arrays require a `@StorageKind` UDA to indicate how their length is represented.

```d
import conductor.serialize.flat;

struct Header
{
    int magic;
    @Endian(Endian.Big)
    ushort version;
    @StorageKind(StorageKind.Length)
    ubyte[] data;
}

Header header = Header(0xDEADBEEF, 1, [1, 2, 3]);
ubyte[] bytes = toBytes(header);

ubyte[] source = bytes.dup;
Header restored = fromBytes!Header(source);
```

### Orchestration

`Orchestrator` wraps host, URL building, and rate limiting into one struct. It sleeps between requests when `minIntervalMs` is set.

```d
import conductor.orchestrate;

Orchestrator api;
api.host = "https://api.example.com";
api.minIntervalMs = 100;

Response response = api.send(HTTP.Method.get, "/data");
```

## Installation

`dub add conductor`

For local development in this workspace:

```json
{
    "dependencies": {
        "conductor": {
            "path": "../conductor"
        }
    }
}
```

## License

Conductor is licensed under [AGPL-3](LICENSE.txt).