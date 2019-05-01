#
# Copyright 2019, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the BSD 2-Clause license. Note that NO WARRANTY is provided.
# See "LICENSE_BSD2.txt" for details.
#
# @TAG(DATA61_BSD)
#

cmake_minimum_required(VERSION 3.7.2)
include_guard(GLOBAL)

# This takes a camkes produced dependency file (this means we can assume one dependency
# per line) and produces a cmake list of dependencies
function(MakefileDepsToList mdfile output_variable)
    file(READ "${mdfile}" raw_file)
    # First remove the target of the dependency list
    string(
        REGEX
        REPLACE
            "^[^:]*: \\\\\r?\n"
            ""
            string_deps
            "${raw_file}"
    )
    # Now turn the list of dependencies into a cmake list. We have assumed
    # that this makefile dep file was generated by camkes and so it has one
    # item per line
    string(
        REGEX
        REPLACE
            "\\\\\r?\n"
            ";"
            deps
            "${string_deps}"
    )
    # Strip the space from each dep
    foreach(dep IN LISTS deps)
        # Strip extra spacing
        string(STRIP "${dep}" dep)
        list(APPEND final_deps "${dep}")
    endforeach()
    # Write the output to the parent
    set("${output_variable}" "${final_deps}" PARENT_SCOPE)
endfunction(MakefileDepsToList)

# Wraps a call to execute_process with checks that only rerun execute_process
# if the command or input files are changed. It also uses a depfile to track
# any files that the command touches internally. This function currently won't
# work without a depfile.
macro(execute_process_with_stale_check invoc_file deps_file outfile extra_dependencies)
    # We need to determine if we actually need to regenerate. We start by assuming that we do
    set(regen TRUE)
    if((EXISTS "${invoc_file}") AND (EXISTS "${deps_file}") AND (EXISTS "${outfile}"))
        file(READ "${invoc_file}" old_contents)
        if("${old_contents}" STREQUAL "${ARGN}")
            MakefileDepsToList("${deps_file}" deps)
            # At this point assume we do not need to regenerate, unless we found a newer file
            set(regen FALSE)
            foreach(dep IN LISTS deps extra_dependencies)
                if("${dep}" IS_NEWER_THAN "${outfile}")
                    set(regen TRUE)
                    break()
                endif()
            endforeach()
        endif()
    endif()
    if(regen)
        message(STATUS "${outfile} is out of date. Regenerating...")
        execute_process(${ARGN})
        file(WRITE "${invoc_file}" "${ARGN}")
    endif()
    # Add dependencies
    MakefileDepsToList("${deps_file}" deps)
    set_property(
        DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        APPEND
        PROPERTY CMAKE_CONFIGURE_DEPENDS "${deps};${extra_dependencies}"
    )

endmacro(execute_process_with_stale_check)

# For custom commands that invoke other build systems, we can create a depfile
# based on a find traversal of the directory.  This saves using CMake to glob it
# which is much slower
macro(create_depfile_by_find ret outfile depfile dir)
    file(RELATIVE_PATH path ${CMAKE_BINARY_DIR} ${outfile})
    list(
        APPEND
            ${ret}
            COMMAND
            echo
            "${path}: \\\\"
            >
            ${depfile}
    )
    list(
        APPEND ${ret} COMMAND
        find
            -L
            ${dir}
            -type
            f
            -printf
            "%p "
            >>
            ${depfile}
    )
    list(APPEND ${ret} DEPFILE ${depfile})
endmacro()
