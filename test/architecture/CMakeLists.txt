cmake_minimum_required(VERSION 3.17.1)

# Keep standalone script tests available without a compiler or GTest.
if("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_CURRENT_SOURCE_DIR}")
    project(CommonBuildArchitectureTests LANGUAGES NONE)
    enable_testing()
endif()

foreach(testCase IN ITEMS
    auto-x86-debug auto-x64-debug auto-x86-release auto-x64-release auto-arm64
    requested-x86 requested-x64
)
    add_test(NAME "architecture.${testCase}"
        COMMAND "${CMAKE_COMMAND}" "-DTEST_CASE=${testCase}" -P "${CMAKE_CURRENT_SOURCE_DIR}/architecture.test.cmake"
    )
endforeach()

# Assert both a nonzero exit code and the intended diagnostic for rejection cases.
foreach(testCase IN ITEMS mismatch-x86 mismatch-x64 invalid-request missing-abi)
    add_test(NAME "architecture.${testCase}"
        COMMAND "${CMAKE_COMMAND}" "-DTEST_CASE=${testCase}" -P "${CMAKE_CURRENT_SOURCE_DIR}/expect-failure.cmake"
    )
endforeach()
