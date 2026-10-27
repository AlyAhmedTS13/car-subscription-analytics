use car_subscription;

select subscription_id , segment ,plan_months , monthly_price, (monthly_price *plan_months) as contract_value
from subscriptions_clean as t1
join cars_clean as t2
on t1.car_id = t2.car_id ;





select count(*)
from(
select subscription_id , segment ,plan_months , monthly_price, (monthly_price *plan_months) as contract_value
from subscriptions_clean as t1
join cars_clean as t2
on t1.car_id = t2.car_id ) as t1 ;



select plan_months, count(*) as cnt_sub , round(AVG(monthly_price *plan_months),2) as avg_contract_value , 
round(sum(monthly_price *plan_months),0) as sum_contract_value, round(sum(monthly_price *plan_months)*100 / 
sum(sum(monthly_price *plan_months)) over(),2) as value_share,
ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2) AS sub_share
from subscriptions_clean as t1
join cars_clean as t2
on t1.car_id = t2.car_id 
group by plan_months
order by avg_contract_value desc;


select plan_months , segment , count(*) as cnt_subs , round(AVG(monthly_price *plan_months),2) as avg_contract_value ,
round(count(*) *100 /sum(count(*)) over (partition by plan_months),2) as share_within_plan
from subscriptions_clean as t1
join cars_clean as t2
on t1.car_id = t2.car_id 
group by plan_months , segment 
order by plan_months asc, avg_contract_value desc ;


with sum_contract as (
select plan_months ,  round(SUM(monthly_price *plan_months),0) as sum_contract_value
from subscriptions_clean
group by plan_months) , collected_amount as (

select plan_months , sum(case when t2.status = 'late' or t2.status = 'paid' then amount end ) as collected,
sum(case when t2.status = 'failed' then amount end ) as failed_amount
from subscriptions_clean as t1
join payments_clean as t2
on t1.subscription_id = t2.subscription_id
group by plan_months)


select  t1.plan_months , sum_contract_value , collected , failed_amount , round((collected*100 / sum_contract_value),2) as collected_pct
from sum_contract as t1
join collected_amount as t2
on t1.plan_months = t2.plan_months
order by t1.plan_months;

SELECT SUM(amount) FROM payments_clean;
