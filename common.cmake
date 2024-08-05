# #######################################################################
# CMake 自定义构建脚本
# 支持 Windows构建、Linux构建、Windows跨平台构建、Linux跨平台构建
# 本脚本编写说明:
# 宏 和 函数 定义: 采用 `CamelCase` 命名法
# 参数: 采用 `snake_case` 命名法
# 局部变量: 采用 `camelBack` 命名法
#
# CMakeList.txt文件示例:
# 编写人: Karelian_na
# ######################################################################

# 加载本机环境配置
#
# 其余设置的变量
# HOME_DIR: 当前用户配置目录
# TARGET_DEV_SYSTEM: 目标计算机
# TARGET_ARCH: 目标架构，取值为 `x86` 或 `x64` 或 `arm64`
# BUILD_CONFIGUARATION: 构建配置，取值为 `Debug` 或 `Release`
# OUTPUT_DIR: 输出目录
# TARGETS: 存储已经配置的目标, 输出信息时使用
macro(PrepareProject)
	if(${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_SOURCE_DIR})
		set(TARGETS "")
	endif()

	set(supportedPlatforms "Windows;Linux")
	set(TARGET_DEV_SYSTEM "${CMAKE_CXX_PLATFORM_ID}")
	
	list(FIND supportedPlatforms ${TARGET_DEV_SYSTEM} tempResult)
	if(${tempResult} EQUAL -1)
		message(FATAL_ERROR "Unsupported platform: ${CMAKE_CXX_PLATFORM_ID} to configure!")
	endif()

	# ###########################################################################################
	# 设置目标架构
	# ###########################################################################################
	string(TOLOWER "${CMAKE_C_COMPILER_ARCHITECTURE_ID}" tempResult)

	if("${tempResult}" STREQUAL x86)
		set(TARGET_ARCH x86)
	elseif("${tempResult}" STREQUAL x64)
		set(TARGET_ARCH x64)
	elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL x86_64)
		set(TARGET_ARCH x64)
	elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL aarch64)
		set(TARGET_ARCH aarch64)
	endif()

	# ###########################################################################################
	# 设置构建配置名
	# ###########################################################################################
	if(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
		set(BUILD_CONFIGUARATION "Debug")
	else()
		set(BUILD_CONFIGUARATION "Release")
	endif()

	# ###########################################################################################
	# 输出目录
	# ###########################################################################################
	string(SUBSTRING ${BUILD_CONFIGUARATION} 0 1 OUTPUT_DIR)

	if(MSVC)
		set(OUTPUT_DIR ${TARGET_ARCH}_v${MSVC_TOOLSET_VERSION}${OUTPUT_DIR})
	else()
		set(OUTPUT_DIR ${TARGET_ARCH}_${CMAKE_CXX_COMPILER_ID}${OUTPUT_DIR})
	endif()

	# ###########################################################################################
	# 设置系统头文件目录（仅用于clangd）
	# ###########################################################################################
	if(MSVC)
		string(REGEX REPLACE "^(.*)/(b|B)in.*$" "\\1" sysIncludeDir ${CMAKE_CXX_COMPILER})

		if(MSVC_VERSION EQUAL 1200)
			include_directories(SYSTEM
				"C:/Program Files (x86)/Microsoft SDK/include"
				${sysIncludeDir}/mfc/include
				${sysIncludeDir}/atl/include
			)

			include_directories(SYSTEM ${sysIncludeDir}/include)
		else()
			include_directories(SYSTEM ${sysIncludeDir}/atlmfc/include)

			if(MSVC_VERSION EQUAL 1600)
				include_directories(SYSTEM "C:/Program Files (x86)/Microsoft SDKs/Windows/v7.0A/Include")
			else()
				string(REGEX MATCH "^(.+)/bin/([^/]*)/" tempResult ${CMAKE_MT})
				include_directories(SYSTEM
					${CMAKE_MATCH_1}/include/${CMAKE_MATCH_2}/ucrt
					${CMAKE_MATCH_1}/include/${CMAKE_MATCH_2}/um
					${CMAKE_MATCH_1}/include/${CMAKE_MATCH_2}/shared
					${CMAKE_MATCH_1}/include/${CMAKE_MATCH_2}/winrt
					${CMAKE_MATCH_1}/include/${CMAKE_MATCH_2}/cppwinrt
				)
			endif()
		endif()

	else()
		foreach(file ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
			add_compile_options(-isystem${file})
		endforeach()
	endif()

	set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
endmacro()

# 内部使用添加指定路径下的所有文件至给定容器中, 用于递归调用
function(InnerAddAllFiles dir_path prefix extensions files_container_name recurse exclude_sources_regex)
	set(GROUPED_FILES "")
	file(GLOB entries "${dir_path}/**")

	foreach(entry ${entries})
		get_filename_component(entryName ${entry} NAME)

		if(IS_DIRECTORY ${entry} AND "${recurse}" STREQUAL "TRUE")
			InnerAddAllFiles(${entry} "${prefix}/${entryName}" ${extensions} ${files_container_name} ${recurse} ${exclude_sources_regex})
		elseif(${entryName} MATCHES ${extensions})
			if(NOT "${exclude_sources_regex}" STREQUAL "" AND NOT ${entryName} MATCHES ${exclude_sources_regex})
				list(APPEND GROUPED_FILES ${entry})
			endif()
		endif()
	endforeach()

	if(NOT "${GROUPED_FILES}" STREQUAL "")
		source_group(${prefix} FILES ${GROUPED_FILES})
		list(APPEND ${files_container_name} ${GROUPED_FILES})
	endif()

	set(${files_container_name} ${${files_container_name}} PARENT_SCOPE)
endfunction()

# 添加指定路径下的 符合指定模式的文件 至 给定容器中
#
# [ARGV0] `dir_path`: 将要添加的文件的路径
# [ARGV1] `prefix`: vs过滤器前缀
# [ARGV2] `extensions`: 将要添加的文件的匹配模式
# [ARGV3] `files_container_name`: 指定添加的容器的名称
# [ARGV4][OPT] `recurse`: 是否递归
# [ARGV5][OPT] `exclude_sources_regex`: 排除的源文件
function(AddFiles dir_path prefix extensions files_container_name)
	if("${ARGV4}" STREQUAL "")
		set(recurse TRUE)
	else()
		set(recurse ${ARGV4})
	endif()

	if("${ARGV5}" STREQUAL "")
		set(exclude_sources_regex "^$")
	else()
		set(exclude_sources_regex ${ARGV5})
	endif()

	if(${dir_path} MATCHES "^\\.?$")
		set(dir_path ${CMAKE_CURRENT_SOURCE_DIR})
	else()
		string(LENGTH ${dir_path} length)
		string(FIND ${dir_path} ${CMAKE_CURRENT_SOURCE_DIR} result)

		if(${result} EQUAL -1)
			message(FATAL_ERROR "couldn't add a directory's files which path is not in ${CMAKE_CURRENT_SOURCE_DIR}")
		endif()

		InnerAddAllFiles(${dir_path} ${prefix} ${extensions} ${files_container_name} ${recurse} ${exclude_sources_regex})
		set(${files_container_name} ${${files_container_name}} PARENT_SCOPE)
	endif()
endfunction()

# 添加构建目标
#
# [ARGV0] target_name 目标名称
# [ARGV1] target_type 目标类型，可执行文件 `EXECUTABLE`, 动态库 `SHARED`, 静态库 `STATIC`
# [ARGV2][OPT] extra_sources 额外的源文件
# [ARGV3][OPT] exclude_sources_regex 需要排除的文件的模式
macro(AddTarget target_name target_type)
	# ###########################################################################################
	# 规整参数
	# ###########################################################################################
	if(TRUE)
		if("${ARGV2}" STREQUAL "")
			set(extra_sources "")
		else()
			set(extra_sources ${${ARGV2}})
		endif()

		if("${ARGV3}" STREQUAL "")
			set(exclude_sources_regex "")
		else()
			set(exclude_sources_regex ${${ARGV3}})
		endif()
	endif()

	# ###########################################################################################
	# 添加源文件、头文件、资源文件
	# ###########################################################################################
	if(TRUE)
		set(targetSources ${extra_sources})

		AddFiles(${CMAKE_CURRENT_SOURCE_DIR} "Header Files" "\\.(h|hpp|inl)$" targetSources TRUE ${exclude_sources_regex})
		AddFiles(${CMAKE_CURRENT_SOURCE_DIR} "Source Files" "\\.(cpp|cc|cxx|def)$" targetSources TRUE ${exclude_sources_regex})
		AddFiles(${CMAKE_CURRENT_SOURCE_DIR} "Resource Files" "\\.rc$" targetSources TRUE ${exclude_sources_regex})
	endif()

	# ###########################################################################################
	# 添加构建目标
	# ###########################################################################################
	if("${target_type}" STREQUAL "EXECUTABLE")
		add_executable(${target_name} ${targetSources})
	elseif("${target_type}" STREQUAL "SHARED")
		add_library(${target_name} SHARED ${targetSources})
	else()
		add_library(${target_name} STATIC ${targetSources})
	endif()

	# ###########################################################################################
	# 设置预编译头，注意，此项会导致该CMake构建时能通过，但使用TdxCMake构建时不通过，固须在某些文件添加StdAfx.h的引用
	# ###########################################################################################
	if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/StdAfx.h)
		target_precompile_headers(${target_name} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/StdAfx.h)
	elseif(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/stdafx.h)
		target_precompile_headers(${target_name} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/stdafx.h)
	elseif(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/pch.h)
		target_precompile_headers(${target_name} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/pch.h)
	endif()

	# ###########################################################################################
	# 设置包含目录
	# ###########################################################################################
	target_include_directories(${target_name}
		PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include/${target_name}
		INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include
	)

	# ###########################################################################################
	# 链接选项
	# ###########################################################################################
	if(${TARGET_DEV_SYSTEM} STREQUAL "Linux")
		if(${BUILD_CONFIGUARATION} STREQUAL "Debug" AND NOT ${CMAKE_HOST_SYSTEM} STREQUAL "Linux")
			target_compile_options(${target_name} PRIVATE -fno-stack-protector)
		endif()
	endif()

	# ###########################################################################################
	# 链接选项
	# ###########################################################################################
	if(MSVC)
		target_link_options(${target_name} PRIVATE /VERBOSE:Lib)
	elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU")
		target_link_options(${target_name} PRIVATE -Wl,--verbose)
	elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang")
		target_link_options(${target_name} PRIVATE -Wl,-verbose)
	endif()

	# ###########################################################################################
	# 其它设置
	# ###########################################################################################
	if(TRUE)
		# 目标架构
		if(${TARGET_ARCH} STREQUAL x86)
			target_compile_options(${target_name} PUBLIC "-m32")
		elseif(NOT ${TARGET_DEV_SYSTEM} STREQUAL "Neokylin")
			target_compile_options(${target_name} PUBLIC "-m64")
		endif()

		# 输出目录
		set_target_properties(${target_name} PROPERTIES
			RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${OUTPUT_DIR}
			LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${OUTPUT_DIR}
			ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${OUTPUT_DIR}
		)
	endif()

	# 添加到配置目标中
	list(FIND TARGETS ${target_name} hasTarget)

	if(hasTarget EQUAL -1)
		list(APPEND TARGETS ${target_name})
	endif()

	if(NOT ${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_SOURCE_DIR})
		set(TARGETS ${TARGETS} PARENT_SCOPE)
	endif()

	# 调试设置
	add_custom_command(TARGET ${target_name} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${target_name}> ${CMAKE_BINARY_DIR}
	)
endmacro()

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

			# 打印头文件
			message(STATUS "|   with headers:")
			get_target_property(tempResult ${target} SOURCES)
			list(FILTER tempResult INCLUDE REGEX ".*\.h$")

			foreach(file ${tempResult})
				message(STATUS "|       ${file}")
			endforeach()

			# 打印源文件
			message(STATUS "|   with sources:")
			get_target_property(tempResult ${target} SOURCES)
			list(FILTER tempResult EXCLUDE REGEX ".*\.h$")

			foreach(file ${tempResult})
				message(STATUS "|       ${file}")
			endforeach()

			# 打印包含目录
			get_target_property(tempResult ${target} INCLUDE_DIRECTORIES)
			message(STATUS "|   with include dirs:")

			foreach(dir ${tempResult})
				message(STATUS "|       ${dir}")
			endforeach()

			# 打印链接目录
			get_target_property(tempResult ${target} LINK_DIRECTORIES)
			message(STATUS "|   with link dirs:")

			foreach(dir ${tempResult})
				message(STATUS "|       ${dir}")
			endforeach()

			# 打印预处理器定义
			get_target_property(tempResult ${target} COMPILE_DEFINITIONS)
			message(STATUS "|   with definitions:")

			foreach(item ${tempResult})
				message(STATUS "|       ${item}")
			endforeach()

			# 打印编译选项
			get_target_property(tempResult ${target} COMPILE_OPTIONS)
			message(STATUS "|   with compile options:")

			if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
				foreach(item ${tempResult})
					message(STATUS "|       ${item}")
				endforeach()
			endif()

			# 打印链接选项
			get_target_property(tempResult ${target} LINK_OPTIONS)
			message(STATUS "|   with link options:")

			if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
				foreach(item ${tempResult})
					message(STATUS "|       ${item}")
				endforeach()
			endif()

			# 打印链接文件
			get_target_property(tempResult ${target} LINK_LIBRARIES)
			message(STATUS "|   with links:")

			if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
				foreach(file ${tempResult})
					message(STATUS "|       ${file}")
				endforeach()
			endif()
		endforeach()

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
	endif()
endmacro()
