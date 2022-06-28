// Marching cubes algorithm is based on this work
// http://graphics.cs.uh.edu/wp-content/papers/2014/2014-TVC-GPUPolygonization.pdf

const native_endian = @import("builtin").target.cpu.arch.endian();

const std = @import("std");
const nyan = @import("nyancore");
const nc = nyan.c;
const nm = nyan.Math;
const Global = @import("../global.zig");
const mc = @import("export_glb_marching_cubes.zig");

const Buffer = nyan.vkctxt.Buffer;

const scene2computeShader = @import("../scene/scene2shader.zig").scene2computeShader;

const file_path_len: usize = 256;
var selected_file_path: [file_path_len]u8 = [_]u8{0} ** file_path_len;

const ExportSettings = struct {
    min_pos: nm.vec3,
    max_pos: nm.vec3,
    resolution: [3]u32,
    precision_steps: u32,
    precision: f32,
};

var export_settings: ExportSettings = .{
    .min_pos = @splat(3, @as(f32, -1.0)),
    .max_pos = @splat(3, @as(f32, 1.0)),
    .resolution = .{100} ** 3,
    .precision_steps = 256,
    .precision = 0.001,
};

const smoothing_iterations = 3;

const Vertex = struct {
    pos: nm.vec4,
    col: nm.vec4,
    nor: nm.vec4,
};

const SmoothingPushConstant = struct {
    step: i32,
    buffer_to_write: i32,
};

const shader_export_compute_layout_header: []const u8 =
    \\layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;
    \\struct Vertex {
    \\  vec3 pos;
    \\  vec3 col;
    \\  vec3 nor;
    \\};
    \\layout(set = 0, binding = 0) buffer VertexBuffer {
    \\  Vertex v[];
    \\} vertexBuffer;
    \\
    \\layout(set = 0, binding = 1) buffer VertexInsideBuffer {
    \\  uint ind[];
    \\} vertexInsideBuffer;
    \\
;

const shader_export_compute_defines: []const u8 =
    \\
    \\#define MIN_POS vec3({d},{d},{d})
    \\#define CELL_SIZE vec3({d},{d},{d})
    \\#define CELL_COUNT_X {d}
    \\#define CELL_COUNT_Y {d}
    \\#define CELL_COUNT_Z {d}
    \\#define EDGE_COUNT {d}
    \\#define PRECISION_STEPS {d}
    \\#define PRECISION {d}
    \\
    \\{s}
    \\
;

const shader_export_compute_main_func: []const u8 =
    \\void main() {
    \\  if (gl_GlobalInvocationID.x > EDGE_COUNT) return;
    \\
    \\  uint idx = gl_GlobalInvocationID.x / 3;
    \\  uint edge_idx = gl_GlobalInvocationID.x % 3;
    \\  uint a = CELL_COUNT_X * CELL_COUNT_Y;
    \\  vec3 iv;
    \\  iv.z = float(idx / a);
    \\  a = idx % a;
    \\  iv.y = float(a / CELL_COUNT_X);
    \\  iv.x = float(a % CELL_COUNT_X);
    \\
    \\  vec3 start_pos = MIN_POS + CELL_SIZE * iv;
    \\  vec3 dir = vec3(0.);
    \\  dir[edge_idx] = 1.;
    \\  float side_size = CELL_SIZE[edge_idx];
    \\  vec3 end_pos = start_pos + dir * CELL_SIZE;
    \\
    \\  float ssp = sign(map(start_pos));
    \\  float sep = sign(map(end_pos));
    \\
    \\  if (edge_idx == 0) {
    \\      if (iv.x == CELL_COUNT_X - 1 || iv.x == 0 ||
    \\              iv.y == CELL_COUNT_Y - 1 || iv.y == 0 ||
    \\              iv.z == CELL_COUNT_Z - 1 || iv.z == 0) {
    \\          vertexInsideBuffer.ind[gl_GlobalInvocationID.x] = 0;
    \\      } else
    \\          vertexInsideBuffer.ind[gl_GlobalInvocationID.x] = uint(ssp < 0.);
    \\  }
    \\
    \\  if (ssp < 0.) {
    \\      vec3 t = start_pos;
    \\      start_pos = end_pos;
    \\      end_pos = t;
    \\      dir *= -1.;
    \\  }
    \\
    \\  float t = 0.;
    \\  for (int i = 0; i < PRECISION_STEPS; i++) {
    \\      vec3 p = start_pos + t * dir;
    \\      float h = map(p);
    \\      if (h < PRECISION || abs(t + h) > side_size) break;
    \\      t += h;
    \\  }
    \\
    \\  vec3 pos = start_pos + t * dir;
    \\  vec3 nor = calcNormal(pos);
    \\  vec3 lig = normalize(ENVIRONMENT_LIGHT_DIR);
    // For now color is calculated as if we are looking towards z direction
    \\  vec3 col = matMap(pos, lig, nor, vec3(0.,0.,1.));
    \\
    \\  vertexBuffer.v[gl_GlobalInvocationID.x].pos = pos;
    \\  vertexBuffer.v[gl_GlobalInvocationID.x].col = col;
    \\  vertexBuffer.v[gl_GlobalInvocationID.x].nor = nor;
    \\}
    \\
