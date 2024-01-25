set(CTYPESGEN_INTERNAL_DIR ${CMAKE_CURRENT_LIST_DIR} CACHE INTERNAL "")

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
        set(shared_library_name ${target})
        get_target_property(target_type ${target} TYPE)
        if (target_type STREQUAL STATIC_LIBRARY)
        message(STATUS "Given ${target} library is static, ctypesgen supports shared librarys only so ${target}_ctypesgen_shared target is created for to create bindings")
        add_library(${target}_ctypesgen_shared SHARED $<TARGET_OBJECTS:${target}>)
        target_link_libraries(${target}_ctypesgen_shared PUBLIC ${target})
        set(shared_library_name ${target}_ctypesgen_shared)
        endif()


        # Enable preprocessed outputs for headers
        list(APPEND myList "value1" "\"value with spaces\"" "value3")
        if(MSVC)
            set_property(TARGET ${shared_library_name} PROPERTY WINDOWS_EXPORT_ALL_SYMBOLS ON)
            list(APPEND compiler_args /P /EP /Fi${CMAKE_CURRENT_BINARY_DIR}/ctypesgen_intermediates/ /FI${CTYPESGEN_INTERNAL_DIR}/ctypesgen_defs.h)
        else()
            list(APPEND compiler_args -E -P -o ${CMAKE_CURRENT_BINARY_DIR}/ctypesgen_intermediates/ -dD "-D__extension__==" "-D__const=const" "-D__asm__(x)=" "-D__asm(x)=" "-DCTYPESGEN=1")
        endif()

        get_target_property(include_dirs ${target} INTERFACE_INCLUDE_DIRECTORIES)
        if(include_dirs)
            foreach(include_dir ${include_dirs})
                if(MSVC)
                list(APPEND compiler_args "/I${include_dir}")
                else()
                list(APPEND compiler_args "-I${include_dir}")
                endif()
            endforeach()
        endif()

        get_target_property(compile_defs ${target} COMPILE_DEFINITIONS)
        if(compile_defs)
            foreach(comp_definition ${compile_defs})
            if(MSVC)
            list(APPEND compiler_args /D${comp_definition})
            else()
            list(APPEND compiler_args -D${comp_definition})
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

        set(compiler ${CMAKE_CXX_COMPILER})

        get_target_property(target_language ${target} LANGUAGE)
        if("${target_language}" STREQUAL "C")
        set(compiler ${CMAKE_C_COMPILER})
        endif()

        string(JOIN " " compiler_args "${compiler_args}")
        add_custom_target(${target}_preprocessed_headers
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/ctypesgen_intermediates/
            COMMAND ${compiler} ${compiler_args} ${public_headers}
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
                COMMAND python -m ctypesgen --preprocessed --all-headers --save-preprocessed-headers ${target}_preprocessed.i -l$<TARGET_FILE:${shared_library_name}> ${preprocessed_headers} -o ${target}.py
            DEPENDS ${target}_preprocessed_headers
            )
        endif()

    endforeach()
endfunction()