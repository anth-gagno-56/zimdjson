# zimdjson Example

This example demonstrates how to use zimdjson to parse JSON data in two ways:

1. **Basic Manual Parsing**: Manually navigate the JSON structure and extract values
2. **Reflection-based Parsing**: Use Zig's compile-time reflection to automatically deserialize JSON into typed structs

## Running the Example

From this directory, run:

```bash
zig build run
```

## What This Example Does

The example parses a simple Twitter-like JSON file ([data.json](data.json)) containing:
- Search metadata (count, completion time)
- An array of tweets with user information

### Example 1: Basic Manual Parsing

Shows how to:
- Access nested fields using `.at()`
- Convert values to appropriate types (`.asUnsigned()`, `.asFloat()`, `.asString()`)
- Iterate over arrays using `.asArray()` and `.next()`

### Example 2: Reflection-based Parsing

Shows how to:
- Define Zig structs that match your JSON structure
- Use `.as()` to automatically deserialize the entire JSON document
- Work with typed data instead of navigating the JSON tree

## Key Concepts

- **FullParser**: Loads the entire JSON document into memory at once
- **StreamParser**: Can handle arbitrarily large documents with O(1) memory usage
- **On-Demand parsing**: Values are only parsed when accessed, improving performance

## Learn More

- [zimdjson Documentation](https://zimdjson.ramis.ar)
- [Main Repository](https://github.com/ezequielramis/zimdjson)
