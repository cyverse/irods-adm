# DATA USAGE REPORT GENERATOR

These scripts generate a report of data usage for all collections in all projects in CyVerse. The system consists of two parts: a Python file that performs the actual work and a bash script that runs it. The bash script sets up the environment and executes the Python file, which then generates the data usage report and uploads it to CyVerse. After that it outputs a message with a link to the report, which can be piped to email. In CyVerse, you can find all the reports in `/iplant/home/shared/CyVerse_DSStats/data-products/project-data-usage`.

## USAGE

1. Just run the bash script `run_data_report.sh` in the `irods-adm/data-usage-report` directory.

    Example:

    ```bash
        ./run_data_report.sh -H <hostname> -P <port> -U <username> -r <resource> --html
    ```

    *(Please refer to the `run_data_report.sh` file for more options.)*

2. The bash script will set up the environment and run the Python file.
3. The Python file will generate a report of data usage for all collections in all projects in CyVerse.
4. The report will be saved in the `irods-adm/data-usage-report/reports` directory as well as in CyVerse.
5. The report will also be stored as JSON in the `irods-adm/data-usage-report/data` directory.
6. If you pipe the bash script to an email, it will send the link to the report in the email.

    Example:

    ```bash
        ./run_data_report.sh -H <hostname> -P <port> -U <username> -r <resource> --html | mail -s "Data Usage Report" <email>
    ```

## AUTHOR

- Tanmay Agrawal
- Tony Edgin *(the original bash script that this script is based on)*
