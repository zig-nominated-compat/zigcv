const c_api = @import("c_api.zig");
const core = @import("../core.zig");
const core_c = @import("../c_api.zig");
const std = @import("std");

pub fn createLBPHFaceMark() FaceMark {
    const facemark = c_api.CreateLBPHFaceMark();
    return FaceMark{
        .c_ptr = facemark,
    };
}

/// Abstract base class for all facemark models
pub const FaceMark = struct {
    const Self = @This();
    c_ptr: c_api.LBPHFaceMark,

    pub fn fit(self: Self, image: core.Mat, faces: core.Rects) !?core.Points2fVector {
        if (faces.items.len == 0) return null;
        const faces_c: *c_api.struct_Rects = @constCast(@ptrCast(&core.rectsToC(faces)));
        const landmarks = c_api.Points2fVector_New();

        if (c_api.LBPHFaceMark_Fit(self.c_ptr, image.ptr, faces_c.*, landmarks) == false) {
            return error.FitFailed;
        }
        return try core.Points2fVector.initFromC(landmarks);
    }

    pub fn loadModel(self: Self, name: []const u8) void {
        c_api.LBPHFaceMark_LoadModel(self.c_ptr, @ptrCast(name));
    }
};
