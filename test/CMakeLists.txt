cmake_minimum_required(VERSION 3.17.1)

include(../common.cmake)

project(test)

# 构建前准备
PrepareProject()

# 添加构建目标
add_subdirectory(dynamic)
add_subdirectory(executable)
target_link_libraries(executable PRIVATE dynamic)

# 输出目标信息，仅在CMake配置根时有效
OutputTargetsInfos()