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

    const labyrinth = load_labyrinth(std.heap.page_allocator, buf);
    defer labyrinth.deinit();

    const opt_path = try is_labyrinth_valid(labyrinth);

    if (opt_path) |path| {
        std.debug.print("Labyrinth is valid\n", .{});
        for (labyrinth.items, 0..) |line, y| {
            for (line, 0..) |cell, x| {
                if (in_path(path, Position{ .x = x, .y = y })) {
                    std.debug.print(".", .{});
                } else {
                    std.debug.print("{c}", .{cell});
                }
            }
            std.debug.print("\n", .{});
        }
    } else {
        std.debug.print("Labyrinth is invalid\n", .{});
        std.debug.print("{s}", .{buf});
    }
}

pub fn load_labyrinth(allocator: std.mem.Allocator, input: []const u8) std.ArrayList([]const u8) {
    var lines = std.ArrayList([]const u8).init(allocator);
    var iter = std.mem.splitAny(u8, input, "\n");
    while (iter.next()) |line| {
        lines.append(line) catch unreachable;
    }
    return lines;
}

pub fn is_labyrinth_valid(labyrinth: std.ArrayList([]const u8)) !?[]const Position {
    for (labyrinth.items, 0..) |line, y| {
        for (line, 0..) |cell, x| {
            if ((y == 0 or x == 0 or y == labyrinth.items.len - 1 or x == line.len - 1) and cell == ' ') {
                // TODO : Create array list here and add first point to start the exploration...
                var path = std.ArrayList(Position).init(std.heap.page_allocator);
                defer path.deinit();

                try path.append(Position{ .x = x, .y = y });
                return explore_labyrinth(labyrinth, path);
            }
        }
    }
    return null;
}

// STOP WHEN:
// - I'm on edge -> OK
// - I've no more issues -> KO
//
const Position = struct {
    x: usize,
    y: usize,
};

pub fn explore_labyrinth(labyrinth: std.ArrayList([]const u8), path: std.ArrayList(Position)) ?[]const Position {
    // return .{
    //  .valid = true/false
    //  .path = {{x,y}, ...}
    // }
    // recursion
    const last_pos = path.getLast();
    const x = last_pos.x;
    const y = last_pos.y;

    // STOP WALL
    if (labyrinth.items[y][x] != ' ') {
        return null;
    }

    // STOP EDGE
    if (path.items.len > 1 and (x == 0 or x == labyrinth.items[y].len - 1 or y == 0 or y == labyrinth.items.len - 1)) {
        return path.items;
    }

    // EXPLORATION
    const north: ?Position = if (y > 0) .{ .x = x, .y = y - 1 } else null;
    const south: ?Position = if (y + 1 < labyrinth.items.len) .{ .x = x, .y = y + 1 } else null;
    const west: ?Position = if (x > 0) .{ .x = x - 1, .y = y } else null;
    const east: ?Position = if (x + 1 < labyrinth.items[y].len) .{ .x = x + 1, .y = y } else null;

    if (search_at(labyrinth, path, north)) |new_path| {
        return new_path;
    }
    if (search_at(labyrinth, path, south)) |new_path| {
        return new_path;
    }
    if (search_at(labyrinth, path, west)) |new_path| {
        return new_path;
    }
    if (search_at(labyrinth, path, east)) |new_path| {
        return new_path;
    }
    return null;
}

pub fn search_at(labyrinth: std.ArrayList([]const u8), path: std.ArrayList(Position), opt_position: ?Position) ?[]const Position {
    if (opt_position) |position| {
        if (in_path(path.items, position)) {
            return null;
        }
        var cloned = path.clone() catch {
            return null;
        };
        cloned.append(position) catch unreachable;
        return explore_labyrinth(labyrinth, cloned);
    }
    return null;
}

pub fn in_path(path: []const Position, to_find: Position) bool {
    for (path) |pos| {
        if (pos.x == to_find.x and pos.y == to_find.y) {
            return true;
        }
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

    try std.testing.expectEqual(null, try is_labyrinth_valid(labyrinth));
}

test "Is Labyrinth valid vertical line representation" {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\x x
        \\x x
        \\x x
    );
    defer labyrinth.deinit();

    try std.testing.expectEqual(true, try is_labyrinth_valid(labyrinth) != null);
}

test "Is Labyrinth valid horintal line representation" {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\xxx
        \\   
        \\xxx
    );
    defer labyrinth.deinit();

    try std.testing.expectEqual(true, try is_labyrinth_valid(labyrinth) != null);
}

test "Is Labyrinth invalid with empty corner" {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\ x 
        \\x x
        \\ x 
    );
    defer labyrinth.deinit();

    try std.testing.expectEqual(null, try is_labyrinth_valid(labyrinth));
}

test "U Labyrinth is invalid" {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\x xx
        \\x x 
        \\xxxx
    );
    defer labyrinth.deinit();

    try std.testing.expectEqual(null, try is_labyrinth_valid(labyrinth));
}

test "10x10 Labyrinth with no exit" {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\x xxxxxxxx
        \\x    x x x
        \\x x    x x
        \\x  xx  x x
        \\xxxxxxxxxx
        \\x        x
        \\x    xxxxx
        \\xxxx x   x
        \\x      x x
        \\xxxxxxxx x
    );

    defer labyrinth.deinit();

    try std.testing.expectEqual(null, try is_labyrinth_valid(labyrinth));
}

test "10x10 Labyrinth with exit" {
    const labyrinth = load_labyrinth(std.testing.allocator,
        \\x xxxxxxxx
        \\x    x x x
        \\x x    x x
        \\x  xx  x x
        \\x xxxxxxxx
        \\x        x
        \\x    xxxxx
        \\xxxx x   x
        \\x      x x
        \\xxxxxxxx x
    );

    defer labyrinth.deinit();

    try std.testing.expectEqual(true, try is_labyrinth_valid(labyrinth) != null);
}

// TODO : Print test name
// CURRENTLY : Trying to make our test fail with the last one written...
