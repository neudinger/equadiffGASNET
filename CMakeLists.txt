cmake_minimum_required(VERSION 3.19...3.23 FATAL_ERROR)

set(TARGET "stencil")
set(TARGET_VERSION 1.0)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
project(${TARGET} LANGUAGES CXX VERSION ${TARGET_VERSION})

function(join_paths joined_path first_path_segment)
    set(temp_path "${first_path_segment}")
    foreach(current_segment IN LISTS ARGN)
        if(NOT ("${current_segment}" STREQUAL ""))
            if(IS_ABSOLUTE "${current_segment}")
                set(temp_path "${current_segment}")
            else()
                set(temp_path "${temp_path}/${current_segment}")
            endif()
        endif()
    endforeach()
    set(${joined_path} "${temp_path}" PARENT_SCOPE)
endfunction()

# https://llvm.org/docs/CMake.html#frequently-used-cmake-variables
# 1. Release: `-O3 -DNDEBUG`
# 2. Debug: `-O0 -g`
# 3. RelWithDebInfo: `-O2 -g -DNDEBUG`
# 4. MinSizeRel: `-Os -DNDEBUG`
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif(NOT CMAKE_BUILD_TYPE)

if(PRINT_PERF)
    add_compile_definitions(PRINT_PERF=True)
    add_compile_definitions(PERF_ON_RANK_0_ONLY=True)
endif(PRINT_PERF)

message(STATUS "CMAKE_BUILD_TYPE is " ${CMAKE_BUILD_TYPE})
message(STATUS "CXX = \"$ENV{CXX}\" for ${TARGET}")

# https://blog.minhazav.dev/guide-compiler-to-auto-vectorise/#loop-unrolling
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=native -ftree-slp-vectorize -ftree-vectorize -ffast-math -funroll-loops")
# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wold-style-cast -Wunused-variable -Wunused-parameter -Wextra -Wreorder -Wconversion -Wsign-conversion")
# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wpedantic")

get_filename_component(HOME_DIR ${PROJECT_SOURCE_DIR} PATH)
set(WORKDIR ${CMAKE_CURRENT_LIST_DIR})
set(INCLUDE_DIR ${WORKDIR}/include)
message(STATUS "CMAKE_CURRENT_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}")
message(STATUS "PROJECT_SOURCE_DIR in: ${PROJECT_SOURCE_DIR}")
message(STATUS "WORKDIR in: ${WORKDIR}")
message(STATUS "INCLUDE_DIR in: ${INCLUDE_DIR}")
include_directories(${INCLUDE_DIR})

file(GLOB 
    SRC
    "${WORKDIR}/src/*.cc"
)

add_executable(
  ${TARGET}
  ${SRC}
)

# ------------- DEPENDENCIES ------------- #

include(FetchContent)

# http://www.gpi-site.com/
# https://github.com/cc-hpc-itwm/GPI-2/archive/v1.4.0.tar.gz

set(GPI2_HOME $ENV{GPI2_HOME} CACHE STRING "Description")
if(GPI2_HOME)
  message(STATUS "GPI2_HOME set in " ${GPI2_HOME})
  join_paths(GPI2_INCLUDE_PATH "${GPI2_HOME}" "include")
elseif(NOT EXISTS "${CMAKE_BINARY_DIR}/GPI2")
  set(GPI2_SOURCE_DIR ${CMAKE_BINARY_DIR}/GPI2)
  message(STATUS "Dowloading GPI2")
  FetchContent_Declare(
    GPI2_SRC
    SOURCE_DIR GPI2
    URL https://github.com/cc-hpc-itwm/GPI-2/archive/refs/tags/v1.5.1.tar.gz
  )
  FetchContent_MakeAvailable(GPI2_SRC)
  message(STATUS "Building GPI2")
  set(GPI2_HOME ${GPI2_SOURCE_DIR}/local CACHE INTERNAL "" FORCE)
  add_custom_command(
    OUTPUT  GPI2_bootstrap
    COMMAND ${GPI2_SOURCE_DIR}/autogen.sh && 
    ${GPI2_SOURCE_DIR}/configure --with-gnu-ld --prefix=${GPI2_SOURCE_DIR}/local
    WORKING_DIRECTORY "${GPI2_SOURCE_DIR}"
    COMMENT "bootstrap GPI2"
  )
  add_custom_target(gpi2
    COMMAND make -j8 -C ${GPI2_SOURCE_DIR} && 
    make install -C ${GPI2_SOURCE_DIR}
    WORKING_DIRECTORY "${GPI2_SOURCE_DIR}"
    COMMENT "make && make install"
    DEPENDS GPI2_bootstrap
  )
  add_dependencies(${TARGET} gpi2)
  message(WARNING "export PATH=$PATH:${GPI2_HOME}/bin/")