;

fn getVertexCount() u32 {
    return (export_settings.resolution[0] + 2) * (export_settings.resolution[1] + 2) * (export_settings.resolution[2] + 2);
}

fn getEdgeCount() u32 {
    return getVertexCount() * 3;
}

fn edge2index(triangle: []u32, x: u32, y: u32, z: u32, resX: u32, resYX: u32) void {
    for (triangle) |*v| {
        v.* = switch (v.*) {
            0 => 3 * ((z + 1) * resYX + y * resX + x),
            1 => 3 * (z * resYX + y * resX + x + 1) + 2,
            2 => 3 * (z * resYX + y * resX + x),
            3 => 3 * (z * resYX + y * resX + x) + 2,
            4 => 3 * ((z + 1) * resYX + (y + 1) * resX + x),
            5 => 3 * (z * resYX + (y + 1) * resX + x + 1) + 2,
            6 => 3 * (z * resYX + (y + 1) * resX + x),
            7 => 3 * (z * resYX + (y + 1) * resX + x) + 2,
            8 => 3 * ((z + 1) * resYX + y * resX + x) + 1,
            9 => 3 * ((z + 1) * resYX + y * resX + x + 1) + 1,
            10 => 3 * (z * resYX + y * resX + x + 1) + 1,
            11 => 3 * (z * resYX + y * resX + x) + 1,
            else => unreachable,
        };
    }
}

fn marchingCubes(vertex_inside_buffer: *Buffer, indices: []u32, indices_size: *usize) void {
    const resX: u32 = export_settings.resolution[0] + 2;
    const resYX: u32 = resX * (export_settings.resolution[1] + 2);

    var index_count: usize = 0;

    var vertex_inside: [*]u32 = @ptrCast([*]u32, @alignCast(@alignOf(u32), vertex_inside_buffer.mapped_memory));

    var z: u32 = 1;
    while (z < export_settings.resolution[2] + 1) : (z += 1) {
        var y: u32 = 1;
        while (y < export_settings.resolution[1] + 1) : (y += 1) {
            var x: u32 = 1;
            while (x < export_settings.resolution[0] + 1) : (x += 1) {
                var verts: u32 = 0;
                var temp: u32 = undefined;

                temp = vertex_inside[3 * ((z + 1) * resYX + y * resX + x)];
                verts ^= (-%temp ^ verts) & (1 << 0);

                temp = vertex_inside[3 * ((z + 1) * resYX + y * resX + x + 1)];
                verts ^= (-%temp ^ verts) & (1 << 1);

                temp = vertex_inside[3 * (z * resYX + y * resX + x + 1)];
                verts ^= (-%temp ^ verts) & (1 << 2);

                temp = vertex_inside[3 * (z * resYX + y * resX + x)];
                verts ^= (-%temp ^ verts) & (1 << 3);

                temp = vertex_inside[3 * ((z + 1) * resYX + (y + 1) * resX + x)];
                verts ^= (-%temp ^ verts) & (1 << 4);

                temp = vertex_inside[3 * ((z + 1) * resYX + (y + 1) * resX + x + 1)];
                verts ^= (-%temp ^ verts) & (1 << 5);

                temp = vertex_inside[3 * (z * resYX + (y + 1) * resX + x + 1)];
                verts ^= (-%temp ^ verts) & (1 << 6);

                temp = vertex_inside[3 * (z * resYX + (y + 1) * resX + x)];
                verts ^= (-%temp ^ verts) & (1 << 7);

                var i: usize = 0;
                while (mc.triTable[verts][i] != -1) : (i += 3) {
                    indices[index_count] = @intCast(u32, mc.triTable[verts][i]);
                    indices[index_count + 1] = @intCast(u32, mc.triTable[verts][i + 1]);
                    indices[index_count + 2] = @intCast(u32, mc.triTable[verts][i + 2]);

                    edge2index(indices[index_count .. index_count + 3], x, y, z, resX, resYX);
                    index_count += 3;
                }
            }
        }
    }

    indices_size.* = index_count;
}

