-- TASK 1. Data Cleaning
-- 1. Check Nulls
SELECT 
	employee_id,
	(CASE WHEN age IS NULL or age = 0 THEN age END) as null_age,
	(CASE WHEN gender IS NULL THEN gender END) as null_gender,
	(CASE WHEN marital_status IS NULL THEN marital_status END) as null_marital_status,
	(CASE WHEN education_level IS NULL THEN education_level END) as null_education_level,
	(CASE WHEN department IS NULL THEN department END) as null_department,
	(CASE WHEN job_role IS NULL THEN job_role END) as null_job_role,
	(CASE WHEN job_level IS NULL OR job_level = 0 THEN job_level END) as null_job_level,
	(CASE WHEN years_at_company IS NULL OR years_at_company <0 THEN years_at_company END) as null_years_at_company,
	(CASE WHEN years_in_role IS NULL OR years_in_role < 0 THEN years_in_role END) as null_years_in_role,
	(CASE WHEN monthly_salary::numeric IS NULL OR monthly_salary <= 0 THEN monthly_salary END) as null_monthly_salary,
	(CASE WHEN "salary_hike_%"::numeric IS NULL OR "salary_hike_%" < 0 THEN "salary_hike_%" END) as null_salary_hike,
	(CASE WHEN overtime IS NULL THEN overtime END) as null_overtime,
	(CASE WHEN work_life_balance IS NULL OR work_life_balance = 0 THEN work_life_balance END) as null_work_life_balance,
	(CASE WHEN job_satisfaction IS NULL OR job_satisfaction = 0 THEN job_satisfaction END) as null_job_satisfaction,
	(CASE WHEN performance_rating IS NULL OR performance_rating = 0 THEN performance_rating END) as null_performance_rating,
	(CASE WHEN training_hours IS NULL OR training_hours = 0 THEN training_hours END) as null_training_hours,
	(CASE WHEN distance_from_home IS NULL OR distance_from_home = 0 THEN distance_from_home END) as null_distance_from_home,
	(CASE WHEN num_companies_worked IS NULL OR num_companies_worked = 0 THEN num_companies_worked END) as null_num_companies_worked
FROM hr_churn
WHERE
    age IS NULL OR age = 0
    OR gender IS NULL
    OR marital_status IS NULL
    OR education_level IS NULL
    OR department IS NULL
    OR job_role IS NULL
    OR job_level IS NULL OR job_level = 0
    OR years_at_company IS NULL OR years_at_company < 0
    OR years_in_role IS NULL OR years_in_role < 0        
    OR monthly_salary IS NULL OR monthly_salary <= 0
    OR "salary_hike_%" IS NULL OR "salary_hike_%" < 0
    OR overtime IS NULL
    OR work_life_balance IS NULL OR work_life_balance = 0
    OR job_satisfaction IS NULL OR job_satisfaction = 0
    OR performance_rating IS NULL OR performance_rating = 0
	OR training_hours IS NULL OR training_hours < 0
    OR distance_from_home IS NULL OR distance_from_home = 0
    OR num_companies_worked IS NULL OR num_companies_worked = 0;


-- 1. check years
WITH company_exp as (
	SELECT 
		employee_id,
		age,
		(age-years_at_company) as work_since_age,
		Case
		when (age-years_at_company) >=20 THEN 'valid'
		else 'invalid'
		END as age_start_work,
		years_at_company,
		CASE 
			WHEN years_at_company = 0 THEN 'new recruit'
			Else 'old members'
		end as worker_status,
		years_in_role,
		CASE 
			WHEN years_in_role = 0 THEN 'intern'
			WHEN years_in_role <= 5 THEN 'junior'
			Else 'senior'
		end as role_status
	FROM hr_churn)

Select 
	*
from company_exp 
where age_start_work = 'invalid'
order by employee_id;


-- 2. Check duplicates
-- Preview duplicates of same person, different IDs
select 
	a.employee_id as first_id,
	b.employee_id as second_id,
	a.age as age,
	a.gender as gender,
	a.marital_status as marital_status,
	a.education_level as education_level,
	a.department as department,
	a.job_role as job_role
FROm hr_churn a
join hr_churn b on a.employee_id < b.employee_id
	and a.age = b.age
	and a.gender = b.gender
	and a.marital_status =b.marital_status
	and a.education_level = b.education_level
	and a.department=b.department
	and a.job_role=b.job_role
