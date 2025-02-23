import os

def replace_font_family_in_files(folder_path):
    """
    Parses all files in a folder and replaces "fontFamily: 'Deezer'" with "fontFamily: 'MontSerrat'".

    Args:
        folder_path: The path to the folder containing the files to be processed.
    """
    for root, _, files in os.walk(folder_path):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                with open(file_path, 'r') as f:
                    file_content = f.read()

                modified_content = file_content.replace("'MontSerrat'", "'Poppins'")

                if modified_content != file_content:
                    with open(file_path, 'w') as f:
                        f.write(modified_content)
                    print(f"Replaced text in: {file_path}")
            except Exception as e:
                print(f"Error processing file: {file_path} - {e}")

    print("Font family replacement process completed.")

# Example usage:
# folder_to_scan = "/path/to/your/folder"  # Replace with the actual path to your folder
# replace_font_family_in_files(folder_to_scan)

replace_font_family_in_files("lib/ui")