fn reduce(vertex_buffer: *Buffer, vertex_inside_buffer: *Buffer, indices: []u32, vertices: *[]Vertex) void {
    const resX: u32 = export_settings.resolution[0] + 2;
    const resYX: u32 = resX * (export_settings.resolution[1] + 2);

    var vertex_inside: [*]u32 = @ptrCast([*]u32, @alignCast(@alignOf(u32), vertex_inside_buffer.mapped_memory));
    var vertex_buffer_memory: [*]Vertex = @ptrCast([*]Vertex, @alignCast(@alignOf(Vertex), vertex_buffer.mapped_memory));

    const edge_count: u32 = getEdgeCount();
    @memset(@ptrCast([*]u8, vertex_inside), 0, edge_count * @sizeOf(u32));

    var vertex_count: u32 = 0;
    var i: usize = 0;
    while (i < indices.len) : (i += 1) {
        if (vertex_inside[indices[i]] == 0) {
            vertex_inside[indices[i]] = vertex_count + 1;
            indices[i] = vertex_count;
            vertex_count += 1;
        } else {
            indices[i] = vertex_inside[indices[i]] - 1;
        }
    }

    vertices.* = nyan.app.allocator.alloc(Vertex, vertex_count) catch unreachable;

    var z: u32 = 1;
    while (z < export_settings.resolution[2] + 1) : (z += 1) {
        var y: u32 = 1;
        while (y < export_settings.resolution[1] + 1) : (y += 1) {
            var x: u32 = 1;
            while (x < export_settings.resolution[0] + 1) : (x += 1) {
                i = 3 * (z * resYX + y * resX + x);
                var j: u32 = 0;
                while (j < 3) : (j += 1) {
                    if (vertex_inside[i + j] > 0) {
                        var vertex_index: u32 = vertex_inside[i + j] - 1;
                        vertices.*[vertex_index] = vertex_buffer_memory[i + j];
                    }
                }
            }
        }
    }
}

fn writeToFile(writer: anytype, data: []const u8) std.os.WriteError!void {
    if (native_endian == std.builtin.Endian.Little) {
        try writer.writeAll(data);
        return;
    }

    for (std.mem.bytesAsSlice([]u32, data)) |v|
        try writer.writeIntLittle(u32, v);
}

fn writeToFilePadded(writer: anytype, data: []const u8, padding: usize) std.os.WriteError!void {
    try writeToFile(writer, data[0 .. data.len - data.len % 4]);

    if (padding == 0)
        return;

    try writer.writeAll(data[data.len .. data.len + 4 - padding]);
    try writer.writeByteNTimes(0x20, padding);
}

fn writeToFilePadded2(writer: anytype, data0: []const u8, data1: []const u8, padding: usize) std.os.WriteError!void {
    try writeToFile(writer, data0[0 .. data0.len - data0.len % 4]);

    const tail: usize = data0.len % 4;
    var offset: usize = 0;
    if (tail > 0) {
        var temp: u32 = undefined;
        var temp_buf: *[4]u8 = std.mem.asBytes(&temp);

        var i: usize = 0;
        while (i < tail) : (i += 1)
            temp_buf[i] = data0[(data0.len - data0.len % 4) + i];
        while (i < 4) : (i += 1)
            temp_buf[i] = data1[i - tail];

        try writer.writeIntLittle(u32, temp);

        offset = 4 - tail;
    }

    try writeToFilePadded(writer, data1[offset..data1.len], padding);
}

fn addNeighbour(neighbours: []u32, vertex: usize) void {
    neighbours[0] += 1;
    neighbours[neighbours[0]] = @intCast(u32, vertex);
}

fn removeNeighbour(neighbours: []u32, vertex: u32) void {
    var index: i32 = -1;
    var i: usize = 0;
    while (i < neighbours[0]) : (i += 1) {
        if (neighbours[1 + i] == vertex) {
            index = i;
            break;
        }
    }
    std.mem.copy(u32, neighbours[1 + index], neighbours[2 + index .. neighbours[0] + 1]);
    neighbours[0] -= 1;
}

fn buildConnectivity(vertices: []Vertex, indices: []u32, vertex_neighbours: []u32, face_neighbours: []u32, vertex_boundary: []u32) void {
    std.mem.set(u32, vertex_neighbours, 0);
    std.mem.set(u32, face_neighbours, 0);
    std.mem.set(u32, vertex_boundary, 0);

    var f: usize = 0;
    while (f < indices.len) : (f += 3) {
        const v1: u32 = indices[f];
        const v2: u32 = indices[f + 1];
        const v3: u32 = indices[f + 2];

        addNeighbour(vertex_neighbours[v2 * 17 .. (v2 + 1) * 17], v1);
        addNeighbour(vertex_neighbours[v3 * 17 .. (v3 + 1) * 17], v2);
        addNeighbour(vertex_neighbours[v1 * 17 .. (v1 + 1) * 17], v3);

        addNeighbour(face_neighbours[v1 * 13 .. (v1 + 1) * 13], f);
        addNeighbour(face_neighbours[v2 * 13 .. (v2 + 1) * 13], f);
        addNeighbour(face_neighbours[v3 * 13 .. (v3 + 1) * 13], f);
    }

    for (vertices) |_, i| {
        var boundary: bool = false;
        var j: usize = 0;
        while (j < vertex_neighbours[i * 17]) : (j += 1) {
            const vj: u32 = vertex_neighbours[i * 17 + j + 1];
            var found: bool = false;
            var k: usize = 0;
            while (k < vertex_neighbours[vj * 17]) : (k += 1) {
                if (vertex_neighbours[vj * 17 + k + 1] == i) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                boundary = true;
                addNeighbour(vertex_neighbours[vj * 17 .. (vj + 1) * 17], i);
            }
        }
        vertex_boundary[i / 32] ^= (-%@as(u32, @boolToInt(boundary)) ^ vertex_boundary[i / 32]) & (@as(u32, 1) << @intCast(u5, i % 32));
    }
}

