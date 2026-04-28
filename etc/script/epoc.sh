#!/bin/sh

# Input and output file paths
input_file="/tmp/dhcp.leases"  # Replace with your input file location
output_file="/tmp/converted_file.txt"  # Replace with your desired output file location

# Create output file or clear its contents
> "$output_file"

# Read each line from the input file
while IFS= read -r line; do
  # Extract the epoch time (the first field in the line)
  epoch_time=$(echo "$line" | awk '{print $1}')

  # Check if the first field is a valid epoch timestamp
  if echo "$epoch_time" | grep -qE '^[0-9]+$'; then
    # Convert epoch time to human-readable CST time
    human_time=$(date -d @"$epoch_time" +"%Y-%m-%d %H:%M:%S")
    # Append the human-readable time to the rest of the line
    echo "$human_time $line" >> "$output_file"
  else
    # Write the original line to the output file if no epoch is found
    echo "$line" >> "$output_file"
  fi
done < "$input_file"
