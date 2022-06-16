-- this is a sql project for my own database, where I put data on the apartment rental market of the wider center of Prague from a popular for rent by owner site

-- just a quick querry to see, how things got imported
select * from SQLProject.dbo.values$


-- right after first querry, I decided to change (update) values, which are in Czech into English.
-- translate (update) the balcony values into english
update SQLProject.dbo.values$ set balcony = 'Yes' where balcony='Ano'
update SQLProject.dbo.values$ set balcony = 'No' where balcony='Ne'

-- translate (update) the terrace values into english
update SQLProject.dbo.values$ set terrace = 'No' where terrace='Ne'
update SQLProject.dbo.values$ set terrace = 'Yes' where terrace='Ano'

-- translate (update) the newbuilt values into english
update SQLProject.dbo.values$ set newbuilt = 'No' where newbuilt='Ne'
update SQLProject.dbo.values$ set newbuilt = 'Yes' where newbuilt='Ano'

-- translate (update) the elevator values into english
update SQLProject.dbo.values$ set elevator = 'No' where elevator='Ne'
update SQLProject.dbo.values$ set elevator = 'Yes' where elevator='Ano'

-- translate (update) the furnished values into english
update SQLProject.dbo.values$ set furnished = 'Partially' where furnished='Èásteènì'
update SQLProject.dbo.values$ set furnished = 'Yes' where furnished='Ano'
update SQLProject.dbo.values$ set furnished = 'No' where furnished='Ne'

-- translate (update) the side_note values into english
update SQLProject.dbo.values$ set side_note = 'No attic' where side_note='první až pøedposlední podlaží'
update SQLProject.dbo.values$ set side_note = 'Ground floor' where side_note='pøízemí'
update SQLProject.dbo.values$ set side_note = 'Attic' where side_note='podkroví'
update SQLProject.dbo.values$ set side_note = 'Elevated ground floor' where side_note='vyvýšené pøízemí'
update SQLProject.dbo.values$ set side_note = 'Last floor' where side_note='poslední podlaží'

update SQLProject.dbo.values$ set district = 'Staré mìsto' where district='Josefov'
update SQLProject.dbo.values$ set district = 'Nusle' where district='Vyšehrad'

-- also I have noticed, that the table contains few rows with district = "#VALUE!". Let´s delete those rows
delete from SQLProject.dbo.values$ where district = '#VALUE!'

/* clients, who are interested to buy one or a package of rental properties are interested in many aspect of the market and I use my database to answer these questions.
One of the basic questions is, what is the composition of the types of apartment on the market, when it comes to their layout. 
To answer that question, here comes a querry. 
I am taking the count of individual apartment layout types shown as a percentage share of all the rows (listings) in the table
*/
select layout, round(cast(count(layout) as float)*100/(select cast(count(*) as float) from SQLProject.dbo.values$) ,2) as percentage_share 
from SQLProject.dbo.values$ 
group by layout
order by layout


/* sometimes clients ask, what has been the average rent per sq. meter per month in the wider center of Prague in general.
The problem here is that the rent isn´t the same as the market fluctuates over time. I decided to make a moving average with a peroid of 100.
Also, I will be taking the average only from rows, where the listing is no longer life (off_line not null) and where the advertising time was less than 30 days,
because by some calculations done outside of this projects earlier, the median advertising time is around just that, and I don´t want to include unsuccessful offfers.
*/
select off_line, live_time, avg(rent / floor_area) over (order by off_line ROWS BETWEEN 100 PRECEDING AND CURRENT ROW ) as moving_averagerent_per_meter
from SQLProject.dbo.values$
where off_line is not null and live_time < 30

-- similarly to querry above, I will do the same moving average. This time, however, I will do the moving average for individual districts withing the observed area.
select off_line, live_time, district, avg(rent / floor_area) over (PARTITION BY district order by off_line ROWS BETWEEN 100 PRECEDING AND CURRENT ROW ) as moving_average
from SQLProject.dbo.values$
where off_line is not null and live_time < 30


