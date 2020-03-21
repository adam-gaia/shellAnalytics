#!/usr/bin/env bash


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
    else
        sqlite3 "${SHELLANALYTICSDATABASE}" "UPDATE commandFrequency SET Tally = Tally + 1 WHERE Command='${cmd}'"
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
    lastCmd=($@)
    cmd=${lastCmd[0]}
    args=${lastCmd[@]:1}

    # TODO: find a better way to handle commands like
    #    ind, watch, xargs

    # Save command to the database
    shellAnalytics_tallyCommand "${cmd}"

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

    # Update tally of times a command has been ran
    sqlite3 "${SHELLANALYTICSDATABASE}" "UPDATE metaStats SET Value = Value + 1 WHERE VarName='globalTally'"
}

function printShellAnalytics()
{
    printBold '\nCommands:\n'
    sqlite3 "${SHELLANALYTICSDATABASE}" 'SELECT * FROM commandFrequency WHERE legitCommand=1' |sort |column -t -s'|' # This requires the default sqlite separator '|'
    echo ''
    printBold 'Typos:\n'
    sqlite3 "${SHELLANALYTICSDATABASE}" 'SELECT * FROM commandFrequency WHERE legitCommand=0' |sort |column -t -s'|'
    echo ''
    printBold 'Stats:\n'
    sqlite3 "${SHELLANALYTICSDATABASE}" "SELECT * FROM metaStats" |sort |column -t -s'|'
    echo ''
}

# TODO: multiline things like switch case and if statements are lost. Fix this
#   • maybe by checking for multiline command and using `fc -ln` to grab the rest?
#   • it seems that shell keywords cause problems
trap 'shellAnalytics_driver ${BASH_COMMAND}' DEBUG











