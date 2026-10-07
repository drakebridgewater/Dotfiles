# zsh tab-completion for the functions below lives in shell/zsh/completions/_siemens_utils
source "${DOTFILES_DIR:-$HOME/Dotfiles}/shell/common/logging"

function warnings_for_file() {
  # example usage: warnings_for_file warnings.json 'perc_type.h'
  # This function searches a getWarnings JSON file for warnings associated with a specific filename.
  local json_file="$1"
  local search_file="$2"
  
  if [ -z "$json_file" ] || [ -z "$search_file" ]; then
    echo "Usage: find_file_in_warnings_json <json_file> <search_filename>"
    echo "Example: find_file_in_warnings_json warnings.json 'perc_type.h'"
    return 1
  fi
  
  jq -c --arg filename "$search_file" '
    .getWarnings[]? |
    # Ensure we have valid structure
    select(.events? != null and (.events | type) == "array") |
    # Check if this build has ANY relevant warnings
    select(
      [.events[]? | select(type == "object")] | 
      any(
        .warning_type? != null and 
        .occurrences? != null and
        (.occurrences | type) == "array" and
        (.occurrences | length > 0) and
        (.occurrences | any(
          select(type == "object" and .associated_file_name? != null) | 
          .associated_file_name == $filename
        ))
      )
    ) |
    # Output the build command and matching events
    {
      build_cmd: .command.build_cmd,
      matching_events: [
        .events[]? | 
        select(type == "object") |
        select(.warning_type? != null and .occurrences? != null) |
        select(
          (.occurrences | type) == "array" and
          (.occurrences | any(
            select(type == "object" and .associated_file_name? != null) | 
            .associated_file_name == $filename
          ))
        )
      ]
    } |
    # Only output if we actually found matching events
    select(.matching_events | length > 0)
  ' "$json_file"
}

function finderror_json() {
  local file="$1"
  local before_lines="${2:-20}"
  local max_distance="${3:-5000}"
  local concat_long_lines=0
  local concat_long_lines_length=300
  local concat_long_lines_total=500
  local vco=$(getVCOFromLogFilePath "$file")
  
  if [ -z "$file" ]; then
    echo "Usage: finderror <filename> [lines_before_error] [max_distance]"
    echo "Example: finderror logfile.log 20 1500"
    return 1
  fi

  awk -v max_dist="$max_distance" \
    -v before="$before_lines" \
    -v concat_long_lines="$concat_long_lines" \
    -v concat_long_lines_length="$concat_long_lines_length" \
    -v concat_long_lines_total="$concat_long_lines_total" '
    BEGIN {
        print "["
        error_count = 0
    }
    {
        # Store each line in the circular buffer
        if (concat_long_lines && length($0) > concat_long_lines_total) {
            buffer[NR] = substr($0, 1, concat_long_lines_length) "<<<TRUNCATED>>>" substr($0, length($0) - concat_long_lines_length)
        } else {
            buffer[NR] = $0
        }
    }
    /Entering directory/ {
        # Extract just the directory path from "Entering directory" line
        # Example input: "gmake4.2.1.exe[3]: Entering directory '/wv/path/to/dir'"
        match($0, /Entering directory '"'"'([^'"'"']+)'"'"'/, matches)
        if (matches[1] != "") {
            entering_directory = matches[1]
            entering_dir_log_line = NR
        }
    }
    /-o .*\.o/ {
        # extract only the .o part
        match($0, /-o ([^ ]*\.o)/, cmd_matches)
        if (cmd_matches[1] != "") {
            last_build_cmd = $0
            last_built_file = cmd_matches[1]
            last_build_cmd_log_line = NR
        }
    }
    /: error: / {
        error_count++
        if (error_count > 1) {
            print "    },"
        }
        
        # Start error object
        print "    {"
        print "      \"id\": " error_count ","
        print "      \"line\": " NR ","
        print "      \"entering_dir_log_line\": " entering_dir_log_line ","
        print "      \"last_build_cmd_log_line\": " last_build_cmd_log_line ","
        print "      \"last_build_cmd\": \""  last_build_cmd "\","
        print "      \"entering_directory\": \"" entering_directory "\","
        print "      \"last_built_file\": \"" last_built_file "\","
        if (before > 0) {
          print "      \"context\": ["
          # Print context lines as JSON array
          context_count = 0
          for (i = (NR - before); i < NR; i++) {
              if (i in buffer) {
                  if (context_count > 0) {
                      print ","
                  }
                  context_count++
                  # escape backslashes
                  gsub(/\\/, "\\\\", buffer[i])
                  # Escape quotes
                  gsub(/"/, "\\\"", buffer[i])
                  printf "          \"" buffer[i] "\""
              }
          }
          print "\n      ],"
        }
        error_line = buffer[NR]
        gsub(/\\/, "\\\\", error_line)
        gsub(/"/, "\\\"", error_line)
        print "      \"error\": \"" error_line "\""
        # Clear old buffer entries
        for (i in buffer) {
            delete buffer[i]
        }
    }
    /\] Error / || /: ERROR / {
        error_count++
        if (error_count > 1) {
            print "    },"
        }
        
        # Start error object
        print "    {"
        print "      \"id\": " error_count ","
        print "      \"line\": " NR ","
        print "      \"entering_dir_log_line\": " entering_dir_log_line ","
        print "      \"last_build_cmd_log_line\": " last_build_cmd_log_line ","
        print "      \"entering_directory\": \"" entering_directory "\","
        print "      \"last_built_file\": \"" last_build_cmd "\","
        
        if (before > 0) {
          print "      \"context\": ["
          # Print context lines as JSON array
          context_count = 0
          for (i = (NR - before); i < NR; i++) {
              if (i in buffer) {
                  if (context_count > 0) {
                      print ","
                  }
                  context_count++
                  # escape backslashes
                  gsub(/\\/, "\\\\", buffer[i])
                  # Escape quotes
                  gsub(/"/, "\\\"", buffer[i])
                  printf "          \"" buffer[i] "\""
              }
          }
          print "\n      ],"
        }
        error_line = buffer[NR]
        gsub(/\\/, "\\\\", error_line)
        gsub(/"/, "\\\"", error_line)
        print "      \"error\": \"" error_line "\""
        # Clear old buffer entries
        for (i in buffer) {
            delete buffer[i]
        }
    }
    END {
        print "    }"  # Close last error object
        print "]"  # Close main object
    }
    ' "$file"
}

