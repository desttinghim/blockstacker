const std = @import("std");

pub const Read = struct {
    pos: u64,
    to_buf: []u8,
};

pub const Write = struct {
    pos: u64,
    from_buf: []u8,
};

// TODO: Take each type/function individually so people can wrap other peoples structs
pub fn Storage(comptime T: type) type {
    const t_info = @typeInfo(T);

    switch (t_info) {
        .Struct => {
            if (@hasDecl(T, "StorageImpl") and T == Storage(T.StorageImpl)) {
                return T;
            }

            std.debug.assert(std.meta.trait.hasFunctions(T, .{ "read", "readIsComplete", "write", "writeIsComplete", "freeRead", "freeWrite" }));
            std.debug.assert(std.meta.trait.hasDecls(T, .{ "ReadHandle", "WriteHandle" }));
        },
        .Pointer => |ptr_info| {
            std.debug.assert(std.meta.trait.hasFunctions(ptr_info.child, .{ "read", "readIsComplete", "write", "writeIsComplete", "freeRead", "freeWrite" }));
            std.debug.assert(std.meta.trait.hasDecls(ptr_info.child, .{ "ReadHandle", "WriteHandle" }));
        },
        else => unreachable,
    }

    return struct {
        impl: T,

        pub const StorageImpl = T;
        pub const ReadHandle = switch (t_info) {
            .Struct => T.ReadHandle,
            .Pointer => |ptr_info| ptr_info.child.ReadHandle,
            else => unreachable,
        };
        pub const WriteHandle = switch (t_info) {
            .Struct => T.WriteHandle,
            .Pointer => |ptr_info| ptr_info.child.WriteHandle,
            else => unreachable,
        };

        pub fn read(this: @This(), pos: u64, to_buf: []u8) !ReadHandle {
            return try this.impl.read(pos, to_buf);
        }

        pub fn readIsComplete(this: @This(), read_handle: ReadHandle) !?usize {
            return try this.impl.readIsComplete(read_handle);
        }

        pub fn freeRead(this: @This(), read_handle: ReadHandle) void {
            this.impl.freeRead(read_handle);
        }

        pub fn write(this: @This(), pos: u64, from_buf: []const u8) !WriteHandle {
            return try this.impl.write(pos, from_buf);
        }

        pub fn writeIsComplete(this: @This(), write_handle: WriteHandle) !?usize {
            return try this.impl.writeIsComplete(write_handle);
        }

        pub fn freeWrite(this: @This(), write_handle: WriteHandle) void {
            this.impl.freeWrite(write_handle);
        }
    };
}

pub fn asStorage(impl: anytype) Storage(@TypeOf(impl)) {
    const Impl = @TypeOf(impl);
    const t_info = @typeInfo(Impl);

    switch (t_info) {
        .Struct => {
            if (@hasDecl(Impl, "StorageImpl") and Impl == Storage(Impl.StorageImpl)) {
                return Impl;
            }

            std.debug.assert(std.meta.trait.hasFunctions(Impl, .{ "read", "readIsComplete", "write", "writeIsComplete", "freeRead", "freeWrite" }));
            std.debug.assert(std.meta.trait.hasDecls(Impl, .{ "ReadHandle", "WriteHandle" }));
        },
        .Pointer => |ptr_info| {
            if (@hasDecl(ptr_info.child, "StorageImpl") and Impl == Storage(ptr_info.child.StorageImpl)) {
                return Impl;
            }

            std.debug.assert(std.meta.trait.hasFunctions(ptr_info.child, .{ "read", "readIsComplete", "write", "writeIsComplete", "freeRead", "freeWrite" }));
            std.debug.assert(std.meta.trait.hasDecls(ptr_info.child, .{ "ReadHandle", "WriteHandle" }));
        },
        else => unreachable,
    }

    return Storage(Impl){
        .impl = impl,
    };
}

pub const LinearMemStorage = struct {
    bytes: std.ArrayList(u8),

    // Just put the number of bytes read in the handle; hope no one passes something invalid in.
    pub const ReadHandle = usize;
    pub const WriteHandle = usize;

    pub fn init(allocator: std.mem.Allocator) @This() {
        return @This(){
            .bytes = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(this: @This()) void {
        this.bytes.deinit();
    }

    pub fn read(this: @This(), pos64: u64, to_buf: []u8) !ReadHandle {
        const pos = @intCast(usize, pos64);

        const available_bytes = this.bytes.items.len -| pos;
        const bytes_read = std.math.min(available_bytes, to_buf.len);

        std.mem.copy(u8, to_buf, this.bytes.items[pos..][0..bytes_read]);

        return bytes_read;
    }

    pub fn readIsComplete(this: @This(), read_handle: ReadHandle) !?usize {
        std.debug.assert(read_handle <= this.bytes.items.len);

        // handle should be the number of bytes read
        return read_handle;
    }

    pub fn freeRead(this: @This(), read_handle: ReadHandle) void {
        std.debug.assert(read_handle <= this.bytes.items.len);
    }

    pub fn write(this: *@This(), pos64: u64, from_buf: []const u8) !WriteHandle {
        const pos = @intCast(usize, pos64);

        const required_len = std.math.max(this.bytes.items.len, pos + from_buf.len);
        try this.bytes.resize(required_len);

        std.mem.copy(u8, this.bytes.items[pos..][0..from_buf.len], from_buf);

        return from_buf.len;
    }

    pub fn writeIsComplete(this: @This(), write_handle: WriteHandle) !?usize {
        std.debug.assert(write_handle <= this.bytes.items.len);

        // handle should be the number of bytes read
        return write_handle;
    }

    pub fn freeWrite(this: @This(), write_handle: WriteHandle) void {
        std.debug.assert(write_handle <= this.bytes.items.len);
    }

    pub fn storage(this: *@This()) Storage(*@This()) {
        return asStorage(this);
    }
};

test "asStorage doesn't double wrap" {
    var mem = LinearMemStorage.init(std.testing.allocator);
    defer mem.deinit();

    try std.testing.expectEqual(@TypeOf(mem.storage()), @TypeOf(asStorage(mem.storage())));
}
