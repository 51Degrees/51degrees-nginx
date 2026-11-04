cmake_minimum_required(VERSION 3.24)
project(PerformanceTest)

include(ExternalProject)

set(EXTERNAL_INSTALL_LOCATION ${CMAKE_BINARY_DIR}/external)

ExternalProject_Add(ApacheBench
    GIT_REPOSITORY https://github.com/51degrees/apachebench
    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${EXTERNAL_INSTALL_LOCATION}
    GIT_TAG main
    STEP_TARGETS build
    EXCLUDE_FROM_ALL TRUE
)


# Obtain the User-Agents evidence file from the data repository, which is
# the cxx/data sub-module. Where the file is not there, the repository's
# get-data-files.sh downloads it beside its .link file. The size check
# guards against a missing or truncated file, either of which would
# silently degrade the benchmark.
set(DATA_DIR "${CMAKE_CURRENT_LIST_DIR}/../../cxx/data")
set(UAS_NAME "20000 User Agents.csv")
set(UAS_LOCAL "${DATA_DIR}/device-detection/${UAS_NAME}")
set(UAS_TARGET ${CMAKE_BINARY_DIR}/uas.csv)
set(UAS_MIN_SIZE 100000)

function(check_file_size filename minsize resultvar)
    set(${resultvar} FALSE PARENT_SCOPE)
    if(EXISTS ${filename})
        file(SIZE ${filename} _size)
        if(_size GREATER ${minsize})
            set(${resultvar} TRUE PARENT_SCOPE)
        endif()
    endif()
endfunction(check_file_size)

# Downloads a device detection data file into cxx/data with the data
# repository's script. The size check that follows reports a failure.
function(download_data_file name)
    message(STATUS "Downloading ${name} with cxx/data/get-data-files.sh")
    execute_process(COMMAND sh "${DATA_DIR}/get-data-files.sh" "${name}")
endfunction(download_data_file)

check_file_size(${UAS_TARGET} ${UAS_MIN_SIZE} UAS_TARGET_OK)
if(NOT UAS_TARGET_OK)
    check_file_size(${UAS_LOCAL} ${UAS_MIN_SIZE} UAS_LOCAL_OK)
    if(NOT UAS_LOCAL_OK)
        download_data_file("${UAS_NAME}")
        check_file_size(${UAS_LOCAL} ${UAS_MIN_SIZE} UAS_LOCAL_OK)
    endif()
    if(UAS_LOCAL_OK)
        message(STATUS "Using User-Agents file from cxx/data")
        file(COPY_FILE ${UAS_LOCAL} ${UAS_TARGET})
    else()
        message(WARNING
            "The User-Agents file could not be found in cxx/data or "
            "downloaded, so the device detection benchmark will not use "
            "varied User-Agents. From the root of the repository, "
            "sh cxx/data/get-data-files.sh '${UAS_NAME}' downloads it.")
    endif()
endif()

# Obtain the evidence records file in the same way. This is the same set
# of evidence the other 51Degrees APIs benchmark against, so the device
# detection benchmark sends a full set of headers per request (including
# the Sec-CH-UA client hints) rather than a User-Agent alone. The file is
# copied to a name without spaces so it is simple to pass on a command
# line.
set(EVIDENCE_NAME "20000 Evidence Records.yml")
set(EVIDENCE_LOCAL "${DATA_DIR}/device-detection/${EVIDENCE_NAME}")
set(EVIDENCE_TARGET ${CMAKE_BINARY_DIR}/evidence.yml)
set(EVIDENCE_MIN_SIZE 1000000)

check_file_size(${EVIDENCE_TARGET} ${EVIDENCE_MIN_SIZE} EVIDENCE_TARGET_OK)
if(NOT EVIDENCE_TARGET_OK)
    check_file_size(${EVIDENCE_LOCAL} ${EVIDENCE_MIN_SIZE} EVIDENCE_LOCAL_OK)
    if(NOT EVIDENCE_LOCAL_OK)
        download_data_file("${EVIDENCE_NAME}")
        check_file_size(${EVIDENCE_LOCAL} ${EVIDENCE_MIN_SIZE} EVIDENCE_LOCAL_OK)
    endif()
    if(EVIDENCE_LOCAL_OK)
        message(STATUS "Using evidence file from cxx/data")
        file(COPY_FILE ${EVIDENCE_LOCAL} ${EVIDENCE_TARGET})
    else()
        message(WARNING
            "The evidence file could not be found in cxx/data or "
            "downloaded, so the device detection benchmark will fall back "
            "to varied User-Agents only. From the root of the repository, "
            "sh cxx/data/get-data-files.sh '${EVIDENCE_NAME}' downloads it.")
    endif()
endif()

add_custom_target(perf ALL
    COMMAND cp ${CMAKE_CURRENT_LIST_DIR}/runPerf.sh .
	COMMAND cp ${CMAKE_CURRENT_LIST_DIR}/nginx.conf.template .
	COMMAND cp ${CMAKE_CURRENT_LIST_DIR}/nginx.conf.ipi.template .
    DEPENDS ${CMAKE_CURRENT_LIST_DIR}/runPerf.sh ${CMAKE_CURRENT_LIST_DIR}/nginx.conf.template ${CMAKE_CURRENT_LIST_DIR}/nginx.conf.ipi.template

    VERBATIM
)

add_dependencies(perf ApacheBench-build)