fn findFlipNeighbours(indices: []u32, face_neighbours: []u32, i: u32, j: u32, f1: *u32, f2: *u32, h: *u32, k: *u32) void {
    var f1_found: bool = false;
    var f2_found: bool = false;

    var f: usize = 0;
    while (f < face_neighbours[i * 13]) : (f += 1) {
        const fi: u32 = face_neighbours[i * 13 + f + 1];

        var offset: usize = 0;
        while (offset < 3) : (offset += 1) {
            if (indices[fi + offset] == j) {
                if (!f1_found) {
                    f1.* = fi;
                    f1_found = true;
                } else {
                    f2.* = fi;
                    f2_found = true;
                    break;
                }
            }
        }
        if (f2_found)
            break;
    }

    var offset: usize = 0;
    while (offset < 3) : (offset += 1) {
        const v: u32 = indices[f1.* + offset];
        if (v != i and v != j) {
            h.* = v;
            break;
        }
    }

    offset = 0;
    while (offset < 3) : (offset += 1) {
        const v: u32 = indices[f2.* + offset];
        if (v != i and v != j) {
            k.* = v;
            break;
        }
    }
}

fn valence(vertex_neighbours: []u32, vertex: usize) u32 {
    return vertex_neighbours[vertex * 17];
}

fn targetValence(vertex_boundary: []u32, vertex: usize) u32 {
    const boundary: u32 = (vertex_boundary[vertex / 32] >> (vertex % 32)) & 1;
    return if (boundary) 4 else 6;
}

fn swapTriangles(indices: []u32, vertex_neighbours: []u32, face_neighbours: []u32, f1: u32, f2: u32, i: u32, k: u32, j: u32, h: u32) void {
    var offset: u32 = 0;
    while (offset < 3) : (offset += 1) {
        if (indices[f1 + offset] == i)
            indices[f1 + offset] = k;
        if (indices[f2 + offset] == j)
            indices[f2 + offset] = h;
    }

    removeNeighbour(vertex_neighbours[i * 17 .. (i + 1) * 17], j);
    removeNeighbour(vertex_neighbours[j * 17 .. (j + 1) * 17], i);
    addNeighbour(vertex_neighbours[h * 17 .. (h + 1) * 17], k);
    addNeighbour(vertex_neighbours[k * 17 .. (k + 1) * 17], h);

    removeNeighbour(face_neighbours[i * 13 .. (i + 1) * 13], f1);
    removeNeighbour(face_neighbours[j * 13 .. (j + 1) * 13], f2);
    addNeighbour(face_neighbours[k * 13 .. (k + 1) * 13], f1);
    addNeighbour(face_neighbours[h * 13 .. (h + 1) * 13], f2);
}

fn flipEdges(vertices: []Vertex, indices: []u32, vertex_neighbours: []u32, face_neighbours: []u32, vertex_boundary: []u32) void {
    var h: u32 = undefined;
    var k: u32 = undefined;
    var f1: u32 = undefined;
    var f2: u32 = undefined;

    for (vertices) |_, i| {
        const neighbours: u32 = vertex_neighbours[i * 17];
        if (valence(vertex_neighbours, i) > targetValence(vertex_boundary, i)) {
            var nj: u32 = 0;
            while (nj < neighbours) : (nj += 1) {
                const j: u32 = vertex_neighbours[i * 17 + 1 + nj];
                findFlipNeighbours(indices, face_neighbours, i, j, &f1, &f2, &h, &k);
                var profit: u32 = 0;
                profit += valence(vertex_neighbours, j) > targetValence(vertex_boundary, j);
                profit += valence(vertex_neighbours, h) < targetValence(vertex_boundary, h);
                profit += valence(vertex_neighbours, k) < targetValence(vertex_boundary, k);
                if (profit >= 2) {
                    swapTriangles(vertices, indices, vertex_neighbours, face_neighbours, f1, f2, i, k, j, h);
                    break;
                }
            }
        }
    }
}

fn smoothIterations(vertices: []Vertex, vertex_neighbours: []u32) void {
    var vertices2: []Vertex = nyan.app.allocator.alloc(Vertex, vertices.len) catch unreachable;
    defer nyan.app.allocator.free(vertices2);

    var input: []Vertex = vertices;
    var output: []Vertex = vertices2;

    var i: usize = 0;
    while (i < smoothing_iterations) : (i += 1) {
        var v: usize = 0;
        while (v < vertices.len) : (v += 1) {
            var vi: Vertex = input[v];
            var vo: Vertex = output[v];

            const neighbours_count: u32 = vertex_neighbours[v * 17];
            var l: nm.vec4 = nm.Vec4.zeros();
            var j: usize = 0;
            while (j < neighbours_count) : (j += 1) {
                const n: Vertex = input[vertex_neighbours[v * 17 + 1 + j]];
                l += n.pos - vi.pos;
            }

            l *= @splat(4, 1.0 / @intToFloat(f32, neighbours_count));
            const dot: f32 = nm.Vec4.dot(l, vi.nor);
            vo.pos = vi.pos + l - vi.nor * @splat(4, dot);
        }

        var temp: []Vertex = input;
        input = output;
        output = temp;
    }

    if (output.ptr == vertices2.ptr)
        std.mem.copy(Vertex, vertices, vertices2);
}

