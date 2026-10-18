-- data quality check:
USE car_subscription;

with dups as (
select payment_id, ROW_NUMBER() OVER(partition by payment_id) as row_num 
FROM payments
)
select payment_id ,row_num
from dups 
where row_num > 1;


select payment_id, count(*) as count
from payments
GROUP by payment_id
having count(*) >1 
order by count desc ;


with dups as (
select payment_id, ROW_NUMBER() OVER(partition by payment_id,amount, status,due_date,subscription_id) as row_num 
FROM payments
)
select payment_id ,row_num
from dups 
where row_num > 1;

select  amount , status , due_date, subscription_id , count(*) as cnt, count(distinct payment_id) 
from payments
group by amount , status , due_date, subscription_id
having count(distinct payment_id) >1;



select count(*) as cnt_rows , count(distinct car_id) as ids , 'cars' as table_name
from cars

UNION  all 


select count(*) , count(distinct customer_id)  , 'customers'
from customers

UNION  all 

select count(*) , count(distinct visitor_id) , 'visitors'
from visitors

UNION  all 

select count(*) , count(distinct subscription_id), 'subscriptions'
from subscriptions;


select sum(case when visitor_id is  null then 1 else 0 end  ) as visitor_id_nulls,
sum(case when visit_date is  null then 1 else 0 end  ) as visit_date_nulls,
sum(case when channel is  null then 1 else 0 end  ) as channel_nulls,
sum(case when city is  null then 1 else 0 end  ) as city_nulls,
sum(case when ab_group is  null then 1 else 0 end  ) as ab_group_nulls,
sum(case when customer_id is  null then 1 else 0 end  ) as customer_id_nulls
from visitors;


-- subscriptions
SELECT
  SUM(CASE WHEN subscription_id IS NULL THEN 1 ELSE 0 END) AS subscription_id_nulls,
  SUM(CASE WHEN customer_id     IS NULL THEN 1 ELSE 0 END) AS customer_id_nulls,
  SUM(CASE WHEN car_id          IS NULL THEN 1 ELSE 0 END) AS car_id_nulls,
  SUM(CASE WHEN plan_months     IS NULL THEN 1 ELSE 0 END) AS plan_months_nulls,
  SUM(CASE WHEN monthly_price   IS NULL THEN 1 ELSE 0 END) AS monthly_price_nulls,
  SUM(CASE WHEN start_date      IS NULL THEN 1 ELSE 0 END) AS start_date_nulls,
  SUM(CASE WHEN end_date        IS NULL THEN 1 ELSE 0 END) AS end_date_nulls,
  SUM(CASE WHEN status          IS NULL THEN 1 ELSE 0 END) AS status_nulls
FROM subscriptions;

-- payments
SELECT
  SUM(CASE WHEN payment_id      IS NULL THEN 1 ELSE 0 END) AS payment_id_nulls,
  SUM(CASE WHEN subscription_id IS NULL THEN 1 ELSE 0 END) AS subscription_id_nulls,
  SUM(CASE WHEN due_date        IS NULL THEN 1 ELSE 0 END) AS due_date_nulls,
  SUM(CASE WHEN amount          IS NULL THEN 1 ELSE 0 END) AS amount_nulls,
  SUM(CASE WHEN status          IS NULL THEN 1 ELSE 0 END) AS status_nulls
FROM payments;

-- customers
SELECT
  SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS customer_id_nulls,
  SUM(CASE WHEN signup_date IS NULL THEN 1 ELSE 0 END) AS signup_date_nulls
FROM customers;

-- cars
SELECT
  SUM(CASE WHEN car_id             IS NULL THEN 1 ELSE 0 END) AS car_id_nulls,
  SUM(CASE WHEN model              IS NULL THEN 1 ELSE 0 END) AS model_nulls,
  SUM(CASE WHEN segment            IS NULL THEN 1 ELSE 0 END) AS segment_nulls,
  SUM(CASE WHEN base_monthly_price IS NULL THEN 1 ELSE 0 END) AS base_monthly_price_nulls
FROM cars;



select status, count(*) as cnt
from subscriptions
where end_date is null
group by status;

select status, count(*) as cnt
from subscriptions
where end_date is not  null
group by status;


select count(*) as cnt
from payments as t1 
left join subscriptions as t2
    on t1.subscription_id = t2.subscription_id
where t2.subscription_id is null ;

select count(*) as cnt
from payments as t1 
right join subscriptions as t2
    on t1.subscription_id = t2.subscription_id
where t1.subscription_id is null ;


select count(*) as cnt
from subscriptions as t1
left join customers as t2
on t1.customer_id = t2.customer_id
where t2.customer_id is null ;


-- A: subscriptions → cars
SELECT COUNT(*) AS cnt
FROM subscriptions AS t1
LEFT JOIN cars AS t2
  ON t1.car_id = t2.car_id
WHERE t2.car_id IS NULL;

-- B: visitors → customers
SELECT COUNT(*) AS cnt
FROM visitors AS t1
LEFT JOIN customers AS t2
  ON t1.customer_id = t2.customer_id
WHERE t1.customer_id IS NOT NULL  
  AND t2.customer_id IS NULL;


SELECT count(*) cnt_subs 
from subscriptions
where start_date > end_date;


select subscription_id,plan_months,start_date,end_date, TIMESTAMPDIFF(day,end_date,start_date) as diff, status
from subscriptions
where start_date > end_date;


select count(*) as cnt, status, MIN(amount) as min_value , MAX(amount) as max_value
from payments
where amount <= 0
group by status;

select status, count(*)
from payments
GROUP by status;

select count(*) as cnt_mismatch
from payments as t1
join subscriptions as t2
    on t1.subscription_id = t2.subscription_id
where amount != monthly_price AND amount != 0;

select distinct channel
from visitors;

SELECT channel, LENGTH(channel) AS len, COUNT(*) AS cnt
FROM visitors
GROUP BY channel;

SELECT city, LENGTH(city) AS len, COUNT(*) AS cnt
FROM visitors
GROUP BY city;


select sum(case when ab_group = 'control' then 1 else 0 end ) as control_cnt,
sum(case when ab_group = 'treatment' then 1 else 0 end )as  treatment_cnt,
sum(case when ab_group is null  then 1 else 0 end )as  null_cnt
from visitors
where visit_date BETWEEN "2025-10-06" and "2025-11-30";


select max(visit_date), min(visit_date)
from  visitors;


SELECT 'customers.signup_date' AS col, MIN(signup_date) AS min_d, MAX(signup_date) AS max_d FROM customers
UNION ALL
SELECT 'subs.start_date', MIN(start_date), MAX(start_date) FROM subscriptions
UNION ALL
SELECT 'subs.end_date', MIN(end_date), MAX(end_date) FROM subscriptions
UNION ALL
SELECT 'payments.due_date', MIN(due_date), MAX(due_date) FROM payments;