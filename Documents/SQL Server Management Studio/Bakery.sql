Use Bakery
------------ 1. Create Database

Create Table Countries(
	Id INT Primary Key Identity,
	Name NVarChar(50) Unique
)

CREATE TABLE Customers (
	Id INT PRIMARY KEY IDENTITY,
	FirstName NVARCHAR(25),
	LastName NVARCHAR(25),
	Gender CHAR(1) CHECK(Gender = 'M' OR Gender = 'F'),
	Age INT Check (Age >= 0),
	PhoneNumber CHAR(10),
	CountryId INT Foreign Key References Countries(Id)
)

Create Table Products(
	Id INT primary Key Identity(1,1),
	Name NVarchar(25) Unique,
	Description NVarchar(250),
	Recipe NVarchar(max),
	Price MONEY CHEck (Price >= 0)
)
Create Table Feedbacks(
	Id INT Primary Key Identity(1,1),
	Description NVarchar(255),
	Rate Decimal(2,2) CHECK (Rate BETWEEN 0 AND 10),
	ProductId INT Foreign Key References Products(Id),
	CustomerId INT Foreign Key References Customers(Id)
)


Create Table Distributors(
	Id INt Primary Key Identity(1,1),
	Name NVarchar(25) UNIQUE,
	AddressText NVarChar(30),
	Summary NvarChar(200),
	CountryId INT Foreign Key References Countries(Id)
)

Create Table Ingredients(
	Id INt Primary Key Identity(1,1),
	Name NVarchar(30),
	Description NVarchar(200),
	OriginCountryId INT Foreign Key References Countries(Id),
	DistributorId Int Foreign Key References Distributors(Id)
)


Create Table ProductsIngredients(
	ProductId INT Foreign Key References Products(Id),
	IngredientId Int Foreign Key References Ingredients(Id) 
	Constraint PK_PrimaryKey Primary KEy(ProductId, IngredientId)
)

---------- 2. Seed database

INSERT INTO Distributors(Name, CountryId, AddressText, Summary) VALUES
	('Deloitte & Touche',2,'6 Arch St #9757','Customizable neutral traveling'),
	('Congress Title',13,'58 Hancock St','Customer loyalty'),
	('Kitchen People',1,'3 E 31st St #77','Triple-buffered stable delivery'),
	('General Color Co Inc',21,'6185 Bohn St #72','Focus group'),
	('Beck Corporation',23,'21 E 64th Ave','Quality-focused 4th generation hardware')

INSERT INTO Customers(FirstName, LastName, Age, Gender, PhoneNumber, CountryId) VALUES
	('Francoise','Rautenstrauch',15,'M','0195698399',5),
	('Kendra','Loud',22,'F','0063631526',11),
	('Lourdes','Bauswell',50,'M','0139037043',8),
	('Hannah','Edmison',18,'F','0043343686',1),
	('Tom','Loeza',31,'M','0144876096',23),
	('Queenie','Kramarczyk',30,'F','0064215793',29),
	('Hiu','Portaro',25,'M','0068277755',16),
	('Josefa','Opitz',43,'F','0197887645',17)

------------ 3. Find Top 10 rated products

Select TOP 10 p.Name, p.Description, 
AVG(f.Rate) as AverageRate, 
COUNT(f.Rate) as FeedbacksAmount FROM Products as p
JOIN Feedbacks as f ON
f.ProductId = p.Id
Group by p.Name, p.Description
Order by AverageRate DESC, FeedbacksAmount DESC

------------- 4. Select low rated products

SELECT f.ProductId, f.Rate, f.Description, f.CustomerId, c.Age, c.Gender FROM Feedbacks as f
JOIN Customers as c on 
f.CustomerId = c.Id
WHERE f.Rate < 5
Order by ProductId DESC, Rate

------------- 5. Find customers who haven't provided feedback

SELECT CONCAT(FirstName, ' ', LastName) as CustomerName, PhoneNumber, Gender FROM Customers 
WHERE Id NOT IN(
SELECT CustomerID FROM Feedbacks
)
ORDER BY Customers.Id

--------------- 6. Find customers who have given feedback more than 3 times

SELECT f.ProductId, CONCAT(c.FirstName, ' ', c.LastName) as CustomerName, 
f.Description from Feedbacks as f
JOIN Customers as c ON
c.Id = f.CustomerID
WHERE c.Id IN (
	SELECT CustomerId FROM Feedbacks
	GROUP BY CustomerId
	HAVING COUNT(CustomerId) >= 3
)
Order by f.ProductId, CustomerName, f.Id

--------------- 7. Find customers by specific criteria

SELECT c.FirstName, c.Age, c.PhoneNumber FROM Customers as c
JOIN Countries as con ON
c.CountryId = con.Id
Where (Age >= 21 AND c.FirstName LIKE '%an%') 
OR(RIGHT(c.PhoneNumber, 2) = 38 AND con.Name != 'Greece')
Order by c.FirstName, c.Age DESC

