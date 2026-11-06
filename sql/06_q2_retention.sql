

USE car_subscription;
SET SQL_SAFE_UPDATES = 0;



select count(*), count(distinct customer_id)
from subscriptions_clean
where is_bad_date = 1;



select customer_id, start_date as first_start,
       month(start_date) as cohort_month,   
       plan_months as first_plan
from (select *, ROW_NUMBER() over (PARTITION BY customer_id order by start_date, subscription_id) as row_num
      from subscriptions_clean) as t1
where row_num = 1
  and customer_id not in (select customer_id from subscriptions_clean where is_bad_date = 1);



select count(*), count(distinct customer_id), month(start_date) as cohort_month
from (select *, ROW_NUMBER() over (PARTITION BY customer_id order by start_date, subscription_id) as row_num
      from subscriptions_clean) as t1
where row_num = 1
  and customer_id not in (select customer_id from subscriptions_clean where is_bad_date = 1)
group by cohort_month;



select count(*),
       sum(case when end_date = (start_date + INTERVAL 1 month) then 1 else 0 end) as end_eq_plus1m,
       sum(case when end_date = (start_date + INTERVAL 1 month - INTERVAL 1 day) then 1 else 0 end) as end_eq_plus1m_minus1d,
       sum(case when end_date != (start_date + INTERVAL 1 month - INTERVAL 1 day)
                 and end_date != (start_date + INTERVAL 1 month) then 1 else 0 end) as neither
from subscriptions_clean
where plan_months = 1 and status = 'completed' and is_bad_date = 0;



with first_sub as (
    select customer_id, start_date as first_start,
           month(start_date) as cohort_month,   
           plan_months as first_plan
    from (select *, ROW_NUMBER() over (PARTITION BY customer_id order by start_date, subscription_id) as row_num
          from subscriptions_clean) as t1
    where row_num = 1
      and customer_id not in (select customer_id from subscriptions_clean where is_bad_date = 1)
)
select t1.customer_id as customer_id, cohort_month, first_plan,
       max(case when t1.start_date <= ADDDATE(first_start, INTERVAL 1 month)
                 and (t1.end_date > ADDDATE(first_start, INTERVAL 1 month) or t1.end_date is null)
                then 1 else 0 end) as alive_M1,
       max(case when t1.start_date <= ADDDATE(first_start, INTERVAL 3 month)
                 and (t1.end_date > ADDDATE(first_start, INTERVAL 3 month) or t1.end_date is null)
                then 1 else 0 end) as alive_M3,
       max(case when t1.start_date <= ADDDATE(first_start, INTERVAL 6 month)
                 and (t1.end_date > ADDDATE(first_start, INTERVAL 6 month) or t1.end_date is null)
                then 1 else 0 end) as alive_M6
from subscriptions_clean as t1
join first_sub as t2
  on t1.customer_id = t2.customer_id
group by t1.customer_id, cohort_month, first_plan;


CREATE OR REPLACE VIEW cohort AS
with first_sub as (
    select customer_id, start_date as first_start,
           month(start_date) as cohort_month,
           plan_months as first_plan
    from (select *, ROW_NUMBER() over (PARTITION BY customer_id order by start_date, subscription_id) as row_num
          from subscriptions_clean) as t1
    where row_num = 1
      and customer_id not in (select customer_id from subscriptions_clean where is_bad_date = 1)
)
SELECT COUNT(*), SUM(alive_M1), SUM(alive_M3), SUM(alive_M6)
from (
    select t1.customer_id as customer_id, cohort_month, first_plan,
           max(case when t1.start_date <= ADDDATE(first_start, INTERVAL 1 month)
                     and (t1.end_date > ADDDATE(first_start, INTERVAL 1 month) or t1.end_date is null)
                    then 1 else 0 end) as alive_M1,
           max(case when t1.start_date <= ADDDATE(first_start, INTERVAL 3 month)
                     and (t1.end_date > ADDDATE(first_start, INTERVAL 3 month) or t1.end_date is null)
                    then 1 else 0 end) as alive_M3,
           max(case when t1.start_date <= ADDDATE(first_start, INTERVAL 6 month)
                     and (t1.end_date > ADDDATE(first_start, INTERVAL 6 month) or t1.end_date is null)
                    then 1 else 0 end) as alive_M6
    from subscriptions_clean as t1
    join first_sub as t2
      on t1.customer_id = t2.customer_id
    group by t1.customer_id, cohort_month, first_plan
) as t3;


select cohort_month , count(*) as cohort_size ,
case when  cohort_month + 1 <= 12 THEN  round((SUM(alive_M1)*100/ count(*)),2)  end as m1_pct ,  
case when  cohort_month + 3 <= 12 THEN round((SUM(alive_M3)*100/ count(*)),2) end as m3_pct , 
case when  cohort_month + 6 <= 12 THEN  round((SUM(alive_M6) *100/ count(*) ),2) end as m6_pct
from cohort
group by cohort_month 
order by cohort_month ;


SELECT first_plan,
       COUNT(*) AS plan_size,

       SUM(CASE WHEN cohort_month + 1 <= 12 THEN 1 ELSE 0 END) AS measurable_m1,
       ROUND(AVG(CASE WHEN cohort_month + 1 <= 12 THEN alive_M1 END) * 100, 2) AS m1_pct,

       SUM(CASE WHEN cohort_month + 3 <= 12 THEN 1 ELSE 0 END) AS measurable_m3,
       ROUND(AVG(CASE WHEN cohort_month + 3 <= 12 THEN alive_M3 END) * 100, 2) AS m3_pct,

       SUM(CASE WHEN cohort_month + 6 <= 12 THEN 1 ELSE 0 END) AS measurable_m6,
       ROUND(AVG(CASE WHEN cohort_month + 6 <= 12 THEN alive_M6 END) * 100, 2) AS m6_pct
FROM cohort
GROUP BY first_plan
ORDER BY first_plan;