order by a.employee_id asc;

-- delete duplicates
Delete from hr_churn 
where
	employee_id in (
	Select
	b.employee_id as second_id
	FROm hr_churn a
	join hr_churn b on a.employee_id < b.employee_id
	and a.age = b.age
	and a.gender = b.gender
	and a.marital_status =b.marital_status
	and a.education_level = b.education_level
	and a.department=b.department
	and a.job_role=b.job_role
);

-- role validation
-- job role & department mismatch
SELECT
	job_role,
	department,
	count(*) as count_head
FROm hr_churn
Group By job_role, department
order By job_role, department;

-- 3. check salary
with bounds as (
	select 
	round(percentile_cont(0.05) within group (order by monthly_salary)::numeric) as lower_bounds,
	round(percentile_cont(0.95) within group (order by monthly_salary)::numeric) as upper_bounds,
	round(min(monthly_salary)::numeric) as min_salary,
	round(max(monthly_salary)::numeric) as max_salary,
	round(avg(monthly_salary)::numeric) as avg_salary
from hr_churn
)
    SELECT
	hr.employee_id,
	hr.department,
	hr.job_role,
	hr.performance_rating,
	hr.monthly_salary,
	b.lower_bounds,
	b.upper_bounds,
	Case
		when hr.monthly_salary < b.lower_bounds then 'underpaid'
		when hr.monthly_salary > b.upper_bounds then 'overpaid'
		else 'normal'
	end as salary_type,
	b.min_salary,
	b.max_salary,
	b.avg_salary
from hr_churn hr, bounds b
where hr.monthly_salary < b.lower_bounds or hr.monthly_salary > b.upper_bounds
order by hr.monthly_salary;

-- TASK 2. Explore Data
-- 1. Workforce Overview — Who Are We Looking At?
-- 1a. Is Performance Being Measured Fairly?
select 
	performance_rating,
	count(*) as count_head,
	round(count(*)*100/sum(count(*)) over () ,2) as percentage
FROM hr_churn
group by performance_rating
order by performance_rating;

-- 1b. Which Department Leads and Which Is Falling Behind?
select 
	department,
	rank() over(order by avg(performance_rating) desc) as rank_performance,
	round(avg(performance_rating),2) as avg_performance,
	COUNT(CASE WHEN performance_rating = 4 THEN 1 END) AS top_performers,
    COUNT(CASE WHEN performance_rating = 1 THEN 1 END) AS low_performers,
	count(*) as count_head,
	round(count(*)*100/sum(count(*)) over () ,2) as percentage
FROM hr_churn
group by department
order by rank_performance;

-- 1c. Does Longer Tenure Mean Better Performance?
select 
	case 
	when years_at_company =0 then 'new recruits'
	when years_at_company between 1 and 3 then '1-3 yrs'
	when years_at_company between 4 and 7 then '4-7 yrs'
	when years_at_company between 8 and 12 then '8-12 yrs'
	else '13+ years'
	end as years_group,
	count(*) as count_head,
	round(avg(performance_rating),2) as avg_performance,
	round(avg(monthly_salary)::numeric,2) as avg_salary,
	round(avg("salary_hike_%")::numeric,2) as avg_salary_hike,
	round(count(*)*100/sum(count(*)) over () ,2) as percentage
FROM hr_churn
group by years_group
ORDER BY min(years_at_company);

-- 1d. Is Training Investment Paying Off?
select 
	case 
	when training_hours between 0 and 20 then '0-20 hours'
	when training_hours between 21 and 40 then '21-40 hours'
	when training_hours between 41 and 60 then '41-60 hours'
	else '61-80 hours'
	end as hours_group,
	count(*) as count_head,
	round(avg(performance_rating),2) as avg_performance,
	round(avg(monthly_salary)::numeric,2) as avg_salary,
	round(avg("salary_hike_%")::numeric,2) as avg_salary_hike,
	round(count(*)*100/sum(count(*)) over () ,2) as percentage
FROM hr_churn
group by hours_group
ORDER BY min(training_hours);


