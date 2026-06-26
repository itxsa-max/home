-- Create_ConstructionManagementDB.sql
-- Full schema for Home Design Architecture and Construction
-- Run in a new database context: CREATE DATABASE HDA_Construction; USE HDA_Construction;

-- Create schemas
IF NOT EXISTS (SELECT 1 FROM sys.schemas s WHERE s.name = 'sys') EXEC('CREATE SCHEMA [sys];');
IF NOT EXISTS (SELECT 1 FROM sys.schemas s WHERE s.name = 'hr') EXEC('CREATE SCHEMA [hr];');
IF NOT EXISTS (SELECT 1 FROM sys.schemas s WHERE s.name = 'project') EXEC('CREATE SCHEMA [project];');
IF NOT EXISTS (SELECT 1 FROM sys.schemas s WHERE s.name = 'sales') EXEC('CREATE SCHEMA [sales];');
IF NOT EXISTS (SELECT 1 FROM sys.schemas s WHERE s.name = 'procurement') EXEC('CREATE SCHEMA [procurement];');
IF NOT EXISTS (SELECT 1 FROM sys.schemas s WHERE s.name = 'inventory') EXEC('CREATE SCHEMA [inventory];');
IF NOT EXISTS (SELECT 1 FROM sys.schemas s WHERE s.name = 'finance') EXEC('CREATE SCHEMA [finance];');
IF NOT EXISTS (SELECT 1 FROM sys.schemas s WHERE s.name = 'asset') EXEC('CREATE SCHEMA [asset];');

