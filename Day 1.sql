--Class 1--
-- A Intro to Databases / DBMS

Create Database lab_6020;

Create table Products(
pname varchar(20),
price decimal(5,2),
category varchar(20),
manufacturer varchar (40)
);

--Next-- 

select * from Products;

insert into Products 
values("IPhone 13","299.99","Cellphone","Apple");

--Next--

insert into Products 
values("IPhone 17 Pro","1299.99","Cellphone","Apple");

--didnt work? why? --
--because we only have 5 types for price--

ALTER TABLE Products 
MODIFY COLUMN price DECIMAL(7,2);

--Next--

insert into Products 
values("IPhone 17 Pro","1299.99","Cellphone","Apple");

--Now how do we drop a table?--

Drop table Products

--Next--

insert into Products 
values("IPhone 17 Pro","Cellphone","Apple");

--What do we do when we dont know something?--

insert into Products(pname,manufacturer,catagory)
values("IPhone 11","Apple","Cellphone");

--We add pname and manufacturer as primary keys here--

ALTER TABLE Products 
ADD PRIMARY KEY (pname, manufacturer);

--Next--
--SELECT FROM WHERE--

--Lets Use New Data--

Truncate Table Products

INSERT INTO Products VALUES ('Gizmo', 19.99, 'Gadgets', 'GizmoWorks');
INSERT INTO Products VALUES ('Powergizmo', 29.99, 'Gadgets', 'GizmoWorks');
INSERT INTO Products VALUES ('SingleTouch', 149.99, 'Photography', 'Canon');
INSERT INTO Products VALUES ('MultiTouch', 203.99, 'Household', 'Hitachi');

--Next we Query--

SELECT pname, manufacturer, price FROM Products 
WHERE category = 'Gadgets';

--Next Query--

SELECT pname, manufacturer FROM Products 
WHERE category = 'Gadgets';

--Next 

create table student(
`Student name` varchar(20)
);

--Query--
select `Student name` from student







