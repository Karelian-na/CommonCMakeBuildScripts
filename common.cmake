include(${CMAKE_CURRENT_LIST_DIR}/utils.cmake)

# #######################################################################
# Common CMake build scripts
# Support Windows build, Linux build, Windows cross-platform build, Linux cross-platform build
# Script writing instructions:
# Macros and functions: use `CamelCase` naming convention
# Parameters: use `snake_case` naming convention
# Local variables: use `camelBack` naming convention
#
# Example CMakeList.txt:
# ```cmake
#   cmake_minimum_required(VERSION 3.15)
#   include(path/to/common.cmake)
#
#   project(YourProjectName LANGUAGES CXX)
#
#   PrepareProject()
#
#   # add a target, automatically add all source files under `src_directory` recursively
#   AddTarget(YourTargetName EXECUTABLE src_directory)
#
#   # add a target, only add additional source files
#   AddFiles(path/to/extra/source "Source Files" extra_sources "cpp;cxx" TRUE)
#   AddTarget(YourTargetName1 STATIC $ extra_sources)
#
#   # ouput targets info
#   OutputTargetsInfos()
# ```
# Author: Karelian_na
# ######################################################################

# Load native environment configuration and set common variables
#
# Other variables set:
# `TARGET_DEV_SYSTEM`: target machine
# `TARGET_ARCH`: target architecture, values are `x86`, `x64`, or `arm64`
# `BUILD_CONFIGUARATION`: build configuration, values are `Debug` or `Release`
# `OUTPUT_DIR`: output directory
# `TARGETS`: stores configured targets, used for output information
macro(PrepareProject)
    if(${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_SOURCE_DIR})
        set(supportedPlatforms "Windows;Linux")
        set(TARGET_DEV_SYSTEM "${CMAKE_CXX_PLATFORM_ID}")

        if(NOT ${TARGET_DEV_SYSTEM} IN_LIST supportedPlatforms)
            message(FATAL_ERROR "Unsupported platform: ${CMAKE_CXX_PLATFORM_ID} to configure!")
        endif()

        # ###########################################################################################
        # Set target architecture
        # ###########################################################################################
        string(TOLOWER "${CMAKE_C_COMPILER_ARCHITECTURE_ID}" tempResult)

        if("${tempResult}" STREQUAL x86)
            set(TARGET_ARCH x86)
        elseif("${tempResult}" STREQUAL x64)
            set(TARGET_ARCH x64)
        elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL x86_64)
            set(TARGET_ARCH x64)
        elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL aarch64)
            set(TARGET_ARCH arm64)
        endif()

        # ###########################################################################################
        # Set build configuration name
        # ###########################################################################################
        if(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
            set(BUILD_CONFIGUARATION "Debug")
        else()
            set(BUILD_CONFIGUARATION "Release")
        endif()

        # ###########################################################################################
        # Set output directory
        # ###########################################################################################
        string(SUBSTRING ${BUILD_CONFIGUARATION} 0 1 OUTPUT_DIR)

        if(MSVC)
            set(OUTPUT_DIR ${TARGET_ARCH}_v${MSVC_TOOLSET_VERSION}${OUTPUT_DIR})
        else()
            set(OUTPUT_DIR ${TARGET_ARCH}_${CMAKE_CXX_COMPILER_ID}${OUTPUT_DIR})
        endif()

        # ###########################################################################################
        # Set system include directories (for clangd only)
        # ###########################################################################################
        if(MSVC)
            add_compile_definitions(_MSC_VER=${MSVC_VERSION})

            string(REGEX REPLACE "^(.*)/(b|B)in.*$" "\\1" sysIncludeDir ${CMAKE_CXX_COMPILER})
            set(programFilesx86Path "$ENV{ProgramFiles} (x86)")

            if(MSVC_VERSION EQUAL 1200)
                set(sdkPath "${programFilesx86Path}/Microsoft SDK")
                include_directories(SYSTEM
                    "${sdkPath}/include"
                    "${sysIncludeDir}/mfc/include"
                    "${sysIncludeDir}/atl/include"
                )
                link_directories(
                    "${sysIncludeDir}/lib" # vcrt
                    "${sysIncludeDir}/mfc/lib" # vcrt
                )
            else()
                include_directories(SYSTEM "${sysIncludeDir}/atlmfc/include")

                if(MSVC_VERSION EQUAL 1600)
                    set(sdkPath "${programFilesx86Path}/Microsoft SDKs/Windows/v7.0A")
                    include_directories(SYSTEM "${sdkPath}/Include")
                else()
                    string(REGEX MATCH "^(.+)/bin/([^/]*)/" tempResult ${CMAKE_MT})
                    set(sdkPath "${CMAKE_MATCH_1}")
                    set(sdkVersion "${CMAKE_MATCH_2}")
                    include_directories(SYSTEM
                        "${sdkPath}/include/${sdkVersion}/ucrt"
                        "${sdkPath}/include/${sdkVersion}/um"
                        "${sdkPath}/include/${sdkVersion}/shared"
                        "${sdkPath}/include/${sdkVersion}/winrt"
                        "${sdkPath}/include/${sdkVersion}/cppwinrt"
                    )
                endif()

                link_directories(
                    "${sdkPath}/Lib/${sdkVersion}/um/${TARGET_ARCH}" # sdk
                    "${sdkPath}/Lib/${sdkVersion}/ucrt/${TARGET_ARCH}" # sdk
                    "${sysIncludeDir}/lib/${TARGET_ARCH}" # vcrt
                )
            endif()

            include_directories(SYSTEM "${sysIncludeDir}/include")
        else()
            foreach(file ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
                add_compile_options(-isystem${file})
            endforeach()
        endif()

        set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
    endif()
endmacro()

# Recursively add all files from the specified path that match the given extensions and not match the given regex to the given container
# This function is for internal use only, do not call it directly, use `AddFiles` instead
#
# [ARGV0] `dir_path`: the path to add files from
# [ARGV1] `prefix`: visual studio filter prefix
# [ARGV2] `files_container_name`: the name of the container to add files to
# [ARGV3] `extensions`: source file extensions
# [ARGV4] `recurse`: whether to recurse
# [ARGV5] `exclude_sources_regex`: regex to exclude source files
function(__AddAllFiles dir_path prefix files_container_name extensions recurse exclude_sources_regex)
    if("${exclude_sources_regex}" STREQUAL "")
        message(FATAL_ERROR "exclude_sources_regex is empty, considering do not call __AddAllFiles diectly!")
    endif()

    set(GROUPED_FILES "")
    file(GLOB entries LIST_DIRECTORIES true ${dir_path}/*)

    foreach(entry ${entries})
        if(${entry} MATCHES ${exclude_sources_regex})
            continue()
        endif()

        get_filename_component(tempResult ${entry} NAME)

        if(IS_DIRECTORY ${entry} AND "${recurse}" STREQUAL "TRUE")
            __AddAllFiles(${entry} "${prefix}/${tempResult}" ${files_container_name} "${extensions}" ${recurse} ${exclude_sources_regex})
        endif()

        get_filename_component(tempResult ${entry} LAST_EXT)

        if("${tempResult}" STREQUAL "")
            continue()
        endif()

        string(SUBSTRING ${tempResult} 1 -1 tempResult)

        if(${tempResult} IN_LIST extensions)
            list(APPEND GROUPED_FILES ${entry})
        endif()
    endforeach()

    if(NOT "${GROUPED_FILES}" STREQUAL "")
        source_group(${prefix} FILES ${GROUPED_FILES})
        list(APPEND ${files_container_name} ${GROUPED_FILES})
    endif()

    set(${files_container_name} ${${files_container_name}} PARENT_SCOPE)
endfunction()

# Add files from the specified path that match the given extensions and not match the given regex to the specified container
#
# [ARGV0] `dir_path`: the path to add files from
# [ARGV1] `prefix`: visual studio filter prefix
# [ARGV2] `files_container_name`: the name of the container to add files to, a list variable name
# [ARGV3] `extensions`: source file extensions (separated by `;`)
# [ARGV4][OPT] `recurse`: whether to recurse
# [ARGV5][OPT] `exclude_sources_regex`: regex to exclude source files
function(AddFiles dir_path prefix files_container_name extensions)
    if("${ARGV3}" STREQUAL "")
        message(FATAL_ERROR "extensions must not be empty")
    endif()

    RegularOptionalParameter("${ARGV4}" recurse TRUE)
    set(exclude_sources_regex "((\\.cache$|\\.git$|build$))")
    if(NOT "${ARGV5}" STREQUAL "")
        string(APPEND exclude_sources_regex "|${ARGV5}")
    endif()

    if(${dir_path} MATCHES "^\\.?$")
        set(dir_path ${CMAKE_CURRENT_SOURCE_DIR})
    else()
        string(LENGTH ${dir_path} length)
        string(FIND ${dir_path} ${CMAKE_CURRENT_SOURCE_DIR} result)

        if(${result} EQUAL -1)
            message(FATAL_ERROR "couldn't add a directory's files which path is not in ${CMAKE_CURRENT_SOURCE_DIR}")
        endif()

        __AddAllFiles(${dir_path} ${prefix} ${files_container_name} "${extensions}" ${recurse} "${exclude_sources_regex}")
        set(${files_container_name} ${${files_container_name}} PARENT_SCOPE)
    endif()
endfunction()

# Add precompile header to target, the search order is:
#  + ${source_dir}
#  + ${source_dir}/include
#  + CMAKE_CURRENT_SOURCE_DIR (if `find_cmake_current_dir` is TRUE)
#  + CMAKE_CURRENT_SOURCE_DIR/include (if `find_cmake_current_dir` is TRUE)
#  + CMAKE_CURRENT_SOURCE_DIR/include/${target_name} (if `find_cmake_current_dir` is TRUE)
#
# [ARGV0] `target_name`: target name
# [ARGV1] `source_dir`: source directory to search pch files
# [ARGV2][OPT] `find_cmake_current_dir`: whether to search current cmake source dir for pch files, default to TRUE
# [ARGV3][OPT] `pch_name`: specific pch file name, if not provided, default to "pch.h;StdAfx.h;stdafx.h"
macro(AddTargetPrecompileHeader target_name source_dir)
    RegularOptionalParameter("${ARGV2}" find_cmake_current_dir TRUE)
    RegularOptionalParameter("${ARGV3}" pch_name "pch.h;StdAfx.h;stdafx.h")

    set(searchBaseDir "${source_dir};${source_dir}/include")
    if(${find_cmake_current_dir} STREQUAL "TRUE")
        list(APPEND searchBaseDir "${CMAKE_CURRENT_SOURCE_DIR};${CMAKE_CURRENT_SOURCE_DIR}/include;${CMAKE_CURRENT_SOURCE_DIR}/include/${target_name}")
    endif()

    foreach(candidateBaseDir ${searchBaseDir})
        set(isFound FALSE)
        foreach(candidatePchName ${pch_name})
            if(EXISTS ${candidateBaseDir}/${candidatePchName})
                target_precompile_headers(${target_name} PRIVATE ${candidateBaseDir}/${candidatePchName})
                set(isFound TRUE)
                break()
            endif()
        endforeach()

        if(${isFound})
            break()
        endif()
    endforeach()

    unset(searchBaseDir)
    unset(isFound)

    unset(find_cmake_current_dir)
    unset(pch_name)
endmacro()

# Add a build target
#
# [ARGV0] `target_name`: the target name
# [ARGV1] `target_type`: the target type, maybe an executable `EXECUTABLE`, shared library `SHARED`, static library `STATIC`
# [ARGV2][OPT] `source_dir`: source directory root, `$` means the macro will not search `${CMAKE_CURRENT_SOURCE_DIR}` automatically, use `extra_sources` only
# [ARGV3][OPT] `extra_sources`: additional source files
# [ARGV4][OPT] `exclude_sources_regex`: pattern for files to exclude, acting on `source_dir`
# [ARGV5][OPT] `no_pch`: do not automatically add precompiled headers
macro(AddTarget target_name target_type)
    # ###########################################################################################
    # Regular parameters
    # ###########################################################################################
    if(TRUE)
        RegularOptionalParameter("${ARGV2}" source_dir "${CMAKE_CURRENT_SOURCE_DIR}")
        if("${ARGV2}" STREQUAL "$")
            set(source_dir "")
        endif()

        RegularOptionalParameter("${${ARGV3}}" extra_sources "")
        RegularOptionalParameter("${ARGV4}" exclude_sources_regex "")
        RegularOptionalParameter("${ARGV5}" no_pch FALSE)
    endif()

    # ###########################################################################################
    # Add source files, header files, resource files
    # ###########################################################################################
    set(targetSources ${extra_sources})
    if(NOT "${source_dir}" STREQUAL "")
        if(EXISTS ${source_dir}/include)
            AddFiles(${source_dir}/include "Header Files" targetSources "h;hpp;inl" TRUE ${exclude_sources_regex})
        elseif(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include)
            AddFiles(${CMAKE_CURRENT_SOURCE_DIR}/include "Header Files" targetSources "h;hpp;inl" TRUE ${exclude_sources_regex})
        else()
            AddFiles(${CMAKE_CURRENT_SOURCE_DIR} "Header Files" targetSources "h;hpp;inl" TRUE ${exclude_sources_regex})
        endif()

        AddFiles(${source_dir} "Source Files" targetSources "cxx;cc;cpp;c++" TRUE ${exclude_sources_regex})
        AddFiles(${source_dir} "Resource Files" targetSources "rc" TRUE ${exclude_sources_regex})
    endif()

    # ###########################################################################################
    # Add build target
    # ###########################################################################################
    if("${target_type}" STREQUAL "EXECUTABLE")
        add_executable(${target_name} ${targetSources})
    elseif("${target_type}" STREQUAL "SHARED")
        add_library(${target_name} SHARED ${targetSources})
    else()
        add_library(${target_name} STATIC ${targetSources})
        string(REPLACE "-" "_" legalled_name ${target_name})
        target_compile_definitions(${target_name} PUBLIC "${legalled_name}_STATIC")
    endif()
    include(GNUInstallDirs)
    unset(targetSources)

    # ###########################################################################################
    # Add precompile header
    # ###########################################################################################
    if("${no_pch}" STREQUAL "FALSE")
        AddTargetPrecompileHeader(${target_name} "${source_dir}")
    endif()

    # ###########################################################################################
    # Set include directories
    # ###########################################################################################
    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include)
        set(includeDir ${CMAKE_CURRENT_SOURCE_DIR}/include)
    elseif("${source_dir}" STREQUAL "")
        set(includeDir ${CMAKE_CURRENT_SOURCE_DIR})
    else()
        set(includeDir ${source_dir})
    endif()
    target_include_directories(${target_name} PRIVATE ${includeDir}
        INTERFACE
        $<BUILD_INTERFACE:${includeDir}>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    )
    unset(includeDir)

    # ###########################################################################################
    # Set Compile options
    # ###########################################################################################
    if(${TARGET_DEV_SYSTEM} STREQUAL "Linux")
        if(${BUILD_CONFIGUARATION} STREQUAL "Debug" AND NOT ${CMAKE_HOST_SYSTEM} STREQUAL "Linux")
            target_compile_options(${target_name} PRIVATE -fno-stack-protector)
        endif()
    endif()

    # ###########################################################################################
    # Set Link options
    # ###########################################################################################
    if(MSVC)
        target_link_options(${target_name} PRIVATE /VERBOSE:Lib)
    elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU")
        target_link_options(${target_name} PRIVATE -Wl,--verbose)
    elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang")
        target_link_options(${target_name} PRIVATE -Wl,-verbose)
    endif()

    # ###########################################################################################
    # Other options
    # ###########################################################################################
    if(TRUE)
        # target architecture
        if(${TARGET_ARCH} STREQUAL x86)
            target_compile_options(${target_name} PRIVATE "-m32")
        elseif(NOT ${TARGET_DEV_SYSTEM} STREQUAL "Neokylin")
            target_compile_options(${target_name} PRIVATE "-m64")
        endif()

        # target postfix
        set(targetReleasePostfix "")
        if(NOT ${target_type} STREQUAL "EXECUTABLE")
            if(${TARGET_ARCH} STREQUAL x64)
                set(targetReleasePostfix "-x64")
            elseif(NOT ${TARGET_ARCH} STREQUAL x86)
                set(targetReleasePostfix "")
            endif()
            set(targetDebugPostfix "d${targetReleasePostfix}")
        endif()

        # other target properties
        set_target_properties(${target_name} PROPERTIES
            DEBUG_POSTFIX "${targetDebugPostfix}"
            MINSIZEREL_POSTFIX "${targetReleasePostfix}"
            RELEASE_POSTFIX "${targetReleasePostfix}"
            RELWITHDEBINFO_POSTFIX "${targetReleasePostfix}"
            RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${OUTPUT_DIR}
            LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${OUTPUT_DIR}
            ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${OUTPUT_DIR}
        )

        unset(targetDebugPostfix)
        unset(targetReleasePostfix)
    endif()

    # Add the target to global TARGETS list
    if(NOT ${target_name} IN_LIST TARGETS)
        list(APPEND TARGETS ${target_name})
    endif()

    if(NOT ${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_SOURCE_DIR})
        set(TARGETS ${TARGETS} PARENT_SCOPE)
    endif()

    unset(source_dir)
    unset(extra_sources)
    unset(exclude_sources_regex)
    unset(no_pch)
endmacro()

# Output configured targets information
#
# The output information includes:
# 1. Target type
# 2. Target name
# 3. Target headers
# 4. Target sources
# 5. Target include directories
# 6. Target link directories
# 7. Target preprocessor definitions
# 8. Target compile options
# 9. Target link options
# 10. Target link options
# 11. Target link files
# 12. Target installation information
macro(OutputTargetsInfos)
    if(${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_SOURCE_DIR})
        foreach(target ${TARGETS})
            get_target_property(tempResult ${target} TYPE)

            if(${tempResult} STREQUAL "EXECUTABLE")
                message(STATUS "Added an exetuable:")
            elseif(${tempResult} STREQUAL "SHARED_LIBRARY")
                message(STATUS "Added a dynamic library:")
            else()
                message(STATUS "Added a static library:")
            endif()

            message(STATUS "|   with name: ${target}")

            # Print headers
            message(STATUS "|   with headers:")
            get_target_property(tempResult ${target} SOURCES)
            list(FILTER tempResult INCLUDE REGEX ".*\.h$")

            if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
                foreach(file ${tempResult})
                    message(STATUS "|       ${file}")
                endforeach()
            endif()

            # Print sources
            message(STATUS "|   with sources:")
            get_target_property(tempResult ${target} SOURCES)
            list(FILTER tempResult EXCLUDE REGEX ".*\.h$")

            if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
                foreach(file ${tempResult})
                    message(STATUS "|       ${file}")
                endforeach()
            endif()

            # Print include directories
            get_target_property(tempResult ${target} INCLUDE_DIRECTORIES)
            message(STATUS "|   with include dirs:")

            if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
                foreach(dir ${tempResult})
                    message(STATUS "|       ${dir}")
                endforeach()
            endif()

            # Print link directories
            get_target_property(tempResult ${target} LINK_DIRECTORIES)
            message(STATUS "|   with link dirs:")

            if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
                foreach(dir ${tempResult})
                    message(STATUS "|       ${dir}")
                endforeach()
            endif()

            # Print preprocessor definitions
            get_target_property(tempResult ${target} COMPILE_DEFINITIONS)
            message(STATUS "|   with definitions:")

            if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
                foreach(item ${tempResult})
                    message(STATUS "|       ${item}")
                endforeach()
            endif()

            # Print compile options
            get_target_property(tempResult ${target} COMPILE_OPTIONS)
            message(STATUS "|   with compile options:")

            if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
                foreach(item ${tempResult})
                    message(STATUS "|       ${item}")
                endforeach()
            endif()

            # Print link options
            get_target_property(tempResult ${target} LINK_OPTIONS)
            message(STATUS "|   with link options:")

            if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
                foreach(item ${tempResult})
                    message(STATUS "|       ${item}")
                endforeach()
            endif()

            # Print link libraries
            get_target_property(tempResult ${target} LINK_LIBRARIES)
            message(STATUS "|   with links:")

            if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
                foreach(file ${tempResult})
                    message(STATUS "|       ${file}")
                endforeach()
            endif()
        endforeach()

        # Print install files
        message(STATUS "|   with install:")
        foreach(target ${TARGETS})
            get_target_property(installFiles ${target} "INSTALL_FILES")

            if(${installFiles} STREQUAL "installFiles-NOTFOUND")
                continue()
            endif()

            string(REPLACE "#" ";" installCategories ${installFiles})

            foreach(category ${installCategories})
                string(REPLACE "," ";" installFilesWithDest ${category})
                list(GET installFilesWithDest 0 target_path)

                list(SUBLIST installFilesWithDest 1 -1 installFiles)

                foreach(dep ${installFiles})
                    message(STATUS "|        ${dep} to ${target_path}")
                endforeach()
            endforeach()
        endforeach()
    else()
        set(TARGETS ${TARGETS} PARENT_SCOPE)
    endif()
endmacro()