fn export2gltf(vertices: []Vertex, indices: []u32) std.os.WriteError!void {
    const gltf_json: []const u8 =
        \\{{
        \\  "asset": {{
        \\      "version": "2.0",
        \\      "generator": "lamia"
        \\  }},
        \\  "nodes": [
        \\      {{
        \\          "name": "Lamia Model",
        \\          "mesh": 0
        \\      }}
        \\  ],
        \\  "scenes": [
        \\      {{
        \\          "name": "Lamia Scene",
        \\          "nodes": [
        \\              0
        \\          ]
        \\      }}
        \\  ],
        \\  "scene": 0,
        \\  "buffers": [
        \\      {{
        \\          "byteLength": {d}
        \\      }}
        \\  ],
        \\  "bufferViews": [
        \\      {{
        \\          "buffer": 0,
        \\          "byteLength": {d},
        \\          "buteOffset": 0,
        \\          "target": 34963
        \\      }},
        \\      {{
        \\          "buffer": 0,
        \\          "byteLength": {d},
        \\          "byteOffset": {d},
        \\          "byteStride": {d},
        \\          "target": 34962
        \\      }}
        \\  ],
        \\  "accessors": [
        \\      {{
        \\          "bufferView": 0,
        \\          "byteOffset": 0,
        \\          "componentType": 5125,
        \\          "count": {d},
        \\          "type": "SCALAR"
        \\      }},
        \\      {{
        \\          "bufferView": 1,
        \\          "byteOffset": {d},
        \\          "componentType": 5126,
        \\          "count": {d},
        \\          "max": [
        \\              {d:.16},
        \\              {d:.16},
        \\              {d:.16}
        \\          ],
        \\          "min": [
        \\              {d:.16},
        \\              {d:.16},
        \\              {d:.16}
        \\          ],
        \\          "type": "VEC3"
        \\      }},
        \\      {{
        \\          "bufferView": 1,
        \\          "byteOffset": {d},
        \\          "componentType": 5126,
        \\          "count": {d},
        \\          "type": "VEC3"
        \\      }},
        \\      {{
        \\          "bufferView": 1,
        \\          "byteOffset": {d},
        \\          "componentType": 5126,
        \\          "count": {d},
        \\          "type": "VEC3"
        \\      }}
        \\  ],
        \\  "meshes": [
        \\      {{
        \\          "name": "Lamia Mesh",
        \\          "primitives": [
        \\              {{
        \\                  "attributes": {{
        \\                      "NORMAL": 3,
        \\                      "POSITION": 1,
        \\                      "COLOR_0": 2
        \\                  }},
        \\                  "indices": 0
        \\              }}
        \\          ]
        \\      }}
        \\  ]
        \\}}
        \\
    ;

    const indices_size: u32 = @intCast(u32, indices.len) * @sizeOf(u32);
    const vertices_size: u32 = @intCast(u32, vertices.len) * @sizeOf(Vertex);

    var real_min_pos: nm.vec4 = vertices[0].pos;
    var real_max_pos: nm.vec4 = vertices[0].pos;

    for (vertices) |v| {
        real_min_pos = @minimum(real_min_pos, v.pos);
        real_max_pos = @maximum(real_max_pos, v.pos);
    }

    const json_chunk_data: []const u8 = std.fmt.allocPrint(nyan.app.allocator, gltf_json, .{
        indices_size + vertices_size,
        indices_size,
        vertices_size,
        indices_size,
        @sizeOf(Vertex),
        indices.len,
        0,
        vertices.len,
        real_max_pos[0],
        real_max_pos[1],
        real_max_pos[2],
        real_min_pos[0],
        real_min_pos[1],
        real_min_pos[2],
        @sizeOf(nm.vec4),
        vertices.len,
        @sizeOf(nm.vec4) * 2,
        vertices.len,
    }) catch unreachable;
    defer nyan.app.allocator.free(json_chunk_data);

    const json_chunk_type: u32 = 0x4E4F534A;
    const json_chunk_length: u32 = @intCast(u32, json_chunk_data.len);
    const json_chunk_padding: u32 = (4 - json_chunk_length % 4) % 4;

    const buffer_chunk_type: u32 = 0x004E4942;
    const buffer_chunk_length: u32 = indices_size + vertices_size;
    const buffer_chunk_padding: u32 = (4 - json_chunk_length % 4) % 4;

    const cwd: std.fs.Dir = std.fs.cwd();
    const file: std.fs.File = cwd.createFile(std.mem.sliceTo(&selected_file_path, 0), .{ .read = true, .truncate = true }) catch {
        nyan.printErrorNoPanic("ExportMesh", "Can't create file for mesh export");
        return;
    };
    defer file.close();
    const writer = file.writer();

    // Header
    const gltf_header: [3]u32 = .{ 0x46546C67, 2, @sizeOf(u32) * 7 + json_chunk_length + json_chunk_padding + buffer_chunk_length + buffer_chunk_padding };
    try writeToFile(&writer, std.mem.sliceAsBytes(gltf_header[0..]));

    // Json Chunk
    const json_header: [2]u32 = .{ json_chunk_length + json_chunk_padding, json_chunk_type };
    try writeToFile(&writer, std.mem.sliceAsBytes(json_header[0..]));
    try writeToFilePadded(&writer, json_chunk_data, json_chunk_padding);

    // Buffer Chunk
    const buffer_header: [2]u32 = .{ buffer_chunk_length + buffer_chunk_padding, buffer_chunk_type };
    try writeToFile(&writer, std.mem.sliceAsBytes(buffer_header[0..]));
    try writeToFilePadded2(&writer, std.mem.sliceAsBytes(indices), std.mem.sliceAsBytes(vertices), buffer_chunk_padding);
}