/* one of very helpful insights is to see, what is the current balance between supply and demand, to time the investment better and so on.
for these purposes, I will create two tables 1) supply table, where I will select the supply of listing in the whole observed area per each month
											2) demand table, where I will select the amount of listing per each month, which were taken down in those months
then I will make inner join of these two tables, so I can compare for each month how much was the supply and demand difference
*/
-- supply tabe
drop table if exists SQLProject.dbo.supply
create table SQLProject.dbo.supply (month_no int, year_no int, supply_amount int) 

-- insert into supply table - the amount of listing is calculated by counting rows of published listing for each month in every year available
insert into SQLProject.dbo.supply
select distinct month(published) as month_published, year(published) as year_published, count(published) over (PARTITION BY month(published), year(published)) as supply
from SQLProject.dbo.values$
order by year_published, month_published

-- demand table
drop table if exists SQLProject.dbo.demand
create table SQLProject.dbo.demand (month_no int,year_no int,demand_amount int) 

-- insert into demand table - the amount of listing is calculated by counting rows of listings, which were found no longer available for each month in every year available
insert into SQLProject.dbo.demand
select distinct month(off_line) as month_off_line, year(off_line) as year_off_line, count(off_line) over ( PARTITION BY month(off_line), year(off_line)) as demand
from SQLProject.dbo.values$
where off_line is not null
order by year_off_line, month_off_line 

-- join of supply and demand, so the comparison can be seen
select concat(SQLProject.dbo.supply.month_no,'.', SQLProject.dbo.supply.year_no) as month, SQLProject.dbo.supply.supply_amount, SQLProject.dbo.demand.demand_amount
from SQLProject.dbo.supply inner join SQLProject.dbo.demand
on	SQLProject.dbo.supply.month_no = SQLProject.dbo.demand.month_no and SQLProject.dbo.supply.year_no = SQLProject.dbo.demand.year_no
order by SQLProject.dbo.supply.year_no, SQLProject.dbo.supply.month_no

-- average rent per square meter of the whole observed area for each month
select datefromparts(y,m,1), a from
	(select top 12 y,m, a from
		(select year(off_line) as y, month(off_line) as m, round(avg(rent / floor_area),0) as a
		from SQLProject.dbo.values$ db_values
		group by year(off_line), month(off_line)) avg_rent 
	where y is not null and m is not null
order by y desc,m desc ) res order by datefromparts(y,m,1)

-- create table with longitude and latitude for selected districts
drop table if exists SQLProject.dbo.position
create table SQLProject.dbo.position (district nvarchar(255), lat float, lon float)

insert into SQLProject.dbo.position (district, lat, lon) values 
	('Holešovice', 50.102535, 14.440558),
	('Karlín', 50.092748, 14.452123),
	('Malá Strana', 50.086992, 14.404281),
	('Nové Mìsto', 50.078994, 14.423653),
	('Nusle', 50.058259, 14.437786),
	('Smíchov', 50.071319, 14.406027),
	('Staré Mìsto', 50.087539, 14.419768),
	('Vinohrady', 50.075163, 14.447463),
	('Vršovice', 50.067248, 14.458034),
	('Žižkov', 50.085814, 14.461004)

select * from SQLProject.dbo.position

-- avg rent per meter from the asking price per district for last full 3 months joined with latitudes and longitudes of districts for purposes of tableau visualization
select t1.district, t1.avg_r_m, pos.lat, pos.lon from
(select district, round(avg(r_m),0) as avg_r_m from
	(select datefromparts(year(published), month(published),1) as d, district, (rent / floor_area) as r_m
	from SQLProject.dbo.values$ db_values
	where	published < datefromparts(year((select top 1 published from SQLProject.dbo.values$ order by published desc)),month((select top 1 published from SQLProject.dbo.values$ order by published desc)),1) 
		and published >= dateadd(month, -3, datefromparts(year((select top 1 published from SQLProject.dbo.values$ order by published desc)),month((select top 1 published from SQLProject.dbo.values$ order by published desc)),1))
		and district not in ('Bubeneè','Libeò', 'Michle','Podolí')
	) l3m
group by district) t1 join SQLProject.dbo.position pos on pos.district = t1.district



