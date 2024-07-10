use new;
-- checking the tables 
select count(*) from work                         -- 14776
select count(*) from artist                       -- 421
select count(*) from canvas_size                  -- 200
select count(*) from image_link                   -- 14,775
select count(*) from museum                       -- 57
select count(*) from museum_hours                 -- 351
select count(*) from product_size                 -- 110,347
select count(*) from subject                      -- 6771

-- 1) Fetch all the paintings which are not displayed on any museaums?

select name from work where museum_id is null;
select count(*)  from work where museum_id is null      -- total 10223 paintings are not displayed in museum


-- 2) Are there museuems without any paintings?
select * from museum m                                                   -- outer query 
where not exists (select 1 from work w where w.museum_id=m.museum_id)    -- inner query    there is no such museum


-- 3) How many paintings have an asking price of more than their regular price? 
select * from product_size 
where sale_price > regular_price;      -- there is no match in such condition 

-- How many paintings have an asking price of less than their regular price? 

select * from product_size 
where sale_price < regular_price; 

select count(*) from product_size where sale_price < regular_price      -- 102807


-- 4) Identify the paintings whose asking price is less than 50% of its regular price
select * 
from product_size
where sale_price < (regular_price*0.5);

select count(*) from product_size where sale_price < (regular_price*0.5);   -- 58 paintings


-- 5) Which canvas size costs the most?
	select cs.label as canva, ps.sale_price
	from (select *
		  , rank() over(order by sale_price desc) as rnk 
		  from product_size) ps
	join canvas_size cs on cs.size_id=ps.size_id
	where ps.rnk=1;

-- alternative query
select label from canvas_size where size_id=(
select size_id from product_size where sale_price=(select max(sale_price) from product_size))       -- '48\" x 96\"(122 cm x 244 cm)'


-- 6) Delete duplicate records from work, product_size, subject and image_link tables
-- remove duplicate from work table
WITH ct AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY work_id,artist_id ORDER BY work_id) AS rn
    FROM work
)
select work_id,name,artist_id,style from ct where rn<=1

-- remove duplicate from image table
WITH im AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY work_id ORDER BY work_id) AS rn
    FROM image_link
)
select work_id,url,thumbnail_small_url,thumbnail_large_url from im where rn<=1
  
-- remove duplicate from prooduct_size table
WITH pr AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY work_id,size_id ORDER BY work_id) AS rn
    FROM product_size
)
select work_id,size_id,sale_price,regular_price from pr where rn<=1


-- remove duplicate from subject table


WITH sub AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY work_id ORDER BY work_id) AS rn
    FROM subject
)
select work_id,subject from sub where rn<=1

-- 7) Identify the museums with invalid city information in the given dataset
select * from museum 
where city regexp '^[0-9]'    -- city that has only numeric value are not valid


-- 8) Museum_Hours table has 1 invalid entry. Identify it and remove it.

select * from museum_hours where (museum_id,day) in
(select museum_id,day
from museum_hours
group by museum_id,day
having count(*)>1)                     -- identify duplicates in museum_hours         

-- remove the invalid
WITH mm AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY museum_id,day) AS rn
    FROM museum_hours
)
select museum_id,day,open,close from mm where rn<=1




-- 9) Fetch the top 10 most famous painting subject
	select * 
	from (
		select s.subject,count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as ranking
		from work w
		join subject s on s.work_id=w.work_id
		group by s.subject ) x
	where ranking <= 10;
    
-- alternative
select subject ,count(*) as count  from subject group by subject order by count desc


-- 10) Identify the museums which are open on both Sunday and Monday. Display museum name, city.

with tm as(
select mh.museum_id,m.name,mh.day
from museum m

join museum_hours mh on m.museum_id=mh.museum_id
where mh.day in('Sunday','Monday')  
)

select museum_id,name from(
select *,
row_number() over(partition by museum_id,name order by day) as rn
from tm) m
where rn>1                                     -- shows the museum that opens both day


-- 11) How many museums are open every single day?
	select count(1)
	from (select museum_id, count(1)
		  from museum_hours
		  group by museum_id
		  having count(1) = 7) x;  -- there are 18 museums

-- 12) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
	select m.name as museum, m.city,m.country,x.no_of_painintgs
	from (	select m.museum_id, count(1) as no_of_painintgs
			, rank() over(order by count(1) desc) as rnk
			from work w
			join museum m on m.museum_id=w.museum_id
			group by m.museum_id) x
	join museum m on m.museum_id=x.museum_id
	where x.rnk<=5;

-- 13) Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)
	select a.full_name as artist, a.nationality,x.no_of_painintgs
	from (	select a.artist_id, count(1) as no_of_painintgs
			, rank() over(order by count(1) desc) as rnk
			from work w
			join artist a on a.artist_id=w.artist_id
			group by a.artist_id) x
	join artist a on a.artist_id=x.artist_id
	where x.rnk<=5;

-- 14) Display the 3 least popular canva sizes
	select label,ranking,no_of_paintings
	from (
		select cs.size_id,cs.label,count(1) as no_of_paintings
		, dense_rank() over(order by count(1) ) as ranking
		from work w
		join product_size ps on ps.work_id=w.work_id
		join canvas_size cs on cs.size_id= ps.size_id
		group by cs.size_id,cs.label) x
	where x.ranking<=3;

