#!/bin/bash
#

interactive() {
  # Check for a the existence of at least 1 properties file in the current folder
  if [ -z "$(find . -name "*.corb" -type f -maxdepth 1)" ]; then
    echo "No corb properties files found in the current folder. "
    echo "Corb properties files should be named with .corb extension!"
    setupJob
    exit 1
  fi

  echo "Available jobs:"
  # List all corb properties files in the current folder and get the user to select one
  # by number. Assign theselected to the variable $job
  i=1
  jobs=""
  for f in $(find . -name "*.corb" -type f -maxdepth 1); do
    jobs="$jobs\n$i) $(basename ${f%.corb})"
    i=$((i + 1))
  done
  echo -e $jobs
  echo ""
  echo -n "Select job to run or press ENTER to create a new job: "
  read choice
  if [ -z "$choice" ]; then
    setupJob
    exit 0
  fi
  # loop over choices and selec the one match # $choice
  i=1
  for f in $(find . -name "*.corb" -type f -maxdepth 1); do
    if [ "$i" == "$choice" ]; then
      job=$(basename ${f%.corb})
    fi
    i=$((i + 1))
  done
  previewJobProperties
  now="$(date +%s)"

  local log=./corb-output-latest.log
  local rep=./corb-report-latest.txt
  main $job

  # Print the time it took to run the job
  echo "Job completed in [$(($(date +%s) - $startedAt))] seconds"
  # Ask user if they want to preview the output file
  cp $log ./corbLogs/corb-output-${job}-${now}.log
  # if the file contains the string "success - exiting with code 0" print the name only.
  # Otherwise offer to view the file.
  if grep -q "success - exiting with code 0" $log; then
    echo "Job completed successfully. Output file [$log]"
  else
    echo -ne "\nPreview the output file [$log]? [y/n] "
    read -n 1 answer
    if [[ $answer == [Yy] ]]; then
      $EDITOR $log
    fi
  fi

  cp $rep ./corbLogs/corb-report-${job}-${now}.txt
  if [ -f "$rep" ]; then
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    head -n 5 $rep | cut -c 1-120
    echo ...
    tail -n 5 $rep | cut -c 1-120
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo -ne "\nView the report file [$rep]? [y/n] "
    read -n 1 answer
    if [[ $answer == [Yy] ]]; then
      # $EDITOR $rep
      if [ -n "$(which sc-im)" ]; then
        sc-im $rep
      else
        echo "sc-im not found. Please install sc-im to view the report file."
        $EDITOR $rep
      fi
    fi
  fi
}

setupJob() {
  echo -n "Please provide a job or type a name to create one: "
  read job
  if [ -n "$job" ]; then
    echo "Creating job [$job]..."
    local jf="${job}.corb"
    touch $jf
    pickAFile "Pick collect module: "
    local collectMod=$PICK_A_FILE_CHOICE
    pickAFile "Pick process module: "
    local processMod=$PICK_A_FILE_CHOICE
    echo "URIS-MODULE=${collectMod}|ADHOC" >>$jf
    echo "PROCESS-MODULE=${processMod}|ADHOC" >>$jf
    echo "BATCH-SIZE=1" >>$jf
    echo "THREAD-COUNT=4" >>$jf
    echo "Job [$job] created."
    previewJobProperties
    # Run the job
    echo "Corb job created. Please switch to the folder [corb/job_${job}] and run 'mlsh corb' again"
    exit 0
  else
    echo "No job provided. Exiting."
  fi
  echo ""
}

previewJobProperties() {
  echo "Job properties [${job}.corb]:"
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  grep -v '^#\|^$' ${job}.corb | sort
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo ""
  echo -n "Press 'e' to edit or any key to continue ... "
  read -n 1 answer
  echo ""
  if [[ $answer == [Ee] ]]; then
    $EDITOR ${job}.corb
  fi
}

pickAFile() {
  local fileTypes=("*.xqy" "*.js" "*.sjs")
  local files=() # Array to hold all matching files
  local i=1      # Index for numbering files
  local choice

  # Save the current screen and cursor position
  tput smcup
  clear

  echo "Select a module for the job:"
  echo ""
  for type in "${fileTypes[@]}"; do
    while IFS= read -r f; do
      files+=("$f")
      echo "  $i) $f"
      i=$((i + 1))
    done < <(find . -name "$type" -type f)
  done

  echo ""
  # Ask the user to select a file
  read -p "$@ " choice

  # Clear the screen, restoring it to the state before listing files
  tput rmcup

  # Validate choice and assign to PICK_A_FILE_CHOICE
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#files[@]}" ]; then
    PICK_A_FILE_CHOICE="${files[$((choice - 1))]}"
  else
    echo "Invalid selection."
    return 1
  fi
}

# Dump configuration settings used
mkdir -p corbLogs
local c=$runDir/config.txt
touch $c
echo "HOST: $ML_HOST" >>$c
echo "USER: $ML_USER" >>$c
