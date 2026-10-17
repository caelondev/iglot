pub const IglotValue = union(enum) {
    int: i64,
    wideint: i128,
    float: f32,
    double: f64,
    bool: u1,
    func: u32,
    heap_ref: usize,
};
