if(NOT DEFINED RETRO_SPREADSHEET_APP OR NOT DEFINED RETRO_SPREADSHEET_UI_ARTIFACTS)
    message(FATAL_ERROR "RetroSpreadsheetUiSmoke requires an app bundle and artifact directory.")
endif()

file(REMOVE_RECURSE "${RETRO_SPREADSHEET_UI_ARTIFACTS}")
execute_process(
    COMMAND /usr/bin/open -W -n "${RETRO_SPREADSHEET_APP}" --args --ui-smoke-test
    RESULT_VARIABLE launchResult
    OUTPUT_VARIABLE launchOutput
    ERROR_VARIABLE launchError
)
if(NOT launchResult EQUAL 0)
    message(FATAL_ERROR "Could not launch the AppKit smoke test.\n${launchOutput}${launchError}")
endif()

if(EXISTS "${RETRO_SPREADSHEET_UI_ARTIFACTS}/failure.txt")
    file(READ "${RETRO_SPREADSHEET_UI_ARTIFACTS}/failure.txt" failureMessage)
    message(FATAL_ERROR "The AppKit smoke test failed.\n${failureMessage}")
endif()

if(NOT EXISTS "${RETRO_SPREADSHEET_UI_ARTIFACTS}/success.txt")
    message(FATAL_ERROR "The AppKit smoke test exited without reporting a result.")
endif()
