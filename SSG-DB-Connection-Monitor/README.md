# SSG DB Connection Monitor

Monitor the count of MySQL database connections and generate an alert when it is not *normal*

Run from cron to report on current MySQL connections

Under normal operating conditions, assuming that the only application using the database is the Layer 7 API Gateway, the SECONDARY node should only see one ESTABLISHED connection to port 3306 (the replication thread) and the PRIMARY should see more than one connection (the replication thread plus all of the processing nodes). This script checks the count of MySQL database connections and if it does not match the above criteria for this type of node then it generates a log entry (using logger) and optionally sends an alert via email.
