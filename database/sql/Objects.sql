-- Objects.sql
-- Views, Stored Procedures, Functions, Triggers, Indexes (examples)

-- Views
IF OBJECT_ID('dbo.vw_ProjectFinancials','V') IS NOT NULL DROP VIEW dbo.vw_ProjectFinancials;
CREATE VIEW dbo.vw_ProjectFinancials AS
SELECT p.ProjectID, p.ProjectCode, p.ProjectName, c.ClientName,
       p.Budget,
       ISNULL((SELECT SUM(mp.TotalAmount) FROM inventory.MaterialPurchases mp WHERE mp.ProjectID = p.ProjectID),0) AS TotalMaterialPurchases,
       ISNULL((SELECT SUM(e.Amount) FROM finance.Expenses e WHERE e.ProjectID = p.ProjectID),0) AS TotalExpenses,
       ISNULL((SELECT SUM(pay.Amount) FROM finance.Payments pay WHERE pay.ProjectID = p.ProjectID),0) AS TotalPayments
FROM project.Projects p
LEFT JOIN sales.Clients c ON p.ClientID = c.ClientID;

IF OBJECT_ID('dbo.vw_InventoryStatus','V') IS NOT NULL DROP VIEW dbo.vw_InventoryStatus;
CREATE VIEW dbo.vw_InventoryStatus AS
SELECT i.InventoryID, m.MaterialName, m.SKU, i.Location, i.QuantityOnHand, i.ReservedQuantity, (i.QuantityOnHand - i.ReservedQuantity) AS Available, i.LastUpdated
FROM inventory.Inventory i
JOIN inventory.Materials m ON i.MaterialID = m.MaterialID;

IF OBJECT_ID('dbo.vw_TaskAssignments','V') IS NOT NULL DROP VIEW dbo.vw_TaskAssignments;
CREATE VIEW dbo.vw_TaskAssignments AS
SELECT t.TaskID, t.Title, t.ProjectID, p.ProjectName, a.AssignmentID, a.EmployeeID, e.FullName AS EmployeeName, a.HoursAllocated, a.AssignedAt
FROM project.Tasks t
LEFT JOIN project.TaskAssignments a ON t.TaskID = a.TaskID
LEFT JOIN project.Projects p ON t.ProjectID = p.ProjectID
LEFT JOIN hr.Employees e ON a.EmployeeID = e.EmployeeID;

-- Stored Procedures (examples)
IF OBJECT_ID('sys.sp_CreateProject','P') IS NOT NULL DROP PROCEDURE sys.sp_CreateProject;
CREATE PROCEDURE sys.sp_CreateProject
    @ProjectCode NVARCHAR(50),
    @ProjectName NVARCHAR(250),
    @ClientID INT = NULL,
    @StartDate DATE = NULL,
    @ManagerEmployeeID INT = NULL,
    @Budget DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO project.Projects (ProjectCode, ProjectName, ClientID, StartDate, ManagerEmployeeID, Budget)
    VALUES (@ProjectCode, @ProjectName, @ClientID, @StartDate, @ManagerEmployeeID, @Budget);
    SELECT SCOPE_IDENTITY() AS NewProjectID;
END
GO

IF OBJECT_ID('project.sp_AssignTask','P') IS NOT NULL DROP PROCEDURE project.sp_AssignTask;
CREATE PROCEDURE project.sp_AssignTask
    @TaskID INT,
    @EmployeeID INT,
    @AssignedByUserID INT,
    @HoursAllocated DECIMAL(10,2) = 0,
    @Role NVARCHAR(100) = NULL,
    @SetTaskAssignedTo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN;
    INSERT INTO project.TaskAssignments (TaskID, EmployeeID, AssignedByUserID, HoursAllocated, Role)
    VALUES (@TaskID, @EmployeeID, @AssignedByUserID, @HoursAllocated, @Role);

    IF @SetTaskAssignedTo = 1
        UPDATE project.Tasks SET AssignedToEmployeeID = @EmployeeID WHERE TaskID = @TaskID;

    COMMIT TRAN;
END
GO

