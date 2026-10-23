SET FOREIGN_KEY_CHECKS = 0;


drop table IF EXISTS cars_clean;

create  table cars_clean as 
select *
from cars;

 drop table IF EXISTS customers_clean;

create  table customers_clean as 
select *
from customers;

 drop table IF EXISTS payments_clean;

create  table payments_clean as 
select *,ROW_NUMBER() over(PARTITION BY payment_id,subscription_id,due_date,amount,status) as row_num
from payments;
 drop table IF EXISTS subscriptions_clean;

create  table subscriptions_clean as 
select *
from subscriptions;

 drop table IF EXISTS visitors_clean;

create  table visitors_clean as 
select *
from visitors;

delete
from payments_clean
where row_num >1;

alter table payments_clean
drop column row_num;

SELECT COUNT(*) FROM payments_clean;

select *
from payments_clean as t1
left join subscriptions_clean as t2
on t1.subscription_id= t2.subscription_id
where  t2.subscription_id is null;



create index idx on subscriptions_clean(subscription_id);
DELETE t1
from payments_clean as t1
left join subscriptions_clean as t2
on t1.subscription_id= t2.subscription_id
where  t2.subscription_id is null;


SELECT COUNT(*) FROM payments_clean;


select *, case when amount = 0 then 1 else 0 END as filled
from payments_clean
where amount =0;


ALTER table payments_clean 
add COLUMN is_filled BOOLEAN  ;


update payments_clean
set is_filled  = case when amount = 0 then 1 else 0 END;

update payments_clean 
join subscriptions_clean
on payments_clean.subscription_id=subscriptions_clean.subscription_id
set amount = monthly_price
where amount = 0;

SELECT COUNT(*) FROM payments_clean;                      
SELECT SUM(is_filled) FROM payments_clean;                 
SELECT COUNT(*) FROM payments_clean WHERE amount = 0;     
SELECT COUNT(*)
FROM payments_clean p
JOIN subscriptions_clean s ON p.subscription_id = s.subscription_id
WHERE p.amount <> s.monthly_price;              

alter table subscriptions_clean
add column is_bad_date BOOLEAN;


update subscriptions_clean
set is_bad_date = case when start_date> end_date then 1 else 0 END;

select sum(is_bad_date) as cnt_bad_date , SUM(case when is_bad_date is null then 1 else 0 END) as cnt_null_bad_date ,SUM(case when is_bad_date =0 then 1 else 0 END) as cnt_0_bad_date
from subscriptions_clean;



update visitors_clean
set city = COALESCE(city,"unknown");

select city, count(*)
from visitors_clean
group by city;


select channel, count(*)
from visitors_clean
group by channel;



update visitors_clean
set channel= trim(channel),
channel= upper(channel),
channel =  replace(channel,' ','_'),
channel =  replace(channel,'-','_'),
channel =  CASE WHEN channel = 'referal' then 'REFERRAL' else channel END;






select channel, count(*)
from visitors_clean
group by channel;


use car_subscription;


ALTER TABLE cars_clean          ADD PRIMARY KEY (car_id);
ALTER TABLE customers_clean     ADD PRIMARY KEY (customer_id);
ALTER TABLE subscriptions_clean ADD PRIMARY KEY (subscription_id);
ALTER TABLE payments_clean      ADD PRIMARY KEY (payment_id);
ALTER TABLE visitors_clean      ADD PRIMARY KEY (visitor_id);


DROP INDEX idx ON subscriptions_clean;


 SET FOREIGN_KEY_CHECKS = 1;