-- 1. System / Security
CREATE TABLE IF NOT EXISTS sys.Roles (
    RoleID INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(400) NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE IF NOT EXISTS sys.Users (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(100) NOT NULL UNIQUE,
    PasswordHash VARBINARY(512) NULL,
    PasswordSalt VARBINARY(128) NULL,
    EmployeeID INT NULL,
    RoleID INT NOT NULL,
    IsActive BIT NOT NULL DEFAULT(1),
    LastLogin DATETIME2(7) NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Users_Role FOREIGN KEY(RoleID) REFERENCES sys.Roles(RoleID)
);

-- 2. HR
CREATE TABLE IF NOT EXISTS hr.Departments (
    DepartmentID INT IDENTITY(1,1) PRIMARY KEY,
    DeptName NVARCHAR(150) NOT NULL UNIQUE,
    ManagerEmployeeID INT NULL,
    Description NVARCHAR(400) NULL
);

CREATE TABLE IF NOT EXISTS hr.Employees (
    EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeCode NVARCHAR(20) NULL UNIQUE,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    FullName AS (FirstName + N' ' + LastName) PERSISTED,
    Email NVARCHAR(200) NULL UNIQUE,
    Phone NVARCHAR(50) NULL,
    HireDate DATE NULL,
    TerminationDate DATE NULL,
    JobTitle NVARCHAR(150) NULL,
    DepartmentID INT NULL,
    SupervisorEmployeeID INT NULL,
    EmploymentType NVARCHAR(50) NOT NULL DEFAULT('Full-Time'),
    IsActive BIT NOT NULL DEFAULT(1),
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    RowVersion ROWVERSION,
    CONSTRAINT CHK_EmploymentType CHECK (EmploymentType IN ('Full-Time','Part-Time','Contractor','Intern')),
    CONSTRAINT FK_Employees_Department FOREIGN KEY(DepartmentID) REFERENCES hr.Departments(DepartmentID)
);

ALTER TABLE hr.Departments ADD CONSTRAINT FK_Departments_Manager FOREIGN KEY(ManagerEmployeeID) REFERENCES hr.Employees(EmployeeID);

CREATE TABLE IF NOT EXISTS hr.Attendance (
    AttendanceID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    AttendanceDate DATE NOT NULL,
    ClockIn DATETIME2(7) NULL,
    ClockOut DATETIME2(7) NULL,
    HoursWorked AS (CASE WHEN ClockIn IS NOT NULL AND ClockOut IS NOT NULL THEN DATEDIFF(MINUTE, ClockIn, ClockOut)/60.0 ELSE NULL END) PERSISTED,
    Notes NVARCHAR(400) NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Attendance_EmployeeDate UNIQUE(EmployeeID, AttendanceDate),
    CONSTRAINT FK_Attendance_Employee FOREIGN KEY(EmployeeID) REFERENCES hr.Employees(EmployeeID)
);

CREATE TABLE IF NOT EXISTS hr.Payroll (
    PayrollID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    PayPeriodStart DATE NOT NULL,
    PayPeriodEnd DATE NOT NULL,
    GrossPay DECIMAL(18,2) NOT NULL,
    Taxes DECIMAL(18,2) NOT NULL DEFAULT(0),
    Deductions DECIMAL(18,2) NOT NULL DEFAULT(0),
    NetPay AS (GrossPay - Taxes - Deductions) PERSISTED,
    PaymentDate DATE NULL,
    PaymentMethod NVARCHAR(50) NULL,
    Notes NVARCHAR(400) NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Payroll_Employee FOREIGN KEY(EmployeeID) REFERENCES hr.Employees(EmployeeID)
);

-- 3. Clients & Suppliers
CREATE TABLE IF NOT EXISTS sales.Clients (
    ClientID INT IDENTITY(1,1) PRIMARY KEY,
    ClientName NVARCHAR(250) NOT NULL,
    ContactName NVARCHAR(200) NULL,
    Email NVARCHAR(200) NULL,
    Phone NVARCHAR(50) NULL,
    Address NVARCHAR(400) NULL,
    IsActive BIT NOT NULL DEFAULT(1),
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE IF NOT EXISTS procurement.Suppliers (
    SupplierID INT IDENTITY(1,1) PRIMARY KEY,
    SupplierName NVARCHAR(250) NOT NULL,
    ContactName NVARCHAR(200) NULL,
    Email NVARCHAR(200) NULL,
    Phone NVARCHAR(50) NULL,
    Address NVARCHAR(400) NULL,
    TaxId NVARCHAR(100) NULL,
    IsActive BIT NOT NULL DEFAULT(1),
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
);

-- 4. Projects & Contracts
CREATE TABLE IF NOT EXISTS project.Projects (
    ProjectID INT IDENTITY(1,1) PRIMARY KEY,
    ProjectCode NVARCHAR(50) NULL UNIQUE,
    ProjectName NVARCHAR(250) NOT NULL,
    ClientID INT NULL,
    StartDate DATE NULL,
    EndDate DATE NULL,
    ProjectStatus NVARCHAR(50) NOT NULL DEFAULT('Proposed'),
    Budget DECIMAL(18,2) NOT NULL DEFAULT(0),
    Address NVARCHAR(400) NULL,
    ManagerEmployeeID INT NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    RowVersion ROWVERSION,
    CONSTRAINT FK_Project_Client FOREIGN KEY(ClientID) REFERENCES sales.Clients(ClientID),
    CONSTRAINT FK_Project_Manager FOREIGN KEY(ManagerEmployeeID) REFERENCES hr.Employees(EmployeeID),
    CONSTRAINT CHK_ProjectStatus CHECK (ProjectStatus IN ('Proposed','Active','On Hold','Completed','Cancelled'))
);

CREATE TABLE IF NOT EXISTS project.ProjectPhases (
    PhaseID INT IDENTITY(1,1) PRIMARY KEY,
    ProjectID INT NOT NULL,
    PhaseName NVARCHAR(200) NOT NULL,
    PhaseOrder INT NOT NULL,
    StartDate DATE NULL,
    EndDate DATE NULL,
    Status NVARCHAR(50) NOT NULL DEFAULT('Planned'),
    Budget DECIMAL(18,2) NOT NULL DEFAULT(0),
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Phase_Project FOREIGN KEY(ProjectID) REFERENCES project.Projects(ProjectID),
    CONSTRAINT UQ_Project_PhaseOrder UNIQUE(ProjectID, PhaseOrder)
);

CREATE TABLE IF NOT EXISTS contracts.Contracts (
    ContractID INT IDENTITY(1,1) PRIMARY KEY,
    ContractNumber NVARCHAR(100) NOT NULL UNIQUE,
    ProjectID INT NULL,
    ClientID INT NULL,
    ContractType NVARCHAR(100) NULL,
    EffectiveDate DATE NULL,
    ExpiryDate DATE NULL,
    ContractValue DECIMAL(18,2) NOT NULL DEFAULT(0),
    Retention DECIMAL(18,2) NOT NULL DEFAULT(0),
    Status NVARCHAR(50) NOT NULL DEFAULT('Draft'),
    SignedDocumentID INT NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Contract_Project FOREIGN KEY(ProjectID) REFERENCES project.Projects(ProjectID),
    CONSTRAINT FK_Contract_Client FOREIGN KEY(ClientID) REFERENCES sales.Clients(ClientID)
);

-- 5. Tasks & Assignments
CREATE TABLE IF NOT EXISTS project.Tasks (
    TaskID INT IDENTITY(1,1) PRIMARY KEY,
    ProjectID INT NOT NULL,
    PhaseID INT NULL,
    Title NVARCHAR(250) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    CreatedByUserID INT NULL,
    AssignedToEmployeeID INT NULL,
    Priority TINYINT NOT NULL DEFAULT(3),
    Status NVARCHAR(50) NOT NULL DEFAULT('Open'),
    StartDate DATE NULL,
    DueDate DATE NULL,
    EstimatedHours DECIMAL(10,2) NULL,
    ActualHours DECIMAL(10,2) NOT NULL DEFAULT(0),
    ParentTaskID INT NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    RowVersion ROWVERSION,
    CONSTRAINT FK_Task_Project FOREIGN KEY(ProjectID) REFERENCES project.Projects(ProjectID),
    CONSTRAINT FK_Task_Phase FOREIGN KEY(PhaseID) REFERENCES project.ProjectPhases(PhaseID),
    CONSTRAINT FK_Task_CreatedBy FOREIGN KEY(CreatedByUserID) REFERENCES sys.Users(UserID),
    CONSTRAINT FK_Task_AssignedTo FOREIGN KEY(AssignedToEmployeeID) REFERENCES hr.Employees(EmployeeID),
    CONSTRAINT FK_Task_Parent FOREIGN KEY(ParentTaskID) REFERENCES project.Tasks(TaskID)
);

CREATE TABLE IF NOT EXISTS project.TaskAssignments (
    AssignmentID INT IDENTITY(1,1) PRIMARY KEY,
    TaskID INT NOT NULL,
    EmployeeID INT NOT NULL,
    AssignedByUserID INT NOT NULL,
    AssignedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    Role NVARCHAR(100) NULL,
    HoursAllocated DECIMAL(10,2) NOT NULL DEFAULT(0),
    IsActive BIT NOT NULL DEFAULT(1),
    CONSTRAINT FK_Assn_Task FOREIGN KEY(TaskID) REFERENCES project.Tasks(TaskID),
    CONSTRAINT FK_Assn_Employee FOREIGN KEY(EmployeeID) REFERENCES hr.Employees(EmployeeID),
    CONSTRAINT FK_Assn_AssignedBy FOREIGN KEY(AssignedByUserID) REFERENCES sys.Users(UserID),
    CONSTRAINT UQ_Task_Employee UNIQUE(TaskID, EmployeeID)
);

-- 6. Finance
CREATE TABLE IF NOT EXISTS finance.Payments (
    PaymentID INT IDENTITY(1,1) PRIMARY KEY,
    ContractID INT NULL,
    ProjectID INT NULL,
    ClientID INT NULL,
    PaymentDate DATE NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    PaymentMethod NVARCHAR(50) NULL,
    Reference NVARCHAR(200) NULL,
    ReceivedByUserID INT NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Payment_Contract FOREIGN KEY(ContractID) REFERENCES contracts.Contracts(ContractID),
    CONSTRAINT FK_Payment_Project FOREIGN KEY(ProjectID) REFERENCES project.Projects(ProjectID),
    CONSTRAINT FK_Payment_Client FOREIGN KEY(ClientID) REFERENCES sales.Clients(ClientID),
    CONSTRAINT FK_Payment_ReceivedBy FOREIGN KEY(ReceivedByUserID) REFERENCES sys.Users(UserID)
);

CREATE TABLE IF NOT EXISTS finance.Expenses (
    ExpenseID INT IDENTITY(1,1) PRIMARY KEY,
    ProjectID INT NULL,
    PhaseID INT NULL,
    SupplierID INT NULL,
    ExpenseDate DATE NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    Category NVARCHAR(150) NULL,
    Description NVARCHAR(400) NULL,
    IncurredByEmployeeID INT NULL,
    ReceiptDocumentID INT NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Expense_Project FOREIGN KEY(ProjectID) REFERENCES project.Projects(ProjectID),
    CONSTRAINT FK_Expense_Phase FOREIGN KEY(PhaseID) REFERENCES project.ProjectPhases(PhaseID),
    CONSTRAINT FK_Expense_Supplier FOREIGN KEY(SupplierID) REFERENCES procurement.Suppliers(SupplierID),
    CONSTRAINT FK_Expense_Employee FOREIGN KEY(IncurredByEmployeeID) REFERENCES hr.Employees(EmployeeID)
);

CREATE TABLE IF NOT EXISTS finance.BudgetManagement (
    BudgetID INT IDENTITY(1,1) PRIMARY KEY,
    ProjectID INT NOT NULL,
    PhaseID INT NULL,
    BudgetCategory NVARCHAR(150) NOT NULL,
    AllocatedAmount DECIMAL(18,2) NOT NULL DEFAULT(0),
    SpentAmount DECIMAL(18,2) NOT NULL DEFAULT(0),
    RemainingAmount AS (AllocatedAmount - SpentAmount) PERSISTED,
    LastUpdated DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Budget_Project FOREIGN KEY(ProjectID) REFERENCES project.Projects(ProjectID),
    CONSTRAINT FK_Budget_Phase FOREIGN KEY(PhaseID) REFERENCES project.ProjectPhases(PhaseID)
);

-- 7. Inventory & Procurement
CREATE TABLE IF NOT EXISTS inventory.MaterialCategories (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(150) NOT NULL UNIQUE,
    Description NVARCHAR(400) NULL
);

CREATE TABLE IF NOT EXISTS inventory.Materials (
    MaterialID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryID INT NULL,
    SKU NVARCHAR(100) NULL UNIQUE,
    MaterialName NVARCHAR(250) NOT NULL,
    Unit NVARCHAR(50) NULL,
    UnitPrice DECIMAL(18,4) NULL,
    ReorderLevel DECIMAL(18,4) NOT NULL DEFAULT(0),
    IsActive BIT NOT NULL DEFAULT(1),
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Material_Category FOREIGN KEY(CategoryID) REFERENCES inventory.MaterialCategories(CategoryID)
);

CREATE TABLE IF NOT EXISTS inventory.MaterialPurchases (
    PurchaseID INT IDENTITY(1,1) PRIMARY KEY,
    SupplierID INT NOT NULL,
    MaterialID INT NOT NULL,
    ProjectID INT NULL,
    PurchaseDate DATE NOT NULL,
    Quantity DECIMAL(18,4) NOT NULL,
    UnitPrice DECIMAL(18,4) NOT NULL,
    TotalAmount AS (Quantity * UnitPrice) PERSISTED,
    InvoiceNumber NVARCHAR(150) NULL,
    ReceivedByEmployeeID INT NULL,
    DocumentID INT NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Purchase_Supplier FOREIGN KEY(SupplierID) REFERENCES procurement.Suppliers(SupplierID),
    CONSTRAINT FK_Purchase_Material FOREIGN KEY(MaterialID) REFERENCES inventory.Materials(MaterialID),
    CONSTRAINT FK_Purchase_Project FOREIGN KEY(ProjectID) REFERENCES project.Projects(ProjectID),
    CONSTRAINT FK_Purchase_ReceivedBy FOREIGN KEY(ReceivedByEmployeeID) REFERENCES hr.Employees(EmployeeID)
);

CREATE TABLE IF NOT EXISTS inventory.Inventory (
    InventoryID INT IDENTITY(1,1) PRIMARY KEY,
    MaterialID INT NOT NULL,
    Location NVARCHAR(150) NOT NULL,
    QuantityOnHand DECIMAL(18,4) NOT NULL DEFAULT(0),
    ReservedQuantity DECIMAL(18,4) NOT NULL DEFAULT(0),
    Unit NVARCHAR(50) NULL,
    LastUpdated DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    RowVersion ROWVERSION,
    CONSTRAINT FK_Inventory_Material FOREIGN KEY(MaterialID) REFERENCES inventory.Materials(MaterialID),
    CONSTRAINT UQ_Inventory_MaterialLocation UNIQUE(MaterialID, Location)
);

-- 8. Assets
CREATE TABLE IF NOT EXISTS asset.Equipment (
    EquipmentID INT IDENTITY(1,1) PRIMARY KEY,
    EquipmentTag NVARCHAR(100) NULL UNIQUE,
    EquipmentName NVARCHAR(250) NOT NULL,
    Manufacturer NVARCHAR(150) NULL,
    Model NVARCHAR(150) NULL,
    SerialNumber NVARCHAR(150) NULL UNIQUE,
    PurchaseDate DATE NULL,
    PurchaseCost DECIMAL(18,2) NULL,
    CurrentValue DECIMAL(18,2) NULL,
    Location NVARCHAR(150) NULL,
    Status NVARCHAR(50) NOT NULL DEFAULT('Available'),
    ResponsibleEmployeeID INT NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Equipment_Employee FOREIGN KEY(ResponsibleEmployeeID) REFERENCES hr.Employees(EmployeeID)
);

CREATE TABLE IF NOT EXISTS asset.EquipmentMaintenance (
    MaintenanceID INT IDENTITY(1,1) PRIMARY KEY,
    EquipmentID INT NOT NULL,
    MaintenanceDate DATE NOT NULL,
    PerformedBy NVARCHAR(200) NULL,
    Description NVARCHAR(MAX) NULL,
    Cost DECIMAL(18,2) NOT NULL DEFAULT(0),
    NextDueDate DATE NULL,
    DocumentID INT NULL,
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Maint_Equipment FOREIGN KEY(EquipmentID) REFERENCES asset.Equipment(EquipmentID)
);

-- 9. Documents, Reports, Notifications, Audit
CREATE TABLE IF NOT EXISTS sys.Documents (
    DocumentID INT IDENTITY(1,1) PRIMARY KEY,
    DocumentGuid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    FileName NVARCHAR(260) NOT NULL,
    FilePath NVARCHAR(400) NULL,
    Content VARBINARY(MAX) NULL,
    MimeType NVARCHAR(100) NULL,
    Size BIGINT NULL,
    UploadedByUserID INT NULL,
    UploadedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    Description NVARCHAR(400) NULL,
    CONSTRAINT FK_Documents_UploadedBy FOREIGN KEY(UploadedByUserID) REFERENCES sys.Users(UserID)
);

CREATE TABLE IF NOT EXISTS sys.Reports (
    ReportID INT IDENTITY(1,1) PRIMARY KEY,
    ReportName NVARCHAR(200) NOT NULL,
    ReportType NVARCHAR(100) NULL,
    Definition NVARCHAR(MAX) NULL,
    LastRun DATETIME2(7) NULL,
    LastRunByUserID INT NULL,
    CONSTRAINT FK_Reports_LastRunBy FOREIGN KEY(LastRunByUserID) REFERENCES sys.Users(UserID)
);

CREATE TABLE IF NOT EXISTS sys.Notifications (
    NotificationID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    Title NVARCHAR(200) NOT NULL,
    Message NVARCHAR(MAX) NOT NULL,
    IsRead BIT NOT NULL DEFAULT(0),
    DateCreated DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    Source NVARCHAR(100) NULL,
    RelatedEntity NVARCHAR(100) NULL,
    RelatedID INT NULL,
    CONSTRAINT FK_Notifications_User FOREIGN KEY(UserID) REFERENCES sys.Users(UserID)
);

CREATE TABLE IF NOT EXISTS sys.AuditLogs (
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    TableName NVARCHAR(128) NOT NULL,
    Operation NVARCHAR(10) NOT NULL,
    KeyValues NVARCHAR(400) NULL,
    ChangedByUserID INT NULL,
    ChangeTime DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    BeforeData NVARCHAR(MAX) NULL,
    AfterData NVARCHAR(MAX) NULL,
    TransactionID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    CONSTRAINT FK_Auditlogs_User FOREIGN KEY(ChangedByUserID) REFERENCES sys.Users(UserID),
    CONSTRAINT CHK_Audit_Operation CHECK (Operation IN ('INSERT','UPDATE','DELETE'))
);

-- Note: IF NOT EXISTS and CREATE TABLE IF NOT EXISTS are not native in older SQL Server versions; replace with conditional logic if needed.
-- End of Create_ConstructionManagementDB.sql
