USE car_subscription;


select count(*) as customers_without_sub
from customers_clean as t1
left join subscriptions_clean as t2
on t1.customer_id = t2.customer_id
where t2.customer_id is null ;


select row_num, count(*)
from(
select ROW_NUMBER() over (partition BY  customer_id) as row_num,customer_id
from visitors_clean
where  customer_id is not null ) as t1
where row_num >1 
group by row_num;

select channel ,count(*)
from visitors_clean
group by channel
order by count(*) desc;





select channel ,count(customer_id) as subscribers, count(*) as visitors ,round(count(customer_id)*100 / count(*),2) as sub_rate, 
round(count(*) * 100 /(select count(*) 
from visitors_clean),2) as visitors_share, round(count(customer_id)*100/(select count(customer_id )
from visitors_clean ),2) as subs_share
from visitors_clean
group by channel
order by  sub_rate desc;



select city ,count(customer_id) as subscribers, count(*) as visitors ,round(count(customer_id)*100 / count(*),2) as sub_rate, 
round(count(*) * 100 /(select count(*) 
from visitors_clean),2) as visitors_share, round(count(customer_id)*100/(select count(customer_id )
from visitors_clean ),2) as subs_share
from visitors_clean
group by city
order by  sub_rate desc;



