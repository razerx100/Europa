cmake_minimum_required(VERSION 3.21)

file(
    GLOB_RECURSE SH_SRC
     src/*.hlsl src/*.hlsli
)

find_program(
    DXC
     dxc.exe
)

add_custom_target(
    HLSL
    DEPENDS
     ${DX_BINARY}
    SOURCES
     ${SH_SRC}
)

set(SHADER_MODEL 6_0)
set(SHADER_PATH resources/shaders)

foreach(SHADER ${SH_SRC})
    message(STATUS "Adding shader...")
    get_filename_component(FILE_NAME ${SHADER} NAME_WLE)
    set(CSO "${CMAKE_BINARY_DIR}/${SHADER_PATH}/${FILE_NAME}.cso")
    message(STATUS ${SHADER})

    string(TOLOWER ${FILE_NAME} lowerFileName)
    string(FIND ${lowerFileName} "vertex" vertexCheck)    
    string(FIND ${lowerFileName} "pixel" pixelCheck)
    string(FIND ${lowerFileName} "compute" computeCheck)
    
    if(vertexCheck GREATER "-1")
        set(SHADER_TYPE vs)
    elseif(pixelCheck GREATER "-1")
        set(SHADER_TYPE ps)
    elseif(computeCheck GREATER "-1")
        set(SHADER_TYPE cs)
    endif()
    
    add_custom_command(
        TARGET
         HLSL
        POST_BUILD
        COMMAND
         ${DXC} ${SHADER} -E main -T ${SHADER_TYPE}_${SHADER_MODEL} -Fo ${CSO}
        COMMAND ${CMAKE_COMMAND}
         -E copy ${CSO} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/${SHADER_PATH}/${FILE_NAME}.cso
        DEPENDS
         ${SHADER}
    )
    list(APPEND DX_BINARY ${CSO})
endforeach(SHADER)

set_source_files_properties(${SH_SRC} PROPERTIES VS_TOOL_OVERRIDE CustomBuild)

source_group("Source Files" FILES ${SH_SRC})