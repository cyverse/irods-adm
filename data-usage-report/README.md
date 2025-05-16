# DATA USAGE REPORT GENERATOR

This script generates a report of data usage for all collections in all projects in CyVerse. There are two parts of this script, one the Python file that does the actual work, and the other is a bash script that runs the Python file. The bash script is used to set up the environment and run the Python file. The Python file does the actual work of generating the report.
# USAGE
1. Just run the bash script `data_usage_report.sh` in the `irods-adm/data-usage-report` directory.
    Example:
    ```bash
        ./data_usage_report.sh -H <hostname> -P <port> -U <username> -r <resource> --html
    ```
    *(Please refer to the `data_usage_report.sh` file for more options.)*
2. The bash script will set up the environment and run the Python file.
3. The Python file will generate a report of data usage for all collections in all projects in CyVerse.
4. The report will be saved in the `irods-adm/data-usage-report` directory as well as in CyVerse.
5. If you pipe the bash script to an email, it will send the report along with the link to the report in CyVerse.

# AUTHOR
- Tanmay Agrawal
- Tony Edgin *(the original bash script that this script is based on)*

