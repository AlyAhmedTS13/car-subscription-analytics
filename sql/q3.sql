
with t1 as (
select *, ROW_NUMBER() over (partition by customer_id order by start_date) as row_num
from subscriptions_clean)

select MONTH(start_date) as month ,count(*) as subs
from t1
where row_num = 1 and is_bad_date = 0
group by MONTH(start_date)
order by month asc;



select MONTH(end_date) as month, count(*) as canclled_cnt
from subscriptions_clean
where status = 'cancelled'  and is_bad_date = 0
group by month
order by month ;



with t1 as (
select *, ROW_NUMBER() over (partition by customer_id order by start_date) as row_num
from subscriptions_clean)

select MONTH(start_date) as month ,count(*) as subs
from t1
where row_num = 1 and is_bad_date = 1
group by MONTH(start_date)
order by month asc;



with t1 as (
select *, ROW_NUMBER() over (partition by customer_id order by start_date) as row_num
from subscriptions_clean)

select MONTH(start_date) as month ,sum(case when row_num = 1 then 1 else 0 end ) as new_subs,
sum(case when row_num > 1 then 1 else 0 END) as renewals_cnt,
count(*) as total_starts 
from t1
where  is_bad_date = 0
group by MONTH(start_date)
order by month asc;

create view alive_cnt_per_month as 
with months as (
select distinct month(start_date) as month
from subscriptions_clean
)

select t2.month, count(*) as alive_subs
from subscriptions_clean as t1
join months as t2 
on month(t1.start_date) <= t2.month and (MONTH(t1.end_date) >= t2.month or t1.end_date is null )
where is_bad_date = 0
group by t2.month 
order by t2.month;




with canclled_cnt as (
select MONTH(end_date) as month, count(*) as canclled_cnt
from subscriptions_clean
where status = 'cancelled'  and is_bad_date = 0
)

select t2.month as month, alive_subs , canclled_cnt , round((canclled_cnt*100 / alive_subs),2) as rate
from alive_cnt_per_month as t1
join  canclled_cnt as t2 
on t1.month = t2.month 
order by t2.month
