#!/usr/bin/python3
import os
import glob

def search_gz_tgz_files(directory):
    # Initialize an empty list to store the file paths
    all_files = []

    # Recursively walk through the directory tree
    for root, dirs, files in os.walk(directory):
        # Join the current root with the pattern for *.gz and *.tgz files
        pattern_gz = os.path.join(root, '*.gz')  # For .gz files
        pattern_tgz = os.path.join(root, '*.tgz*')  # For .tgz files

        # Use glob to find files matching the patterns
        gz_files = glob.glob(pattern_gz)
        tgz_files = glob.glob(pattern_tgz)

        # Combine the lists of .gz and .tgz files
        all_files.extend(gz_files + tgz_files)

    return all_files


def calculate_total_size(files):
    global nbfiles 
    total_size = 0
    for file in files:
        total_size += os.path.getsize(file)
        nbfiles += 1
        os.remove(file)
    return total_size

def convert_size_to_human_readable(size_in_bytes):
    # Convert bytes to megabytes
    size_in_mb = size_in_bytes / (1024 ** 2)

    # If size is greater than 1 GB, convert to gigabytes
    if size_in_mb > 1024:
        size_in_gb = size_in_mb / 1024
        return f"{size_in_gb:.2f} GB"
    else:
        return f"{size_in_mb:.2f} MB"


nbfiles = 0

# Specify the directory path
directory_path = '/data'

# Search for .gz and .tgz files in the specified directory and its subdirectories
result_files = search_gz_tgz_files(directory_path)

# Calculate the total size of all files
total_size = calculate_total_size(result_files)

# Convert the total size to human-readable format
total_size_hr = convert_size_to_human_readable(total_size)

# Print the result
if nbfiles == 0:
    print("No file to delete")
else:
    print(f"{nbfiles} files have been deleted for a total of {total_size_hr}")
