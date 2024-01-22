
function(ctype_python_binding targets)
    # Check if ctypesgen module exists
    execute_process(
        COMMAND python -c "import ctypesgen;"
        RESULT_VARIABLE CTYPE_EXISTS
        ERROR_QUIET
    )
    
    if(NOT "${CTYPE_EXISTS}" EQUAL "0")
    message(FATAL_ERROR "ctypesgen python module isn't installed. Please install it using pip.")
    endif()

    # Iterate over all targets and add targets for python bindings
    foreach(target ${targets})
        # Enable preprocessed outputs for headers
        if(MSVC)
            set_property(TARGET ${target} PROPERTY WINDOWS_EXPORT_ALL_SYMBOLS ON)
            set(compiler_args /P /EP /Fi${CMAKE_CURRENT_BINARY_DIR}/ctypesgen_intermediates/)
        else()
            set(compiler_args -E -P -o ${CMAKE_CURRENT_BINARY_DIR}/ctypesgen_intermediates/)
        endif()

        get_target_property(include_dirs ${target} INTERFACE_INCLUDE_DIRECTORIES)
        if(include_dirs)
            foreach(include_dirs ${public_headers})
                if(MSVC)
                    set(compiler_args ${compiler_args} "/I${public_header}")
                else()
                    set(compiler_args ${compiler_args} "-I${public_header}")
                endif()
            endforeach()
        endif()

        get_target_property(compile_defs ${target} COMPILE_DEFINITIONS)
        if(compile_defs)
            foreach(comp_definition ${compile_defs})
            if(MSVC)
            set(compiler_args ${compiler_args} /D${comp_definition})
            else()
            set(compiler_args ${compiler_args} -D${comp_definition})
            endif()
            endforeach()
        endif()

        set(public_headers "")
        set(preprocessed_headers "")
        if(include_dirs)
            foreach(include_dir ${include_dirs})
                file(GLOB headers ${include_dir}/*.h)
                set(public_headers ${public_headers} ${headers})
            endforeach()
        endif()

        set(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${HEADER}.i")

        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/ctypesgen_intermediates
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/ctypesgen_intermediates/
            COMMAND ${CMAKE_CXX_COMPILER} ${compiler_args} ${public_headers}
            COMMENT "Preprocessing headers ${public_headers} "
            DEPENDS ${target}
            VERBATIM
        )
        
        set(preprocessed_headers "")
        foreach(public_header ${public_headers})
            get_filename_component(header_name ${public_header} NAME)
            string(REPLACE ".h" ".i " preprocessed_name ${header_name})
            set(preprocessed_headers  ${preprocessed_headers} ${CMAKE_CURRENT_BINARY_DIR}/ctypesgen_intermediates/${preprocessed_name})
        endforeach()

        if(NOT "${header_inputs}" EQUAL "")
            message("${header_inputs}")
            add_custom_target(${target}.py 
                COMMAND python -m ctypesgen --preprocessed --all-headers -l$<TARGET_FILE:${target}> ${preprocessed_headers} -o ${target}.py
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/ctypesgen_intermediates
            )
        endif()

    endforeach()
endfunction()