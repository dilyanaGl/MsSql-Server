Use Airlines

-------- 1. Create database

CREATE TABLE Flights(
	FlightId INT PRIMARY KEY NOT NULL,
	DepartureTime DATETIME NOT NULL,
	ArrivalTime DATETIME NOT NULL,
	Status VARCHAR(9), 
	OriginAirportId INT FOREIGN KEY REFERENCES Airports(AirportId),
	DestinationAirportId INT FOREIGN KEY REFERENCES Airports(AirportId),
	AirlineId INT FOREIGN KEY REFERENCES Airlines(AirlineId),
	CONSTRAINT CK_CheckStatus CHECK ([Status] = 'Departing' OR [Status] = 'Delayed' 
	OR [Status] = 'Arrived' OR [Status] = 'Cancelled')
)

CREATE TABLE Tickets(
	TicketId INT Primary KEY NOT NULL,
	Price DECIMAL(8, 2) NOT NULL,
	Class VARCHAR(6),
	Seat VARCHAR(5) NOT NULL,
	CustomerId INT Foreign KEY REFERENCES Customers(CustomerId),
	FlightId INT FOREIGN KEY REFERENCES Flights(FlightId),
	CONSTRAINT CK_CheckClass CHECK (Class = 'First' OR Class = 'Second' OR Class = 'Third')
)

---------- 2. Seed Database

INSERT INTO Flights(FlightId, DepartureTime, ArrivalTime, Status, OriginAirportId, DestinationAirportId, AirlineId) VALUES
	(1, '2016-10-13 06:00 AM', '2016-10-13 10:00 AM', 'Delayed', 1, 4, 1),
	(2, '2016-10-12 12:00 PM', '2016-10-12 12:01 PM', 'Departing', 1, 3, 2 ),
	(3, '2016-10-14 03:00 PM', '2016-10-20 04:00 AM', 'Delayed', 4, 2, 4),
	(4, '2016-10-12 01:24 PM', '2016-10-12 4:31 PM', 'Departing', 3, 1, 3),
	(5, '2016-10-12 08:11 AM', '2016-10-12 11:22 PM', 'Departing', 4, 1, 1),
	(6, '1995-06-21 12:30 PM', '1995-06-22 08:30 PM', 'Arrived', 2, 3, 5),
	(7, '2016-10-12 11:34 PM', '2016-10-13 03:00 AM', 'Departing', 2, 4, 2), 
	(8, '2016-11-11 01:00 PM', '2016-11-12 10:00 PM', 'Delayed', 4, 3, 1),
	(9, '2015-10-01 12:00 PM', '2015-12-01 01:00 AM', 'Arrived', 1, 2, 1),
	(10, '2016-10-12 07:30 PM', '2016-10-13 12:30 PM', 'Departing', 2, 1, 7)

INSERT INTO Tickets(TicketId, Price, Class, Seat, CustomerId, FlightId) VALUES
	(1, 3000.00, 'First', '233-A', 3, 8),
	(2, 1799.90, 'Second', '123-D', 1, 1),
	(3, 1200.50, 'Second', '12-Z', 2, 5),
	(4, 410.68, 'Third', '45-Q', 2, 8), 
	(5, 560.00, 'Third', '201-R', 4, 6),
	(6, 2100.00, 'Second', '13-T', 1, 9),
	(7, 5500.00, 'First', '98-O', 2, 7)

----------- 3. Extract delayed flights

SELECT FlightId, DepartureTime, ArrivalTime FROM Flights 
WHERE Status = 'Delayed'
ORDER BY FlightId

------------ 4. Find top 5 airports with the most flights

SELECT TOP 5 AirlineId, AirlineName, Nationality, Rating FROM Airlines
WHERE AirlineID IN (SELECT AirlineId FROM Flights GROUP BY AirlineId HAVING COUNT(FlightId) > 0)
ORDER BY Rating DESC, AirlineId 

------------ 5. Find customers who flight from home

SELECT c.CustomerId, CONCAT(c.FirstName, ' ', c.LastName) as FullName,
 town.TownName As HomeTown
 FROM Customers as c
JOIN Tickets as t ON
c.CustomerId = t.CustomerId
JOIN Flights as f on
f.FlightId = t.FlightId
JOIN Airports as a ON
a.AirportId = f.OriginAirportId
JOIN Towns as town ON
town.TownId = a.TownId
WHERE town.TownId = c.HomeTownId
GROUP BY c.CustomerId, c.FirstName, c.LastName, town.TownName
ORDER BY c.CustomerId

