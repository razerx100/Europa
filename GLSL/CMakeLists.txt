cmake_minimum_required(VERSION 3.21)

project(EuropaGLSL)

file(GLOB_RECURSE SH_SRC src/*.frag src/*.vert)

add_executable(${PROJECT_NAME}
    ${SH_SRC}
)

set_target_properties(${PROJECT_NAME} PROPERTIES LINKER_LANGUAGE CXX)
