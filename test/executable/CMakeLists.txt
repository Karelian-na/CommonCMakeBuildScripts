cmake_minimum_required(VERSION 3.17.1)
include(${CMAKE_CURRENT_LIST_DIR}/../../common.cmake)

project(executable)

# 构建前准备
PrepareProject()

# 添加构建目标
AddTarget(executable EXECUTABLE)

add_test(NAME executable.build
    COMMAND "${CMAKE_COMMAND}" --build "${CMAKE_BINARY_DIR}" --config "$<CONFIG>" --target executable
)
set_tests_properties(executable.build PROPERTIES
    FIXTURES_REQUIRED dynamic_built
    FIXTURES_SETUP executable_built
)

add_test(NAME executable.run
    COMMAND "${CMAKE_COMMAND}" "-DTEST_EXECUTABLE=$<TARGET_FILE:executable>"
    -P "${CMAKE_CURRENT_SOURCE_DIR}/executable.test.cmake"
)
set_tests_properties(executable.run PROPERTIES FIXTURES_REQUIRED executable_built)

# 输出目标信息，仅在CMake配置根时有效
OutputTargetsInfos()
