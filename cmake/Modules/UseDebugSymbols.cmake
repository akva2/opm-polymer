# - Generate debug symbols in a separate file
#
# (1) Include this file in your CMakeLists.txt; it will setup everything
#     to compile WITH debug symbols in any case.
#
# (2) Run the strip_debug_symbols function on every target that you want
#     to strip.

# Copyright (C) 2012 Uni Research AS
# This code is licensed under The GNU General Public License v3.0

include (AddOptions)

# only debugging using the GNU toolchain is supported for now
if (CMAKE_COMPILER_IS_GNUCXX)
  # add debug symbols to *all* targets, regardless. there WILL come a
  # time when you need to find a bug which only manifests itself in a
  # release target on a production system!
  message (STATUS "Generating debug symbols: -ggdb3")
  add_options (ALL_LANGUAGES ALL_BUILDS "-ggdb3")

  # extracting the debug info is done by a separate utility in the GNU
  # toolchain. check that this is actually installed.
  message (STATUS "Looking for strip utility")
  find_program (OBJCOPY
	objcopy
	${CYGWIN_INSTALL_PATH}/bin /usr/bin /usr/local/bin
	)
  mark_as_advanced (OBJCOPY)
  if (OBJCOPY)
	message (STATUS "Looking for strip utility - found")
  else (OBJCOPY)
	message (WARNING "Looking for strip utility - not found")
  endif (OBJCOPY)
endif (CMAKE_COMPILER_IS_GNUCXX)

# command to separate the debug information from the executable into
# its own file; this must be called for each target; optionally takes
# the name of a variable to receive the list of .debug files
function (strip_debug_symbols targets)
  if (CMAKE_COMPILER_IS_GNUCXX AND OBJCOPY)
	foreach (target IN LISTS targets)
	  # libraries must retain the symbols in order to link to them, but
	  # everything can be stripped in an executable
	  get_target_property (_kind ${target} TYPE)
	  
	  # don't strip static libraries
	  if ("${_kind}" STREQUAL "STATIC_LIBRARY")
		return ()
	  endif ("${_kind}" STREQUAL "STATIC_LIBRARY")	  

	  # don't strip public symbols in shared objects
	  if ("${_kind}" STREQUAL "EXECUTABLE")
		set (_strip_args "--strip-all")
	  else ("${_kind}" STREQUAL "EXECUTABLE")
		set (_strip_args "--strip-debug")
	  endif ("${_kind}" STREQUAL "EXECUTABLE")
	  
	  # add_custom_command doesn't support generator expressions in the
	  # working_directory argument (sic; that's what you get when you do
	  # ad hoc programming all the time), so we need to extract the
	  # location up front (the location on the other hand should not be
	  # used for libraries as it does not include the soversion -- sic
	  # again)
	  get_target_property (_full ${target} LOCATION)
	  get_filename_component (_dir ${_full} PATH)
	  get_filename_component (_name ${_full} NAME)
	  # only libraries have soversion property attached
	  get_target_property (_target_soversion ${target} SOVERSION)
	  get_target_property (_target_version ${target} VERSION)
	  if (_target_soversion)
		set (_target_file "${_full}.${_target_version}")
		set (_target_file_name "${_name}.${_target_version}")
	  else (_target_soversion)
		set (_target_file "${_full}")
		set (_target_file_name "${_name}")
	  endif (_target_soversion)
	  # do without generator expressions (which doesn't work everywhere)
	  add_custom_command (TARGET ${target}
		POST_BUILD
		WORKING_DIRECTORY ${_dir}
		COMMAND ${OBJCOPY} ARGS --only-keep-debug ${_target_file} ${_target_file}.debug
		COMMAND ${OBJCOPY} ARGS ${_strip_args} ${_target_file}
		COMMAND ${OBJCOPY} ARGS --add-gnu-debuglink=${_target_file_name}.debug ${_target_file}
		VERBATIM
		)
	  # add this .debug file to the list
	  file (RELATIVE_PATH _this_debug_file "${PROJECT_BINARY_DIR}" "${_target_file}.debug")
	  set (_debug_files ${_debug_files} ${_this_debug_file})
	endforeach (target)
	# if optional debug list was requested, then copy to output parameter
	if (ARGV1)
	  set (${ARGV1} ${_debug_files} PARENT_SCOPE)
	endif (ARGV1)
  endif (CMAKE_COMPILER_IS_GNUCXX AND OBJCOPY)
endfunction (strip_debug_symbols targets)

