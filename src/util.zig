const seizer = @import("seizer");
const Veci = seizer.math.Vec(2, isize);
const veci = Veci.init;
const Vec = seizer.math.Vec(2, usize);
const vec = Vec.init;

pub fn contains(size: Vec, point: Veci) bool {
    return point.x >= 0 and point.y >= 0 and point.x < size.x and point.y < size.y;
}

pub fn vec2i(size: Vec, pos: Veci) ?usize {
    return if (contains(size, pos)) @intCast(usize, pos.x) + (size.x * @intCast(usize, pos.y)) else null;
}

pub fn i2vec(size: Vec, i: usize) ?Veci {
    return if (i < size.x * size.y) veci(@intCast(isize, i % size.x), @intCast(isize, i / size.x)) else null;
}
