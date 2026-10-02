# ALY6030 - Data Warehousing and SQL 
# Final Project Assignment - Pharmacy Claims 
# Jayesh Patil

USE Pharmacy_Claims;

# -----PART 1-----

# 1. Renaming the the imported raw table
ALTER TABLE `aly 6030 final project data set`
RENAME TO pharmacy_raw;

# 2. Creating fact table: fact_drug One row per prescription fill event (1NF)
CREATE TABLE fact_drug AS
SELECT
    member_id,
    drug_ndc,
    fill_date,
    copay,
    insurance_paid
FROM (
# fills from group 1
    SELECT
        member_id,
        drug_ndc,
        fill_date1 AS fill_date,
        copay1     AS copay,
        insurancepaid1 AS insurance_paid
    FROM pharmacy_raw
    WHERE fill_date1 IS NOT NULL

    UNION ALL

# fills from group 2
    SELECT
        member_id,
        drug_ndc,
        fill_date2 AS fill_date,
        copay2     AS copay,
        insurancepaid2 AS insurance_paid
    FROM pharmacy_raw
    WHERE fill_date2 IS NOT NULL

    UNION ALL

# fills from group 3
    SELECT
        member_id,
        drug_ndc,
        fill_date3 AS fill_date,
        copay3     AS copay,
        insurancepaid3 AS insurance_paid
    FROM pharmacy_raw
    WHERE fill_date3 IS NOT NULL
) AS t;


# 3. Creating Dimension: dim_member (2NF / 3NF)
CREATE TABLE dim_member AS
SELECT DISTINCT
    member_id,
    member_first_name,
    member_last_name,
    member_birth_date,
    member_age,
    member_gender
FROM pharmacy_raw;


# 4. Creating Dimension: dim_drug_ndc (2NF)
CREATE TABLE dim_drug_ndc AS
SELECT DISTINCT
    drug_ndc,
    drug_name,
    drug_form_code,
    drug_brand_generic_code
FROM pharmacy_raw;

# 5. Creating Dimension: dim_drug_form_code (3NF - lookup table)
CREATE TABLE dim_drug_form_code AS
SELECT DISTINCT
    drug_form_code,
    drug_form_desc
FROM pharmacy_raw;


# 6. Creating Dimension: dim_brand_generic (3NF – lookup table)
CREATE TABLE dim_brand_generic AS
SELECT DISTINCT
    drug_brand_generic_code,
    drug_brand_generic_desc
FROM pharmacy_raw;


# 7. Doing a quick sanity check – row counts for all tables
SELECT COUNT(*) AS rows_pharmacy_raw      FROM pharmacy_raw;
SELECT COUNT(*) AS rows_fact_drug         FROM fact_drug;
SELECT COUNT(*) AS rows_dim_member        FROM dim_member;
SELECT COUNT(*) AS rows_dim_drug_ndc      FROM dim_drug_ndc;
SELECT COUNT(*) AS rows_dim_drug_form     FROM dim_drug_form_code;
SELECT COUNT(*) AS rows_brand_generic     FROM dim_brand_generic;



# -----PART 2-----

# 1. PRIMARY KEYS
# 1A. FACT TABLE: fact_drug         
# Adding a surrogate key for the fact table
ALTER TABLE fact_drug
  ADD COLUMN fact_drug_id INT NOT NULL AUTO_INCREMENT FIRST,
  ADD CONSTRAINT pk_fact_drug PRIMARY KEY (fact_drug_id);

# 1B. DIMENSION: dim_member
# Natural key for member_id
ALTER TABLE dim_member
  ADD CONSTRAINT pk_dim_member PRIMARY KEY (member_id);

# 1C. DIMENSION: dim_drug_ndc
# Natural key for drug_ndc
ALTER TABLE dim_drug_ndc
  ADD CONSTRAINT pk_dim_drug_ndc PRIMARY KEY (drug_ndc);

# 1D. DIMENSION: dim_drug_form_code
# Natural key for  drug_form_code
ALTER TABLE dim_drug_form_code
  MODIFY COLUMN drug_form_code VARCHAR(100) NOT NULL,
  ADD CONSTRAINT pk_dim_drug_form_code PRIMARY KEY (drug_form_code);

