#!/usr/bin/env bash
# Source this file in ~/bash_profile

# TODO: create a compiled version. Interact with the sqlite lib

# Stuff to save:
#   command ran
#   tally times this command has been ran
#       verify this is a legit command with 'command -v <lastCommand>'
#           have a contingency in place in case this wasn't a command before but is now a command
#   what number in history it was ran
#       use this to keep track of how many times command n-1 has been ran before running this one
#           and times command n+1 was ran (this happens implicitly because the next command will save this command)
#               also keep track of how many times this command was ran in a row. (or chains of alternating between 2 or 3 commands?)
#   what directory this command was called from
#   what inputs/arguments this command was called with
#   if any input is a path, tally the times this path was ever used
#       and tally the times this path was used with this command
#   
#   Have separate table for Mac and Linux?
#
#
# TODO: come up with a namespace
# TODO: Make this repo a git subtree for my dotfiles
# TODO: stop the possibility of injection - need to escape special chars
# TODO: var deceleration is not recognized as a valid command. Should this be fixed?
#   Doing so could provide interesting info on what var names I use the most

export SHELLANALYTICSDATABASE='/Users/adamgaia/repo/shellAnalytics/shellAnalytics.db'


function shellAnalytics_initDataBase()
{
    # Table for per-command tally
    sqlite3 "${SHELLANALYTICSDATABASE}" 'CREATE TABLE commandFrequency(Command TEXT, Tally INTEGER, legitCommand INTEGER)'
    
    # Table for global stats
    sqlite3 "${SHELLANALYTICSDATABASE}" 'CREATE TABLE metaStats(VarName TEXT, Value BIGINT)'
    sqlite3 "${SHELLANALYTICSDATABASE}" "INSERT INTO metaStats VALUES('globalTally', 0)"

    echo 'Shell analytics database created'
}

function shellAnalytics_tallyCommandArgs()
{
    fullCommand=($@)
    cmd="${fullCommand[0]}"
    args="$*" # Save the entire command instead of just the args

    tableName="${cmd}_argTally"

    # Check if we have used this combo of args before
    check="$(sqlite3 "${SHELLANALYTICSDATABASE}" "SELECT EXISTS(SELECT 1 FROM ${tableName} WHERE Arguments='${args}')")"
    if [[ "${check}" -eq '0' ]]; then
        sqlite3 "${SHELLANALYTICSDATABASE}" "INSERT INTO ${tableName} VALUES('${args}', 1)"
    else
        sqlite3 "${SHELLANALYTICSDATABASE}" "UPDATE ${tableName} SET Tally = Tally + 1 WHERE Arguments='${args}'"
    fi
}

function shellAnalytics_tallyCommand()
{
    cmd="${*}"

    # Check if real command
    if command -v "${cmd}" > /dev/null 2>&1; then
        cmdIsReal='1'
    else
        cmdIsReal='0'
    fi

    # Check if we have ran this command before
    check="$(sqlite3 "${SHELLANALYTICSDATABASE}" "SELECT EXISTS(SELECT 1 FROM commandFrequency WHERE Command='${cmd}')")"
    if [[ ${check} -eq '0' ]]; then

        sqlite3 "${SHELLANALYTICSDATABASE}" "INSERT INTO commandFrequency VALUES('${cmd}', 1, '${cmdIsReal}')"

        # Create a table to tally args used with this command
        tableName="${cmd}_argTally"
        sqlite3 "${SHELLANALYTICSDATABASE}" "CREATE TABLE ${tableName}(Arguments TEXT, Tally INTEGER)"

    else
        sqlite3 "${SHELLANALYTICSDATABASE}" "UPDATE commandFrequency SET Tally = Tally + 1 WHERE Command='${cmd}'"
    fi
}

function shellAnalytics_verifyCommandIsInDatabase()
{
    cmd="$1"
    check="$(sqlite3 "${SHELLANALYTICSDATABASE}" "SELECT EXISTS(SELECT 1 FROM commandFrequency WHERE Command='${cmd}')")"

    if [[ "$check" -eq '0' ]]; then
        return 1
    else
        return 0
    fi
}

function shellAnalytics_driver()
{
    # Only proceed if there is an input
    if [[ -z "$*" ]]; then
        return 0
    fi

    # Check for database
    if [[ ! -e "${SHELLANALYTICSDATABASE}" ]]; then
        shellAnalytics_initDataBase
    fi

    # Separate command from arguments
    cmdWithArgs=($@)
    cmd=${cmdWithArgs[0]}
    args=${cmdWithArgs[@]:1}

    # TODO: find a better way to handle commands like
    #    ind, watch, xargs
    #    where the 'real command' is in the arguments

    # Save command to the database
    shellAnalytics_tallyCommand "${cmd}"

    # Tally these specific args used with this command
    shellAnalytics_tallyCommandArgs ${@}

    # Preformed extra options depending on which command was ran
    case "${cmd}" in
        "cd")
            # write to database cd table
            # TODO
            ;;
        "back")
            # write to database cd tables
            # TODO
            ;;
    esac

    # Update tally of times any command has been ran
    sqlite3 "${SHELLANALYTICSDATABASE}" "UPDATE metaStats SET Value = Value + 1 WHERE VarName='globalTally'"
}

