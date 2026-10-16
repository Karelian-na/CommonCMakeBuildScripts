cmake_minimum_required(VERSION 3.17.1)

include(../common.cmake)

project(test)

# Prepare compiler metadata shared by the integration projects.
PrepareProject()
enable_testing()

# Build the shared library and its consumer with the common target helpers.
add_subdirectory(dynamic)
add_subdirectory(executable)
target_link_libraries(executable PRIVATE dynamic)

add_subdirectory(architecture)

OutputTargetsInfos()