IF OBJECT_ID('inventory.sp_RecordMaterialPurchase','P') IS NOT NULL DROP PROCEDURE inventory.sp_RecordMaterialPurchase;
CREATE PROCEDURE inventory.sp_RecordMaterialPurchase
    @SupplierID INT,
    @MaterialID INT,
    @ProjectID INT = NULL,
    @PurchaseDate DATE,
    @Quantity DECIMAL(18,4),
    @UnitPrice DECIMAL(18,4),
    @InvoiceNumber NVARCHAR(150) = NULL,
    @Location NVARCHAR(150) = NULL,
    @ReceivedByEmployeeID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO inventory.MaterialPurchases (SupplierID, MaterialID, ProjectID, PurchaseDate, Quantity, UnitPrice, InvoiceNumber, ReceivedByEmployeeID)
        VALUES (@SupplierID, @MaterialID, @ProjectID, @PurchaseDate, @Quantity, @UnitPrice, @InvoiceNumber, @ReceivedByEmployeeID);

        IF @Location IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM inventory.Inventory WHERE MaterialID = @MaterialID AND Location = @Location)
            BEGIN
                UPDATE inventory.Inventory
                SET QuantityOnHand = QuantityOnHand + @Quantity, LastUpdated = SYSUTCDATETIME()
                WHERE MaterialID = @MaterialID AND Location = @Location;
            END
            ELSE
            BEGIN
                INSERT INTO inventory.Inventory (MaterialID, Location, QuantityOnHand, Unit, LastUpdated)
                SELECT @MaterialID, @Location, @Quantity, Unit, SYSUTCDATETIME()
                FROM inventory.Materials WHERE MaterialID = @MaterialID;
            END
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('finance.sp_RecordPayment','P') IS NOT NULL DROP PROCEDURE finance.sp_RecordPayment;
CREATE PROCEDURE finance.sp_RecordPayment
    @ContractID INT = NULL,
    @ProjectID INT = NULL,
    @ClientID INT = NULL,
    @PaymentDate DATE,
    @Amount DECIMAL(18,2),
    @PaymentMethod NVARCHAR(50) = NULL,
    @Reference NVARCHAR(200) = NULL,
    @ReceivedByUserID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO finance.Payments (ContractID, ProjectID, ClientID, PaymentDate, Amount, PaymentMethod, Reference, ReceivedByUserID)
    VALUES (@ContractID, @ProjectID, @ClientID, @PaymentDate, @Amount, @PaymentMethod, @Reference, @ReceivedByUserID);
    SELECT SCOPE_IDENTITY() AS NewPaymentID;
END
GO

-- Functions & additional views
IF OBJECT_ID('sys.fn_GetEmployeeFullName','FN') IS NOT NULL DROP FUNCTION sys.fn_GetEmployeeFullName;
CREATE FUNCTION sys.fn_GetEmployeeFullName(@EmployeeID INT)
RETURNS NVARCHAR(201)
AS
BEGIN
    DECLARE @name NVARCHAR(201);
    SELECT @name = FullName FROM hr.Employees WHERE EmployeeID = @EmployeeID;
    RETURN @name;
END
GO

-- Triggers (audit example for project.Projects)
IF OBJECT_ID('project.trg_Audit_Project_Changes','TR') IS NOT NULL DROP TRIGGER project.trg_Audit_Project_Changes;
CREATE TRIGGER project.trg_Audit_Project_Changes
ON project.Projects
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(10);
    IF EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted)
        SET @op = 'UPDATE';
    ELSE IF EXISTS(SELECT 1 FROM inserted)
        SET @op = 'INSERT';
    ELSE
        SET @op = 'DELETE';

    INSERT INTO sys.AuditLogs (TableName, Operation, KeyValues, BeforeData, AfterData)
    SELECT
        'project.Projects',
        @op,
        COALESCE(CONVERT(NVARCHAR(400), ISNULL(i.ProjectID, d.ProjectID)), ''),
        (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.ProjectID = d.ProjectID;
END
GO

-- Trigger to update inventory on purchases (example)
IF OBJECT_ID('inventory.trg_UpdateInventory_OnPurchase','TR') IS NOT NULL DROP TRIGGER inventory.trg_UpdateInventory_OnPurchase;
CREATE TRIGGER inventory.trg_UpdateInventory_OnPurchase
ON inventory.MaterialPurchases
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- For each inserted purchase, add to inventory at specified project address or default location
        INSERT INTO inventory.Inventory(MaterialID, Location, QuantityOnHand, Unit, LastUpdated)
        SELECT i.MaterialID, ISNULL(pr.Address, 'Main Warehouse') AS Location, SUM(i.Quantity), m.Unit, SYSUTCDATETIME()
        FROM inserted i
        LEFT JOIN inventory.Materials m ON i.MaterialID = m.MaterialID
        LEFT JOIN project.Projects pr ON i.ProjectID = pr.ProjectID
        GROUP BY i.MaterialID, ISNULL(pr.Address, 'Main Warehouse'), m.Unit
        HAVING NOT EXISTS (SELECT 1 FROM inventory.Inventory inv WHERE inv.MaterialID = i.MaterialID AND inv.Location = ISNULL(pr.Address, 'Main Warehouse'));

        -- Update existing
        UPDATE inv
        SET inv.QuantityOnHand = inv.QuantityOnHand + src.TotalQty, inv.LastUpdated = SYSUTCDATETIME()
        FROM inventory.Inventory inv
        JOIN (
            SELECT i.MaterialID, ISNULL(pr.Address,'Main Warehouse') AS Location, SUM(i.Quantity) AS TotalQty
            FROM inserted i
            LEFT JOIN project.Projects pr ON i.ProjectID = pr.ProjectID
            GROUP BY i.MaterialID, ISNULL(pr.Address,'Main Warehouse')
        ) src
        ON inv.MaterialID = src.MaterialID AND inv.Location = src.Location;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

-- Index recommendations (examples)
CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Projects_ClientID ON project.Projects(ClientID);
CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Tasks_ProjectID_Status ON project.Tasks(ProjectID, Status);
CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_TaskAssignments_EmployeeID ON project.TaskAssignments(EmployeeID);
CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_MaterialPurchases_MaterialID ON inventory.MaterialPurchases(MaterialID);
CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Inventory_MaterialID_Location ON inventory.Inventory(MaterialID, Location);

-- End of Objects.sql