function shellAnalytics_printSingleCommandDetailedInfo()
{
    printBold "${cmd} "
    sqlite3 "${SHELLANALYTICSDATABASE}" "SELECT Tally FROM commandFrequency WHERE Command='${cmd}'"
    tableName="${cmd}_argTally"
    sqlite3 "${SHELLANALYTICSDATABASE}" "SELECT * FROM ${tableName}"
    echo ''
}

function shellAnalytics_removeCommand()
{
    # Remove input commands from the database
    if [[ $# -eq '0' ]]; then
        echo "Usage:"
        echo "shellAnalytics_removeCommand <commands to remove>"
        return 1
    fi

    for cmdToRm in $@; do

        if ! shellAnalytics_verifyCommandIsInDatabase; then
            echo "Error, '${cmdToRm}' is not in the datbase"
            # Skip this cmd
            continue
        fi

        # Ask user for conformation to delete
        echo "Remove '${cmdToRm}' from record? [y|n]"
        read conformation
        if [[ "${conformation}" != 'y' ]]; then
            # Skip this cmd
            continue
        fi

        # Subtract this command's tally from the global tally
        cmdTally="$(sqlite3 "${SHELLANALYTICSDATABASE}" "SELECT Tally FROM commandFrequency WHERE Command='${cmdToRm}'")"
        sqlite3 "${SHELLANALYTICSDATABASE}" "UPDATE metaStats SET Value = Value - ${cmdTally} WHERE VarName='globalTally'"

        # Remove entry from main table
        sqlite3 "${SHELLANALYTICSDATABASE}" "DELETE FROM commandFrequency WHERE Command='${cmdToRm}'"

        # Remove secondary table with all args
        tableName="${cmdToRm}_argTally"
        sqlite3 "${SHELLANALYTICSDATABASE}" "DROP TABLE ${tableName}"
    done
}

function printShellAnalytics()
{
    if [[ "$1" == '--help' ]]; then
        echo "TODO: add a help message"

    elif [[ $# -eq 0 ]]; then
        printBold '\nCommands:\n'
        # TODO: clean up the formatting
        sqlite3 "${SHELLANALYTICSDATABASE}" 'SELECT * FROM commandFrequency WHERE legitCommand=1' |sort |column -t -s'|'  | awk '{$NF=""}1' |column -t # This requires the default sqlite separator '|'
        echo ''
        printBold 'Typos:\n'
        sqlite3 "${SHELLANALYTICSDATABASE}" 'SELECT * FROM commandFrequency WHERE legitCommand=0' |sort |column -t -s'|'  | awk '{$NF=""}1' |column -t
        echo ''
        printBold 'Stats:\n'
        sqlite3 "${SHELLANALYTICSDATABASE}" "SELECT * FROM metaStats" |sort |column -t -s'|'
        echo ''

    elif [[ "$1" == '--all' ]]; then
        allCommands=("$(sqlite3 "${SHELLANALYTICSDATABASE}" 'SELECT Command FROM commandFrequency')")
        for cmd in ${allCommands}; do
            shellAnalytics_printSingleCommandDetailedInfo $cmd
        done

    elif [[ "$1" == '--real' ]]; then
        allCommands=("$(sqlite3 "${SHELLANALYTICSDATABASE}" 'SELECT Command FROM commandFrequency WHERE legitCommand=1')")
        for cmd in ${allCommands}; do
            shellAnalytics_printSingleCommandDetailedInfo $cmd
        done

    elif [[ "$1" == '--typos' ]]; then
        allCommands=("$(sqlite3 "${SHELLANALYTICSDATABASE}" 'SELECT Command FROM commandFrequency WHERE legitCommand=0')")
        for cmd in ${allCommands}; do
            shellAnalytics_printSingleCommandDetailedInfo $cmd
        done

    else
        for cmd in $@; do
            if ! shellAnalytics_verifyCommandIsInDatabase; then
            echo "Error, user entry '${cmd}' is not in the datbase"
            # Skip this cmd
            continue
        fi
            shellAnalytics_printSingleCommandDetailedInfo $cmd
        done
    fi   
}

# TODO: multiline commands like switch case and if statements are lost. Fix this
#   • maybe by checking for multiline command and using `fc -ln` to grab the rest?
#   • it seems that shell keywords cause problems

# Using a debug trap is the magic that allows us to save $BASH_COMMAND before it is updated
trap 'shellAnalytics_driver ${BASH_COMMAND}' DEBUG

