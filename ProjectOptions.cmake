include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(parallel_fft_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(parallel_fft_setup_options)
  option(parallel_fft_ENABLE_HARDENING "Enable hardening" ON)
  option(parallel_fft_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    parallel_fft_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    parallel_fft_ENABLE_HARDENING
    OFF)

  parallel_fft_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR parallel_fft_PACKAGING_MAINTAINER_MODE)
    option(parallel_fft_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(parallel_fft_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(parallel_fft_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(parallel_fft_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(parallel_fft_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(parallel_fft_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(parallel_fft_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(parallel_fft_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(parallel_fft_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(parallel_fft_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(parallel_fft_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(parallel_fft_ENABLE_PCH "Enable precompiled headers" OFF)
    option(parallel_fft_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(parallel_fft_ENABLE_IPO "Enable IPO/LTO" ON)
    option(parallel_fft_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(parallel_fft_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(parallel_fft_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(parallel_fft_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(parallel_fft_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(parallel_fft_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(parallel_fft_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(parallel_fft_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(parallel_fft_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(parallel_fft_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(parallel_fft_ENABLE_PCH "Enable precompiled headers" OFF)
    option(parallel_fft_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      parallel_fft_ENABLE_IPO
      parallel_fft_WARNINGS_AS_ERRORS
      parallel_fft_ENABLE_USER_LINKER
      parallel_fft_ENABLE_SANITIZER_ADDRESS
      parallel_fft_ENABLE_SANITIZER_LEAK
      parallel_fft_ENABLE_SANITIZER_UNDEFINED
      parallel_fft_ENABLE_SANITIZER_THREAD
      parallel_fft_ENABLE_SANITIZER_MEMORY
      parallel_fft_ENABLE_UNITY_BUILD
      parallel_fft_ENABLE_CLANG_TIDY
      parallel_fft_ENABLE_CPPCHECK
      parallel_fft_ENABLE_COVERAGE
      parallel_fft_ENABLE_PCH
      parallel_fft_ENABLE_CACHE)
  endif()

  parallel_fft_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (parallel_fft_ENABLE_SANITIZER_ADDRESS OR parallel_fft_ENABLE_SANITIZER_THREAD OR parallel_fft_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(parallel_fft_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(parallel_fft_global_options)
  if(parallel_fft_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    parallel_fft_enable_ipo()
  endif()

  parallel_fft_supports_sanitizers()

  if(parallel_fft_ENABLE_HARDENING AND parallel_fft_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR parallel_fft_ENABLE_SANITIZER_UNDEFINED
       OR parallel_fft_ENABLE_SANITIZER_ADDRESS
       OR parallel_fft_ENABLE_SANITIZER_THREAD
       OR parallel_fft_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${parallel_fft_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${parallel_fft_ENABLE_SANITIZER_UNDEFINED}")
    parallel_fft_enable_hardening(parallel_fft_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(parallel_fft_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(parallel_fft_warnings INTERFACE)
  add_library(parallel_fft_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  parallel_fft_set_project_warnings(
    parallel_fft_warnings
    ${parallel_fft_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(parallel_fft_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    parallel_fft_configure_linker(parallel_fft_options)
  endif()

  include(cmake/Sanitizers.cmake)
  parallel_fft_enable_sanitizers(
    parallel_fft_options
    ${parallel_fft_ENABLE_SANITIZER_ADDRESS}
    ${parallel_fft_ENABLE_SANITIZER_LEAK}
    ${parallel_fft_ENABLE_SANITIZER_UNDEFINED}
    ${parallel_fft_ENABLE_SANITIZER_THREAD}
    ${parallel_fft_ENABLE_SANITIZER_MEMORY})

  set_target_properties(parallel_fft_options PROPERTIES UNITY_BUILD ${parallel_fft_ENABLE_UNITY_BUILD})

  if(parallel_fft_ENABLE_PCH)
    target_precompile_headers(
      parallel_fft_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(parallel_fft_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    parallel_fft_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(parallel_fft_ENABLE_CLANG_TIDY)
    parallel_fft_enable_clang_tidy(parallel_fft_options ${parallel_fft_WARNINGS_AS_ERRORS})
  endif()

  if(parallel_fft_ENABLE_CPPCHECK)
    parallel_fft_enable_cppcheck(${parallel_fft_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(parallel_fft_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    parallel_fft_enable_coverage(parallel_fft_options)
  endif()

  if(parallel_fft_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(parallel_fft_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(parallel_fft_ENABLE_HARDENING AND NOT parallel_fft_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR parallel_fft_ENABLE_SANITIZER_UNDEFINED
       OR parallel_fft_ENABLE_SANITIZER_ADDRESS
       OR parallel_fft_ENABLE_SANITIZER_THREAD
       OR parallel_fft_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    parallel_fft_enable_hardening(parallel_fft_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