function finderror() {
  local file="$1"
  local before_lines="${2:-20}"
  local max_distance="${3:-5000}"
  local concat_long_lines=1
  local concat_long_lines_length=180
  local concat_long_lines_total=360

  if [ -z "$file" ]; then
    echo "Usage: finderror <filename> [lines_before_error] [max_distance]"
    echo "Example: finderror logfile.log 20 1500"
    return 1
  fi

  # echo "=== Search Parameters ==="
  # echo "File: $file"
  # echo "Looking for: '] Error' pattern"
  # echo "Context lines: $before_lines"
  # echo "Max distance from directory: $max_distance"
  # echo ""

  awk -v max_dist="$max_distance" \
    -v before="$before_lines" \
    -v concat_long_lines="$concat_long_lines" \
    -v concat_long_lines_length="$concat_long_lines_length" \
    -v concat_long_lines_total="$concat_long_lines_total" '
    {
        # Store each line in the circular buffer
        if (concat_long_lines && length($0) > concat_long_lines_total) {
            buffer[NR] = substr($0, 1, concat_long_lines_length) "<<<TRUNCATED>>>" substr($0, length($0) - concat_long_lines_length)
        } else {
            buffer[NR] = $0
        }
    }
    /Entering directory/ {
        entry_raw=$0
        match($0, /Entering directory '"'"'([^'"'"']+)'"'"'/, matches)
        entry=matches[1]
        entry_line=NR
    }
    # Get the last build command before the error within max_dist
    /-o.*\.o/ {
        # extract only the .o part
        match($0, /-o ([^ ]*\.o)/, cmd_matches)
        if (cmd_matches[1] != "") {
          last_build_cmd = cmd_matches[1]
          build_cmd_line = NR
        }
    }
    /: error: / {
        error_count++
          printf "===================== START Error ======================= #%d @ line %d\n", error_count, NR
          if (entry != "") {
            printf "Entering directory (%d): %s\n", entry_line, entry
          }
          if (last_build_cmd != "") {
              printf "Build Command (%d): %s\n", build_cmd_line, last_build_cmd
          }
          printf "---------------------------------------------------------\n", before
          # Print actual previous lines from buffer
          for (i = (NR - before); i <= NR; i++) {
              if (i in buffer) {
                  printf "(%d): %s\n", i, buffer[i]
              }
          }
          printf "===================== END Error ========================= #%d @ line %d\n", error_count, NR
          printf "=========================================================\n\n"
        # Clear old buffer entries
        for (i in buffer) {
          delete buffer[i]
        }
    }
     /\] Error / {
         error_count++
          printf "===================== START Error ======================= #%d @ line %d\n", error_count, NR
         for (i = (NR - before); i <= NR; i++) {
             if (i in buffer) {
                 printf "(%d): %s\n", i, buffer[i]
             }
         }
         printf "(%d): %s\n", NR, $0
         printf "==========================================================\n\n"
     }
    END {
        if (error_count == 0) {
            print "No errors found matching the pattern."
        } else {
            printf "\nTotal Errors Found: %d\n", error_count
        }
    }
    ' "$file"
}