------------- 6. Extract customers who are about to depart

Select c.CustomerId, CONCAT(c.FirstName, ' ', c.LastName) as FullName, 
DATEDIFF(YEAR, c.DateOfBirth, '20160101') AS Age
FROM Customers as c
JOIN Tickets AS t ON 
t.CustomerId = c.CustomerId
JOIN Flights as f ON
f.FlightId = t.FlightId
WHERE f.Status = 'Departing'
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.DateOfBirth
ORDER BY Age, CustomerId

------------ 7. Extract customers whose flights have been delayed

SELECT TOP 3 c.CustomerId, 
CONCAT(c.FirstName, ' ', c.LastName) as FullName,
 t.Price as TicketPrice, a.AirportName as Destination 
 FROM Flights as f
JOIN Tickets as t ON
f.FlightId = t.FlightId
JOIN Customers as c ON 
c.CustomerId = t.CustomerId
JOIN Airports as a ON
a.AirportId = f.DestinationAirportId
WHERE f.Status = 'Delayed'
ORDER BY TicketPrice DESC, c.CustomerId

----------- 8. Find the lastest 5 flights to depart

WITH CTE_Export_Flights
(FlightId, DepartureTime, ArrivalTime, Origin, Destination)
AS
	(
		SELECT TOP 5 f.FlightId as FlightId, f.DepartureTime as DepartureTime, f.ArrivalTime as ArrivalTime,
		 o.AirportName as Origin,
		 a.AirportName as Destination
		FROM Flights as f
		JOIN Airports as a ON
		a.AirportID = f.DestinationAirportId
		JOIN Airports as o ON
		o.AirportID = f.OriginAirportId
		WHERE f.Status = 'Departing'
		ORDER BY f.DepartureTime DESC
	)

SELECT * FROM CTE_Export_Flights
ORDER By DepartureTime, FlightId

----------- 9. Find customers under 21 

SELECT c.CustomerId, CONCAT(c.FirstName, ' ', c.LastName) as FullName,
DATEDIFF(YEAR, c.DateOfBirth, '20160101') as Age
FROM Customers as c
JOIN Tickets as t ON
t.CustomerId = c.CustomerId
JOIN Flights AS f ON
f.FlightId = t.FlightId
WHERE DATEDIFF(YEAR, c.DateOfBirth, '20160101') < 21 AND f.Status = 'Arrived'
GROUP BY c.CustomerId, c.LastName, c.FirstName, c.DateOfBirth
Order BY Age DESC, CustomerId

---------- 10. Find passenger count for departing flights

SELECT a.AirportId, a.AirportName, COUNT(*) as Passengers FROM Airports as a
JOIN Flights as f ON
f.OriginAirportId = a.AirportID
JOIN Tickets as t ON 
t.FlightId = f.FlightId
WHERE f.Status = 'Departing' 
AND  f.FlightId IN 
	(
		SELECT t.FlightId FROM Tickets as t
		GROUP BY FlightId
	)
GROUP BY a.AirportID, a.AirportName

---------- 11. Purchase a ticket

CREATE PROCEDURE usp_PurchaseTicket
(@CustomerId INT, @FlightId INT, @TicketPrice DECIMAL(19, 2), @Class VARCHAR(6), @Seat VARCHAR(5))
AS
	Begin
	DECLARE @CustomerBalance DECIMAL(19, 2) = (SELECT Balance FROM CustomerBankAccounts 
														WHERE CustomerID = @CustomerId)
		BEGIN TRANSACTION
		IF(@CustomerBalance < @TicketPrice OR @CustomerBalance IS NULL)
			BEGIN
				RAISERROR('Insufficient bank account balance for ticket purchase.',16 ,1)
				ROLLBACK
			END
		ELSE
			BEGIN
					INSERT INTO Tickets(TicketId, FlightId, Price, CustomerId, Class, Seat) VALUES
						(51, @FlightId, @TicketPrice, @CustomerId, @Class, @Seat)

					UPDATE CustomerBankAccounts
					SET Balance -= @TicketPrice
					WHERE CustomerID = @CustomerId

				COMMIT
			END
	END