-- 15) Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
-- extract hour min and am/pm
-- convert both time in 24 hr format
-- the time which is in PM and >12 add 12 to convert 24 hr format 
-- then divide the minute  to 60 and  then add the values
with tmh as(
select *,
left(close,2)+12+(substring(close,4,2)/60)  as close_main,
case 
	when substring(open,7,2)='PM' and left(open,2) >=1 and left(open,2)<12 then left(open,2)+12+(substring(open,4,2)/60)
    else left(open,2)+(substring(open,4,2)/60)
end as open_main
from museum_hours
)
select museum_id,name,city,state from museum where museum_id in
(select museum_id from
(select * ,close_main-open_main as duration from tmh 
order by duration  desc
LIMIT 1) m)                  -- museum id 40 has longest duration of opening


-- 16) Which museum has the most no of most popular painting style?
	with pop_style as 
			(select style
			,rank() over(order by count(1) desc) as rnk
			from work
			group by style),
		cte as
			(select w.museum_id,m.name as museum_name,ps.style, count(1) as no_of_paintings
			,rank() over(order by count(1) desc) as rnk
			from work w
			join museum m on m.museum_id=w.museum_id
			join pop_style ps on ps.style = w.style
			where w.museum_id is not null
			and ps.rnk=1
			group by w.museum_id, m.name,ps.style)
	select museum_name,style,no_of_paintings
	from cte 
	where rnk=1;


-- 17) Identify the artists whose paintings are displayed in multiple countries
	with cte as
		(select  distinct a.full_name as artist
		, w.name as painting, m.name as museum
		, m.country
		from work w
		join artist a on a.artist_id=w.artist_id
		join museum m on m.museum_id=w.museum_id)
	select artist,count(4) as no_of_countries
	from cte
	group by artist
	having count(4)>1
	order by 2 desc;


-- 
-- 18) Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.

select city,country ,count(*) as no_of_museum
from museum
group by city,country       

-- NEW YORK,USA HAS MOST MUSEUM

-- 19) Identify the artist and the museum where the most expensive and least expensive painting is placed. 
-- Display the artist name, sale_price, painting name, museum name, museum city and canvas label
	with cte as 
		(select *
		, rank() over(order by sale_price desc) as rnk
		, rank() over(order by sale_price ) as rnk_asc
		from product_size )
	select w.name as painting
	, cte.sale_price
	, a.full_name as artist
	, m.name as museum, m.city
	, cz.label as canvas
	from cte
	join work w on w.work_id=cte.work_id
	join museum m on m.museum_id=w.museum_id
	join artist a on a.artist_id=w.artist_id
	join canvas_size cz on cz.size_id = cte.size_id
	where rnk=1 or rnk_asc=1;
    
-- 20) Which country has the 5th highest no of paintings?
	with cte as 
		(select m.country, count(1) as no_of_Paintings
		, rank() over(order by count(1) desc) as rnk
		from work w
		join museum m on m.museum_id=w.museum_id
		group by m.country)
	select country, no_of_Paintings
	from cte 
	where rnk=5;


-- 21) Which are the 3 most popular and 3 least popular painting styles?
	with cte as 
		(select style, count(1) as cnt
		, rank() over(order by count(1) desc) rnk
		, count(1) over() as no_of_records
		from work
		where style is not null
		group by style)
	select style
	, case when rnk <=3 then 'Most Popular' else 'Least Popular' end as remarks 
	from cte
	where rnk <=3
	or rnk > no_of_records - 3;

-- 22) Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality.
	select full_name as artist_name, nationality, no_of_paintings
	from (
		select a.full_name, a.nationality
		,count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as rnk
		from work w
		join artist a on a.artist_id=w.artist_id
		join subject s on s.work_id=w.work_id
		join museum m on m.museum_id=w.museum_id
		where s.subject='Portraits'
		and m.country != 'USA'
		group by a.full_name, a.nationality) x
	where rnk=1
    
    
    
    
    
-- ---------------------------------------other insights from this database--------------------------------------------------------


-- which paintings earns most ( show details)   
-- for that we need product_size table and  work table and artist table 


select p.work_id,w.name as painting_name,sum(p.sale_price) as total_earning,a.full_name as artist_name
from product_size p
join work w
on p.work_id=w.work_id
join artist a
on a.artist_id=w.artist_id
group by p.work_id,w.name,a.full_name
order by sum(sale_price) desc

    
-- which artist erans most 
select a.full_name as Artist_Nmae ,sum(p.sale_price) as Toatl_Earning
from product_size p
join work w on w.work_id=p.work_id
join artist a on a.artist_id=w.artist_id
group by a.full_name


-- which artist covers  more subjects
select full_name ,count(subject) as total_subject_covered from
(select  distinct a.artist_id,a.full_name, s.subject
from work w
join artist a on a.artist_id=w.artist_id
join subject s on s.work_id=w.work_id) m
group by full_name
order by total_subject_covered desc
 
 
 
 -- which artist covers  more styles
 
 select full_name ,count(style) as total_style_covered from
(select  distinct a.artist_id,a.full_name, w.style
from work w
join artist a on a.artist_id=w.artist_id
)m
group by full_name
order by total_style_covered desc

    
--  IS THERE ANY PAINTING BEING DISPLAYED MORE THAN ONE COUNTRIES?
select painting ,count(country) as total_displayed_country from
(select distinct w.work_id,w.museum_id,m.country,w.name as painting
from work w 
join museum m on m.museum_id=w.museum_id) m
group by painting 
having count(country)>1
order by count(country) desc