function getVCOFromLogFilePath() {
  # given /wv/src_renewal/gitlab-ci/2025-09-18T06-13-56/aok-clang-nocuda-warn/4284231/cwarn_01.BUILD.aok-clang-nocuda-warn it returns aok-clang-nocuda-warn
  # given /wv/src_renewal/gitlab-ci/2025-12-18T09-13-56/aaw-clang-warn/4284231/cwarn_01.BUILD.aaw-clang-warn it returns aaw-clang-warn
  # given /wv/drabri2r_nobackup/calibre_builds/calibre_2025_WA01/calibre_2025_WA01.BUILD_aok-lvsonly it returns aok-lvsonly
  # given ./calibre_2025_WA01.BUILD_aok-lvsonly it returns aok-lvsonly
  local logpath="$1"
  if [ -z "$logpath" ]; then
    echo "Usage: getVCOFromLogFilePath <logpath>"
    return 1
  fi
  
  # Get the base filename first
  local filename
  filename=$(basename "$logpath")
  
  # Extract the VCO from the filename using sed
  # Pattern 1: filename.BUILD.vco or filename.BUILD_vco
  local vco
  vco=$(echo "$filename" | sed -n 's/.*\.BUILD[._]\([a-z][a-z0-9-]*\)$/\1/p')
  
  if [ -n "$vco" ]; then
    echo "$vco"
    return 0
  fi
  
  # Pattern 2: from directory path like /aok-clang-nocuda-warn/4284231/
  vco=$(echo "$logpath" | sed -n 's|.*/\([a-z][a-z0-9-]*\)/[0-9]\+/.*|\1|p')
  
  if [ -n "$vco" ]; then
    echo "$vco"
    return 0
  fi
  
  # If no pattern matches, return empty
  echo ""
  return 1
}

function getBuildFlagsFromVCO() {
  # given aok-clang-nocuda-warn it returns -Taok -Tclang -Tnocuda -Twarn
  # given aaw-clang-warn it returns -Taaw -Tclang -Twarn
  local vco="$1"
  if [ -z "$vco" ]; then
    echo "Usage: getBuildFlagsFromVCO <vco>"
    return 1
  fi
  local flags=""
  flags=$(echo "$vco" | sed "s/-/ -T/g" | cut -d ' ' -f 2-)
  echo "$flags"
}

function getFirstErrors() {
  local logpath="$1"
  if [ -z "$logpath" ]; then
    echo "Usage: getFirstErrors <logpath>"
    return 1
  fi

  local result
  result=$(awk -F': error: ' '/: error: / {print NR ":" $0; exit}' "$logpath")
  if [ -z "$result" ]; then
    result=$(awk -F'/\] Error ' '/\] Error / {print NR ":" $0; exit}' "$logpath")
  fi
  echo "$result"
}

