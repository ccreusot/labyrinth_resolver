const std = @import("std");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    std.debug.print("arg: {s}\n", .{args[1]});

    const file = try std.fs.cwd().openFile(args[1], .{
        .mode = std.fs.File.OpenMode.read_only,
    });
    defer file.close();

    const stat = try file.stat();
    const buf: []u8 = try file.readToEndAlloc(std.heap.page_allocator, stat.size);
    defer std.heap.page_allocator.free(buf);

    std.debug.print("{s}", .{buf});
}

pub fn load_labyrinth(allocator: std.mem.Allocator, input: []const u8) std.ArrayList([]const u8) {
    var lines = std.ArrayList([]const u8).init(allocator);
    var iter = std.mem.splitAny(u8, input, "\n");
    while (iter.next()) |line| {
        lines.append(line) catch unreachable;
    }
    return lines;
}

pub fn is_labyrinth_valid(labyrinth: std.ArrayList([]const u8)) bool {
    var counter: i32 = 0;
    for (labyrinth.items, 0..) |line, y| {
        for (line, 0..) |cell, x| {
            if ((y == 0 or x == 0 or y == labyrinth.items.len - 1 or x == line.len - 1) and cell == ' ') {
                if (explore_labyrinth(labyrinth, y, x)) {
                    std.debug.print("y: {}, x: {}\n", .{ y, x });
                    counter += 1;
                }
            }
        }
    }
    return counter >= 2;
}

pub fn explore_labyrinth(labyrinth: std.ArrayList([]const u8), y: usize, x: usize) bool {
    if (x > 0 and labyrinth.items[y][x - 1] == ' ') {
        return true;
    } else if (y > 0 and labyrinth.items[y - 1][x] == ' ') {
        return true;
    } else if (x + 1 < labyrinth.items[y].len and labyrinth.items[y][x + 1] == ' ') {
        return true;
    } else if (y + 1 < labyrinth.items.len and labyrinth.items[y + 1][x] == ' ') {
        return true;
    }
    return false;
}

test "Load Labyrinth" {
    const expected_result = [3][3]u8{
        [_]u8{ 'x', 'x', 'x' },
        [_]u8{ 'x', ' ', 'x' },
        [_]u8{ 'x', 'x', 'x' },
    };

    const result = load_labyrinth(std.testing.allocator, "xxx\nx x\nxxx");
    defer result.deinit();

    const items = result.items;

    for (expected_result, 0..) |line, y| {
        for (line, 0..) |expected_cell, x| {
            // std.debug.print("cell value: {} y: {} x: {}\n", .{ items[y][x], y, x });
            try std.testing.expect(expected_cell == items[y][x]);
        }
    }
}

test "Is Labyrinth not valid" {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\xxx
        \\x x
        \\xxx
    );
    defer labyrinth.deinit();

    try std.testing.expectEqual(false, is_labyrinth_valid(labyrinth));
}

test "Is Labyrinth valid" {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\x x
        \\x x
        \\x x
    );
    defer labyrinth.deinit();

    try std.testing.expectEqual(true, is_labyrinth_valid(labyrinth));
}

test "Is Labyrinth invalid with empty corner" {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\ x 
        \\x x
        \\ x 
    );
    defer labyrinth.deinit();

    try std.testing.expectEqual(false, is_labyrinth_valid(labyrinth));
}

test "U Labyrinth is invalid " {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\x xx
        \\x x
        \\xxxx
    );
    defer labyrinth.deinit();

    try std.testing.expectEqual(false, is_labyrinth_valid(labyrinth));
}

// TODO : Print test name
// CURRENTLY : Trying to make our test fail with the last one written...
