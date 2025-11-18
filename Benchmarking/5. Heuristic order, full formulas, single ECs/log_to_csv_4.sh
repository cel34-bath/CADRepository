#!/bin/bash

# Loop over all timestamped logfiles
for logfile in logfile_*.log; do
    # Extract the timestamp from the filename
    timestamp=$(echo "$logfile" | sed -E 's/^logfile_(.*)\.log$/\1/')
    outputfile="results_${timestamp}.csv"

    # Skip if output CSV already exists
    if [[ -f "$outputfile" ]]; then
        echo "Skipping $logfile (output already exists: $outputfile)"
        continue
    fi

    echo "Processing $logfile -> $outputfile"

    # Add CSV headers
    echo "File,rc_ordering,rc_memory,rc_cputime,rc_realtime,rc_cells,qe_ordering,qe_memory,qe_cputime,qe_realtime,qe_cells" > "$outputfile"

    # Extract data from logfile and append to output CSV
    awk '
    function quote(str) {
		# If the string is already wrapped in double quotes, return as is
		if (substr(str, 1, 1) == "\"" && substr(str, length(str), 1) == "\"") {
			return str;
		} else
        # Wrap in double quotes if it contains comma or square brackets or isn’t numeric
        if (str ~ /[,\[\]]/ || str ~ /[A-Za-z]/) {
            gsub(/"/, "\"\"", str);  # Escape internal quotes
            return "\"" str "\"";
        }
        return str;
    }
    BEGIN { FS="::: ";
        # Initialize variables
        file_id = ""
        rc_ordering = ""
        rc_memory = ""
        rc_cputime = ""
        rc_realtime = ""
        rc_cells = ""
        qe_ordering_vars = ""
        qe_memory = ""
        qe_cputime = ""
        qe_realtime = ""
        qe_cells = ""
    }
    # Extract file name
    /^=== .*\.smt2 ===$/ { file_id = gensub(/^=== polypaver-sqrt43-int-3vars-chunk-0*([0-9]+)\.smt2 ===$/, "\\1", "g", $0)
        qe_ordering_vars = ""  # Reset for each file
    }
    # Extract polynomial variables
    /Polynomials at level [0-9]+ for variable / {
        match($0, /for variable ([^:]+):/, m)
        if (m[1] != "") {
            if (qe_ordering_vars != "") {
                qe_ordering_vars = m[1] ", " qe_ordering_vars
            } else {
                qe_ordering_vars = m[1]
            }
        }
    }
    /^rc_ordering:/ { rc_ordering = quote($2) }
    /^rc_memory:/   { rc_memory = quote($2) }
    /^rc_cputime:/  { rc_cputime = quote($2) }
    /^rc_realtime:/ { rc_realtime = quote($2) }
    /^rc_cells:/    { rc_cells = quote($2) }
    /^qe_ordering:/ {
        if ($2 == "TIME OUT" || $2 == "\"TIME OUT\"") {
            qe_ordering = quote($2)
        } else if (qe_ordering_vars != "") {
            qe_ordering = quote("[" qe_ordering_vars "]")
        } else {
            qe_ordering = quote("ERROR")
        }
    }
    /^qe_memory:/   { qe_memory = quote($2) }
    /^qe_cputime:/  { qe_cputime = quote($2) }
    /^qe_realtime:/ { qe_realtime = quote($2) }
    /^qe_cells:/    { qe_cells = quote($2) }
    /^----------------------------------------$/ {
        print file_id "," rc_ordering "," rc_memory "," rc_cputime "," rc_realtime "," rc_cells "," qe_ordering "," qe_memory "," qe_cputime "," qe_realtime "," qe_cells
    }
    ' "$logfile" >> "$outputfile"

    echo "Done with $logfile"
done

echo "All CSV conversions complete."