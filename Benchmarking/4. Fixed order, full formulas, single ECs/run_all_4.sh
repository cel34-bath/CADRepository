#!/bin/bash

# Set directory containing the .smt2 files
target_dir="../meti-tarki-polypaver-sqrt43-int-3vars-ECMOD"
timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
logfile="logfile_$timestamp.log"
mapledir="C:/Program Files/Maple 2024/bin.X86_64_WINDOWS"
maple_script="process_file_4.m"

# Start timer (in ms)
start_time=$(date +%s%N)

# Clear previous log file
echo "Benchmark results - $(date)" > "$logfile"

# Loop through all .smt2 files
for file in "$target_dir"/*.smt2; do
    echo "=== $(basename "$file") ===" | tee -a "$logfile"

    (
        echo "filename := \"$file\":" # writes "filename:=[the file]" for sending to Maple
        cat "$maple_script" # prints the content of the entire script file below it
        # EOF is used to feed multiple lines - start with <<EOF and end with EOF to mark beginning/end of input.
        cat <<EOF
printf("\n");
printf("RC\n");
rc_ordering := ListTools:-Reverse(rc_ordering):
if RC_result = "TIME OUT" then
	rc_ordering := "TIME OUT":
	rc_memory := "TIME OUT":
	rc_cputime := "TIME OUT":
	rc_realtime := "TIME OUT":
	rc_cells := "TIME OUT":
elif StringTools:-IsPrefix("ERROR: ", RC_result) then
    rc_ordering := RC_result:
    rc_memory := RC_result:
    rc_cputime := RC_result:
    rc_realtime := RC_result:
    rc_cells := RC_result:
elif not type(rc_memory, integer) then
    rc_ordering := "ERROR":
    rc_memory := "ERROR":
    rc_cputime := "ERROR":
    rc_realtime := "ERROR":
    rc_cells := "ERROR":
end if:

printf("rc_ordering::: %a\n", rc_ordering);
printf("rc_memory::: %a\n", rc_memory);
printf("rc_cputime::: %a\n", rc_cputime);
printf("rc_realtime::: %a\n", rc_realtime);
printf("rc_cells::: %a\n", rc_cells);

printf("QE\n");

if QE_result = "TIME OUT" then
	qe_ordering := "TIME OUT":
	qe_memory := "TIME OUT":
	qe_cputime := "TIME OUT":
	qe_realtime := "TIME OUT":
	qe_cells := "TIME OUT":
elif StringTools:-IsPrefix("ERROR: ", QE_result) then
    qe_ordering := QE_result:
    qe_memory := QE_result:
    qe_cputime := QE_result:
    qe_realtime := QE_result:
    qe_cells := QE_result:
elif not type(qe_memory, integer) then
    qe_ordering := "ERROR":
    qe_memory := "ERROR":
    qe_cputime := "ERROR":
    qe_realtime := "ERROR":
    qe_cells := "ERROR":
end if:

printf("qe_ordering::: %a\n", qe_ordering);
printf("qe_memory::: %a\n", qe_memory);
printf("qe_cputime::: %a\n", qe_cputime);
printf("qe_realtime::: %a\n", qe_realtime);
printf("qe_cells::: %a\n", qe_cells);
EOF
    ) | "$mapledir"/cmaple.exe -q | tee -a "$logfile"

    echo "----------------------------------------" | tee -a "$logfile"
done

# End timer and compute duration in ms
end_time=$(date +%s%N)
total_sec=$(awk "BEGIN {printf \"%.3f\", ($end_time - $start_time)/1000000000}")
total_min=$(awk "BEGIN {printf \"%.2f\", $total_sec/60}")

echo "Done. Output saved in $logfile."
echo "Total time taken: $total_sec seconds (~$total_min minutes)" | tee -a "$logfile"
read -p "Press Enter to close."