# 1E. DIMENSION: dim_brand_generic
# Natural key for drug_brand_generic_code
ALTER TABLE dim_brand_generic
  MODIFY COLUMN drug_brand_generic_code VARCHAR(100) NOT NULL,
  ADD CONSTRAINT pk_dim_brand_generic PRIMARY KEY (drug_brand_generic_code);

# 2. FOREIGN KEYS
  # 2A. fact_drug = dim_member and dim_drug_ndc
# member_id references dim_member(member_id)
# drug_ndc  references dim_drug_ndc(drug_ndc)
# ON DELETE RESTRICT: does not allow deleting a member or drug if there are fact rows that depend on it
# ON UPDATE CASCADE: if a key value is corrected in the dimension, update the related fact rows automatically

ALTER TABLE fact_drug
  ADD CONSTRAINT fk_fact_drug_member
    FOREIGN KEY (member_id)
    REFERENCES dim_member(member_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  ADD CONSTRAINT fk_fact_drug_drug
    FOREIGN KEY (drug_ndc)
    REFERENCES dim_drug_ndc(drug_ndc)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

# 2B. dim_drug_ndc = dim_drug_form_code and dim_brand_generic
# drug_form_code = dim_drug_form_code(drug_form_code)
# drug_brand_generic_code = dim_brand_generic(drug_brand_generic_code)
# Same logic for RESTRICT / CASCADE as I stated in the earlier step

# Makeing sure the types of these columns match the lookup tables
ALTER TABLE dim_drug_ndc
  MODIFY COLUMN drug_form_code VARCHAR(100) NOT NULL,
  MODIFY COLUMN drug_brand_generic_code VARCHAR(100) NOT NULL;

ALTER TABLE dim_drug_ndc
  ADD CONSTRAINT fk_dim_drug_ndc_form
    FOREIGN KEY (drug_form_code)
    REFERENCES dim_drug_form_code(drug_form_code)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  ADD CONSTRAINT fk_dim_drug_ndc_brand
    FOREIGN KEY (drug_brand_generic_code)
    REFERENCES dim_brand_generic(drug_brand_generic_code)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;


# -----PART 3----- 
# Star Schema created, attached in the report and single page PDF attached in submissions 


# Part 4 — Analytics and Reporting

# Prescriptions grouped by drug name
# Q1: Number of prescriptions grouped by drug name
SELECT
    d.drug_name,
    COUNT(*) AS num_prescriptions
FROM fact_drug f
Inner JOIN dim_drug_ndc d
    ON f.drug_ndc = d.drug_ndc
GROUP BY d.drug_name
ORDER BY num_prescriptions DESC;

# Age buckets: 65+ vs <65
SELECT
    CASE
        WHEN m.member_age >= 65 THEN 'age 65+'
        ELSE '< 65'
    END AS age_group,
    COUNT(*) AS total_prescriptions,
    COUNT(DISTINCT f.member_id) AS unique_members,
    SUM(f.copay) AS total_copay,
    SUM(f.insurance_paid) AS total_insurance_paid
FROM fact_drug f
JOIN dim_member m
    ON f.member_id = m.member_id
GROUP BY age_group
ORDER BY age_group;

# Most recent prescription per member
WITH ranked_fills AS (
    SELECT
        f.member_id,
        m.member_first_name,
        m.member_last_name,
        d.drug_name,
        f.fill_date,
        f.insurance_paid,
        ROW_NUMBER() OVER (
            PARTITION BY f.member_id
            ORDER BY f.fill_date DESC
        ) AS rn
    FROM fact_drug f
    Inner JOIN dim_member m
        ON f.member_id = m.member_id
    inner JOIN dim_drug_ndc d
        ON f.drug_ndc = d.drug_ndc
)
SELECT
    member_id,
    member_first_name,
    member_last_name,
    drug_name,
    fill_date AS most_recent_fill_date,
    insurance_paid AS most_recent_insurance_paid
FROM ranked_fills
WHERE rn = 1
ORDER BY member_id;

 