fn exportToMesh() void {
    const buffer_usage_flags: nyan.vk.BufferUsageFlags = .{ .storage_buffer_bit = true };
    const buffer_mem_flags: nyan.vk.MemoryPropertyFlags = .{ .host_visible_bit = true, .host_coherent_bit = true };

    const edge_count: u32 = getEdgeCount();

    var vertex_buffer: Buffer = undefined;
    vertex_buffer.init(edge_count * @sizeOf(Vertex), buffer_usage_flags, buffer_mem_flags);
    defer vertex_buffer.destroy();

    var vertex_inside_buffer: Buffer = undefined;
    vertex_inside_buffer.init(edge_count * @sizeOf(u32), buffer_usage_flags, buffer_mem_flags);
    defer vertex_inside_buffer.destroy();

    var cell_size: nm.vec3 = export_settings.max_pos - export_settings.min_pos;
    cell_size[0] /= @intToFloat(f32, export_settings.resolution[0]);
    cell_size[1] /= @intToFloat(f32, export_settings.resolution[1]);
    cell_size[2] /= @intToFloat(f32, export_settings.resolution[2]);

    const shader_buf: []const u8 = std.fmt.allocPrint(nyan.app.allocator, shader_export_compute_defines, .{
        export_settings.min_pos[0] - cell_size[0],
        export_settings.min_pos[1] - cell_size[1],
        export_settings.min_pos[2] - cell_size[2],
        cell_size[0],
        cell_size[1],
        cell_size[2],
        export_settings.resolution[0] + 2,
        export_settings.resolution[1] + 2,
        export_settings.resolution[2] + 2,
        edge_count,
        export_settings.precision_steps,
        export_settings.precision,
        shader_export_compute_main_func,
    }) catch unreachable;
    defer nyan.app.allocator.free(shader_buf);

    const extract_shader: nyan.vk.ShaderModule = scene2computeShader(
        &Global.main_scene,
        &Global.main_scene.settings,
        shader_export_compute_layout_header,
        shader_buf,
    );
    defer nyan.vkfn.d.destroyShaderModule(nyan.vkctxt.device, extract_shader, null);

    const descriptor_pool: nyan.vk.DescriptorPool = createDescriptorPool();
    defer nyan.vkfn.d.destroyDescriptorPool(nyan.vkctxt.device, descriptor_pool, null);
    const descriptor_set_layout: nyan.vk.DescriptorSetLayout = createDescriptorSetLayout();
    defer nyan.vkfn.d.destroyDescriptorSetLayout(nyan.vkctxt.device, descriptor_set_layout, null);
    const descriptor_set: nyan.vk.DescriptorSet = allocateDescriptorSet(descriptor_pool, descriptor_set_layout, &vertex_buffer, &vertex_inside_buffer);

    const pipeline_cache: nyan.vk.PipelineCache = createPipelineCache();
    defer nyan.vkfn.d.destroyPipelineCache(nyan.vkctxt.device, pipeline_cache, null);
    const pipeline_layout: nyan.vk.PipelineLayout = createPipelineLayout(descriptor_set_layout);
    defer nyan.vkfn.d.destroyPipelineLayout(nyan.vkctxt.device, pipeline_layout, null);
    const extract_pipeline: nyan.vk.Pipeline = createComputePipeline(pipeline_cache, pipeline_layout, extract_shader);
    defer nyan.vkfn.d.destroyPipeline(nyan.vkctxt.device, extract_pipeline, null);

    const command_buffer: nyan.vk.CommandBuffer = nyan.global_render_graph.allocateCommandBuffer();
    nyan.RenderGraph.beginSingleTimeCommands(command_buffer);

    nyan.vkfn.d.cmdBindDescriptorSets(
        command_buffer,
        .compute,
        pipeline_layout,
        0,
        1,
        @ptrCast([*]const nyan.vk.DescriptorSet, &descriptor_set),
        0,
        undefined,
    );
    nyan.vkfn.d.cmdBindPipeline(command_buffer, .compute, extract_pipeline);

    nyan.vkfn.d.cmdDispatch(command_buffer, (edge_count / 128) + 1, 1, 1);

    nyan.RenderGraph.endSingleTimeCommands(command_buffer);
    nyan.global_render_graph.submitCommandBuffer(command_buffer);

    var indices: []u32 = nyan.app.allocator.alloc(u32, getVertexCount() * 15) catch unreachable;
    defer nyan.app.allocator.free(indices);
    var indices_count: usize = undefined;
    var vertices: []Vertex = undefined;

    marchingCubes(&vertex_inside_buffer, indices, &indices_count);
    indices = nyan.app.allocator.realloc(indices, indices_count) catch unreachable;
    reduce(&vertex_buffer, &vertex_inside_buffer, indices, &vertices);
    defer nyan.app.allocator.free(vertices);

    var vertex_neighbours: []u32 = nyan.app.allocator.alloc(u32, vertices.len * 17) catch unreachable;
    defer nyan.app.allocator.free(vertex_neighbours);
    var face_neighbours: []u32 = nyan.app.allocator.alloc(u32, vertices.len * 13) catch unreachable;
    defer nyan.app.allocator.free(face_neighbours);
    var vertex_boundary: []u32 = nyan.app.allocator.alloc(u32, vertices.len / 32 + @boolToInt(vertices.len % 32 != 0)) catch unreachable;
    defer nyan.app.allocator.free(vertex_boundary);
    buildConnectivity(vertices, indices, vertex_neighbours, face_neighbours, vertex_boundary);

    smoothIterations(vertices, vertex_neighbours);

    export2gltf(vertices, indices) catch {
        nyan.printErrorNoPanic("ExportGlb", "Couldn't export gltf");
    };
}

