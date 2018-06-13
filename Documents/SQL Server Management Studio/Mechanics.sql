Use Mechanics

---------- 1. Create Database

CREATE TABLE Clients(
ClientId INT PRIMARY KEY IDENTITY(1,1),
FirstName VARCHAR(50),
LastName VARCHAR(50),
Phone CHAR(12)
)

CREATE TABLE Mechanics(
MechanicId INT PRIMARY KEY IDENTITY(1,1),
FirstName VARCHAR(50),
LastName VARCHAR(50),
Address VARCHAR(255)
)

CREATE TABLE Models(
ModelId INT PRIMARY KEY IDENTITY(1,1),
Name VARCHAR(50) UNIQUE
)

CREATE TABLE Jobs(
JobId INT PRIMARY KEY IDENTITY(1,1),
ModelId INT FOREIGN KEY REFERENCES Models(ModelId),
Status VARCHAR(11) DEFAULT 'Pending' CHECK(Status = 'Pending' OR 
Status = 'Finished' OR Status = 'In Progress'),
ClientId INT FOREIGN KEY REFERENCES Clients(ClientId),
MechanicId INT FOREIGN KEY REFERENCES Mechanics(MechanicId),
IssueDate DATE,
FinishDate DATE
)

CREATE TABLE Orders(
OrderId INT PRIMARY KEY IDENTITY(1,1),
JobId INT FOREIGN KEY REFERENCES Jobs(JobId),
IssueDate DATE,
Delivered BIT DEFAULT 'False'
)

CREATE TABLE Vendors(
	VendorId INT PRIMARY KEY IDENTITY(1,1),
	Name VARCHAR(50) UNIQUE
)

CREATE TABLE Parts(
	PartId INT PRIMARY KEY IDENTITY(1,1),
	SerialNumber VARCHAR(50) UNIQUE,
	Description VARCHAR(255),
	Price DECIMAL(8, 2) CHECK (Price > 0),
	VendorId INT FOREIGN KEY REFERENCES Vendors(VendorId),
	StockQty INT DEFAULT 0 CHECK(StockQty >= 0)
)

CREATE TABLE PartsNeeded(
	PartId INT,
	JobId INT,
	Quantity INT DEFAULT 1 CHECK(Quantity > 0),
	CONSTRAINT PK_PrimaryKey PRIMARY KEY (PartId, JobId),
	CONSTRAINT FK_ForeignKey FOREIGN KEY(PartId) REFERENCES Parts(PartId),
	CONSTRAINT FK_ForeignKey_JobId FOREIGN KEY(JobId) REFERENCES Jobs(JobId)
)

CREATE TABLE OrderParts(
	OrderId INT,
	PartId INT,
	Quantity INT DEFAULT 1 CHECK(Quantity > 0),
	CONSTRAINT PK_PrimaryKey_OrderParts PRIMARY Key(OrderId, PartId),
	CONSTRAINT FK_FKey FOREIGN KEY(OrderId) REFERENCES Orders(OrderId),
	CONSTRAINT FK_ForeignKeyParts FOREIGN KEY(PartId) REFERENCES Parts(PartId)
)

----------- 2. Seed Database

INSERT INTO Clients (FirstName, LastName, Phone)
VALUES 
	   ('Teri', 'Ennaco', '570-889-5187'),
	   ('Merlyn', 'Lawler', '201-588-7810'),
	   ('Georgene', 'Montezuma', '925-615-5185'),
	   ('Jettie', 'Mconnell', '908-802-3564'),
	   ('Lemuel', 'Latzke', '631-748-6479'),
	   ('Melodie', 'Knipp', '805-690-1682'),
	   ('Candida', 'Corbley', '908-275-8357')

INSERT INTO Parts (SerialNumber, Description, Price, VendorId)
VALUES 
		('WP8182119', 'Door Boot Seal', '117.86', 2),
	    ('W10780048', 'Suspension Rod', '42.81', 1),
	    ('W10841140', 'Silicone Adhesive', '6.77', 4),
		('WPY055980', 'High Temperature Adhesive', '13.94', 3)

-----------  3. Select mechanics and their status

SELECT CONCAT(m.FirstName, ' ', m.LastName) AS Mechanic, j.Status, j.IssueDate 
	FROM Mechanics as m
	LEFT JOIN Jobs as j ON
	j.MechanicId = m.MechanicId
	ORDER BY m.MechanicId, j.IssueDate, j.JobId

-----------  4. Select current clients 

SELECT CONCAT(c.FirstName, ' ', c.LastName) as Client, 
DATEDIFF(DAY, j.IssueDate, '2017-04-24') AS [Days Going],
j.Status FROM Clients as c
JOIN Jobs as j ON
j.ClientId = c.ClientId
WHERE j.Status != 'Finished'
ORDER BY [Days Going] DESC, c.ClientId

