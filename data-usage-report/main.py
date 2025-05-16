"""
This program generates a report on the amount of public and private data each
project has in on a given list of root resources.

© 2025, The Arizona Board of Regents on behalf of The University of Arizona.
For license information, see https://cyverse.org/license.
"""

import argparse
import os
import sys
import io
import glob
import pandas as pd
import ldap
import traceback
from os import path
from contextlib import redirect_stdout
from datetime import datetime, timedelta
from sqlalchemy import (
    create_engine,
    text,
    MetaData,
    Table,
    Column,
    BigInteger,
    String,
    Index,
)
from typing import List, Optional, Dict
from irods.session import iRODSSession


try:
    _IRODS_ENV_FILE = os.environ["IRODS_ENVIRONMENT_FILE"]
except KeyError:
    _IRODS_ENV_FILE = path.expanduser("~/.irods/irods_environment.json")

# Find directory of the Python script
SCRIPT_DIR = path.dirname(path.abspath(__file__))


def find_recent_json_report(max_age_days=2):
    """
    Find the most recent JSON report file if it's less than max_age_days old.

    Args:
        max_age_days: Maximum age in days for a report to be considered recent

    Returns:
        Path to the most recent JSON report if it exists and is recent enough, None otherwise
    """
    # Find all report JSON files
    json_files = glob.glob(f"{SCRIPT_DIR}/data/report_*.json")

    if not json_files:
        return None

    def extract_date(filename):
        # Extract the date part from the filename, formatted as report_YYYYMMDD_HHMMSS.json
        date_str = filename.split("_", 1)[1].split(".")[0]
        return datetime.strptime(date_str, "%Y%m%d_%H%M%S")

    # Sort files by modification time (newest first)
    json_files.sort(key=extract_date, reverse=True)

    # Get the most recent file
    most_recent = json_files[0]

    # Check if it's less than max_age_days old
    file_mtime = extract_date(most_recent)
    # print(file_mtime)
    age = datetime.now() - file_mtime

    if age < timedelta(days=max_age_days):
        # print(age)
        print(
            f"Found recent report: {most_recent} (created {age.total_seconds() / 3600:.1f} hours ago)"
        )
        return most_recent

    print(
        f"Most recent report {most_recent} is {age.days} days old, which exceeds the maximum age of {max_age_days} days"
    )
    return None