function getOffendingFileFromErrorLine() {
  # given: ../../../lv/src/lvbase/perc_type.h:50:30: error: constexpr variable 'PatternMultiFileSubcktNamePrefix_length' must be initialized by a constant expression
  # return perc_type.h
  local error_line="$1"
  if [ -z "$error_line" ]; then
    echo "Usage: getOffendingFileFromErrorLine <error_line>"
    return 1
  fi

  # extract the file path before the first colon
  local filepath
  filepath=$(echo "$error_line" | awk -F':' '{print $1}')
  # return empty string if "Isrc" is not in the result
  if [[ "$filepath" != *Isrc* ]]; then
    filepath=""
  fi
  # get the base name of the file
  local filename
  filename=$(basename "$filepath")
  echo "$filename"
}

function getBuildTarget() {
  local log_line="$1"
  local full_target_path
  full_target_path=$(echo "$log_line" | head -n1 | sed -E "s/.*-o ([^ ]*\.o).*/\1/")
  echo "$full_target_path"
}

function getPreviousBuildFile() {
  # Given the argument logpath and offending file name it returns ( cd ic/lv/aok; cglu; gmake -Tclang -Tnocuda -Twarn -C lithas/calibrewb/ ../main_src/cwb/mdf_plot.o )
  local logpath="$1"
  local line_number="$2"
  if [ -z "$logpath" ] || [ -z "$line_number" ]; then
    echo "Usage: getPreviousBuildCmd <logpath> <line_number>"
    return 1
  fi
  local result
  result=$(head -n "$line_number" "$logpath" | grep -i -E -- "-o .*\.o" | tail -n 1)
  result=$(echo "$result" | sed -E "s/.*-o ([^ ]*\.o).*/\1/")
  echo "$result"
}

function getLogLineNumber() {
  local log_line="$1"
  local line_number
  line_number=$(echo "$log_line" | head -n1 | cut -d: -f1)
  echo "$line_number"
}

function getOGBuildCmd() {
  local offending_file="$1"
  local logpath="$2"
  if [ -z "$offending_file" ] || [ -z "$logpath" ]; then
    echo "Usage: getOGBuildCmd <offending_file> <logpath>"
    return 1
  fi
  local grep_pattern
  grep_pattern="-o .*${offending_file}.*.o"
  result=$(grep -n -- "$grep_pattern" "$logpath")
  echo "$result"
}

function getEnteringDirectory() {
  local logpath="$1"
  local log_line_number=$2
  if [ -z "$logpath" ]; then
    echo "Usage: getEnteringDirectory <logpath>"
    return 1
  fi
  local result
  result=$(head -n "$log_line_number" "$logpath" | grep -i "entering directory" | tail -n 1)
  echo "$result"
}

function getBuildDirectory() {
  # given "gmake4.2.1.exe[4]: Entering directory '/wv/toaster_build/calibre_builds/cwarn_01/ic/lv/$VCO/lithas/opclibs'"
  # return lithas/opclibs
  # given "gmake4.2.1.exe[4]: Entering directory '/wv/toaster_build/calibre_builds/cwarn_01/ic/lv/$VCO/lithas/abc/opclibs'"
  # return lithas/abc/opclibs
  local entering_directory_line="$1"
  local vco="$2"
  if [ -z "$vco" ] || [ -z "$entering_directory_line" ]; then
    echo "Usage: getBuildDirectory <entering_directory_line> <vco>"
    return 1
  fi
  local dir_path
  dir_path=$(echo "$entering_directory_line" | sed -E "s/.*Entering directory '.*\/lv\/${vco}\/(.*)'/\1/")
  echo "$dir_path"
}

function getSrcDir() {
  # given "gmake4.2.1.exe[4]: Entering directory '/wv/toaster_build/calibre_builds/cwarn_01/ic/lv/$VCO/lithas/opclibs'"
  # return $IWA/ic/lv/$VCO
  # given "gmake4.2.1.exe[4]: Entering directory '/wv/toaster_build/calibre_builds/cwarn_01/ic/lv/$VCO/lithas/abc/opclibs'"
  # return $IWA/ic/lv/$VCO
  local entering_directory_line=$1
  local vco=$2
  dir_path=$(echo "$entering_directory_line" | sed -E "s/.*Entering directory '\/.*\/(ic\/.*)\/${vco}\/.*/\1/")
  # short vco is the string before the frist -
  local short_vco=$(echo "$vco" | sed -E "s/-.*//")
  echo "\$IWA/$dir_path/$short_vco"
}

