# Construction Management Database - README

This folder contains SQL scripts to create and populate a complete Construction Management Database for "Home Design Architecture and Construction". The scripts are organized for easy execution and for linking to Microsoft Access as a front-end.

Files included:
- Create_ConstructionManagementDB.sql  — schema (schemas & CREATE TABLE statements)
- Sample_Data.sql                     — sample INSERTs for initial testing
- Objects.sql                         — views, stored procedures, functions, triggers, recommended indexes
- RoleBasedAccess_Backup_Security.sql — RBAC scripts, backup & security recommendations (also included inline below)

How to install (recommended in a test environment first):
1. Create a new database in SQL Server Management Studio (SSMS):
   CREATE DATABASE HDA_Construction;
   GO
   USE HDA_Construction;
   GO

2. Run scripts in this order in SSMS (or via sqlcmd):
   - Create_ConstructionManagementDB.sql
   - Objects.sql
   - Sample_Data.sql

3. After installation:
   - Verify tables and sample data: SELECT TOP 10 * FROM project.Projects;
   - Review sys.AuditLogs for auditing behavior.

4. Role-based access (example):
   - Open RoleBasedAccess_Backup_Security.sql and follow mapping steps to create DB roles and assign users or AD groups.

Connecting Microsoft Access as front-end:
- Create an ODBC DSN (prefer Windows Authentication). Use latest ODBC Driver for SQL Server.
- In Access: External Data -> New Data Source -> From Other Sources -> ODBC Database -> Link to the data source by creating linked tables.
- Link to views for read-only dashboards (e.g., vw_ProjectFinancials, vw_InventoryStatus, vw_TaskAssignments).
- For heavy queries or multi-step operations, use PASS-THROUGH queries in Access calling stored procedures (e.g., sys.sp_CreateProject, inventory.sp_RecordMaterialPurchase).

Notes & recommendations:
- Store large files in cloud storage or file server; save file paths in sys.Documents.
- Test triggers and procedures in a controlled environment before enabling in production.
- Use BACKUP strategy: full weekly, differential daily, log backups every 15 minutes (FULL recovery model).

If you want, I can also:
- Create a small Access .accdb sample front-end (forms & sample reports) and add it to this branch — confirm if you want that.
- Generate a downloadable combined SQL file or a zip of these scripts and an Access template.

-- End README
