cmake_minimum_required(VERSION 3.21)

file(
    GLOB_RECURSE SH_SRC src/*.hlsl
)
file(
    GLOB_RECURSE SH_HEAD src/*.hlsli
)

find_program(
    DXC dxc
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

set(VERTEX_NAME "Vertex")
set(VERTEX_NAME1 "VS")
set(COMPUTE_NAME "Compute")
set(COMPUTE_NAME1 "CS")
set(MESH_NAME "Mesh")
set(MESH_NAME1 "MS")
set(AMP_NAME "Amplification")
set(AMP_NAME1 "AS")

foreach(SHADER ${SH_SRC})
    set(SHADER_MODEL 6_0)
    message(STATUS "Adding shader...")
    get_filename_component(FILE_NAME ${SHADER} NAME_WLE)
    message(STATUS ${SHADER})

    string(FIND ${FILE_NAME} ${VERTEX_NAME} vertexCheck)
    string(FIND ${FILE_NAME} ${VERTEX_NAME1} vertexCheck1)
    string(FIND ${FILE_NAME} ${COMPUTE_NAME} computeCheck)
    string(FIND ${FILE_NAME} ${COMPUTE_NAME1} computeCheck1)
    string(FIND ${FILE_NAME} ${MESH_NAME} meshCheck)
    string(FIND ${FILE_NAME} ${MESH_NAME1} meshCheck1)
    string(FIND ${FILE_NAME} ${AMP_NAME} ampCheck)
    string(FIND ${FILE_NAME} ${AMP_NAME1} ampCheck1)

    set(OUTPUT_NAME ${FILE_NAME})

    if(computeCheck GREATER "-1" OR computeCheck1 GREATER "-1")
        set(SHADER_TYPE cs)
    elseif(vertexCheck GREATER "-1" OR vertexCheck1 GREATER "-1")
        set(SHADER_TYPE vs)
    elseif(ampCheck GREATER "-1" OR ampCheck1 GREATER "-1")
        set(SHADER_TYPE as)
        set(SHADER_MODEL 6_5)
    elseif(meshCheck GREATER "-1" OR meshCheck1 GREATER "-1")
        set(SHADER_TYPE ms)
        set(SHADER_MODEL 6_5)
    else()
        set(SHADER_TYPE ps)
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
