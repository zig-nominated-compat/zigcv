const std = @import("std");
const cv = @import("zigcv");
const cv_c_api = cv.c_api;

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    const prog = args.next();
    const device_id_char = args.next() orelse {
        std.log.err("usage: {s} [cameraID]", .{prog.?});
        std.posix.exit(1);
    };
    args.deinit();

    const device_id = try std.fmt.parseUnsigned(c_int, device_id_char, 10);

    // open webcam
    var webcam = try cv.VideoCapture.init();
    try webcam.openDevice(device_id);
    defer webcam.deinit();

    // open display window
    const window_name = "Face Detect";
    var window = try cv.Window.init(window_name);
    defer window.deinit();

    // prepare image matrix
    var img = try cv.Mat.init();
    defer img.deinit();

    // load classifier to recognize faces
    var classifier = try cv.CascadeClassifier.init();
    defer classifier.deinit();

    classifier.load("./data/haarcascade_frontalface_default.xml") catch {
        std.debug.print("no xml", .{});
        std.posix.exit(1);
    };

    const blue = cv.Color{ .b = 255 };
    while (true) {
        webcam.read(&img) catch {
            std.debug.print("capture failed", .{});
            std.posix.exit(1);
        };
        if (img.isEmpty()) {
            continue;
        }
        const rects = try classifier.detectMultiScale(img, allocator);
        defer rects.deinit();
        const found_num = rects.items.len;
        std.debug.print("found {d} faces\n", .{found_num});
        for (rects.items) |r| {
            std.debug.print("x:\t{}, y:\t{}, w:\t{}, h:\t{}\n", .{ r.x, r.y, r.width, r.height });
            cv.rectangle(&img, r, blue, 3);
        }

        window.imShow(img);
        if (window.waitKey(1) >= 0) {
            break;
        }
    }
}
