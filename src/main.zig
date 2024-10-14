const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");

const print = std.debug.print;

const WIDTH: i32 = 1000;
const HEIGHT: i32 = 800;
var POWER: f32 = 0.25;
const n = 30;
const agents = 10;

const Vec2 = struct {
    x: i32,
    y: i32,
};

const Ant = struct {
    pos: Vec2,
    city: usize,
    paths: [][2]usize,
    cities: []usize,
    counter: usize,
};

fn vec2Dist(v1: Vec2, v2: Vec2) i32 {
    const v: u32 = @intCast((v1.x - v2.x) * (v1.x - v2.x) + (v1.y - v2.y) * (v1.y - v2.y));
    const r: i32 = std.math.sqrt(v);
    return r;
}

fn generateCities() ![]Vec2 {
    var r: [n]Vec2 = undefined;
    for (0..@as(usize, n)) |i| {
        r[i] = Vec2{ .x = std.crypto.random.intRangeAtMost(i32, 50, WIDTH - 50), .y = std.crypto.random.intRangeAtMost(i32, 50, HEIGHT - 50) };
    }

    const r_copy = try std.heap.page_allocator.dupe(Vec2, &r);
    return r_copy;
}

fn drawCities(cities: []Vec2) void {
    for (cities) |city| {
        rl.drawCircle(city.x, city.y, 10, rl.Color.gray);
    }
}

fn calcCities(cities: []Vec2, ants: *[agents]Ant) !void {
    var ant: *Ant = undefined;
    var pcity: usize = 0;
    for (0..agents) |k| {
        ant = &ants[k];
        if (ant.counter + 1 <= n) {
            var prng = std.rand.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                try std.posix.getrandom(std.mem.asBytes(&seed));
                break :blk seed;
            });
            const rnd = prng.random();
            var probs: [n]f32 = undefined;
            for (0..@as(usize, n)) |i| {
                if (ant.city == i or ant.cities[i] == 1) {
                    probs[i] = -1;
                } else {
                    probs[i] = std.math.pow(f32, 1 / @as(f32, @floatFromInt(vec2Dist(ant.pos, cities[i]))), POWER);
                }
            }
            const ix: usize = n - (ant.counter + 1);
            var stp: [n]f32 = undefined;
            var sti: [n]usize = undefined;
            var j: usize = 0;
            for (0..@as(usize, n)) |i| {
                if (probs[i] != -1) {
                    stp[j] = probs[i];
                    sti[j] = i;
                    j += 1;
                }
            }
            pcity = ant.city;
            if (ix > 1) {
                ant.city = sti[std.rand.weightedIndex(rnd, f32, stp[0..ix])];
            } else if (ix == 1) {
                ant.city = sti[0];
            } else if (ix == 0) {
                ant.city = 0;
            }

            ant.paths[ant.counter][0] = pcity;
            ant.paths[ant.counter][1] = ant.city;
            ant.counter += 1;
            ant.pos.x = cities[ant.city].x;
            ant.pos.y = cities[ant.city].y;
        }
    }
}

fn visit(ants: *[agents]Ant) void {
    var ant: *Ant = undefined;
    for (0..agents) |i| {
        ant = &ants[i];
        ant.cities[ant.city] = 1;
    }
}

fn newAnt(cities: []Vec2) !Ant {
    var visited_cities: [n]usize = undefined;
    var paths: [n][2]usize = undefined;
    for (0..n) |i| {
        if (i != 0) {
            visited_cities[i] = 0;
        } else {
            visited_cities[i] = 1;
        }
        paths[i] = [2]usize{ 0, 0 };
    }
    const ant = Ant{
        .pos = Vec2{
            .x = cities[0].x,
            .y = cities[0].y,
        },
        .city = 0,
        .cities = try std.heap.page_allocator.dupe(usize, &visited_cities),
        .counter = 0,
        .paths = try std.heap.page_allocator.dupe([2]usize, &paths),
    };

    return ant;
}

fn drawPaths(ants: *[agents]Ant, cities: []Vec2) void {
    for (ants) |ant| {
        for (ant.paths) |paths| {
            rl.drawLineEx(rl.Vector2{ .x = @floatFromInt(cities[paths[0]].x), .y = @floatFromInt(cities[paths[0]].y) }, rl.Vector2{ .x = @floatFromInt(cities[paths[1]].x), .y = @floatFromInt(cities[paths[1]].y) }, 3.0, rl.Color.white);
        }
    }
}

fn stabilizePaths(ants: [agents]Ant) !void {
    var map = std.AutoHashMap([2]usize, i32).init(std.heap.page_allocator);
    defer map.deinit();
    var t: i32 = 0;
    for (ants) |ant| {
        for (ant.paths) |path| {
            t = map.get(path) orelse -1;
            if (t == -1) {
                try map.put(path, 1);
            } else {
                try map.put(path, t + 1);
            }
        }
    }
    var keyIter = map.keyIterator();
    for (0..keyIter.len) |_| {
        _ = keyIter.next();
    }
}

fn drawAnts(ants: *[agents]Ant) void {
    for (ants.*) |ant| {
        rl.drawCircle(ant.pos.x, ant.pos.y, 8, rl.Color.black);
    }
}

pub fn main() !void {
    const cities = try generateCities();
    var ants: [agents]Ant = undefined;
    for (0..agents) |i| {
        ants[i] = try newAnt(cities);
    }
    rl.initWindow(WIDTH, HEIGHT, "Ants");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        drawCities(cities);

        drawAnts(&ants);
        if (rl.isKeyDown(rl.KeyboardKey.key_space)) {
            try calcCities(cities, &ants);
            visit(&ants);
        }

        drawPaths(&ants, cities);
        try stabilizePaths(ants);
    }
}
