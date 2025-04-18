# ZIGCV

[![ci](https://github.com/ryoppippi/zigcv/actions/workflows/ci.yml/badge.svg)](https://github.com/ryoppippi/zigcv/actions/workflows/ci.yml)

<div align="center">
  <img src="./logo/zigcv.png" width="50%" />
</div>

The ZIGCV library provides Zig language bindings for the [OpenCV 4](http://opencv.org/) computer vision library.

This fork of the zigcv library supports the [nominated version of zig](https://machengine.org/docs/nominated-zig) and OpenCV (v4.6.0) on Linux and OSX. This fork does **NOT** have support for Windows yet due to [Froxcey](https://github.com/Froxcey/) not having access to a Windows machine. Contribution to add Windows support is welcome, but Froxcey does not have any plan to add it himself.

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
const zigcv = @import("zigcv");
const zigcv_dep = b.dependency("zigcv", .{});
if (zigcv.make_step != null) exe.step.dependOn(&zigcv.make_step.?);
exe.root_module.addImport("zigcv", zigcv_dep.module("zigcv"));
```

If you build from source (required on Linux), additional packages may be required.

```sh
# Ubuntu/Debian
apt install cmake python3-numpy libc++-15-dev libc++abi-15-dev pkg-config libopencv-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev
# macOS
brew install cmake pkg-config ffmpeg openvino gstreamer
```

## Demos

you can build some demos.
For example:

```sh
zig build examples
```

Or you can build a bundled version

```sh
zig build -Dbundle examples
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
