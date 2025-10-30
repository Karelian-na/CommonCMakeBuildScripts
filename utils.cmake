# #######################################################################
# Common cmake macros and functions for CMake build scripts
#
# Author: Karelian_na
# ######################################################################

# Regular optional parameter, will produce a variable named <param_name> 
# which equals to <optional_arg_value> if provided, otherwise equals to <default_value>
#
# [ARGV0] optional_arg_value optional argument value to check, like `${ARGV1}`....
# [ARGV1] param_name parameter name to set
# [ARGV2][OPT] default_value default value to set if optional argument is empty, default to ""
macro(RegularOptionalParameter optional_arg_value param_name)
    if("${ARGV2}" STREQUAL "")
        set(default_value "")
    else()
        set(default_value ${ARGV2})
    endif()

    if("${ARGV0}" STREQUAL "")
        set(${param_name} ${default_value})
    else()
        set(${param_name} ${optional_arg_value})
    endif()

    unset(default_value)
endmacro()
