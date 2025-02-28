# ZIGCV

[![ci](https://github.com/ryoppippi/zigcv/actions/workflows/ci.yml/badge.svg)](https://github.com/ryoppippi/zigcv/actions/workflows/ci.yml)

<div align="center">
  <img src="./logo/zigcv.png" width="50%" />
</div>

The ZIGCV library provides Zig language bindings for the [OpenCV 4](http://opencv.org/) computer vision library.

This for of the zigcv library supports the nominated of zig and OpenCV (v4.6.0) on Linux and macOS.

## Caution

Still under development, so the zig APIs will be dynamically changed.

You can use `const c_api = @import("zigcv").c_api;` to call c bindings directly.
This C-API is currently fixed.

## Installation

Run this following to fetch this zig package:
```sh
zig fetch --save git+https://github.com/zig-nominated-compat/zigcv.git
```
then add this to your build.zig:
```zig
const zigcv_dep = b.dependency("zigcv", .{});
const zigcv_module = zigcv_dep.module("zigcv");
// Replace exe with whatever Compile you are using
exe.step.dependOn(zigcv_dep.builder.default_step);
exe.root_module.addImport("zigcv", zigcv_module);
```

## Demos

you can build some demos.
For example:

```sh
zig build examples
```

Or you can run the demo with the following command:

<div align="center">
  <img width="400" alt="face detection" src="https://user-images.githubusercontent.com/1560508/188515175-4d344660-5680-43e7-9b74-3bad92507430.gif">
</div>

You can see the full demo list by `zig build --help`.

## Technical restrictions

Zigcv requires bundling on Linux, more details [here](https://github.com/zig-nominated-compat/zigcv/issues/2).

Due to zig being a relatively new language it does [not have full C ABI support](https://github.com/ziglang/zig/issues/1481) at the moment.
For use that mainly means we can't use any functions that return structs that are less than 16 bytes large on x86, and passing structs to any functions may cause memory error on arm.

## License

MIT

## Author

Ryotaro "Justin" Kimura (a.k.a. ryoppippi)
Froxcey
