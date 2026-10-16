cmake_minimum_required(VERSION 3.17.1)

# Verify that the consumer loads the shared library and runs both object lifetimes.
execute_process(
    COMMAND "${TEST_EXECUTABLE}"
    RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE errors
)
if(NOT "${result}" STREQUAL "0")
    message(FATAL_ERROR "The executable failed (${result}):\n${output}${errors}")
endif()
if(NOT "${output}" STREQUAL "HelloHellowordword")
    message(FATAL_ERROR "Unexpected constructor/destructor output: '${output}'\n${errors}")
endif()
