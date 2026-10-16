# Common CMake Build Scripts

Reusable CMake helpers for Windows and Linux C/C++ projects. Keep a checkout of this repository in your project, for example at `deps/CommonCMakeBuildScripts`, and include its scripts directly.

## Benefits

- **Less target boilerplate:** `AddTarget()` creates executables, shared libraries or static libraries, discovers source/header/resource files, sets include directories, and picks up conventional precompiled headers such as `pch.h`.
- **Consistent artifacts:** build outputs are grouped by architecture, compiler/toolset and configuration. Library postfixes distinguish Debug/Release and x86/x64 variants.
- **Architecture checks:** `PrepareProject()` detects the compiler target and validates an optional `TARGET_ARCH` requirement. Linux x86/x64 detection uses the compiler ABI's pointer size, including multilib builds.
- **Reusable packaging:** `InstallProject()` installs targets and public headers, generates package configuration/version files, and exports namespaced targets for `find_package()` consumers.
- **Easier inspection:** compiler include paths and compile commands are prepared for tooling such as clangd; `OutputTargetsInfos()` prints the collected sources, include paths, definitions and build options.

## Quick start

For example, use this layout for a static library:

```text
MyLibrary/
  CMakeLists.txt
  deps/CommonCMakeBuildScripts/
  include/MyLibrary/MyLibrary.h
  src/MyLibrary.cpp
```

In the top-level `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.21)
project(MyLibrary VERSION 1.0.0)
include(deps/CommonCMakeBuildScripts/common.cmake)
PrepareProject()

AddTarget(MyLibrary STATIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_compile_features(MyLibrary PUBLIC cxx_std_17)

OutputTargetsInfos()
```

Include `common.cmake` after `project()` enables the compilers, then call `PrepareProject()`. The example enables both C and C++ through the default `project()` behavior. Nested projects can reuse the prepared environment and create their own targets with `AddTarget()`.

`AddTarget()` accepts `EXECUTABLE`, `SHARED` `MODULE` or `STATIC`. It searches the source directory recursively and uses the project's `include` directory when present. Reconfigure after adding or removing files so discovery runs again; continue using normal CMake commands for target-specific dependencies, features and options.

With CMake 3.21 or newer, Ninja and a C/C++ compiler available, configure and build from the project root:

```sh
cmake -S . -B build/debug -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build/debug
```

On Windows, use a Visual Studio developer terminal for the required target architecture. Use separate build directories for different architectures and configurations. For example, a Linux GCC x64 Debug build places artifacts under `build/debug/x64_GNUD`.

To require a particular architecture, add `-DTARGET_ARCH=x64` to the configure command or define `TARGET_ARCH` in a preset. Supported values are `x86`, `x64` and `arm64`; configuration fails if the detected compiler ABI differs. Select the compiler ABI before `project()` with the corresponding compiler or toolchain settings. For example, Linux x86 builds require a toolchain that supplies `-m32` and matching dependencies; `TARGET_ARCH` only validates the resulting ABI.

## Installing a library

For the example above, add this after creating the target:

```cmake
include(deps/CommonCMakeBuildScripts/install.common.cmake)
InstallProject(TARGETS cmake/MyLibraryConfig.cmake.in
    "${PROJECT_VERSION}" SameMajorVersion MyLibraryTargets.cmake)
```

The first argument, `TARGETS`, is the name of the target-list variable populated by `AddTarget()`. Public headers are installed from `include/${PROJECT_NAME}`. Create `cmake/MyLibraryConfig.cmake.in` with:

```cmake
@PACKAGE_INIT@

@ARCH_DETECT@
include("${CMAKE_CURRENT_LIST_DIR}/${DETECTED_ARCH}/@PROJECT_NAME@Targets.cmake")
check_required_components(@PROJECT_NAME@)
```

`InstallProject()` substitutes the architecture-detection code into this template so the consumer can select the matching target export. After building, install to a chosen prefix:

```sh
cmake --install build/debug --prefix /path/to/install
```

A consuming project enables C++ before finding the package, sets `CMAKE_PREFIX_PATH` to that prefix, and links the exported target:

```cmake
project(MyApp LANGUAGES CXX)
find_package(MyLibrary CONFIG REQUIRED)
add_executable(MyApp main.cpp)
target_link_libraries(MyApp PRIVATE MyLibrary::MyLibrary)
```

## Tests

The `test` project registers all tests with CTest: 11 architecture cases, shared-library and executable build checks, and a runtime check of the executable's constructor/destructor output. CTest fixtures build the targets in dependency order before running the executable, including when selecting only the runtime test.

With CMake 3.21 or newer and Ninja available, configure once from the `test` directory:

```sh
cmake --preset tests
```

On Windows, use a Visual Studio developer terminal so MSVC and the Windows SDK are available. On Linux, use a terminal with a C/C++ compiler available.

Run all tests, including any required incremental builds, with one command:

```sh
ctest --preset tests
```

List the discovered tests with `ctest --preset tests -N`. Use `ctest --preset tests -R '^architecture\.'` for architecture cases, or `ctest --preset tests -R '^executable\.run$'` for the runtime check and its prerequisite builds.

For compiler-free script testing, configure `test/architecture` as a standalone CMake project and run CTest in its build directory.
