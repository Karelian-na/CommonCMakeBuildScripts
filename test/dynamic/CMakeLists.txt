cmake_minimum_required(VERSION 3.17.1)
include(${CMAKE_CURRENT_LIST_DIR}/../../common.cmake)

project(dynamic)

# 构建前准备
PrepareProject()

# 添加构建目标
AddTarget(dynamic SHARED)

# 输出目标信息，仅在CMake配置根时有效
OutputTargetsInfos()