endif()
  
join_paths(GPI2_INCLUDE_PATH "${GPI2_HOME}" "include")
include_directories(${GPI2_INCLUDE_PATH})
join_paths(GPI2_LIBRARIES_PATH "${GPI2_HOME}" "lib64")

if(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
  join_paths(GPI2_LIBRARIES "${GPI2_LIBRARIES_PATH}" "libGPI2-dbg.so")
else()
  join_paths(GPI2_LIBRARIES "${GPI2_LIBRARIES_PATH}" "libGPI2.so")
endif()

find_package(Boost 1.70.0 COMPONENTS program_options)
set(Boost_USE_STATIC_LIBS       ON)   # only find static libs
set(Boost_USE_DEBUG_LIBS        OFF)  # ignore debug libs and
set(Boost_USE_RELEASE_LIBS      ON)   # only find release libs
set(Boost_USE_MULTITHREADED     ON)
set(Boost_USE_STATIC_RUNTIME    ON)
if(NOT ${Boost_FOUND})
# https://cmake.org/cmake/help/latest/module/FindBoost.html?highlight=findboost
  message(STATUS "Downloading boost")
  FetchContent_Declare(
    boost_src
    SOURCE_DIR Boost
    URL https://boostorg.jfrog.io/artifactory/main/release/1.79.0/source/boost_1_79_0.tar.bz2
    URL_HASH SHA256=475d589d51a7f8b3ba2ba4eda022b170e562ca3b760ee922c146b6c65856ef39
  )
  FetchContent_MakeAvailable(boost_src)
  message(STATUS "boost_src_SOURCE_DIR in: ${boost_src_SOURCE_DIR}")
  if(NOT EXISTS "${boost_src_SOURCE_DIR}/stage")
    message(STATUS "Building boost")
    add_custom_command(
      OUTPUT  boost_bootstrap
      COMMAND ${boost_src_SOURCE_DIR}/bootstrap.sh --with-libraries=program_options
      WORKING_DIRECTORY "${boost_src_SOURCE_DIR}"
      COMMENT "bootstrap boost"
    )
    add_custom_target(boost_b2
      COMMAND ${boost_src_SOURCE_DIR}/b2
      WORKING_DIRECTORY "${boost_src_SOURCE_DIR}"
      COMMENT "b2"
      DEPENDS boost_bootstrap
    )
    add_dependencies(${TARGET} boost_b2)
    set(Boost_INCLUDE_DIR ${boost_src_SOURCE_DIR})
    message(${Boost_INCLUDE_DIR})
    set(Boost_INCLUDE_DIRS ${boost_src_SOURCE_DIR})
    message(STATUS "Boost_INCLUDE_DIRS set to ${Boost_INCLUDE_DIRS}")
    set(BOOST_LIBS_OPTIONAL
      program_options
      CACHE STRING "Boost libs to be compiled"
    )
    set(Boost_LIBRARIES "")
    foreach(lib ${BOOST_LIBS_OPTIONAL})
      # In case only a subset of modules is available (eg. after using bcp)
      list(APPEND Boost_LIBRARIES "${boost_src_SOURCE_DIR}/stage/lib/libboost_${lib}.a")
      # list(APPEND Boost_LIBRARIES "${boost_src_SOURCE_DIR}/stage/lib/libboost_${lib}.so")
    endforeach()
  else(NOT EXISTS "${boost_src_SOURCE_DIR}/stage")
    set(Boost_INCLUDE_DIR "${CMAKE_BINARY_DIR}/Boost")
  endif(NOT EXISTS "${boost_src_SOURCE_DIR}/stage")
endif(NOT ${Boost_FOUND})

if(EXISTS "${boost_src_SOURCE_DIR}/stage")
  find_package(Boost EXACT 1.79.0 REQUIRED COMPONENTS program_options)
endif(EXISTS "${boost_src_SOURCE_DIR}/stage")
include_directories(${Boost_INCLUDE_DIRS})

set_property(TARGET ${TARGET} PROPERTY CXX_STANDARD ${CMAKE_CXX_STANDARD})
target_compile_features(${TARGET} PRIVATE cxx_std_${CMAKE_CXX_STANDARD})

set_target_properties(
    ${TARGET}
    PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

if(OPENMP)
  find_package(OpenMP)
  if(OpenMP_CXX_FOUND)
      target_link_libraries(${TARGET} PUBLIC OpenMP::OpenMP_CXX)
  endif(OpenMP_CXX_FOUND)
endif(OPENMP)

target_link_libraries(
    ${TARGET}
    PRIVATE
    ${GPI2_LIBRARIES}
    ${Boost_LIBRARIES} # Boost::program_options
    pthread # multithreading
    m # math
    dl # dynamic loader
    z # zlib
    hwloc
    ibverbs # infiniband
)