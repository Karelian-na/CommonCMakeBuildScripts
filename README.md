# Common CMake Build Scripts

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
