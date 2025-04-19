const std = @import("std");
const cv = @import("zigcv");

const blue = cv.Color{ .b = 255 };

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    const prog = args.next();
    const device_id_char = args.next() orelse {
        std.log.err("usage: {s} [cameraID]", .{prog.?});
        std.posix.exit(1);
    };

    const device_id = try std.fmt.parseUnsigned(c_int, device_id_char, 10);

    // open webcam
    var webcam = try cv.VideoCapture.init();
    try webcam.openDevice(device_id);
    defer webcam.deinit();

    // open display window
    const window_name = "FaceMark";
    var window = try cv.Window.init(window_name);
    defer window.deinit();

    var img = try cv.Mat.init();
    defer img.deinit();

    // Load classifier to recognize faces
    var classifier = try cv.CascadeClassifier.init();
    defer classifier.deinit();
    try classifier.load("./data/haarcascade_frontalface_default.xml");

    // Load facemark detector
    const facemark = cv.face.createLBPHFaceMark();
    facemark.loadModel("data/lbfmodel.yaml");

    while (true) {
        webcam.read(&img) catch {
            std.debug.print("capture failed", .{});
            std.posix.exit(1);
        };

        if (img.isEmpty()) continue;

        // Find faces
        const faces = try classifier.detectMultiScale(img, allocator);
        defer faces.deinit();
        for (faces.items) |r| {
            cv.rectangle(&img, r, blue, 3);
        }

        // Calculate the landmarks and display it
        const landmarks_opt = try facemark.fit(img, faces);
        if (landmarks_opt) |landmarks| {
            for (0..@abs(landmarks.size())) |idx| {
                const points = try landmarks.at(@intCast(idx));

                for (0..@abs(points.size())) |pt_idx| {
                    const point = points.at(@intCast(pt_idx));
                    cv.circle(&img, point.round(), 5, blue, 3);
                }
            }
        }

        window.imShow(img);

        if (window.waitKey(1) == 27) break;
    }
}
