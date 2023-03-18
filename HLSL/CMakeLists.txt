cmake_minimum_required(VERSION 3.21)

file(
    GLOB_RECURSE SH_SRC
     src/*.hlsl
)
file(
    GLOB_RECURSE SH_HEAD
     src/*.hlsli
)

find_program(
    DXC
     dxc
)

set(SHADER_PATH resources/shaders)

foreach(SHADER ${SH_SRC})
    get_filename_component(FILE_NAME ${SHADER} NAME_WLE)
    set(CSO "${CMAKE_BINARY_DIR}/${SHADER_PATH}/${FILE_NAME}.cso")
    list(APPEND DX_BINARY ${CSO})
endforeach(SHADER)

add_custom_target(
    HLSL
    ALL
    DEPENDS
     ${DX_BINARY}
    SOURCES
     ${SH_SRC} ${SH_HEAD}
)

set(SHADER_MODEL 6_0)
set(VERTEX_NAME "Vertex")
set(PIXEL_NAME "Pixel")
set(COMPUTE_NAME "Compute")
set(MESH_NAME "Mesh")

foreach(SHADER ${SH_SRC})
    message(STATUS "Adding shader...")
    get_filename_component(FILE_NAME ${SHADER} NAME_WLE)
    message(STATUS ${SHADER})

    string(FIND ${FILE_NAME} ${VERTEX_NAME} vertexCheck)    
    string(FIND ${FILE_NAME} ${PIXEL_NAME} pixelCheck)
    string(FIND ${FILE_NAME} ${COMPUTE_NAME} computeCheck)
    string(FIND ${FILE_NAME} ${MESH_NAME} meshCheck)
    
    set(OUTPUT_NAME ${FILE_NAME})
    if(vertexCheck GREATER "-1")
        set(SHADER_TYPE vs)
    elseif(pixelCheck GREATER "-1")
        set(SHADER_TYPE ps)
        string(REPLACE ${PIXEL_NAME} "" OUTPUT_NAME ${FILE_NAME})
    elseif(computeCheck GREATER "-1")
        set(SHADER_TYPE cs)
    elseif(meshCheck GREATER "-1")
        set(SHADER_TYPE ms)
        set(SHADER_MODEL 6_5)
    endif()

    set(CSO "${CMAKE_BINARY_DIR}/${SHADER_PATH}/${OUTPUT_NAME}.cso")
    
    add_custom_command(
        TARGET
         HLSL
        POST_BUILD
        COMMAND ${CMAKE_COMMAND}
         -E make_directory ${CMAKE_BINARY_DIR}/${SHADER_PATH}
        COMMAND
         ${DXC} ${SHADER} -E main -T ${SHADER_TYPE}_${SHADER_MODEL} -Fo ${CSO}
        COMMAND ${CMAKE_COMMAND}
         -E copy ${CSO} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/${SHADER_PATH}/${OUTPUT_NAME}.cso
        DEPENDS
         ${SHADER}
    )
endforeach(SHADER)

set_source_files_properties(${SH_SRC} PROPERTIES VS_TOOL_OVERRIDE CustomBuild)

source_group("Source Files" FILES ${SH_SRC})
source_group("Header Files" FILES ${SH_HEAD})