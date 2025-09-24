DROP DATABASE IF EXISTS university_main;
CREATE DATABASE university_main
         TEMPLATE = template0
         ENCODING = 'UTF8';

DROP DATABASE IF EXISTS university_archive;
CREATE DATABASE university_archive
         TEMPLATE = template0
         CONNECTION LIMIT = 50;

DROP DATABASE IF EXISTS university_test;
CREATE DATABASE university_test
         CONNECTION LIMIT = 10
         IS_TEMPLATE = TRUE;


DROP TABLESPACE IF EXISTS student_data;
CREATE TABLESPACE student_data LOCATION 'C:/pgbases/students';

DROP TABLESPACE IF EXISTS course_data;
CREATE TABLESPACE course_data LOCATION 'C:/pgbases/courses';


DROP DATABASE IF EXISTS university_distributed;
CREATE DATABASE university_distributed
    WITH TABLESPACE = student_data
         ENCODING = 'UTF8';

\c university_main;

-- Students table
CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone CHAR(15),
    date_of_birth DATE,
    enrollment_date DATE,
    gpa NUMERIC(3,2),
    is_active BOOLEAN,
    graduation_year SMALLINT
);

CREATE TABLE professors (
    professor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    office_number VARCHAR(20),
    hire_date DATE,
    salary NUMERIC(12,2),
    is_tenured BOOLEAN,
    years_experience INTEGER
);

CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_code CHAR(8),
    course_title VARCHAR(100),
    description TEXT,
    credits SMALLINT,
    max_enrollment INTEGER,
    course_fee NUMERIC(8,2),
    is_online BOOLEAN,
    created_at TIMESTAMP WITHOUT TIME ZONE
);

CREATE TABLE class_schedule (
    schedule_id SERIAL PRIMARY KEY,
    course_id INTEGER,
    professor_id INTEGER,
    classroom VARCHAR(20),
    class_date DATE,
    start_time TIME WITHOUT TIME ZONE,
    end_time TIME WITHOUT TIME ZONE,
    duration INTERVAL
);

CREATE TABLE student_records (
    record_id SERIAL PRIMARY KEY,
    student_id INTEGER,
    course_id INTEGER,
    semester VARCHAR(20),
    year INTEGER,
    grade CHAR(2),
    attendance_percentage NUMERIC(4,1),
    submission_timestamp TIMESTAMPTZ,
    last_updated TIMESTAMPTZ
);

ALTER TABLE students
    ADD COLUMN middle_name VARCHAR(30),
    ADD COLUMN student_status VARCHAR(20) DEFAULT 'ACTIVE',
    ALTER COLUMN phone TYPE VARCHAR(20),
    ALTER COLUMN gpa SET DEFAULT 0.00;

ALTER TABLE professors
    ADD COLUMN department_code CHAR(5),
    ADD COLUMN research_area TEXT,
    ALTER COLUMN years_experience TYPE SMALLINT,
    ALTER COLUMN is_tenured SET DEFAULT FALSE,
    ADD COLUMN last_promotion_date DATE;

ALTER TABLE courses
    ADD COLUMN prerequisite_course_id INTEGER,
    ADD COLUMN difficulty_level SMALLINT,
    ALTER COLUMN course_code TYPE VARCHAR(10),
    ALTER COLUMN credits SET DEFAULT 3,
    ADD COLUMN lab_required BOOLEAN DEFAULT FALSE;

ALTER TABLE class_schedule
    ADD COLUMN room_capacity INTEGER,
    DROP COLUMN duration,
    ADD COLUMN session_type VARCHAR(15),
    ALTER COLUMN classroom TYPE VARCHAR(30),
    ADD COLUMN equipment_needed TEXT;

ALTER TABLE student_records
    ADD COLUMN extra_credit_points NUMERIC(3,1) DEFAULT 0.0,
    ALTER COLUMN grade TYPE VARCHAR(5),
    ADD COLUMN final_exam_date DATE,
    DROP COLUMN last_updated;

CREATE TABLE departments (
    department_id SERIAL PRIMARY KEY,
    department_name VARCHAR(100),
    department_code CHAR(5),
    building VARCHAR(50),
    phone VARCHAR(15),
    budget NUMERIC(15,2),
    established_year INTEGER
);

CREATE TABLE library_books (
    book_id SERIAL PRIMARY KEY,
    isbn CHAR(13),
    title VARCHAR(200),
    author VARCHAR(100),
    publisher VARCHAR(100),
    publication_date DATE,
    price NUMERIC(8,2),
    is_available BOOLEAN,
    acquisition_timestamp TIMESTAMP WITHOUT TIME ZONE
);

CREATE TABLE student_book_loans (
    loan_id SERIAL PRIMARY KEY,
    student_id INTEGER,
    book_id INTEGER,
    loan_date DATE,
    due_date DATE,
    return_date DATE,
    fine_amount NUMERIC(8,2),
    loan_status VARCHAR(20)
);

ALTER TABLE professors ADD COLUMN department_id INTEGER;
ALTER TABLE students ADD COLUMN advisor_id INTEGER;
ALTER TABLE courses ADD COLUMN department_id INTEGER;

CREATE TABLE grade_scale (
    grade_id SERIAL PRIMARY KEY,
    letter_grade CHAR(2),
    min_percentage NUMERIC(4,1),
    max_percentage NUMERIC(4,1),
    gpa_points NUMERIC(3,2)
);

CREATE TABLE semester_calendar (
    semester_id SERIAL PRIMARY KEY,
    semester_name VARCHAR(20),
    academic_year INTEGER,
    start_date DATE,
    end_date DATE,
    registration_deadline TIMESTAMPTZ,
    is_current BOOLEAN
);


DROP TABLE IF EXISTS student_book_loans;
DROP TABLE IF EXISTS library_books;
DROP TABLE IF EXISTS grade_scale;


CREATE TABLE grade_scale (
    grade_id SERIAL PRIMARY KEY,
    letter_grade CHAR(2),
    min_percentage NUMERIC(4,1),
    max_percentage NUMERIC(4,1),
    gpa_points NUMERIC(3,2),
    description TEXT
);

DROP TABLE IF EXISTS semester_calendar CASCADE;
CREATE TABLE semester_calendar (
    semester_id SERIAL PRIMARY KEY,
    semester_name VARCHAR(20),
    academic_year INTEGER,
    start_date DATE,
    end_date DATE,
    registration_deadline TIMESTAMPTZ,
    is_current BOOLEAN
);

DROP DATABASE IF EXISTS university_test;
DROP DATABASE IF EXISTS university_distributed;
CREATE DATABASE university_backup TEMPLATE university_main;