--------------- 8. Find products with average feedback rate between 5 and 8

Select d.Name as DistributorName, i.Name as IngredientName, p.Name as ProductName,
AVG(f.Rate) as AverageRate FROM Ingredients as i
Join ProductsIngredients as pn ON
pn.IngredientId = i.Id
JOIN Distributors as d ON
d.Id = i.DistributorId
JOIn Feedbacks as f ON
f.ProductId = pn.ProductId
JOIN Products as p ON
p.Id = pn.ProductId
GROUp BY d.Name, i.Name, p.Name
HAVING Avg(f.Rate) Between 5 and 8
Order By DistributorName, IngredientName, ProductName

---------------- 9. Find which country has given the most positive feedback

SELECT CountryName, FeedbackRate FROM
	(
		SELECT con.Name as CountryName, Avg(f.Rate) as FeedbackRate, 
		Dense_Rank() Over(Order BY AVG(f.Rate) DESC) as rank
		From Feedbacks as f
		Join Customers as c ON 
		c.Id = f.CustomerId
		JOIN Countries as con ON
		con.Id = c.CountryId
		GROUP BY con.Name
	) rnk
Where rank = 1

----------------- 10. Find the most common distributor for each country

Select CountryName, DistributorName FROM
	(
		SELECT c.Name as CountryName, d.Name as DistributorName,
		DENSE_RANK() OVER(Partition BY c.Name ORDER BY COUNT(i.Id) DESC) as rank
		FROM Distributors as d
		JOIN Countries as c ON
		c.Id = d.CountryId
		JOIN Ingredients as i ON
		i.DistributorId = d.Id
		GROUP BY c.Name, d.Name
	) d
WHERE rank = 1
Order by CountryName, DistributorName

------------------ 11. Return feedback by product name

Create Function udf_GetRating(@ProductName Varchar(50))
RETURNS VARCHAR(12)
AS
BEGIN
DECLARE @ProductId INT = (SELECT p.Id from Products as p 
							WHERE p.Name = @ProductName)
DECLARE @Rating DECIMAL(10, 2) = 
	(SELECT AVG(f.Rate) from Feedbacks as f 
			Where f.ProductId = @ProductId)
DECLARE @Result VARCHAR(12)

		IF (@Rating IS NULL)
		SET @Result = 'No rating'
		IF(@Rating BETWEEN 0 AND 5 )
		SET @Result = 'Poor'
		IF(@Rating BETWEEN 5 AND 8)
		SET @Result = 'Average'
		IF(@Rating Between 8 and 10)
		SET @Result = 'Good'
		REturn @Result;
END

--------------- 12. Send feedback procedure

CREATE PROCEDURE usp_SendFeedback (
@customerId INT, @productId INT, @rate DECIMAL(10, 2), @description VARCHAR(255))
AS
BEGIN
	BEGIN TRANSACTION
	Insert INTO Feedbacks(Description, Rate, ProductId, CustomerId) VALUES
		(@description, @rate, @productId, @customerId)

	IF((Select COUNT(*) FROM Feedbacks Where CustomerId = @customerId) > 3)
		BEGIN
			RAISERROR('You are limited to only 3 feedbacks per product!', 16, 1)
			ROLLBACK
			RETURN
		END
COMMIT

END

------------------- 13. Delete products from database

CREATE TRIGGER tr_DeleteProducts ON Products Instead of DELETE
AS
	DECLARE @ProductID INT = (SELECT Id from deleted) 
	BEGIN 
		DELETE FROM ProductsIngredients
		WHERE ProductId = @ProductID

		DELETE FROM Feedbacks
		WHERE ProductId = @ProductID

		Delete from Products 
		WHERE Id = @ProductID

	END

------------------- 14. Find products by one distributor

SELECT p.Name as ProductName, AVG(f.Rate) as ProductAverageRate,
d.Name as DistributorName, 
c.Name as DistributorCountry FROM Products as p 
	LEFT JOIN ProductsIngredients as pn ON
	pn.ProductId = p.Id
	LEFT JOIN Ingredients as i ON 
	i.Id = pn.IngredientId
	LEFT JOIN Distributors as d ON
	d.Id = i.DistributorId 
	LEFT JOIN Countries as c ON 
	c.Id = d.CountryId
	LEFT JOIN Feedbacks as f
	ON f.ProductId = p.Id
WHERE p.Id IN(

				SELECT p.Id FROM Products as p
				JOIN ProductsIngredients as pn ON
				pn.ProductId = p.Id
				LEFT JOIN Ingredients as i ON 
				i.Id = pn.IngredientId
				LEFT JOIN Distributors as d ON
				d.Id = i.DistributorId 
				GROUP BY p.Id
				HAVING COUNT(distinct d.Id) = 1
)
GROUP BY p.Name, p.Id, d.Name, c.Name
ORDER BY p.Id 


