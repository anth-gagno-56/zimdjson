const std = @import("std");
const zimdjson = @import("zimdjson");

// Define data structures matching our JSON
const User = struct {
    name: []const u8,
    screen_name: []const u8,
    followers_count: u32,
};

const Tweet = struct {
    id: u64,
    text: []const u8,
    user: User,
    retweet_count: u32,
};

const SearchMetadata = struct {
    count: u32,
    completed_in: f64,
};

const TwitterData = struct {
    search_metadata: SearchMetadata,
    statuses: []const Tweet,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== zimdjson Example: JSON Parsing ===\n\n", .{});

    // Example 1: Basic manual parsing
    try basicParsing(allocator);

    // Example 2: Reflection-based parsing
    try reflectionParsing(allocator);
}

fn basicParsing(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 1: Basic Manual Parsing\n", .{});
    std.debug.print("--------------------------------\n", .{});

    var parser = zimdjson.ondemand.FullParser(.default).init;
    defer parser.deinit(allocator);

    const json = try std.fs.cwd().readFileAlloc(allocator, "data.json", 1024 * 1024);
    defer allocator.free(json);

    const document = try parser.parseFromSlice(allocator, json);

    // Access nested fields
    const metadata_count = try document.at("search_metadata").at("count").asUnsigned();
    const completed_in = try document.at("search_metadata").at("completed_in").asDouble();

    std.debug.print("Found {d} results (completed in {d:.3}s)\n", .{ metadata_count, completed_in });

    // Iterate over array of tweets
    var statuses = (try document.at("statuses").asArray()).iterator();
    var tweet_idx: usize = 0;

    while (try statuses.next()) |status| {
        tweet_idx += 1;
        const tweet_id = try status.at("id").asUnsigned();
        const text = try status.at("text").asString();
        const user_name = try status.at("user").at("name").asString();
        const retweets = try status.at("retweet_count").asUnsigned();

        std.debug.print("\nTweet #{d}:\n", .{tweet_idx});
        std.debug.print("  ID: {d}\n", .{tweet_id});
        std.debug.print("  Text: {s}\n", .{text});
        std.debug.print("  By: {s}\n", .{user_name});
        std.debug.print("  Retweets: {d}\n", .{retweets});
    }

    std.debug.print("\n", .{});
}

fn reflectionParsing(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 2: Reflection-based Parsing (Schema)\n", .{});
    std.debug.print("---------------------------------------------\n", .{});

    var parser = zimdjson.ondemand.FullParser(.default).init;
    defer parser.deinit(allocator);

    const json = try std.fs.cwd().readFileAlloc(allocator, "data.json", 1024 * 1024);
    defer allocator.free(json);

    const document = try parser.parseFromSlice(allocator, json);

    // Parse entire document into typed struct using reflection
    const data = try document.as(TwitterData, allocator, .{});
    defer data.deinit();

    std.debug.print("Search Metadata:\n", .{});
    std.debug.print("  Count: {d}\n", .{data.value.search_metadata.count});
    std.debug.print("  Completed in: {d:.3}s\n\n", .{data.value.search_metadata.completed_in});

    std.debug.print("Tweets ({d} total):\n", .{data.value.statuses.len});
    for (data.value.statuses, 0..) |tweet, i| {
        std.debug.print("\nTweet #{d}:\n", .{i + 1});
        std.debug.print("  ID: {d}\n", .{tweet.id});
        std.debug.print("  Text: {s}\n", .{tweet.text});
        std.debug.print("  User: {s} (@{s})\n", .{ tweet.user.name, tweet.user.screen_name });
        std.debug.print("  Followers: {d}\n", .{tweet.user.followers_count});
        std.debug.print("  Retweets: {d}\n", .{tweet.retweet_count});
    }

    std.debug.print("\n", .{});
}
