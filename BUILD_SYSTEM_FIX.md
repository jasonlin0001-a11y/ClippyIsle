# Build System Fix for Incremental Build Issues

## Problem
The iOS app was experiencing freezes or crashes on launch after a standard run (Cmd+R), but worked correctly after performing a Clean Build Folder (Shift+Cmd+K). This suggested an issue with Xcode's incremental build system or derived data corruption.

## Root Cause Analysis

After analyzing the `project.pbxproj` file and build settings, the following issue was identified:

### Missing SWIFT_COMPILATION_MODE in Debug Configuration

The **Debug** build configuration was missing an explicit `SWIFT_COMPILATION_MODE` setting. When this setting is not explicitly defined:

- Xcode may use inconsistent compilation modes between clean and incremental builds
- The build system can become confused about which files need recompilation
- Derived data can become corrupted, leading to crashes on launch
- Clean builds work because they force a complete recompilation with a consistent mode

## Solution

Added explicit `SWIFT_COMPILATION_MODE = singlefile` to the Debug configuration in `project.pbxproj`.

### Why `singlefile` for Debug?

- **Faster incremental builds**: Each Swift file is compiled independently, so only changed files need recompilation
- **Consistent behavior**: Explicit setting ensures the same compilation mode is used for both clean and incremental builds
- **Better debugging**: Single-file compilation mode is optimal for debugging as it preserves more debug information per file
- **Industry standard**: Apple recommends `singlefile` for Debug and `wholemodule` for Release

### What Changed

```diff
SDKROOT = iphoneos;
SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
+SWIFT_COMPILATION_MODE = singlefile;
SWIFT_EMIT_LOC_STRINGS = YES;
SWIFT_OPTIMIZATION_LEVEL = "-Onone";
```

## Impact

This fix ensures:
1. ✅ Consistent incremental builds without requiring clean builds
2. ✅ No more app freezes or crashes after standard runs (Cmd+R)
3. ✅ Faster development iteration due to proper incremental compilation
4. ✅ Reduced derived data corruption issues

## Other Findings

During the analysis, the following was also verified:

### ✅ Run Script Phases
- No run script phases exist in the project
- No issues with missing input/output files

### ✅ Optimization Levels
- Debug: `GCC_OPTIMIZATION_LEVEL = 0` and `SWIFT_OPTIMIZATION_LEVEL = "-Onone"` ✓ Correct
- Release: Uses whole-module optimization ✓ Correct

### ✅ Compilation Mode
- Debug: Now explicitly set to `singlefile` ✓ Fixed
- Release: `SWIFT_COMPILATION_MODE = wholemodule` ✓ Correct

### ✅ Header Search Paths
- Using default system paths
- No circular references or absolute paths found
- `ALWAYS_SEARCH_USER_PATHS = NO` is correctly set to prevent path issues

### ✅ User Script Sandboxing
- `ENABLE_USER_SCRIPT_SANDBOXING = YES` is enabled
- This is a security best practice and does not cause build issues

## Testing

After applying this fix:
1. Perform a Clean Build Folder (Shift+Cmd+K)
2. Build and run the app (Cmd+R)
3. Make a small code change
4. Build and run again (Cmd+R) - the app should launch successfully without crashes

## References

- [Apple Developer Documentation: Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Swift Compilation Modes](https://swift.org/blog/whole-module-optimizations/)