fn createDescriptorPool() nyan.vk.DescriptorPool {
    const pool_size: nyan.vk.DescriptorPoolSize = .{
        .type = .storage_buffer,
        .descriptor_count = 2,
    };

    const descriptor_pool_info: nyan.vk.DescriptorPoolCreateInfo = .{
        .pool_size_count = 1,
        .p_pool_sizes = @ptrCast([*]const nyan.vk.DescriptorPoolSize, &pool_size),
        .max_sets = 1,
        .flags = .{},
    };

    return nyan.vkfn.d.createDescriptorPool(nyan.vkctxt.device, descriptor_pool_info, null) catch |err| {
        nyan.printVulkanError("Couldn't create descriptor pool for mesh export", err);
        return undefined;
    };
}

fn createDescriptorSetLayout() nyan.vk.DescriptorSetLayout {
    const set_layout_bindings: [2]nyan.vk.DescriptorSetLayoutBinding = .{
        .{
            .stage_flags = .{ .compute_bit = true },
            .binding = 0,
            .descriptor_count = 1,
            .descriptor_type = .storage_buffer,
            .p_immutable_samplers = undefined,
        },
        .{
            .stage_flags = .{ .compute_bit = true },
            .binding = 1,
            .descriptor_count = 1,
            .descriptor_type = .storage_buffer,
            .p_immutable_samplers = undefined,
        },
    };

    const set_layout_create_info: nyan.vk.DescriptorSetLayoutCreateInfo = .{
        .binding_count = 2,
        .p_bindings = @ptrCast([*]const nyan.vk.DescriptorSetLayoutBinding, &set_layout_bindings),
        .flags = .{},
    };

    return nyan.vkfn.d.createDescriptorSetLayout(nyan.vkctxt.device, set_layout_create_info, null) catch |err| {
        nyan.printVulkanError("Can't create descriptor set layout for mesh export", err);
        return undefined;
    };
}

fn allocateDescriptorSet(descriptor_pool: nyan.vk.DescriptorPool, descriptor_set_layout: nyan.vk.DescriptorSetLayout, vertex_buffer: *Buffer, vertex_inside_buffer: *Buffer) nyan.vk.DescriptorSet {
    var descriptor_set: nyan.vk.DescriptorSet = undefined;

    const descriptor_set_allocate_info: nyan.vk.DescriptorSetAllocateInfo = .{
        .descriptor_pool = descriptor_pool,
        .p_set_layouts = @ptrCast([*]const nyan.vk.DescriptorSetLayout, &descriptor_set_layout),
        .descriptor_set_count = 1,
    };

    nyan.vkfn.d.allocateDescriptorSets(nyan.vkctxt.device, descriptor_set_allocate_info, @ptrCast([*]nyan.vk.DescriptorSet, &descriptor_set)) catch |err| {
        nyan.printVulkanError("Can't allocate descriptor set for mesh export", err);
    };

    const vrt_buffer_info: nyan.vk.DescriptorBufferInfo = .{
        .buffer = vertex_buffer.buffer,
        .offset = 0,
        .range = nyan.vk.WHOLE_SIZE,
    };

    const vrt_index_buffer_info: nyan.vk.DescriptorBufferInfo = .{
        .buffer = vertex_inside_buffer.buffer,
        .offset = 0,
        .range = nyan.vk.WHOLE_SIZE,
    };

    const write_descriptor_set: [2]nyan.vk.WriteDescriptorSet = .{
        .{
            .dst_set = descriptor_set,
            .descriptor_type = .storage_buffer,
            .dst_binding = 0,
            .p_buffer_info = @ptrCast([*]const nyan.vk.DescriptorBufferInfo, &vrt_buffer_info),
            .descriptor_count = 1,
            .p_image_info = undefined,
            .p_texel_buffer_view = undefined,
            .dst_array_element = 0,
        },
        .{
            .dst_set = descriptor_set,
            .descriptor_type = .storage_buffer,
            .dst_binding = 1,
            .p_buffer_info = @ptrCast([*]const nyan.vk.DescriptorBufferInfo, &vrt_index_buffer_info),
            .descriptor_count = 1,
            .p_image_info = undefined,
            .p_texel_buffer_view = undefined,
            .dst_array_element = 0,
        },
    };

    nyan.vkfn.d.updateDescriptorSets(nyan.vkctxt.device, 2, @ptrCast([*]const nyan.vk.WriteDescriptorSet, &write_descriptor_set), 0, undefined);
    return descriptor_set;
}

