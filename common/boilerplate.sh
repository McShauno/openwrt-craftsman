
############################### Global variables ###############################

NUM_ARGS=$#
BASENAME=$0
WRONG_NUMBER_OF_ARGUMENTS_ERROR=1

################################## Functions ###################################



###################### Assert number of command line args ######################
# Usage: assert_number_of_arguments EXPECTED_NUMBER
#  e.g.  assert_numner_of_arguments 3
#        assert_numner_of_arguments 0

assert_num_args() {
  # Credit: http://www.linuxweblog.com/bash-argument-numbers-check
  EXPECTED_NUM_ARGS=$1
  if [ $NUM_ARGS -ne $EXPECTED_NUM_ARGS ]
  then
    if [ "$NUM_ARGS" -eq "1" ];
    then
      MSG="Expected 1 argument (got $NUM_ARGS)"
    else
      MSG="Expected $EXPECTED_NUM_ARGS arguments (got $NUM_ARGS)"
    fi
    printf "Usage: `basename $BASENAME`\n$MSG\n"
    exit $WRONG_NUMBER_OF_ARGUMENTS_ERROR
  fi
}

########################## Run command, exit on error ##########################
# Usage: exit_on_error "COMMAND"
# e.g. : exit_on_error "ls"
#        exit_on_error 'echo "1+2" | bc'

exit_on_error() {
  COMMAND=$1
  eval "$COMMAND"
  RETCODE=$?
  if [ $RETCODE -eq 0 ];
  then
    return
  else
    exit $RETCODE
  fi
}

######################### Convert string to lower case #########################
# Usage: to_lower "String in quotes" RESULT_VARIABLE_NAME
# e.g. : to_lower "Cheese shop" l1
#        echo $l1  # "cheese shop"

function to_lower()
{
  local  __resultvar=$2
  eval $__resultvar=$(echo "'$1'" | tr '[A-Z]' '[a-z]' )
}

######################### Convert string to UPPER case #########################
# Usage: to_upper "String in quotes" RESULT_VARIABLE_NAME
# e.g. : to_upper "Cheese shop" l1
#        echo $l1  # "CHEESE SHOP"

function to_upper()
{
  local  __resultvar=$2
  eval $__resultvar=$(echo "'$1'" | tr '[a-z]' '[A-Z]' )
}


################################## debug echo ##################################
# Conditionally echos a message:
# If $DEBUG_SHELL is "true", "yes", "on" or "1", displayes the message.
# If $DEBUG_LOG_FILE is defined, appends echo to the file (regardless of 
# $DEBUG_SHELL)
#
# Usage: decho <echo-args>
# e.g. : decho -n "*"
#        decho "`date`"

function decho()
{
  local __decho_msg="$@"
  to_lower "$DEBUG_SHELL" __debug_status
  if [[ "$__debug_status" == "true" ]] || [[ "$__debug_status" == "yes" ]] || [[ "$__debug_status" == "on" ]] || [[ "$__debug_status" == "1" ]];
  then
    eval "echo $__decho_msg"
  fi
  if [ ! -z "$DEBUG_LOG_FILE" ];
  then
    eval "echo $__decho_msg" >> $DEBUG_LOG_FILE
  fi
}

function check_directory()
{
    local _checkValue=$1
    debug "Checking if directory [$_checkValue] exists."
    if [ ! -d "$_checkValue" ]; then
        fail "Required directory [$_checkValue] does not exist."
    fi
}

function check_executable()
{
    local __executable=$1
    debug "Checking if executable [$__executable] exists."
    if command -v $__executable > /dev/null; then
        return;
    else
        fail "$__executable not found."
    fi
}

function debug() {
    decho $1
}

function logline  {
    echo ""
    echo $1
}

function log() {
    echo -en $1
}

function fail() {
    failMessage=$1
    logline "failing: $failMessage"
    exit 1
}  
