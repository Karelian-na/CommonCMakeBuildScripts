cmake_minimum_required(VERSION 3.17.1)

if(TEST_CASE STREQUAL "mismatch-x86")
    set(expectedDiagnostic "Requested target architecture 'x86' does not match the compiler ABI 'x64'")
elseif(TEST_CASE STREQUAL "mismatch-x64")
    set(expectedDiagnostic "Requested target architecture 'x64' does not match the compiler ABI 'x86'")
elseif(TEST_CASE STREQUAL "invalid-request")
    set(expectedDiagnostic "Unsupported requested target architecture: unknown")
elseif(TEST_CASE STREQUAL "missing-abi")
    set(expectedDiagnostic "Unsupported x86 pointer size:")
else()
    message(FATAL_ERROR "Unknown rejection case: ${TEST_CASE}")
endif()

# Child script processes exercise fatal diagnostics, not project configuration.
execute_process(
    COMMAND "${CMAKE_COMMAND}" "-DTEST_CASE=${TEST_CASE}" -P "${CMAKE_CURRENT_LIST_DIR}/architecture.test.cmake"
    RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE errors
)
string(APPEND output "${errors}")
string(REGEX REPLACE "[ \t\r\n]+" " " normalizedOutput "${output}")
string(FIND "${normalizedOutput}" "${expectedDiagnostic}" diagnosticPosition)
if(NOT "${result}" STREQUAL "1" OR diagnosticPosition EQUAL -1)
    message(FATAL_ERROR "${TEST_CASE} did not report the expected architecture rejection:\n${output}")
endif()
message(STATUS "PASS ${TEST_CASE}: rejected before output directory selection")