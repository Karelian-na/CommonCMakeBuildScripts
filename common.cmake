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
		set(supportedPlatforms "Windows;Linux")
		set(TARGET_DEV_SYSTEM "${CMAKE_CXX_PLATFORM_ID}")

		if(NOT ${TARGET_DEV_SYSTEM} IN_LIST supportedPlatforms)
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
			set(programFilesx86Path "$ENV{ProgramFiles} (x86)")

			if(MSVC_VERSION EQUAL 1200)
				include_directories(SYSTEM
					"${programFilesx86Path}/Microsoft SDK/include"
					${sysIncludeDir}/mfc/include
					${sysIncludeDir}/atl/include
				)
			else()
				include_directories(SYSTEM ${sysIncludeDir}/atlmfc/include)

				if(MSVC_VERSION EQUAL 1600)
					include_directories(SYSTEM "${programFilesx86Path}/Microsoft SDKs/Windows/v7.0A/Include")
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

			include_directories(SYSTEM ${sysIncludeDir}/include)
		else()
			foreach(file ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
				add_compile_options(-isystem${file})
			endforeach()
		endif()

		set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
	endif()
endmacro()

# 内部使用添加指定路径下的所有文件至给定容器中, 用于递归调用
#
# [ARGV0] `dir_path`: 将要添加的文件的路径
# [ARGV1] `prefix`: vs过滤器前缀
# [ARGV2] `files_container_name`: 指定添加的容器的名称
# [ARGV3] `extensions`: 源文件的扩展名
# [ARGV4] `recurse`: 是否递归
# [ARGV5] `exclude_sources_regex`: 排除的源文件
function(InnerAddAllFiles dir_path prefix files_container_name extensions recurse exclude_sources_regex)
	if("${exclude_sources_regex}" STREQUAL "")
		message(FATAL_ERROR "exclude_sources_regex is empty, considering do not call InnerAddAllFiles diectly!")
	endif()

	set(GROUPED_FILES "")
	file(GLOB entries LIST_DIRECTORIES true ${dir_path}/*)

	foreach(entry ${entries})
		if(${entry} MATCHES ${exclude_sources_regex})
			continue()
		endif()

		get_filename_component(tempResult ${entry} NAME)

		if(IS_DIRECTORY ${entry} AND "${recurse}" STREQUAL "TRUE")
			InnerAddAllFiles(${entry} "${prefix}/${tempResult}" ${files_container_name} "${extensions}" ${recurse} ${exclude_sources_regex})
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

# 添加指定路径下的 符合指定模式的文件 至 给定容器中
#
# [ARGV0] `dir_path`: 将要添加的文件的路径
# [ARGV1] `prefix`: vs过滤器前缀
# [ARGV2] `files_container_name`: 指定添加的容器的名称
# [ARGV3] `extensions`: 源文件的扩展名
# [ARGV4][OPT] `recurse`: 是否递归
# [ARGV5][OPT] `exclude_sources_regex`: 排除的源文件
function(AddFiles dir_path prefix files_container_name extensions)
	if("${ARGV3}" STREQUAL "")
		message(FATAL_ERROR "extensions must not be empty")
	endif()

	if("${ARGV4}" STREQUAL "")
		set(recurse TRUE)
	else()
		set(recurse ${ARGV4})
	endif()

	set(exclude_sources_regex "((\\.cache|\\.git|build)$)")

	if(NOT "${ARGV5}" STREQUAL "")
		set(exclude_sources_regex "${exclude_sources_regex}|${ARGV5}")
	endif()

	if(${dir_path} MATCHES "^\\.?$")
		set(dir_path ${CMAKE_CURRENT_SOURCE_DIR})
	else()
		string(LENGTH ${dir_path} length)
		string(FIND ${dir_path} ${CMAKE_CURRENT_SOURCE_DIR} result)

		if(${result} EQUAL -1)
			message(FATAL_ERROR "couldn't add a directory's files which path is not in ${CMAKE_CURRENT_SOURCE_DIR}")
		endif()

		InnerAddAllFiles(${dir_path} ${prefix} ${files_container_name} "${extensions}" ${recurse} ${exclude_sources_regex})
		set(${files_container_name} ${${files_container_name}} PARENT_SCOPE)
	endif()
endfunction()

# 添加构建目标
#
# [ARGV0] target_name 目标名称
# [ARGV1] target_type 目标类型，可执行文件 `EXECUTABLE`, 动态库 `SHARED`, 静态库 `STATIC`
# [ARGV2][OPT] source_dir 源文件根目录
# [ARGV3][OPT] extra_sources 额外的源文件
# [ARGV4][OPT] exclude_sources_regex 需要排除的文件的模式
macro(AddTarget target_name target_type)
	# ###########################################################################################
	# 规整参数
	# ###########################################################################################
	if(TRUE)
		if("${ARGV2}" STREQUAL "")
			set(source_dir "${CMAKE_CURRENT_SOURCE_DIR}")
		else()
			set(source_dir ${ARGV2})
		endif()

		if("${ARGV3}" STREQUAL "")
			set(extra_sources "")
		else()
			set(extra_sources ${${ARGV3}})
		endif()

		if("${ARGV4}" STREQUAL "")
			set(exclude_sources_regex "")
		else()
			set(exclude_sources_regex ${ARGV4})
		endif()
	endif()

	# ###########################################################################################
	# 添加源文件、头文件、资源文件
	# ###########################################################################################
	if(TRUE)
		set(targetSources ${extra_sources})

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
	if(TRUE)
		list(APPEND precompileHeaders
			${source_dir}/StdAfx.h
			${source_dir}/stdafx.h
			${source_dir}/pch.h
			${source_dir}/include/pch.h
			${source_dir}/include/${target_name}/pch.h
			${CMAKE_CURRENT_SOURCE_DIR}/pch.h
			${CMAKE_CURRENT_SOURCE_DIR}/include/pch.h
			${CMAKE_CURRENT_SOURCE_DIR}/include/${target_name}/pch.h
		)

		foreach(header ${precompileHeaders})
			if(EXISTS ${header})
				target_precompile_headers(${target_name} PUBLIC ${header})
				break()
			endif()
		endforeach()

		unset(precompileHeaders)
	endif()

	# ###########################################################################################
	# 设置包含目录
	# ###########################################################################################
	if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include/${target_name})
		target_include_directories(${target_name}
			PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include/${target_name}
			INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include
		)
	elseif(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include)
		target_include_directories(${target_name} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
	else()
		target_include_directories(${target_name} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
	endif()

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
	if(NOT ${target_name} IN_LIST TARGETS)
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

# 输出配置目标信息
#
# 包含：
# 1.目标的类型
# 2.目标的名称
# 3.目标的头文件
# 4.目标的源文件
# 5.目标的包含目录
# 6.目标的链接目录
# 7.目标的预处理器定义
# 8.目标的编译选项
# 9.目标的链接选项
# 10.目标的链接选项
# 11.目标的链接文件
# 12.目标的安装信息
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

			if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
				foreach(file ${tempResult})
					message(STATUS "|       ${file}")
				endforeach()
			endif()

			# 打印源文件
			message(STATUS "|   with sources:")
			get_target_property(tempResult ${target} SOURCES)
			list(FILTER tempResult EXCLUDE REGEX ".*\.h$")

			if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
				foreach(file ${tempResult})
					message(STATUS "|       ${file}")
				endforeach()
			endif()

			# 打印包含目录
			get_target_property(tempResult ${target} INCLUDE_DIRECTORIES)
			message(STATUS "|   with include dirs:")

			if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
				foreach(dir ${tempResult})
					message(STATUS "|       ${dir}")
				endforeach()
			endif()

			# 打印链接目录
			get_target_property(tempResult ${target} LINK_DIRECTORIES)
			message(STATUS "|   with link dirs:")

			if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
				foreach(dir ${tempResult})
					message(STATUS "|       ${dir}")
				endforeach()
			endif()

			# 打印预处理器定义
			get_target_property(tempResult ${target} COMPILE_DEFINITIONS)
			message(STATUS "|   with definitions:")

			if(NOT "${tempResult}" STREQUAL "tempResult-NOTFOUND")
				foreach(item ${tempResult})
					message(STATUS "|       ${item}")
				endforeach()
			endif()

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
