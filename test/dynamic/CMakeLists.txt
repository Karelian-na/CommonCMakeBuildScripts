cmake_minimum_required(VERSION 3.17.1)

set(includePath "")
string(APPEND includePath "${CMAKE_CURRENT_SOURCE_DIR}/" ../../common.cmake)
include(${includePath})

project(dynamic)

# 构建前准备
PrepareProject()

# 添加构建目标
AddTarget(dynamic SHARED)

# 输出目标信息，仅在CMake配置根时有效
OutputTargetsInfos()