fn createPipelineCache() nyan.vk.PipelineCache {
    const pipeline_cache_create_info: nyan.vk.PipelineCacheCreateInfo = .{
        .flags = .{},
        .initial_data_size = 0,
        .p_initial_data = undefined,
    };

    return nyan.vkfn.d.createPipelineCache(nyan.vkctxt.device, pipeline_cache_create_info, null) catch |err| {
        nyan.printVulkanError("Can't create pipeline cache for mesh export", err);
        return undefined;
    };
}

fn createPipelineLayout(descriptor_set_layout: nyan.vk.DescriptorSetLayout) nyan.vk.PipelineLayout {
    const pipeline_layout_create_info: nyan.vk.PipelineLayoutCreateInfo = .{
        .set_layout_count = 1,
        .p_set_layouts = @ptrCast([*]const nyan.vk.DescriptorSetLayout, &descriptor_set_layout),
        .push_constant_range_count = 0,
        .p_push_constant_ranges = undefined,
        .flags = .{},
    };

    return nyan.vkfn.d.createPipelineLayout(nyan.vkctxt.device, pipeline_layout_create_info, null) catch |err| {
        nyan.printVulkanError("Can't create pipeline layout for mesh export", err);
        return undefined;
    };
}

fn createComputePipeline(pipeline_cache: nyan.vk.PipelineCache, pipeline_layout: nyan.vk.PipelineLayout, shader: nyan.vk.ShaderModule) nyan.vk.Pipeline {
    const info: nyan.vk.ComputePipelineCreateInfo = .{
        .flags = .{},
        .stage = .{
            .flags = .{},
            .stage = .{ .compute_bit = true },
            .module = shader,
            .p_name = "main",
            .p_specialization_info = null,
        },
        .layout = pipeline_layout,

        .base_pipeline_handle = undefined,
        .base_pipeline_index = 0,
    };

    var pipeline: nyan.vk.Pipeline = undefined;
    _ = nyan.vkfn.d.createComputePipelines(
        nyan.vkctxt.device,
        pipeline_cache,
        1,
        @ptrCast([*]const nyan.vk.ComputePipelineCreateInfo, &info),
        null,
        @ptrCast([*]nyan.vk.Pipeline, &pipeline),
    ) catch |err| {
        nyan.printVulkanError("Can't create pipeline for mesh export", err);
    };

    return pipeline;
}

pub fn drawExportGlbDialog() void {
    var close_modal: bool = true;
    if (nc.igBeginPopupModal("Export to GLB Mesh", &close_modal, nc.ImGuiWindowFlags_None)) {
        _ = nc.igInputFloat3("Min Point", @ptrCast([*c]f32, &export_settings.min_pos), "%.3f", nc.ImGuiInputTextFlags_None);
        _ = nc.igInputFloat3("Max Point", @ptrCast([*c]f32, &export_settings.max_pos), "%.3f", nc.ImGuiInputTextFlags_None);
        _ = nc.igInputScalarN("Resolution", nc.ImGuiDataType_U32, &export_settings.resolution, 3, null, null, "%u", nc.ImGuiInputTextFlags_None);
        _ = nc.igInputScalar("Precision Ray Steps", nc.ImGuiDataType_U32, &export_settings.precision_steps, null, null, "%u", nc.ImGuiInputTextFlags_None);
        _ = nc.igInputFloat("Precision", &export_settings.precision, 0.0, 0.0, "%.3f", nc.ImGuiInputTextFlags_None);

        if (nc.igInputText("Path", @ptrCast([*c]u8, &selected_file_path), file_path_len, nc.ImGuiInputTextFlags_EnterReturnsTrue, null, null)) {
            exportToMesh();
            nc.igCloseCurrentPopup();
        }

        if (nc.igButton("Export", .{ .x = 0, .y = 0 })) {
            exportToMesh();
            nc.igCloseCurrentPopup();
        }

        nc.igSameLine(200.0, 2.0);
        if (nc.igButton("Cancel", .{ .x = 0, .y = 0 }))
            nc.igCloseCurrentPopup();

        nc.igEndPopup();
    }
}