function log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  # return if level is DEBUG and DEBUG is not set or is 0
  if [ "$level" = "DEBUG" ] && [ -z "$DEBUG" ]; then
    return
  fi
  echo "[$timestamp] [$level] $message"
}

function getBuildCmd() {
  # Given the argument logpath and offending file name it returns ( cd ic/lv/aok; cglu; gmake -Tclang -Tnocuda -Twarn -C lithas/calibrewb/ ../main_src/cwb/mdf_plot.o )
  local offending_file="$1"
  local logpath=$(realpath "$2")

  local vco=$(getVCOFromLogFilePath "$logpath")
  log "DEBUG" "VCO=$vco"
  if [ -z "$vco" ]; then
    log "ERROR" "Could not determine VCO from log file path '$logpath'."
    return 1
  fi

  local vco_flags
  vco_flags=$(getBuildFlagsFromVCO "$vco")
  log "DEBUG" "VCO Flags=$vco_flags"
  if [ -z "$vco_flags" ]; then
    log "ERROR" "Could not determine build flags from VCO '$vco'."
    return 1
  fi

  local log_line
  log_line=$(getOGBuildCmd "$offending_file" "$logpath")
  log "DEBUG" "Log Line=$log_line"
  if [ -z "$log_line" ]; then
    log "ERROR" "Could not find build command for offending file '$offending_file' in log '$logpath'."
    return 1
  fi

  local build_target
  build_target=$(getBuildTarget "$log_line")
  log "DEBUG" "Build Target=$build_target"
  if [ -z "$build_target" ]; then
    log "ERROR" "Could not determine build target from log line."
    return 1
  fi

  local target_build_line_number
  target_build_line_number=$(getLogLineNumber "$log_line")
  log "DEBUG" "Build Line Number=$target_build_line_number"

  local entering_directory
  entering_directory=$(getEnteringDirectory "$logpath" "$target_build_line_number")
  log "DEBUG" "Entering Directory Line=$entering_directory"

  local build_directory
  build_directory=$(getBuildDirectory "$entering_directory" "$vco")
  log "DEBUG" "Build Directory=$build_directory"

  local src_dir
  src_dir=$(getSrcDir "$entering_directory" "$vco")
  log "DEBUG" "Source Directory=$src_dir"

  # Construct the build command
  local build_cmd="( cd "$src_dir"; cglu; gmake $vco_flags -C $build_directory $build_target )"
  echo "$build_cmd"
}

function getFailingBuildCmd() {
  # Given the argument logpath and offending file name it returns ( cd ic/lv/aok; cglu; gmake -Tclang -Tnocuda -Twarn -C lithas/calibrewb/ ../main_src/cwb/mdf_plot.o )
  local logpath="$1"
  local DEBUG=${DEBUG:-0}

  if [ -z "$logpath" ]; then
    echo "Usage: getBuildCmd <logpath>"
    return 1
  fi
  log "DEBUG" "logpath=$logpath"

  first_errors=$(getFirstErrors "$logpath")
  log "DEBUG" "First Errors=$first_errors"
  if [ -z "$first_errors" ]; then
    log "ERROR" "No errors found in log file '$logpath'."
    return 1
  fi
  local error_line_number
  error_line_number=$(echo "$first_errors" | cut -d: -f1)
  log "INFO" "Error Line Number=$error_line_number"

  offending_file=$(getOffendingFileFromErrorLine "$first_errors")
  if [ -z "$offending_file" ]; then
    log "ERROR" "Could not determine offending file from error line."
    log "INFO" "Trying something else"
    offending_file=$(getPreviousBuildFile "$logpath" "$error_line_number")
    if [ -z "$offending_file" ]; then
      log "ERROR" "Could not determine offending file from error line."
      return 1
    fi
  fi
  case "$offending_file" in
  *.h | *.c | *.cpp | *.C)
    offending_file="${offending_file%.*}"
    ;;
  esac
  log "DEBUG" "Offending File=$offending_file"
  local build_cmd
  build_cmd=$(getBuildCmd "$offending_file" "$logpath")
  echo "$build_cmd"
}
