import os
import json
import re

# Define the test script function
def extract_i18n_strings_from_file(file_path):
    relevant_strings = []

    # Regex pattern to match strings in the specified formats
    pattern = re.compile(r"(['\"])(.*?)\1\.i18n")

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                matches = pattern.findall(line)
                for _, relevant_string in matches:
                    relevant_strings.append(relevant_string)
    except (IOError, UnicodeDecodeError) as e:
        print(f"Error reading file {file_path}: {e}")

    return relevant_strings

strings = []

# Define the test file path
directory = '../lib'

# Traverse the directory recursively
for root, _, files in os.walk(directory):
    for file in files:
        file_path = os.path.join(root, file)
        try:
            file_strings = extract_i18n_strings_from_file(file_path)
        except (IOError, UnicodeDecodeError) as e:
            print(f"Error reading file {file_path}: {e}")

        strings += file_strings

# Create the output JSON structure
output = {string: string for string in strings}

# Write to dnd.json
output_path = 'dnd.json'
with open(output_path, 'w', encoding='utf-8') as json_file:
    json.dump(output, json_file, ensure_ascii=False, indent=4)

    