----------- 5. Find mechanics with the best performance

SELECT CONCAT(m.FirstName, ' ', m.LastName) AS Mechanic,
AVG(DATEDIFF(DAY, j.IssueDate, j.FinishDate)) as [Average Days] FROM Mechanics AS m
JOIN Jobs as j ON
j.MechanicId = m.MechanicId
GROUP BY m.FirstName, m.LastName, m.MechanicId
ORDER BY m.MechanicId

------------- 6. Find mechanics with the highest number of unfinished jobs

SELECT TOP 3 CONCAT(m.FirstName, ' ', m.LastName) AS Mechanic,
COUNT(j.JobId) AS Jobs FROM Mechanics AS m
JOIN Jobs AS j ON
j.MechanicId = m.MechanicId
WHERE j.Status != 'Finished'
GROUP BY m.FirstName, m.LastName, m.MechanicId
HAVING COUNT(j.JobId) > 1
ORDER BY Jobs DESC, m.MechanicId

------------- 7. Find mechanic witout unfinished jobs

SELECT CONCAT(m.FirstName, ' ', m.LastName) AS Available 
FROM Mechanics as m
LEFT JOIN Jobs as j
ON j.MechanicId = m.MechanicId
WHERE m.MechanicId NOT IN
			(SELECT m.MechanicId FROM Mechanics AS m
			LEFT JOIN Jobs as j ON
			j.MechanicId = m.MechanicId
			WHERE j.Status = 'In Progress' OR j.Status = 'Pending')
GROUP BY m.FirstName, m.LastName, m.MechanicId
ORDER BY m.MechanicId

--------------- 8. Find how much the parts for each order cost

SELECT ISNULL(SUM(p.Price * op.Quantity), 0) AS [Parts Total] FROM Parts as p
JOIN OrderParts as op ON
op.PartId = p.PartId
JOIN Orders AS o ON
o.OrderId = op.OrderId
WHERE DATEDIFF(WEEK, o.IssueDate, '2017-04-24') <= 3 

-------------- 9. Find the parts cost for each finished job

SELECT j.JobId, ISNULL(SUM(p.Price * op.Quantity), 0) AS Total FROM Jobs as j
LEFT JOIN Orders AS o ON
o.JobId = j.JobId
LEFT JOIN OrderParts AS op ON
op.OrderId = o.OrderId
LEFT JOIN Parts AS p ON
p.PartId = op.PartId
WHERE j.Status = 'Finished'
GROUP BY j.JobId
ORDER BY Total DESC, j.JobId

--------------- 10. Find how much time it takes to repair each model

SELECT m.ModelId, m.Name, 
CONCAT(AVG(DATEDIFF(DAY, j.IssueDate, ISNULL(j.FinishDate, '2017-04-24'))), ' ', 'days') AS [Average Service Time]
 FROM Models AS m
JOIN Jobs as j ON
j.ModelId = m.ModelId
GROUP BY m.ModelId, m.Name
ORDER BY AVG(DATEDIFF(DAY, j.IssueDate, ISNULL(j.FinishDate, '2017-04-24')))


-------------- 11. Find which model breaks the most often

SELECT TOP 1 m.Name, COUNT(j.JobId) as [Times Serviced],
	(
		SELECT ISNULL(SUM(p.Price * op.Quantity), 0) FROM Parts AS p
		JOIN OrderParts AS op
		ON op.PartId = p.PartId
		JOIN Orders AS o ON
		o.OrderId = op.OrderId
		JOIN Jobs AS j ON
		j.JobId = o.JobId
		WHERE j.ModelId = m.ModelId
	) AS [Total Parts]
FROM Models as m
JOIN Jobs as j ON 
j.ModelId = m.ModelId
GROUP BY m.Name, m.ModelId
ORDER BY [Times Serviced] DESC

----------------- 12. Find which parts are not in stock

SELECT p.PartId, p.Description, SUM(pn.Quantity) AS Required, 
AVG(p.StockQty) as [In Stock],
SUM(ISNULL(op.Quantity, 0)) AS Ordered 
FROM Parts as p
JOIN PartsNeeded AS pn
ON pn.PartId = p.PartId
JOIN Jobs AS j ON
j.JobId = pn.JobId
LEFT JOIN Orders AS o ON
o.JobId = j.JobId
LEFT JOIN OrderParts AS op ON
op.OrderId = o.OrderId
WHERE j.Status <> 'Finished'
GROUP BY p.PartId, p.Description
HAVING SUM(pn.Quantity) > AVG(p.StockQty) + ISNULL(SUM(op.Quantity), 0)
ORDER BY PartId

------------ 13. Find how much a job costs by Id

