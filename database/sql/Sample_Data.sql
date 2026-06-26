-- Sample_Data.sql
-- Populate minimal sample data for testing

-- Roles
INSERT INTO sys.Roles (RoleName, Description) VALUES
('President','Company President'),
('VicePresident','Vice President'),
('Employee','Standard employee');

-- Departments
INSERT INTO hr.Departments (DeptName, Description) VALUES
('Architecture','Architecture department'),
('Construction','Construction operations'),
('Engineering','Engineering services');

-- Employees
INSERT INTO hr.Employees (EmployeeCode, FirstName, LastName, Email, JobTitle, DepartmentID, IsActive)
VALUES
('E001','Alice','Johnson','alice.johnson@hda.com','President',NULL,1),
('E002','Bob','Martinez','bob.martinez@hda.com','VP Operations',1,1),
('E003','Clara','Nguyen','clara.nguyen@hda.com','Architect',1,1),
('E004','Daniel','Smith','daniel.smith@hda.com','Site Engineer',2,1);

-- Users (note: replace PasswordHash placeholders with real hashes if enabling local auth)
INSERT INTO sys.Users (Username, PasswordHash, EmployeeID, RoleID)
VALUES
('alice',0x0,1,1),
('bob',0x0,2,2),
('clara',0x0,3,3);

-- Client
INSERT INTO sales.Clients (ClientName, ContactName, Email, Phone, Address)
VALUES ('Sunrise Estates','Maria Lopez','maria@sunrise.com','+1-555-0100','123 Elm Street');

-- Project
INSERT INTO project.Projects (ProjectCode, ProjectName, ClientID, StartDate, ProjectStatus, Budget, ManagerEmployeeID, Address)
VALUES ('PRJ-001','Sunrise Villas',1, '2026-02-01','Active', 2500000, 2, 'Sunrise Development Site');

-- Phases
INSERT INTO project.ProjectPhases (ProjectID, PhaseName, PhaseOrder, StartDate, Status, Budget)
VALUES (1, 'Design', 1, '2026-02-01', 'Active', 250000),
       (1, 'Construction', 2, '2026-04-01', 'Planned', 2000000);

-- Suppliers & Materials
INSERT INTO procurement.Suppliers (SupplierName, ContactName, Email)
VALUES ('ABC Cement Co.','Jose Ramirez','jose@abccement.com');

INSERT INTO inventory.MaterialCategories (CategoryName) VALUES ('Concrete & Cement');

INSERT INTO inventory.Materials (CategoryID, SKU, MaterialName, Unit, UnitPrice, ReorderLevel)
VALUES (1,'CEM-42','Portland Cement 42.5','Bag',12.50,100);

-- Purchase & Inventory
INSERT INTO inventory.MaterialPurchases (SupplierID, MaterialID, ProjectID, PurchaseDate, Quantity, UnitPrice, InvoiceNumber, ReceivedByEmployeeID)
VALUES (1,1,1,'2026-03-15',500,12.50,'INV-1001',4);

INSERT INTO inventory.Inventory (MaterialID, Location, QuantityOnHand, Unit)
VALUES (1,'Sunrise Site',500,'Bag');

-- Contract & Payment
INSERT INTO contracts.Contracts (ContractNumber, ProjectID, ClientID, ContractType, EffectiveDate, ContractValue, Status)
VALUES ('CNT-001',1,1,'LumpSum','2026-02-01',2500000,'Signed');

INSERT INTO finance.Payments (ContractID, ProjectID, ClientID, PaymentDate, Amount, PaymentMethod, Reference, ReceivedByUserID)
VALUES (1,1,1,'2026-02-15',500000,'Bank Transfer','Downpayment',1);

-- Documents
INSERT INTO sys.Documents (FileName, FilePath, UploadedByUserID) VALUES ('contract_CNT-001.pdf','\\fileserver\\contracts\\CNT-001.pdf',1);
