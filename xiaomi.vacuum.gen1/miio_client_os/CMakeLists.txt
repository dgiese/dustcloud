cmake_minimum_required(VERSION 2.8)

project(miio_client)

add_executable(${PROJECT_NAME} "main.c" "lib/cJSON/cJSON.c")
TARGET_LINK_LIBRARIES(${PROJECT_NAME} gcrypt)
set(CMAKE_C_FLAGS "${CMAKE_CXX_FLAGS} -std=c99 -Wall -pedantic -Wextra -fno-strict-aliasing")