-- 1e. Is Overtime Helping or Hurting Performance?
select 
	overtime,
	work_life_balance,
	count(*) as count_head,
	round(avg(performance_rating),2) as avg_performance,
	round(avg(monthly_salary)::numeric,2) as avg_salary,
	round(avg("salary_hike_%")::numeric,2) as avg_salary_hike,
	round(count(*)*100/sum(count(*)) over () ,2) as percentage
FROM hr_churn
group by overtime, work_life_balance
ORDER BY overtime, work_life_balance;

-- 2. Are High Performers Actually Being Rewarded?
SELECT
    performance_rating,
    COUNT(*) AS count_head,
    ROUND(AVG("salary_hike_%")::numeric, 2) AS avg_salary_hike,
    MIN("salary_hike_%") AS min_hike,
    MAX("salary_hike_%") AS max_hike,
    COUNT(CASE WHEN performance_rating = 1 AND "salary_hike_%" > 20 THEN 1 END) AS low_perf_high_hike,
    COUNT(CASE WHEN performance_rating = 4 AND "salary_hike_%" < 5 THEN 1 END) AS high_perf_low_hike
FROM hr_churn
GROUP BY performance_rating
ORDER BY performance_rating;

-- 3. Are Loyal Employees Growing or Getting Stuck?
select 
	job_level,
	case 
	when years_at_company =0 then 'new recruits'
	when years_at_company between 1 and 3 then '1-3 yrs'
	when years_at_company between 4 and 7 then '4-7 yrs'
	when years_at_company between 8 and 12 then '8-12 yrs'
	else '13+ years'
	end as years_group,
	count(*) as count_head,
	round(avg(years_at_company),2) as avg_years_at_company,
	round(avg(performance_rating),2) as avg_performance,
	round(avg(monthly_salary)::numeric,2) as avg_salary,
	round(avg("salary_hike_%")::numeric,2) as avg_salary_hike,
	round(count(*)*100/sum(count(*)) over () ,2) as percentage
from hr_churn
group by job_level, years_group
order by job_level, MIN(years_at_company);

-- 4. Which Departments Are Burning Out?
select 
	department,
	count(*) as count_head,
	count(case when overtime = 'Yes' then 1 end) as count_overtime,
	count(case when overtime = 'No' then 1 end) as count_no_overtime,
	round(count(case when overtime = 'Yes' then 1 end)*100/count(*),2) as percentage_overtime,
	round(avg(case when overtime = 'Yes' then 1 end),2) as avg_overtime,
	round(avg(case when overtime = 'No' then 1 end),2) as avg_no_overtime,
	round(avg(case when overtime = 'Yes' then performance_rating end),2) as avg_overtime_performance,
	round(avg(case when overtime = 'No' then performance_rating end),2) as avg_no_overtime_performance,
	round(avg(case when overtime = 'Yes' then work_life_balance end),2) as avg_overtime_wlb,
	round(avg(case when overtime = 'No' then work_life_balance end),2) as avg_no_overtime_wlb
from hr_churn
group by department
order by percentage_overtime;

-- 5. Does More Training Lead to Better and Happier Employees?
select
	case 
		when training_hours between 0 and 20 then '0-20 hours'
		when training_hours between 21 and 40 then '21-40 hours'
		when training_hours between 41 and 60 then '41-60 hours'
		else '61-80 hours'
	end as hours_group,
	count(*) as count_head,
	round(avg(years_at_company),2) as avg_years_at_company,
	round(avg(performance_rating),2) as avg_performance,
	round(avg(job_satisfaction),2) as avg_satisfaction,
	round(avg(monthly_salary)::numeric,2) as avg_salary,
	round(avg("salary_hike_%")::numeric,2) as avg_salary_hike,
	round(count(*)*100/sum(count(*)) over () ,2) as percentage
from hr_churn
group by hours_group
order by min(training_hours);

-- 6. Are Employees Truly Happy — or Just Coping?
select 
	job_satisfaction,
	work_life_balance,
	count(*) as count_head,
	round(avg(performance_rating),2) as avg_performance,
	round(avg("salary_hike_%")::numeric,2) as avg_salary_hike,
	round(avg(monthly_salary)::numeric,2) as avg_salary,
	count(case when overtime = 'Yes' then 1 end) as count_overtime,
	round(count(*)*100/sum(count(*)) over () ,2) as percentage
from hr_churn
group by job_satisfaction, work_life_balance
order by job_satisfaction, work_life_balance;