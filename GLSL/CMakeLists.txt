cmake_minimum_required(VERSION 3.21)

file(
    GLOB_RECURSE SH_SRC
     src/*.frag src/*.vert
)

find_program(
    GLSLC
     glslc
    HINTS
     /usr/bin
     /usr/local/bin
     $ENV{VULKAN_SDK}/Bin/
)

foreach(SHADER ${SH_SRC})
    get_filename_component(FILE_NAME ${SHADER} NAME_WLE)
    set(SPIRV "${CMAKE_BINARY_DIR}/${SHADER_PATH}/${FILE_NAME}.spv")
    list(APPEND SPIRV_BINARY ${SPIRV})
endforeach(SHADER)

add_custom_target(
    GLSL
    ALL
    DEPENDS
     ${SPIRV_BINARY}
    SOURCES
     ${SH_SRC}
)

set(SHADER_PATH resources/shaders)

foreach(SHADER ${SH_SRC})
    message(STATUS "Adding shader...")
    get_filename_component(FILE_NAME ${SHADER} NAME_WLE)
    set(SPIRV "${CMAKE_BINARY_DIR}/${SHADER_PATH}/${FILE_NAME}.spv")
    message(STATUS ${SHADER})

    add_custom_command(
        TARGET
         GLSL
        POST_BUILD
        COMMAND
         ${GLSLC} ${SHADER} -o ${SPIRV}
        COMMAND ${CMAKE_COMMAND}
         -E copy ${SPIRV} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/${SHADER_PATH}/${FILE_NAME}.spv
        DEPENDS
         ${SHADER}
    )
endforeach(SHADER)

source_group("Source Files" FILES ${SH_SRC})