def main():
    """Main function to parse arguments and generate the report."""

    # Print some initial information, as this script output will be sent as an email
    print(
        f"DATA ACCESS REPORT - GENERATED ON {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )

    parser = argparse.ArgumentParser(
        description="Generate report on public and private data usage per project."
    )
    parser.add_argument("-H", "--host", help="PostgreSQL host")
    parser.add_argument("-P", "--port", help="PostgreSQL port")
    parser.add_argument("-U", "--user", help="PostgreSQL user")
    parser.add_argument(
        "resources", nargs="+", help="List of root resources to analyze"
    )
    parser.add_argument(
        "--html", action="store_true", help="Output as HTML file (output.html)"
    )
    parser.add_argument(
        "--ldap-server",
        default="ldap://ldap.iplantcollaborative.org",
        help="LDAP server URL (default: ldap://ldap.iplantcollaborative.org)",
    )
    parser.add_argument(
        "--ldap-base",
        default="dc=iplantcollaborative,dc=org",
        help="LDAP base DN (default: dc=iplantcollaborative,dc=org)",
    )
    parser.add_argument(
        "--force-refresh",
        action="store_true",
        help="Force regeneration of the report, ignoring recent JSON reports",
    )
    parser.add_argument(
        "--max-report-age",
        type=int,
        default=2,
        help="Maximum age (in days) of a JSON report to reuse (default: 2)",
    )
    parser.add_argument(
        "--irods-upload-location",
        default="/iplant/home/shared/CyVerse_DSStats/data-products/project-data-usage",
    )
    parser.add_argument(
        "--debug", action="store_true", help="Enable debug mode for detailed output"
    )
    args = parser.parse_args()

    # Create a buffer to capture the program output
    program_output = io.StringIO()
    if args.debug:
        program_output = sys.stdout  # Redirect to stdout if debug mode is enabled

    html_filename = None

    try:
        # Redirect stdout to our buffer for everything between the markers
        with redirect_stdout(program_output):
            # Check for a recent report first, unless force-refresh is specified
            report_df = None
            if not args.force_refresh:
                recent_report = find_recent_json_report(args.max_report_age)
                if recent_report:
                    print(f"Loading data from recent report: {recent_report}")
                    try:
                        report_df = pd.read_json(recent_report)
                        print("Successfully loaded data from recent report")
                    except ValueError as e:
                        print(f"Error loading recent report: {e}")
                        report_df = None

            # If no recent report was found or loading failed, generate a new one
            if report_df is None:
                # Set environment variables for database connection
                if args.host:
                    os.environ["PGHOST"] = args.host
                if args.port:
                    os.environ["PGPORT"] = args.port
                if args.user:
                    os.environ["PGUSER"] = args.user

                # Create SQLAlchemy engine
                print("Connecting to the database...")
                conn_string = create_connection_string(
                    host=args.host if args.host else os.environ.get("PGHOST"),
                    port=args.port if args.port else os.environ.get("PGPORT"),
                    user=args.user if args.user else os.environ.get("PGUSER"),
                    dbname="ICAT",
                )
                engine = create_engine(conn_string)

                # Generate and output the report
                print("Generating the report...")
                print("\tGetting the local zone...")
                local_zone = get_local_zone(engine)
                print(f"\tLocal zone: {local_zone}")
                print("\tGenerating the report data...")

                # Generate report using temporary tables approach
                report_df = gen_report(engine, local_zone, args.resources)

                # Save it as a JSON object, and include the date and time of the report in the report filename
                report_filename = f"{SCRIPT_DIR}/data/report_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.json"
                report_df.to_json(report_filename, orient="records")
                print(f"Report saved as JSON: {report_filename}")

            # Output the report
            if args.html:
                # Format the output as HTML
                print("Formatting the report as HTML...")
                html_output = format_html_report(
                    report_df, args.ldap_server, args.ldap_base
                )

                # Save the output in output.html
                # Make the filename report-YYYY-MM-DD.html
                html_filename = f"{SCRIPT_DIR}/reports/report_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.html"
                print("Saving the report to HTML file...")
                with open(html_filename, "w", encoding="utf-8") as f:
                    f.write(html_output)
                print(
                    "Report generated successfully. You can view the report in your web browser."
                )

                # Save it to the iRODS upload location
                if args.irods_upload_location:
                    print(
                        f"Saving the report to iRODS upload location: {args.irods_upload_location}"
                    )
                    with iRODSSession(irods_env_file=_IRODS_ENV_FILE) as session:
                        # Create the collection if it doesn't exist
                        session.collections.create(args.irods_upload_location)
                        # Upload the file
                        session.data_objects.put(
                            html_filename, args.irods_upload_location
                        )
                    print(f"Report uploaded to iRODS at {args.irods_upload_location}")

            else:
                # Print to console
                print("\nPublic and Private Data Volume (GiB) per Project")
                print("=" * 60)
                print(report_df.to_string(index=False))

        # Resume normal output (outside the redirect)
        print("Report generation completed.")
        if html_filename and args.irods_upload_location:
            # Replace the iRODs upload location with the actual URL - by changing /iplant/home/shared to data.cyverse.org/dav/iplant/projects
            print(
                f"To access report, please visit: https://data.cyverse.org/dav/iplant/projects/{args.irods_upload_location.replace('/iplant/home/shared', '')}/{os.path.basename(html_filename)}"
            )
        print("Thank you for using the Data Access Report Generator!")

    except Exception as e:
        # If an error occurs, print the captured output and the error
        print("------ Program output START -------")
        print(program_output.getvalue())
        print("------ Program output END -------")
        print(f"ERROR: {str(e)}")
        print(traceback.format_exc())  # Print the full traceback for debugging
        sys.exit(1)  # Exit with error code


def create_connection_string(
    host: Optional[str], port: Optional[str], user: Optional[str], dbname: str
) -> str:
    """Create a SQLAlchemy connection string."""
    # Note: This uses environment variables for password authentication
    return f"postgresql://{user}@{host}:{port}/{dbname}"


def get_local_zone(engine) -> str:
    """Get the local zone name from the database."""
    query = "SELECT zone_name FROM r_zone_main WHERE zone_type_name = 'local'"
    with engine.connect() as conn:
        result = conn.execute(text(query)).fetchone()
        return result[0]


def gen_report(engine, zone: str, root_resources: List[str]) -> pd.DataFrame:
    """Generate the report data using temporary tables."""
    metadata = MetaData()

    with engine.begin() as conn:  # Use transaction
        # Set isolation level
        conn.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ"))

        # Step 1: Create and populate the resource table
        print("\tCreating storage resource table...")
        store_resc = create_store_resc_table(conn, metadata, root_resources)
        assert store_resc is not None, "Failed to create store_resc table"

        # Step 2: Create and populate project collections table
        print("\tCreating project collections table...")
        proj_coll = create_proj_coll_table(conn, metadata, zone)
        assert proj_coll is not None, "Failed to create proj_coll table"

        # Step 3: Create and populate project data table
        print("\tCreating project data table...")
        proj_data = create_proj_data_table(conn, metadata)
        assert proj_data is not None, "Failed to create proj_data table"

        # Step 4: Create and populate public objects table
        print("\tCreating public objects table...")
        pub_obj = create_pub_obj_table(conn, metadata)
        assert pub_obj is not None, "Failed to create pub_obj table"

        # Step 5: Create and populate public project data table
        print("\tCreating public project data table...")
        create_pub_proj_data_table(conn, metadata)

        # Step 6: Query for the final report
        print("\tGenerating final report...")
        # query = """
        # SELECT
        #     ROUND((tot_vol / 2^30)::NUMERIC, 3) AS "Total",
        #     ROUND((pub_vol / 2^30)::NUMERIC, 3) AS "Public",
        #     ROUND(((tot_vol - pub_vol) / 2^30)::NUMERIC, 3) AS "Private",
        #     proj AS "Project",
        #     creator AS "Creator",
        #     owner AS "Owner"
        # FROM (
        #     SELECT
        #         a.proj,
        #         SUM(a.data_size) AS tot_vol,
        #         COALESCE(SUM(p.data_size), 0) AS pub_vol,
        #         MAX(pc.creator) AS creator,
        #         MAX(pc.owner) AS owner
        #     FROM proj_data AS a
        #     LEFT JOIN pub_proj_data AS p ON p.data_id = a.data_id
        #     LEFT JOIN (
        #         SELECT
        #             proj,
        #             STRING_AGG(DISTINCT creator, '; ') FILTER (WHERE creator IS NOT NULL) AS creator,
        #             STRING_AGG(DISTINCT owner, '; ') FILTER (WHERE owner IS NOT NULL) AS owner
        #         FROM proj_coll
        #         GROUP BY proj
        #     ) pc ON pc.proj = a.proj
        #     GROUP BY a.proj
        # ) AS t
        # ORDER BY proj
        # """
        query = """
                SELECT
                ROUND((tot_vol / 2^30)::NUMERIC, 3) AS "Total",
                ROUND((pub_vol / 2^30)::NUMERIC, 3) AS "Public",
                ROUND(((tot_vol - pub_vol) / 2^30)::NUMERIC, 3) AS "Private",
                proj AS "Project",
                creator AS "Creator",
                owner AS "Owner"
            FROM (
                SELECT 
                    a.proj, 
                    SUM(a.data_size) AS tot_vol, 
                    COALESCE(SUM(p.data_size), 0) AS pub_vol,
                    MAX(pc.creator) AS creator,
                    MAX(pc.owner) AS owner
                FROM proj_data AS a 
                LEFT JOIN pub_proj_data AS p ON p.data_id = a.data_id
                LEFT JOIN (
                    SELECT 
                        proj,
                        STRING_AGG(DISTINCT creator, '; ') FILTER (WHERE creator IS NOT NULL) AS creator,
                        STRING_AGG(DISTINCT owner, '; ') FILTER (WHERE owner IS NOT NULL) AS owner
                    FROM proj_coll
                    GROUP BY proj
                ) pc ON pc.proj = a.proj
                GROUP BY a.proj
            ) AS t
            ORDER BY proj
        """
        # Execute the query and fetch the result
        result = pd.read_sql_query(text(query), conn)

        # Clean up - drop all temporary tables at the end of the transaction
        metadata.drop_all(conn)

    return result


def create_store_resc_table(conn, metadata, root_resources: List[str]):
    """Create temporary table for storage resources using SQLAlchemy."""
    # Define the temporary table
    store_resc = Table(
        "store_resc", metadata, Column("id", BigInteger), prefixes=["TEMPORARY"]
    )

    # Create the table
    store_resc.create(conn)

    # Create index
    Index("store_resc_idx", store_resc.c.id).create(conn)

    # Build the recursive query
    resources_str = ", ".join(f"'{r}'" for r in root_resources)
    recursive_query = f"""
        WITH RECURSIVE resc_hier(resc_id, resc_net) AS (
            SELECT resc_id, resc_net
            FROM r_resc_main
            WHERE resc_name IN ({resources_str})
            UNION SELECT m.resc_id, m.resc_net
            FROM resc_hier AS h JOIN r_resc_main AS m ON m.resc_parent = h.resc_id::TEXT
            WHERE h.resc_net = 'EMPTY_RESC_HOST' 
        )
        INSERT INTO store_resc (id)
        SELECT resc_id FROM resc_hier
    """
    conn.execute(text(recursive_query))

    return store_resc


def create_proj_coll_table(conn, metadata, zone: str):
    """Create temporary table for project collections using SQLAlchemy."""
    # Define the temporary table
    proj_coll = Table(
        "proj_coll",
        metadata,
        Column("proj", String),
        Column("coll_id", BigInteger),
        prefixes=["TEMPORARY"],
    )

    # Create the table
    proj_coll.create(conn)

    # Create index
    Index("proj_coll_idx", proj_coll.c.coll_id).create(conn)

    # # Insert data
    # insert_query = f"""
    #     INSERT INTO proj_coll (proj, coll_id, creator, owner)
    #     SELECT
    #         REGEXP_REPLACE(c.coll_name, '/{zone}/home/shared/([^/]+).*', E'\\\\1') AS proj,
    #         c.coll_id,
    #         CASE
    #             WHEN c.coll_name ~ '/{zone}/home/shared/[^/]+$' THEN c.coll_owner_name
    #             ELSE NULL
    #         END AS creator,
    #         CASE
    #             WHEN c.coll_name ~ '/{zone}/home/shared/[^/]+$' THEN u.user_name
    #             ELSE NULL
    #         END AS owner
    #     FROM r_coll_main c
    #     LEFT JOIN r_objt_access a ON c.coll_id = a.object_id AND a.access_type_id = 1200
    #     LEFT JOIN r_user_main u ON a.user_id = u.user_id
    #     WHERE c.coll_name LIKE '/{zone}/home/shared/%'
    #     AND c.coll_name NOT SIMILAR TO '/{zone}/home/shared/commons_repo(/%)?'
    #     AND u.user_type_name = 'rodsuser'
    # """

    # Insert data
    insert_query = f"""
        INSERT INTO proj_coll (proj, coll_id)
        SELECT 
            REGEXP_REPLACE(c.coll_name, '/{zone}/home/shared/([^/]+).*', E'\\\\1') AS proj, 
            c.coll_id
        FROM r_coll_main c
        WHERE c.coll_name LIKE '/{zone}/home/shared/%'
        AND c.coll_name NOT SIMILAR TO '/{zone}/home/shared/commons_repo(/%)?'
    """

    conn.execute(text(insert_query))
    # print the number of rows inserted
    count_query = "SELECT COUNT(*) FROM proj_coll"
    count_result = conn.execute(text(count_query)).fetchone()
    print(f"\tInserted {count_result[0]} rows into proj_coll table.")
    return proj_coll


def create_proj_data_table(conn, metadata):
    """Create temporary table for project data using SQLAlchemy."""
    # Define the temporary table
    proj_data = Table(
        "proj_data",
        metadata,
        Column("proj", String),
        Column("coll_id", BigInteger),
        Column("data_id", BigInteger),
        Column("data_size", BigInteger),
        prefixes=["TEMPORARY"],
    )

    # Create the table
    proj_data.create(conn)

    # Create indices
    Index("proj_data_coll_data_idx", proj_data.c.coll_id, proj_data.c.data_id).create(
        conn
    )
    Index("proj_data_data_idx", proj_data.c.data_id).create(conn)

    # Insert data
    insert_query = """
        INSERT INTO proj_data (proj, coll_id, data_id, data_size)
        SELECT c.proj, c.coll_id, d.data_id, d.data_size
        FROM proj_coll AS c 
        JOIN r_data_main AS d ON d.coll_id = c.coll_id
        WHERE d.resc_id IN (SELECT id FROM store_resc)
    """
    conn.execute(text(insert_query))

    return proj_data


def create_pub_obj_table(conn, metadata):
    """Create temporary table for public objects using SQLAlchemy."""
    # Define the temporary table
    pub_obj = Table(
        "pub_obj", metadata, Column("id", BigInteger), prefixes=["TEMPORARY"]
    )

    # Create the table
    pub_obj.create(conn)

    # Create index
    Index("pub_obj_idx", pub_obj.c.id).create(conn)

    # Insert data
    insert_query = """
        INSERT INTO pub_obj (id)
        SELECT object_id
        FROM r_objt_access
        WHERE user_id = (SELECT user_id FROM r_user_main WHERE user_name = 'public')
    """
    conn.execute(text(insert_query))

    return pub_obj


def create_pub_proj_data_table(conn, metadata):
    """Create temporary table for public project data using SQLAlchemy."""
    # Define the temporary table
    pub_proj_data = Table(
        "pub_proj_data",
        metadata,
        Column("proj", String),
        Column("data_id", BigInteger),
        Column("data_size", BigInteger),
        prefixes=["TEMPORARY"],
    )

    # Create the table
    pub_proj_data.create(conn)

    # Create indices
    Index("pub_proj_data_data_idx", pub_proj_data.c.data_id).create(conn)
    Index("pub_proj_data_proj_idx", pub_proj_data.c.proj).create(conn)

    # Insert data
    insert_query = """
        INSERT INTO pub_proj_data (proj, data_id, data_size)
        SELECT proj, data_id, data_size
        FROM proj_data
        WHERE coll_id IN (SELECT id FROM pub_obj) 
        AND data_id IN (SELECT id FROM pub_obj)
    """
    conn.execute(text(insert_query))

    return pub_proj_data


def get_ldap_user_info(
    username: str, ldap_server: str, ldap_base: str
) -> Optional[Dict]:
    """Query LDAP for detailed user information."""
    if not username:
        return None

    try:
        # Connect to LDAP server
        ldap_conn = ldap.initialize(ldap_server)
        ldap_conn.set_option(ldap.OPT_REFERRALS, 0)

        # Perform the search
        search_filter = f"(uid={username})"
        attributes = ["cn", "mail", "title", "departmentNumber", "uid", "o"]

        result = ldap_conn.search_s(
            ldap_base, ldap.SCOPE_SUBTREE, search_filter, attributes
        )

        # If user found, extract attributes
        if result and len(result) > 0:
            _, attrs = result[0]
            return {
                "fullname": attrs.get("cn", [b""])[0].decode("utf-8")
                if attrs.get("cn")
                else "",
                "email": attrs.get("mail", [b""])[0].decode("utf-8")
                if attrs.get("mail")
                else "",
                "title": attrs.get("title", [b""])[0].decode("utf-8")
                if attrs.get("title")
                else "",
                "department": attrs.get("departmentNumber", [b""])[0].decode("utf-8")
                if attrs.get("departmentNumber")
                else "",
                "username": attrs.get("uid", [b""])[0].decode("utf-8")
                if attrs.get("uid")
                else "",
                "organization": attrs.get("o", [b""])[0].decode("utf-8")
                if attrs.get("o")
                else "",
            }

        ldap_conn.unbind()
    except Exception as e:
        print(f"LDAP error for user {username}: {e}")

    return None


def format_html_report(df: pd.DataFrame, ldap_server: str, ldap_base: str) -> str:
    """Format the DataFrame as an HTML report with LDAP info for owners."""
    html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Public and Private Data Volume (GiB) per Project</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                margin: 20px;
                line-height: 1.6;
            }
            h1 {
                color: #333;
                margin-bottom: 20px;
            }
            table {
                border-collapse: collapse;
                width: 100%;
                margin-bottom: 20px;
            }
            th, td {
                padding: 8px 12px;
                text-align: left;
                border-bottom: 1px solid #ddd;
            }
            th {
                background-color: #f2f2f2;
                font-weight: bold;
            }
            tr:hover {
                background-color: #f5f5f5;
            }
            .footer {
                font-size: 0.8em;
                color: #666;
                margin-top: 30px;
            }
            .subtable {
                margin: 0;
                width: 100%;
                border: none;
                margin-top: 5px;
                border: 1px solid #ddd;
                border-radius: 0 0 3px 3px;
            }
            .subtable td {
                border: none;
                padding: 2px 6px;
            }
            .subtable tr:hover {
                background-color: transparent;
            }
            .label {
                font-weight: bold;
                color: #555;
            }
            details {
                cursor: pointer;
                margin: 0;
                padding: 0;
            }
            summary {
                padding: 5px;
                background-color: #f8f8f8;
                border: 1px solid #ddd;
                border-radius: 3px;
                font-weight: bold;
            }
            details[open] summary {
                border-bottom-left-radius: 0;
                border-bottom-right-radius: 0;
            }
            .separator {
                height: 1px;
                background-color: #ddd;
                padding: 0 !important;
            }
            .owner-header {
                font-weight: bold;
                padding-top: 8px !important;
                color: #333;
            }
        </style>
    </head>
    <body>
        <h1>Public and Private Data Volume (GiB) per Project</h1>
    """

    # Custom HTML generation instead of using pandas to_html
    html += """
    <table>
        <thead>
            <tr>
    """

    # Add headers
    for col in df.columns:
        html += f"<th>{col}</th>"

    html += """
            </tr>
        </thead>
        <tbody>
    """

    # Add rows
    for _, row in df.iterrows():
        html += "<tr>"

        for col in df.columns:
            if col == "Owner" and row[col]:
                html += "<td>"

                # Split multiple owners if there are any
                owners = row[col].split("; ")
                owner_infos = []

                # Fetch LDAP info for all owners first
                for owner in owners:
                    owner = owner.strip()
                    user_info = get_ldap_user_info(owner, ldap_server, ldap_base)
                    if user_info:
                        owner_infos.append(user_info)
                    else:
                        # Create minimal info for users without LDAP data
                        owner_infos.append(
                            {
                                "username": owner,
                                "fullname": owner,
                                "email": "",
                                "title": "",
                                "department": "",
                                "organization": "",
                            }
                        )

                # Get full names for summary
                fullnames = [info["fullname"] for info in owner_infos]
                summary_line = "; ".join(fullnames)

                # Create collapsible section
                html += f"""
                <details>
                    <summary>{summary_line}</summary>
                    <table class="subtable">
                """

                # Add details for each owner in one single table
                for i, info in enumerate(owner_infos):
                    html += f"""
                    <tr>
                        <td colspan="2" class="owner-header">{info['fullname']} ({info['username']})</td>
                    </tr>
                    """

                    if info["email"]:
                        html += f"""<tr><td class="label">Email:</td><td><a href="/cdn-cgi/l/email-protection#91eaf8fff7fecab6f4fcf0f8fdb6ccec">{info['email']}</a></td></tr>"""

                    if info["title"]:
                        html += f"""<tr><td class="label">Title:</td><td>{info['title']}</td></tr>"""

                    if info["department"]:
                        html += f"""<tr><td class="label">Department:</td><td>{info['department']}</td></tr>"""

                    if info["organization"]:
                        html += f"""<tr><td class="label">Organization:</td><td>{info['organization']}</td></tr>"""

                    if (
                        info["username"] == info["fullname"]
                    ):  # This is our check for missing LDAP data
                        html += """<tr><td colspan="2">No detailed information available</td></tr>"""

                    # Add a separator row except for the last owner
                    if i < len(owner_infos) - 1:
                        html += '<tr><td colspan="2" class="separator"></td></tr>'

                # Close the table and details
                html += """
                    </table>
                </details>
                """

                html += "</td>"
            else:
                html += f"<td>{row[col]}</td>"

        html += "</tr>"

    html += """
        </tbody>
    </table>
    """

    # Add footer and close tags
    html += """
        <div class="footer">
            © 2025, The Arizona Board of Regents on behalf of The University of Arizona.
            For license information, see <a href="https://cyverse.org/license">https://cyverse.org/license</a>.
        </div>
    <script data-cfasync="false" src="/cdn-cgi/scripts/5c5dd728/cloudflare-static/email-decode.min.js"></script></body>
    </html>
    """

    return html


if __name__ == "__main__":
    main()
