#!/usr/bin/env bash
set -e

# Setup
if [[ ! -e shellAnalytics.db ]]; then
    sqlite3 -list shellAnalytics.db 'CREATE TABLE cdTallyTable(Path TEXT, Tally INTEGER);'
    echo "database created"
fi

function cdTally()
{
    # Parse args
    if [[ "$#" -eq '0' ]]; then
        destination="${HOME}"
    else
        destination="$(realpath "$*")" # Absolute path
    fi

    source="$(pwd)"

    # Verify destination path is a dir
    builtin test -d "${destination}" # TODO: dotfile bash lint should check that for any functions I define that overlap basic builtins or basic utils, we must use builtin or full path and not my function unless needed

    # Check if we have cd'd to this destination path before
    check="$(sqlite3 -list shellAnalytics.db "SELECT EXISTS(SELECT 1 FROM cdTallyTable WHERE Path='${destination}')")"
    if [[ ${check} -eq '0' ]]; then
        sqlite3 -list shellAnalytics.db "INSERT INTO cdTallyTable VALUES('${destination}', 1)"
    else
        sqlite3 -list shellAnalytics.db "UPDATE cdTallyTable SET Tally = Tally + 1 WHERE Path='${destination}'"
    fi
}


# TODO: bash auto complete based on results from this database
# TODO: run all the sql stuff in the background so the user can cd immediately
# TODO: if not cd'd to before, create a table to keep track of where we've cd'd from + tally. Use this for a smart auto complete


#cdTally
cdTally /Users/adamgaia/Desktop
cdTally /Users/adamgaia/Desktop
cdTally /Users/adamgaia/repo/shellAnalytics
cdTally
cdTally
cdTally
sqlite3 -list shellAnalytics.db 'SELECT * FROM cdTallyTable'