CREATE FUNCTION udf_GetCost(@JobId INT)
RETURNS DECIMAL(18, 2)
AS
BEGIN
DECLARE @TotalSum DECIMAL(18,2) =   (SELECT SUM(p.Price)
													FROM Parts as p
													JOIN OrderParts AS op ON 
													op.PartId = p.PartId
													JOIN Orders as o ON 
													o.OrderId = op.OrderId
													JOIN Jobs as j ON
													j.JobId = o.JobId
													WHERE j.JobId = @JobId
													GROUP BY j.JobId)
													RETURN ISNULL(@TotalSum, 0)
													END

-------------- 14. Place an order

CREATE PROCEDURE usp_PlaceOrder(@JobId INT, @SerialNum VARCHAR(50), @Quantity INT)
AS
DECLARE @JobStatus VARCHAR(11) = (SELECT j.Status FROM Jobs as j 
										WHERE j.JobId = @JobId)
DECLARE @rowCount INT = 
					(SELECT @@ROWCOUNT FROM Jobs as j 
										WHERE j.JobId = @JobId GROUP BY j.JobId)
DECLARE @partCount INT =
					(SELECT @@RowCount FROM Parts as p 
									    WHERE p.SerialNumber = @SerialNum GROUP BY p.PartId)
DECLARE @PartId INT = (Select PartId FROM Parts WHERE SerialNumber = @SerialNum)

BEGIN TRANSACTION

IF(@Quantity <= 0)
	BEGIN 
		RAISERROR('Part quantity must be more than zero!', 16, 1)
		RETURN
	END

IF(@rowCount = 0)
	BEGIN 
		RAISERROR('Job not found!', 16, 1)
		RETURN
	END


IF(@JobStatus = 'Finished')
	BEGIN
		RAISERROR('This job is not active!', 16, 1)
		RETURN
	END

IF(@partCount = 0)
	BEGIN
		RAISERROR('Part not found', 16, 1)
		RETURN
	END

DECLARE @OrderId INT = (SELECT OrderId FROM Orders WHERE JobId = @JobId AND IssueDate IS NULL)

IF (@OrderId IS NULL) 
	BEGIN 
		INSERT INTO Orders(JobId, IssueDate) VALUES
		(@JobId, NULL)
		Insert INTO OrderParts(OrderId, PartId, Quantity) VALUES
		(IDENT_CURRENT('Orders'), @PartId, @Quantity)
	END

ELSE
BEGIN
IF((SELECT @@ROWCOUNT FROM OrderParts 
			WHERE OrderId = @OrderId AND PartId = @PartId) = 0)
	BEGIN 
		UPDATE OrderParts
		SET Quantity += @Quantity
		WHERE OrderId = @OrderId AND PartId = @PartId
	END

ELSE

BEGIN
INSERT INTO OrderParts(OrderId, PartId, Quantity) VALUES
		(@OrderId, @PartId, @Quantity)
END

END

COMMIT

---------------- 15. Check status after order update

CREATE TRIGGER tr_DetectDelivery ON Orders AFTER UPDATE
AS
	DECLARE @OldStatus INT = (SELECT Delivered FROM deleted)
	DECLARE @NewStatus INT = (SELECT Delivered FROM inserted)
		BEGIN
			IF(@OldStatus = 0 AND @NewStatus = 1)
			BEGIN
				UPDATE Parts
				SET StockQty += op.Quantity FROM Parts AS p
				JOIN OrderParts as op
				ON op.PartId = p.PartId
				JOIN inserted AS i ON
				i.OrderId = op.OrderId
			END
	END

---------------- 16. Find the most popular vendor

SELECT Mechanic, Vendor, Quantity, CONCAT(CAST(Quantity * 100 / TotalParts AS INT), '%') as Preference
FROM	
	(
			SELECT m.MechanicId as Id, CONCAT(m.FirstName, ' ', m.LastName) as Mechanic,
			 v.Name as Vendor,
			SUM(op.Quantity) as Quantity from Mechanics as m
			JOIN Jobs as j ON
			j.MechanicId = m.MechanicId
			JOIN Orders as o ON
			o.JobId = j.JobId
			JOIN OrderParts as op ON
			op.OrderId = o.OrderId
			JOIN Parts as p ON
			p.PartId = op.PartId
			JOIN Vendors as v ON
			v.VendorId = p.VendorId
			GROUP BY m.MechanicId, m.FirstName, m.LastName, v.Name
			) VendorInfo 
			JOIN (
				SELECT m.MechanicId as Id, SUM(op.Quantity) as TotalParts FROM Mechanics as m
				JOIN Jobs as j ON 
				j.MechanicId = m.MechanicId
				JOIN Orders as o ON
				o.JobId = j.JobId
				JOIN OrderParts as op oN
				op.OrderId = o.OrderId
				JOIN Parts as p ON
				p.PartId = op.PartId
				GROUP BY m.MechanicId
		) TotalPartInfo 
ON TotalPartInfo.Id = VendorInfo.Id
ORDER BY Mechanic, Quantity DESC, Vendor
