-- phpMyAdmin SQL Dump
-- version 4.8.5
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Jul 22, 2021 at 01:39 PM
-- Server version: 10.1.38-MariaDB
-- PHP Version: 5.6.40

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `opensis`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `ATTENDANCE_CALC` (IN `cp_id` INT)  BEGIN
 DELETE FROM missing_attendance WHERE COURSE_PERIOD_ID=cp_id;
 INSERT INTO missing_attendance(SCHOOL_ID,SYEAR,SCHOOL_DATE,COURSE_PERIOD_ID,PERIOD_ID,TEACHER_ID,SECONDARY_TEACHER_ID) 
         SELECT s.ID AS SCHOOL_ID,acc.SYEAR,acc.SCHOOL_DATE,cp.COURSE_PERIOD_ID,cpv.PERIOD_ID, IF(tra.course_period_id=cp.course_period_id AND acc.school_date<tra.assign_date =true,tra.pre_teacher_id,cp.teacher_id) AS TEACHER_ID,
         cp.SECONDARY_TEACHER_ID FROM attendance_calendar acc INNER JOIN course_periods cp ON cp.CALENDAR_ID=acc.CALENDAR_ID INNER JOIN course_period_var cpv ON cp.COURSE_PERIOD_ID=cpv.COURSE_PERIOD_ID 
         AND (cpv.COURSE_PERIOD_DATE IS NULL AND position(substring('UMTWHFS' FROM DAYOFWEEK(acc.SCHOOL_DATE) FOR 1) IN cpv.DAYS)>0 OR cpv.COURSE_PERIOD_DATE IS NOT NULL AND cpv.COURSE_PERIOD_DATE=acc.SCHOOL_DATE) 
         INNER JOIN schools s ON s.ID=acc.SCHOOL_ID LEFT JOIN teacher_reassignment tra ON (cp.course_period_id=tra.course_period_id) INNER JOIN schedule sch ON sch.COURSE_PERIOD_ID=cp.COURSE_PERIOD_ID 
         AND sch.student_id IN(SELECT student_id FROM student_enrollment se WHERE sch.school_id=se.school_id AND sch.syear=se.syear AND start_date<=acc.school_date AND (end_date IS NULL OR end_date>=acc.school_date))
         AND (cp.MARKING_PERIOD_ID IS NOT NULL AND cp.MARKING_PERIOD_ID IN (SELECT MARKING_PERIOD_ID FROM school_years WHERE SCHOOL_ID=acc.SCHOOL_ID AND acc.SCHOOL_DATE BETWEEN START_DATE AND END_DATE UNION SELECT MARKING_PERIOD_ID FROM school_semesters WHERE SCHOOL_ID=acc.SCHOOL_ID AND acc.SCHOOL_DATE BETWEEN START_DATE AND END_DATE UNION SELECT MARKING_PERIOD_ID FROM school_quarters WHERE SCHOOL_ID=acc.SCHOOL_ID AND acc.SCHOOL_DATE BETWEEN START_DATE AND END_DATE) OR (cp.MARKING_PERIOD_ID IS NULL AND acc.school_date BETWEEN cp.begin_date AND cp.end_date))
         AND sch.START_DATE<=acc.SCHOOL_DATE AND (sch.END_DATE IS NULL OR sch.END_DATE>=acc.SCHOOL_DATE ) AND cpv.DOES_ATTENDANCE='Y' AND acc.SCHOOL_DATE<CURDATE() AND cp.course_period_id=cp_id 
         AND NOT EXISTS (SELECT '' FROM  attendance_completed ac WHERE ac.SCHOOL_DATE=acc.SCHOOL_DATE AND ac.COURSE_PERIOD_ID=cp.COURSE_PERIOD_ID AND ac.PERIOD_ID=cpv.PERIOD_ID 
         AND IF(tra.course_period_id=cp.course_period_id AND acc.school_date<=tra.assign_date =true,ac.staff_id=tra.pre_teacher_id,ac.staff_id=cp.teacher_id)) 
         GROUP BY acc.SCHOOL_DATE,cp.COURSE_PERIOD_ID,cp.TEACHER_ID,cpv.PERIOD_ID;
 END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ATTENDANCE_CALC_BY_DATE` (IN `sch_dt` DATE, IN `year` INT, IN `school` INT)  BEGIN
  DELETE FROM missing_attendance WHERE SCHOOL_DATE=sch_dt AND SYEAR=year AND SCHOOL_ID=school;
  INSERT INTO missing_attendance(SCHOOL_ID,SYEAR,SCHOOL_DATE,COURSE_PERIOD_ID,PERIOD_ID,TEACHER_ID,SECONDARY_TEACHER_ID) SELECT s.ID AS SCHOOL_ID,acc.SYEAR,acc.SCHOOL_DATE,cp.COURSE_PERIOD_ID,cpv.PERIOD_ID, IF(tra.course_period_id=cp.course_period_id AND acc.school_date<tra.assign_date =true,tra.pre_teacher_id,cp.teacher_id) AS TEACHER_ID,cp.SECONDARY_TEACHER_ID FROM attendance_calendar acc INNER JOIN marking_periods mp ON mp.SYEAR=acc.SYEAR AND mp.SCHOOL_ID=acc.SCHOOL_ID AND acc.SCHOOL_DATE BETWEEN mp.START_DATE AND mp.END_DATE INNER JOIN course_periods cp ON cp.MARKING_PERIOD_ID=mp.MARKING_PERIOD_ID  AND cp.CALENDAR_ID=acc.CALENDAR_ID INNER JOIN course_period_var cpv ON cp.COURSE_PERIOD_ID=cpv.COURSE_PERIOD_ID AND cpv.DOES_ATTENDANCE='Y' LEFT JOIN teacher_reassignment tra ON (cp.course_period_id=tra.course_period_id) INNER JOIN school_periods sp ON sp.SYEAR=acc.SYEAR AND sp.SCHOOL_ID=acc.SCHOOL_ID AND sp.PERIOD_ID=cpv.PERIOD_ID AND (sp.BLOCK IS NULL AND position(substring('UMTWHFS' FROM DAYOFWEEK(acc.SCHOOL_DATE) FOR 1) IN cpv.DAYS)>0 OR sp.BLOCK IS NOT NULL AND acc.BLOCK IS NOT NULL AND sp.BLOCK=acc.BLOCK) INNER JOIN schools s ON s.ID=acc.SCHOOL_ID INNER JOIN schedule sch ON sch.COURSE_PERIOD_ID=cp.COURSE_PERIOD_ID AND sch.START_DATE<=acc.SCHOOL_DATE AND (sch.END_DATE IS NULL OR sch.END_DATE>=acc.SCHOOL_DATE )  LEFT JOIN attendance_completed ac ON ac.SCHOOL_DATE=acc.SCHOOL_DATE AND IF(tra.course_period_id=cp.course_period_id AND acc.school_date<tra.assign_date =true,ac.staff_id=tra.pre_teacher_id,ac.staff_id=cp.teacher_id) AND ac.PERIOD_ID=sp.PERIOD_ID WHERE acc.SYEAR=year AND acc.SCHOOL_ID=school AND (acc.MINUTES IS NOT NULL AND acc.MINUTES>0) AND acc.SCHOOL_DATE=sch_dt AND ac.STAFF_ID IS NULL GROUP BY s.TITLE,acc.SCHOOL_DATE,cp.TITLE,cp.COURSE_PERIOD_ID,cp.TEACHER_ID;
 END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SEAT_COUNT` ()  BEGIN
 UPDATE course_periods SET filled_seats=filled_seats-1 WHERE COURSE_PERIOD_ID IN (SELECT COURSE_PERIOD_ID FROM schedule WHERE end_date IS NOT NULL AND end_date < CURDATE() AND dropped='N');
 UPDATE schedule SET dropped='Y' WHERE end_date IS NOT NULL AND end_date < CURDATE() AND dropped='N';
 END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SEAT_FILL` ()  BEGIN
 UPDATE course_periods SET filled_seats=filled_seats+1 WHERE COURSE_PERIOD_ID IN (SELECT COURSE_PERIOD_ID FROM schedule WHERE dropped='Y' AND ( end_date IS NULL OR end_date >= CURDATE()));
 UPDATE schedule SET dropped='N' WHERE dropped='Y' AND ( end_date IS NULL OR end_date >= CURDATE()) ;
 END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `TEACHER_REASSIGNMENT` ()  BEGIN
 UPDATE course_periods cp,course_period_var cpv,teacher_reassignment tr,school_periods sp,marking_periods mp,staff st SET cp.title=CONCAT(sp.title,IF(cp.mp<>'FY',CONCAT(' - ',mp.short_name),''),IF(CHAR_LENGTH(cpv.days)<5,CONCAT(' - ',cpv.days),''),' - ',cp.short_name,' - ',CONCAT_WS(' ',st.first_name,st.middle_name,st.last_name)), cp.teacher_id=tr.teacher_id WHERE cpv.period_id=sp.period_id and cp.marking_period_id=mp.marking_period_id and st.staff_id=tr.teacher_id and cp.course_period_id=tr.course_period_id AND assign_date <= CURDATE() AND updated='N' AND cp.COURSE_PERIOD_ID=cpv.COURSE_PERIOD_ID; 
  UPDATE teacher_reassignment SET updated='Y' WHERE assign_date <=CURDATE() AND updated='N';
 END$$

--
-- Functions
--
CREATE DEFINER=`root`@`localhost` FUNCTION `CALC_CUM_GPA_MP` (`mp_id` INT) RETURNS INT(11) BEGIN
 
 DECLARE req_mp INT DEFAULT 0;
 DECLARE done INT DEFAULT 0;
 DECLARE gp_points DECIMAL(10,2);
 DECLARE student_id INT;
 DECLARE gp_points_weighted DECIMAL(10,2);
 DECLARE divisor DECIMAL(10,2);
 DECLARE credit_earned DECIMAL(10,2);
 DECLARE cgpa DECIMAL(10,2);
 
 DECLARE cur1 CURSOR FOR
    SELECT srcg.student_id,
                   IF(ISNULL(sum(srcg.unweighted_gp)),  (SUM(srcg.weighted_gp*srcg.credit_earned)),
                       IF(ISNULL(sum(srcg.weighted_gp)), SUM(srcg.unweighted_gp*srcg.credit_earned),
                          ( SUM(srcg.unweighted_gp*srcg.credit_attempted)+ SUM(srcg.weighted_gp*srcg.credit_earned))
                         ))as gp_points,
 
                       SUM(srcg.weighted_gp*srcg.credit_earned) as gp_points_weighted,
                       SUM(srcg.credit_attempted) as divisor,
                       SUM(srcg.credit_earned) as credit_earned,
    		      IF(ISNULL(sum(srcg.unweighted_gp)),  (SUM(srcg.weighted_gp*srcg.credit_earned))/ sum(srcg.credit_attempted),
                           IF(ISNULL(sum(srcg.weighted_gp)), SUM(srcg.unweighted_gp*srcg.credit_earned)/sum(srcg.credit_attempted),
                              ( SUM(srcg.unweighted_gp*srcg.credit_attempted)+ SUM(srcg.weighted_gp*srcg.credit_earned))/sum(srcg.credit_attempted)
                             )
                          ) as cgpa
 
             FROM marking_periods mp,temp_cum_gpa srcg
             INNER JOIN schools sc ON sc.id=srcg.school_id
             WHERE srcg.marking_period_id= mp.marking_period_id AND srcg.gp_scale<>0 AND srcg.marking_period_id NOT LIKE 'E%'
             AND mp.marking_period_id IN (SELECT marking_period_id  FROM marking_periods WHERE mp_type=req_mp )
             GROUP BY srcg.student_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
 
 
   CREATE TEMPORARY TABLE tmp(
     student_id int,
     sum_weighted_factors decimal(10,6),
     count_weighted_factors int,
     sum_unweighted_factors decimal(10,6),
     count_unweighted_factors int,
     grade_level_short varchar(10)
   );
 
   INSERT INTO tmp(student_id,sum_weighted_factors,count_weighted_factors,
     sum_unweighted_factors, count_unweighted_factors,grade_level_short)
   SELECT
     srcg.student_id,
     SUM(srcg.weighted_gp/s.reporting_gp_scale) AS sum_weighted_factors,
     COUNT(*) AS count_weighted_factors,
     SUM(srcg.unweighted_gp/srcg.gp_scale) AS sum_unweighted_factors,
     COUNT(*) AS count_unweighted_factors,
     eg.short_name
   FROM student_report_card_grades srcg
   INNER JOIN schools s ON s.id=srcg.school_id
   LEFT JOIN enroll_grade eg on eg.student_id=srcg.student_id AND eg.syear=srcg.syear AND eg.school_id=srcg.school_id
   WHERE srcg.marking_period_id=mp_id AND srcg.gp_scale<>0 AND srcg.marking_period_id NOT LIKE 'E%'
   GROUP BY srcg.student_id,eg.short_name;
 
  /* UPDATE student_mp_stats sms
     INNER JOIN tmp t on t.student_id=sms.student_id
   SET
     sms.sum_weighted_factors=t.sum_weighted_factors,
     sms.count_weighted_factors=t.count_weighted_factors,
     sms.sum_unweighted_factors=t.sum_unweighted_factors,
     sms.count_unweighted_factors=t.count_unweighted_factors
   WHERE sms.marking_period_id=mp_id;*/
 
   /*INSERT INTO student_mp_stats(student_id,marking_period_id,sum_weighted_factors,count_weighted_factors,
     sum_unweighted_factors,count_unweighted_factors,grade_level_short)
   SELECT
       t.student_id,
       mp_id,
       t.sum_weighted_factors,
       t.count_weighted_factors,
       t.sum_unweighted_factors,
       t.count_unweighted_factors,
       t.grade_level_short
     FROM tmp t
     LEFT JOIN student_mp_stats sms ON sms.student_id=t.student_id AND sms.marking_period_id=mp_id
     WHERE sms.student_id IS NULL;*/
 
   INSERT INTO student_gpa_calculated (student_id,marking_period_id)
   SELECT
       t.student_id,
       mp_id
     FROM tmp t
     LEFT JOIN student_gpa_calculated sms ON sms.student_id=t.student_id AND sms.marking_period_id=mp_id
     WHERE sms.student_id IS NULL;
 
 /*  UPDATE student_mp_stats g
     INNER JOIN (
 	SELECT s.student_id,
 		SUM(s.weighted_gp/sc.reporting_gp_scale)/COUNT(*) AS cum_weighted_factor,
 		SUM(s.unweighted_gp/s.gp_scale)/COUNT(*) AS cum_unweighted_factor
 	FROM student_report_card_grades s
 	INNER JOIN schools sc ON sc.id=s.school_id
 	LEFT JOIN course_periods p ON p.course_period_id=s.course_period_id
 	WHERE p.marking_period_id IS NULL OR p.marking_period_id=s.marking_period_id
 	GROUP BY student_id) gg ON gg.student_id=g.student_id
     SET g.cum_unweighted_factor=gg.cum_unweighted_factor, g.cum_weighted_factor=gg.cum_weighted_factor;*/
 
   UPDATE student_gpa_calculated g
     INNER JOIN (
 	SELECT s.student_id,
 		SUM(s.weighted_gp/sc.reporting_gp_scale)/COUNT(*) AS cum_weighted_factor,
 		SUM(s.unweighted_gp/s.gp_scale)/COUNT(*) AS cum_unweighted_factor
 	FROM student_report_card_grades s
 	INNER JOIN schools sc ON sc.id=s.school_id
 	LEFT JOIN course_periods p ON p.course_period_id=s.course_period_id
 	WHERE p.marking_period_id IS NULL OR p.marking_period_id=s.marking_period_id
 	GROUP BY student_id) gg ON gg.student_id=g.student_id
     SET g.cum_unweighted_factor=gg.cum_unweighted_factor;
 
 
     SELECT mp_type INTO @mp_type FROM marking_periods WHERE marking_period_id=mp_id;
 
  
     IF @mp_type = 'quarter'  THEN
            set req_mp = 'quarter';
     ELSEIF @mp_type = 'semester'  THEN
         IF EXISTS(SELECT student_id FROM student_report_card_grades srcg WHERE srcg.marking_period_id IN (SELECT marking_period_id  FROM marking_periods WHERE mp_type=@mp_type)) THEN
            set req_mp  = 'semester';
        ELSE
            set req_mp  = 'quarter';
         END IF;
    ELSEIF @mp_type = 'year'  THEN
            IF EXISTS(SELECT student_id FROM student_report_card_grades srcg WHERE srcg.MARKING_PERIOD_ID IN (SELECT marking_period_id  FROM marking_periods WHERE mp_type='semester')
                      UNION  SELECT student_id FROM student_report_card_grades srcg WHERE srcg.MARKING_PERIOD_ID IN (SELECT marking_period_id  FROM history_marking_periods WHERE mp_type='semester')
                      ) THEN
                  set req_mp  = 'semester';
          
           ELSE
                   set req_mp  = 'quarter ';
             END IF;
    END IF;
 
 
 
 open cur1;
 fetch cur1 into student_id, gp_points,gp_points_weighted,divisor,credit_earned,cgpa;
 
 while not done DO
     IF EXISTS(SELECT student_id FROM student_gpa_calculated WHERE  student_gpa_calculated.student_id=student_id) THEN
     UPDATE student_gpa_calculated gc
                SET gc.cgpa=cgpa where gc.student_id=student_id and gc.marking_period_id=mp_id;
     ELSE
         INSERT INTO student_gpa_running(student_id,marking_period_id,mp,cgpa)
           VALUES(student_id,mp_id,mp_id,cgpa);
     END IF;
 fetch cur1 into student_id, gp_points,gp_points_weighted,divisor,credit_earned,cgpa;
 END WHILE;
 /*while not done DO
     IF EXISTS(SELECT student_id FROM student_gpa_running WHERE  student_gpa_running.student_id=student_id) THEN
     UPDATE student_gpa_running gc
                SET gpa_points=gp_points,gpa_points_weighted=gp_points_weighted,gc.divisor=divisor,credit_earned=credit_earned,gc.cgpa=cgpa where gc.student_id=student_id;
     ELSE
         INSERT INTO student_gpa_running(student_id,marking_period_id,gpa_points,gpa_points_weighted, divisor,credit_earned,cgpa)
           VALUES(student_id,mp_id,gp_points,gp_points_weighted,divisor,credit_earned,cgpa);
     END IF;
 fetch cur1 into student_id, gp_points,gp_points_weighted,divisor,credit_earned,cgpa;
 END WHILE;*/
 CLOSE cur1;
 
 
 RETURN 1;
 
 END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `CALC_GPA_MP` (`s_id` INT, `mp_id` INT) RETURNS INT(11) BEGIN
   SELECT
     SUM(srcg.weighted_gp/s.reporting_gp_scale) AS sum_weighted_factors, 
     COUNT(*) AS count_weighted_factors,                        
     SUM(srcg.unweighted_gp/srcg.gp_scale) AS sum_unweighted_factors, 
     COUNT(*) AS count_unweighted_factors,
    IF(ISNULL(sum(srcg.unweighted_gp)),  (SUM(srcg.weighted_gp*srcg.credit_earned))/ sum(srcg.credit_attempted),
                       IF(ISNULL(sum(srcg.weighted_gp)), SUM(srcg.unweighted_gp*srcg.credit_earned)/sum(srcg.credit_attempted),
                          ( SUM(srcg.unweighted_gp*srcg.credit_attempted)+ SUM(srcg.weighted_gp*srcg.credit_earned))/sum(srcg.credit_attempted)
                         )
       ),
     
     SUM(srcg.weighted_gp*srcg.credit_earned)/(select sum(sg.credit_attempted) from student_report_card_grades sg where sg.marking_period_id=mp_id AND sg.student_id=s_id
                                                   AND sg.weighted_gp  IS NOT NULL  AND sg.unweighted_gp IS NULL AND sg.course_period_id IS NOT NULL GROUP BY sg.student_id, sg.marking_period_id) ,
     SUM(srcg.unweighted_gp*srcg.credit_earned)/ (select sum(sg.credit_attempted) from student_report_card_grades sg where sg.marking_period_id=mp_id AND sg.student_id=s_id
                                                      AND sg.unweighted_gp  IS NOT NULL  AND sg.weighted_gp IS NULL AND sg.course_period_id IS NOT NULL GROUP BY sg.student_id, sg.marking_period_id) ,
     eg.short_name
   INTO
     @sum_weighted_factors,
     @count_weighted_factors,
     @sum_unweighted_factors,
     @count_unweighted_factors,
     @gpa,
     @weighted_gpa,
     @unweighted_gpa,
     @grade_level_short
   FROM student_report_card_grades srcg
   INNER JOIN schools s ON s.id=srcg.school_id
 INNER JOIN course_periods cp ON cp.course_period_id=srcg.course_period_id
 INNER JOIN report_card_grade_scales rcgs ON rcgs.id=cp.grade_scale_id
   LEFT JOIN enroll_grade eg on eg.student_id=srcg.student_id AND eg.syear=srcg.syear AND eg.school_id=srcg.school_id
   WHERE srcg.marking_period_id=mp_id AND srcg.student_id=s_id AND srcg.gp_scale<>0 AND srcg.course_period_id IS NOT NULL AND (rcgs.gpa_cal='Y' OR cp.grade_scale_id IS NULL) AND srcg.marking_period_id NOT LIKE 'E%'
   AND (eg.START_DATE IS NULL OR eg.START_DATE='0000-00-00'  OR eg.START_DATE<=CURDATE()) AND (eg.END_DATE IS NULL OR eg.END_DATE='0000-00-00'  OR eg.END_DATE>=CURDATE())  
   GROUP BY srcg.student_id,eg.short_name;
 
   /*IF EXISTS(SELECT NULL FROM student_mp_stats WHERE marking_period_id=mp_id AND student_id=s_id) THEN
     UPDATE student_mp_stats
     SET
       sum_weighted_factors=@sum_weighted_factors,
       count_weighted_factors=@count_weighted_factors,
       sum_unweighted_factors=@sum_unweighted_factors,
       count_unweighted_factors=@count_unweighted_factors
     WHERE marking_period_id=mp_id AND student_id=s_id;
   ELSE
     INSERT INTO student_mp_stats(student_id,marking_period_id,sum_weighted_factors,count_weighted_factors,
         sum_unweighted_factors,count_unweighted_factors,grade_level_short)
       VALUES(s_id,mp_id,@sum_weighted_factors,@count_weighted_factors,@sum_unweighted_factors,
         @count_unweighted_factors,@grade_level_short);
   END IF;
 
   UPDATE student_mp_stats g
     INNER JOIN (
 	SELECT s.student_id,
 		SUM(s.weighted_gp/sc.reporting_gp_scale)/COUNT(*) AS cum_weighted_factor,
 		SUM(s.unweighted_gp/s.gp_scale)/COUNT(*) AS cum_unweighted_factor
 	FROM student_report_card_grades s
 	INNER JOIN schools sc ON sc.id=s.school_id
 	LEFT JOIN course_periods p ON p.course_period_id=s.course_period_id
 	WHERE s.course_period_id IS NOT NULL AND p.marking_period_id IS NULL OR p.marking_period_id=s.marking_period_id
 	GROUP BY student_id) gg ON gg.student_id=g.student_id
     SET g.cum_unweighted_factor=gg.cum_unweighted_factor, g.cum_weighted_factor=gg.cum_weighted_factor
     WHERE g.student_id=s_id;*/
 
   IF NOT EXISTS(SELECT NULL FROM student_gpa_calculated WHERE marking_period_id=mp_id AND student_id=s_id) THEN
     INSERT INTO student_gpa_calculated (student_id,marking_period_id)
       VALUES(s_id,mp_id);
   END IF;
 
   UPDATE student_gpa_calculated g
     INNER JOIN (
 	SELECT s.student_id,
 		SUM(s.unweighted_gp/s.gp_scale)/COUNT(*) AS cum_unweighted_factor
 	FROM student_report_card_grades s
 	INNER JOIN schools sc ON sc.id=s.school_id
 	LEFT JOIN course_periods p ON p.course_period_id=s.course_period_id
 	WHERE s.course_period_id IS NOT NULL AND p.marking_period_id IS NULL OR p.marking_period_id=s.marking_period_id
 	GROUP BY student_id) gg ON gg.student_id=g.student_id
     SET g.cum_unweighted_factor=gg.cum_unweighted_factor
     WHERE g.student_id=s_id;
 
 IF EXISTS(SELECT student_id FROM student_gpa_calculated WHERE marking_period_id=mp_id AND student_id=s_id) THEN
     UPDATE student_gpa_calculated
     SET
       gpa            = @gpa,
       weighted_gpa   =@weighted_gpa,
       unweighted_gpa =@unweighted_gpa
 
     WHERE marking_period_id=mp_id AND student_id=s_id;
   ELSE
         INSERT INTO student_gpa_calculated(student_id,marking_period_id,mp,gpa,weighted_gpa,unweighted_gpa,grade_level_short)
             VALUES(s_id,mp_id,mp_id,@gpa,@weighted_gpa,@unweighted_gpa,@grade_level_short  );
                    
 
    END IF;
 
   RETURN 0;
 END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `CREDIT` (`cp_id` INT, `mp_id` INT) RETURNS DECIMAL(10,3) BEGIN
   SELECT credits,IF(ISNULL(marking_period_id),'Y',marking_period_id),mp INTO @credits,@marking_period_id,@mp FROM course_periods WHERE course_period_id=cp_id;
    SELECT mp_type INTO @mp_type FROM marking_periods WHERE marking_period_id=mp_id;
   
 IF @marking_period_id='Y' THEN 
 RETURN @credits;
    ELSEIF   @marking_period_id=mp_id THEN
     RETURN @credits;
 ELSEIF @mp = 'QTR' AND @mp_type = 'semester' THEN
      RETURN @credits;
    ELSEIF @mp='FY' AND @mp_type='semester' THEN
      SELECT COUNT(*) INTO @val FROM marking_periods WHERE parent_id=@marking_period_id GROUP BY parent_id;
    ELSEIF @mp = 'FY' AND @mp_type = 'quarter' THEN
      SELECT count(*) into @val FROM marking_periods WHERE grandparent_id=@marking_period_id GROUP BY grandparent_id;
    ELSEIF @mp = 'SEM' AND @mp_type = 'quarter' THEN
      SELECT count(*) into @val FROM marking_periods WHERE parent_id=@marking_period_id GROUP BY parent_id;
    ELSE
      RETURN 0;
    END IF;
    IF @val > 0 THEN
      RETURN @credits/@val;
    END IF;
    RETURN 0;
 END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_marking_period_seq` () RETURNS INT(11) BEGIN
   INSERT INTO marking_period_id_generator VALUES(NULL);
 RETURN LAST_INSERT_ID();
 END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `RE_CALC_GPA_MP` (`s_id` INT, `mp_id` INT, `sy` INT, `sch_id` INT) RETURNS INT(11) BEGIN
   SELECT
     SUM(srcg.weighted_gp/s.reporting_gp_scale) AS sum_weighted_factors, 
     COUNT(*) AS count_weighted_factors,                        
     SUM(srcg.unweighted_gp/srcg.gp_scale) AS sum_unweighted_factors, 
     COUNT(*) AS count_unweighted_factors,
    IF(ISNULL(sum(srcg.unweighted_gp)),  (SUM(srcg.weighted_gp*srcg.credit_earned))/ sum(srcg.credit_attempted),
                       IF(ISNULL(sum(srcg.weighted_gp)), SUM(srcg.unweighted_gp*srcg.credit_earned)/sum(srcg.credit_attempted),
                          ( SUM(srcg.unweighted_gp*srcg.credit_attempted)+ SUM(srcg.weighted_gp*srcg.credit_earned))/sum(srcg.credit_attempted)
                         )
       ),
     
     SUM(srcg.weighted_gp*srcg.credit_earned)/(select sum(sg.credit_attempted) from student_report_card_grades sg where sg.marking_period_id=mp_id AND sg.student_id=s_id
                                                   AND sg.weighted_gp  IS NOT NULL  AND sg.unweighted_gp IS NULL GROUP BY sg.student_id, sg.marking_period_id) ,
     SUM(srcg.unweighted_gp*srcg.credit_earned)/ (select sum(sg.credit_attempted) from student_report_card_grades sg where sg.marking_period_id=mp_id AND sg.student_id=s_id
                                                      AND sg.unweighted_gp  IS NOT NULL  AND sg.weighted_gp IS NULL GROUP BY sg.student_id, sg.marking_period_id) ,
     eg.short_name
   INTO
     @sum_weighted_factors,
     @count_weighted_factors,
     @sum_unweighted_factors,
     @count_unweighted_factors,
     @gpa,
     @weighted_gpa,
     @unweighted_gpa,
     @grade_level_short
   FROM student_report_card_grades srcg
   INNER JOIN schools s ON s.id=srcg.school_id
   LEFT JOIN enroll_grade eg on eg.student_id=srcg.student_id AND eg.syear=srcg.syear AND eg.school_id=srcg.school_id
   WHERE srcg.marking_period_id=mp_id AND srcg.student_id=s_id AND srcg.gp_scale<>0 AND srcg.school_id=sch_id AND srcg.syear=sy AND srcg.marking_period_id NOT LIKE 'E%'
 AND (eg.START_DATE IS NULL OR eg.START_DATE='0000-00-00'  OR eg.START_DATE<=CURDATE()) AND (eg.END_DATE IS NULL OR eg.END_DATE='0000-00-00'  OR eg.END_DATE>=CURDATE())
   GROUP BY srcg.student_id,eg.short_name;
 
   /*IF EXISTS(SELECT NULL FROM student_mp_stats WHERE marking_period_id=mp_id AND student_id=s_id) THEN
     UPDATE student_mp_stats
     SET
       sum_weighted_factors=@sum_weighted_factors,
       count_weighted_factors=@count_weighted_factors,
       sum_unweighted_factors=@sum_unweighted_factors,
       count_unweighted_factors=@count_unweighted_factors
     WHERE marking_period_id=mp_id AND student_id=s_id;
   ELSE
     INSERT INTO student_mp_stats(student_id,marking_period_id,sum_weighted_factors,count_weighted_factors,
         sum_unweighted_factors,count_unweighted_factors,grade_level_short)
       VALUES(s_id,mp_id,@sum_weighted_factors,@count_weighted_factors,@sum_unweighted_factors,
         @count_unweighted_factors,@grade_level_short);
   END IF;
 
   UPDATE student_mp_stats g
     INNER JOIN (
 	SELECT s.student_id,
 		SUM(s.weighted_gp/sc.reporting_gp_scale)/COUNT(*) AS cum_weighted_factor,
 		SUM(s.unweighted_gp/s.gp_scale)/COUNT(*) AS cum_unweighted_factor
 	FROM student_report_card_grades s
 	INNER JOIN schools sc ON sc.id=s.school_id
 	LEFT JOIN course_periods p ON p.course_period_id=s.course_period_id
 	WHERE p.marking_period_id IS NULL OR p.marking_period_id=s.marking_period_id
 	GROUP BY student_id) gg ON gg.student_id=g.student_id
     SET g.cum_unweighted_factor=gg.cum_unweighted_factor, g.cum_weighted_factor=gg.cum_weighted_factor
     WHERE g.student_id=s_id;*/
 
   IF NOT EXISTS(SELECT NULL FROM student_gpa_calculated WHERE marking_period_id=mp_id AND student_id=s_id) THEN
     INSERT INTO student_mp_stats(student_id,marking_period_id)
       VALUES(s_id,mp_id);
   END IF;
 
   UPDATE student_gpa_calculated g
     INNER JOIN (
 	SELECT s.student_id,
 		SUM(s.unweighted_gp/s.gp_scale)/COUNT(*) AS cum_unweighted_factor
 	FROM student_report_card_grades s
 	INNER JOIN schools sc ON sc.id=s.school_id
 	LEFT JOIN course_periods p ON p.course_period_id=s.course_period_id
 	WHERE p.marking_period_id IS NULL OR p.marking_period_id=s.marking_period_id
 	GROUP BY student_id) gg ON gg.student_id=g.student_id
     SET g.cum_unweighted_factor=gg.cum_unweighted_factor
     WHERE g.student_id=s_id;
 
 IF EXISTS(SELECT student_id FROM student_gpa_calculated WHERE marking_period_id=mp_id AND student_id=s_id) THEN
     UPDATE student_gpa_calculated
     SET
       gpa            = @gpa,
       weighted_gpa   =@weighted_gpa,
       unweighted_gpa =@unweighted_gpa
 
     WHERE marking_period_id=mp_id AND student_id=s_id;
   ELSE
         INSERT INTO student_gpa_calculated(student_id,marking_period_id,mp,gpa,weighted_gpa,unweighted_gpa,grade_level_short)
             VALUES(s_id,mp_id,mp_id,@gpa,@weighted_gpa,@unweighted_gpa,@grade_level_short  );
                    
 
    END IF;
 
   RETURN 0;
 END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `SET_CLASS_RANK_MP` (`mp_id` INT) RETURNS INT(11) BEGIN
 
 DECLARE done INT DEFAULT 0;
 DECLARE marking_period_id INT;
 DECLARE student_id INT;
 DECLARE rank NUMERIC;
 
 declare cur1 cursor for
 select
   mp.marking_period_id,
   sgc.student_id,
  (select count(*)+1 
    from student_gpa_calculated sgc3
    where sgc3.gpa > sgc.gpa
      and sgc3.marking_period_id = mp.marking_period_id 
      and sgc3.student_id in (select distinct sgc2.student_id 
                                                 from student_gpa_calculated sgc2, student_enrollment se2
                                                 where sgc2.student_id = se2.student_id 
                                                 and sgc2.marking_period_id = mp.marking_period_id 
                                                 and se2.grade_id = se.grade_id
                                                 and se2.syear = se.syear
                                                 group by gpa
                                 )
   ) as rank
   from student_enrollment se, student_gpa_calculated sgc, marking_periods mp
   where se.student_id = sgc.student_id
     and sgc.marking_period_id = mp.marking_period_id
     and mp.marking_period_id = mp_id
     and se.syear = mp.syear
     and not sgc.gpa is null
   order by grade_id, rank;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
 
 open cur1;
 fetch cur1 into marking_period_id,student_id,rank;
 
 while not done DO
 	update student_gpa_calculated sgc
 	  set
 	    class_rank = rank
 	where sgc.marking_period_id = marking_period_id
 	  and sgc.student_id = student_id;
 	fetch cur1 into marking_period_id,student_id,rank;
 END WHILE;
 CLOSE cur1;
 
 RETURN 1;
 END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `STUDENT_DISABLE` (`stu_id` INT) RETURNS INT(1) BEGIN
 UPDATE students set is_disable ='Y' where (select end_date from student_enrollment where  student_id=stu_id ORDER BY id DESC LIMIT 1) IS NOT NULL AND (select end_date from student_enrollment where  student_id=stu_id ORDER BY id DESC LIMIT 1)< CURDATE() AND  student_id=stu_id;
 RETURN 1;
 END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `api_info`
--

CREATE TABLE `api_info` (
  `id` int(11) NOT NULL,
  `api_key` varchar(255) CHARACTER SET utf8 NOT NULL,
  `api_secret` varchar(255) CHARACTER SET utf8 NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `app`
--

CREATE TABLE `app` (
  `name` varchar(100) NOT NULL,
  `value` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `app`
--

INSERT INTO `app` (`name`, `value`) VALUES
('version', '7.6'),
('date', 'September 11, 2020'),
('build', '20200811001'),
('update', '0'),
('last_updated', 'September 11, 2020');

-- --------------------------------------------------------

--
-- Table structure for table `attendance_calendar`
--

CREATE TABLE `attendance_calendar` (
  `syear` decimal(4,0) NOT NULL,
  `school_id` decimal(10,0) NOT NULL,
  `school_date` date NOT NULL,
  `minutes` decimal(10,0) DEFAULT NULL,
  `block` varchar(10) DEFAULT NULL,
  `calendar_id` decimal(10,0) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Triggers `attendance_calendar`
--
DELIMITER $$
CREATE TRIGGER `td_cal_missing_attendance` AFTER DELETE ON `attendance_calendar` FOR EACH ROW DELETE mi.* FROM missing_attendance mi,course_periods cp WHERE mi.course_period_id=cp.course_period_id and cp.calendar_id=OLD.calendar_id AND mi.SCHOOL_DATE=OLD.school_date
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `ti_cal_missing_attendance` AFTER INSERT ON `attendance_calendar` FOR EACH ROW BEGIN
     DECLARE associations INT;
     SET associations = (SELECT COUNT(course_period_id) FROM `course_periods` WHERE calendar_id=NEW.calendar_id);
     IF associations>0 THEN
 	CALL ATTENDANCE_CALC_BY_DATE(NEW.school_date, NEW.syear,NEW.school_id);
     END IF;
 END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_codes`
--

CREATE TABLE `attendance_codes` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `short_name` varchar(10) DEFAULT NULL,
  `type` varchar(10) DEFAULT NULL,
  `state_code` varchar(1) DEFAULT NULL,
  `default_code` varchar(1) DEFAULT NULL,
  `table_name` decimal(10,0) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_code_categories`
--

CREATE TABLE `attendance_code_categories` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_completed`
--

CREATE TABLE `attendance_completed` (
  `staff_id` decimal(10,0) NOT NULL,
  `school_date` date NOT NULL,
  `period_id` decimal(10,0) NOT NULL,
  `course_period_id` int(11) NOT NULL,
  `cpv_id` int(11) NOT NULL,
  `substitute_staff_id` decimal(10,0) DEFAULT NULL,
  `is_taken_by_substitute_staff` char(1) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_day`
--

CREATE TABLE `attendance_day` (
  `student_id` decimal(10,0) NOT NULL,
  `school_date` date NOT NULL,
  `minutes_present` decimal(10,0) DEFAULT NULL,
  `state_value` decimal(2,1) DEFAULT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `marking_period_id` int(11) DEFAULT NULL,
  `comment` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_period`
--

CREATE TABLE `attendance_period` (
  `student_id` decimal(10,0) NOT NULL,
  `school_date` date NOT NULL,
  `period_id` decimal(10,0) NOT NULL,
  `attendance_code` decimal(10,0) DEFAULT NULL,
  `attendance_teacher_code` decimal(10,0) DEFAULT NULL,
  `attendance_reason` varchar(100) DEFAULT NULL,
  `admin` varchar(1) DEFAULT NULL,
  `course_period_id` decimal(10,0) NOT NULL,
  `marking_period_id` int(11) DEFAULT NULL,
  `comment` varchar(100) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `calendar_events`
--

CREATE TABLE `calendar_events` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `calendar_id` decimal(10,0) DEFAULT NULL,
  `school_date` date DEFAULT NULL,
  `title` varchar(50) DEFAULT NULL,
  `description` text,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `calendar_events_visibility`
--

CREATE TABLE `calendar_events_visibility` (
  `calendar_id` int(11) NOT NULL,
  `profile_id` int(11) DEFAULT NULL,
  `profile` varchar(50) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `courses`
--

CREATE TABLE `courses` (
  `syear` decimal(4,0) NOT NULL,
  `course_id` int(8) NOT NULL,
  `subject_id` decimal(10,0) NOT NULL,
  `school_id` decimal(10,0) NOT NULL,
  `grade_level` decimal(10,0) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `short_name` varchar(25) DEFAULT NULL,
  `rollover_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Stand-in structure for view `course_details`
-- (See below for the actual view)
--
CREATE TABLE `course_details` (
`school_id` decimal(10,0)
,`syear` int(4)
,`marking_period_id` int(11)
,`subject_id` decimal(10,0)
,`course_id` decimal(10,0)
,`course_period_id` int(11)
,`teacher_id` int(11)
,`secondary_teacher_id` int(11)
,`course_title` varchar(100)
,`cp_title` varchar(100)
,`grade_scale_id` int(11)
,`mp` varchar(3)
,`credits` decimal(10,3)
,`begin_date` date
,`end_date` date
);

-- --------------------------------------------------------

--
-- Table structure for table `course_periods`
--

CREATE TABLE `course_periods` (
  `syear` int(4) NOT NULL,
  `school_id` decimal(10,0) NOT NULL,
  `course_period_id` int(11) NOT NULL,
  `course_id` decimal(10,0) NOT NULL,
  `course_weight` varchar(10) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `short_name` text,
  `mp` varchar(3) DEFAULT NULL,
  `marking_period_id` int(11) DEFAULT NULL,
  `begin_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `teacher_id` int(11) DEFAULT NULL,
  `secondary_teacher_id` int(11) DEFAULT NULL,
  `total_seats` int(11) DEFAULT NULL,
  `filled_seats` decimal(10,0) NOT NULL DEFAULT '0',
  `does_honor_roll` varchar(1) DEFAULT NULL,
  `does_class_rank` varchar(1) DEFAULT NULL,
  `gender_restriction` varchar(1) DEFAULT NULL,
  `house_restriction` varchar(1) DEFAULT NULL,
  `availability` int(11) DEFAULT NULL,
  `parent_id` int(11) DEFAULT NULL,
  `calendar_id` int(11) DEFAULT NULL,
  `half_day` varchar(1) DEFAULT NULL,
  `does_breakoff` varchar(1) DEFAULT NULL,
  `rollover_id` int(11) DEFAULT NULL,
  `grade_scale_id` int(11) DEFAULT NULL,
  `credits` decimal(10,3) DEFAULT NULL,
  `schedule_type` enum('FIXED','VARIABLE','BLOCKED') DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_by` int(11) NOT NULL,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Triggers `course_periods`
--
DELIMITER $$
CREATE TRIGGER `td_course_periods` AFTER DELETE ON `course_periods` FOR EACH ROW BEGIN
 	DELETE FROM course_period_var WHERE course_period_id=OLD.course_period_id;
 END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `tu_course_periods` AFTER UPDATE ON `course_periods` FOR EACH ROW BEGIN
 	CALL ATTENDANCE_CALC(NEW.course_period_id);
 END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `course_period_var`
--

CREATE TABLE `course_period_var` (
  `id` int(11) NOT NULL,
  `course_period_id` int(11) NOT NULL,
  `days` varchar(7) DEFAULT NULL,
  `course_period_date` date DEFAULT NULL,
  `period_id` int(11) NOT NULL,
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `room_id` int(11) NOT NULL,
  `does_attendance` varchar(1) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Triggers `course_period_var`
--
DELIMITER $$
CREATE TRIGGER `td_course_period_var` AFTER DELETE ON `course_period_var` FOR EACH ROW CALL ATTENDANCE_CALC(OLD.course_period_id)
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `ti_course_period_var` AFTER INSERT ON `course_period_var` FOR EACH ROW CALL ATTENDANCE_CALC(NEW.course_period_id)
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `tu_course_period_var` AFTER UPDATE ON `course_period_var` FOR EACH ROW CALL ATTENDANCE_CALC(NEW.course_period_id)
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `course_subjects`
--

CREATE TABLE `course_subjects` (
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `subject_id` int(8) NOT NULL,
  `title` text,
  `short_name` text,
  `rollover_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `custom_fields`
--

CREATE TABLE `custom_fields` (
  `id` int(8) NOT NULL,
  `type` varchar(10) DEFAULT NULL,
  `search` varchar(1) DEFAULT NULL,
  `title` varchar(30) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `select_options` varchar(10000) DEFAULT NULL,
  `category_id` decimal(10,0) DEFAULT NULL,
  `system_field` char(1) DEFAULT NULL,
  `required` varchar(1) DEFAULT NULL,
  `default_selection` varchar(255) DEFAULT NULL,
  `hide` varchar(1) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `device_info`
--

CREATE TABLE `device_info` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `profile_id` int(11) NOT NULL,
  `device_type` varchar(255) CHARACTER SET utf8 NOT NULL,
  `device_token` longtext CHARACTER SET utf8 NOT NULL,
  `device_id` longtext CHARACTER SET utf8 NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `eligibility`
--

CREATE TABLE `eligibility` (
  `student_id` decimal(10,0) DEFAULT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_date` date DEFAULT NULL,
  `period_id` decimal(10,0) DEFAULT NULL,
  `eligibility_code` varchar(20) DEFAULT NULL,
  `course_period_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `eligibility_activities`
--

CREATE TABLE `eligibility_activities` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `eligibility_completed`
--

CREATE TABLE `eligibility_completed` (
  `staff_id` decimal(10,0) NOT NULL,
  `school_date` date NOT NULL,
  `period_id` decimal(10,0) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Stand-in structure for view `enroll_grade`
-- (See below for the actual view)
--
CREATE TABLE `enroll_grade` (
`id` int(8)
,`syear` decimal(4,0)
,`school_id` decimal(10,0)
,`student_id` decimal(10,0)
,`start_date` date
,`end_date` date
,`short_name` varchar(5)
,`title` varchar(50)
);

-- --------------------------------------------------------

--
-- Table structure for table `ethnicity`
--

CREATE TABLE `ethnicity` (
  `ethnicity_id` int(8) NOT NULL,
  `ethnicity_name` varchar(255) NOT NULL,
  `sort_order` int(8) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Date time ethnicity record modified',
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `ethnicity`
--

INSERT INTO `ethnicity` (`ethnicity_id`, `ethnicity_name`, `sort_order`, `last_updated`, `updated_by`) VALUES
(1, 'White, Non-Hispanic', 1, '0000-00-00 00:00:00', NULL),
(2, 'Black, Non-Hispanic', 2, '0000-00-00 00:00:00', NULL),
(3, 'Hispanic', 3, '0000-00-00 00:00:00', NULL),
(4, 'American Indian or Native Alaskan', 4, '0000-00-00 00:00:00', NULL),
(5, 'Pacific Islander', 5, '0000-00-00 00:00:00', NULL),
(6, 'Asian', 6, '0000-00-00 00:00:00', NULL),
(7, 'Indian', 7, '0000-00-00 00:00:00', NULL),
(8, 'Middle Eastern', 8, '0000-00-00 00:00:00', NULL),
(9, 'African', 9, '0000-00-00 00:00:00', NULL),
(10, 'Mixed Race', 10, '0000-00-00 00:00:00', NULL),
(11, 'Other', 11, '0000-00-00 00:00:00', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `filters`
--

CREATE TABLE `filters` (
  `filter_id` int(11) NOT NULL,
  `filter_name` varchar(255) DEFAULT NULL,
  `school_id` int(11) DEFAULT '0',
  `show_to` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `filter_fields`
--

CREATE TABLE `filter_fields` (
  `filter_field_id` int(11) NOT NULL,
  `filter_id` int(11) DEFAULT NULL,
  `filter_column` varchar(255) DEFAULT NULL,
  `filter_value` longtext
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `gradebook_assignments`
--

CREATE TABLE `gradebook_assignments` (
  `assignment_id` int(8) NOT NULL,
  `staff_id` decimal(10,0) DEFAULT NULL,
  `marking_period_id` int(11) DEFAULT NULL,
  `course_period_id` decimal(10,0) DEFAULT NULL,
  `course_id` decimal(10,0) DEFAULT NULL,
  `assignment_type_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `assigned_date` date DEFAULT NULL,
  `due_date` date DEFAULT NULL,
  `points` decimal(10,0) DEFAULT NULL,
  `description` longtext,
  `ungraded` int(8) NOT NULL DEFAULT '1',
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `gradebook_assignment_types`
--

CREATE TABLE `gradebook_assignment_types` (
  `assignment_type_id` int(8) NOT NULL,
  `staff_id` decimal(10,0) DEFAULT NULL,
  `course_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `final_grade_percent` decimal(6,5) DEFAULT NULL,
  `course_period_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `gradebook_grades`
--

CREATE TABLE `gradebook_grades` (
  `student_id` decimal(10,0) NOT NULL,
  `period_id` decimal(10,0) DEFAULT NULL,
  `course_period_id` decimal(10,0) NOT NULL,
  `assignment_id` decimal(10,0) NOT NULL,
  `points` decimal(6,2) DEFAULT NULL,
  `comment` longtext,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `grades_completed`
--

CREATE TABLE `grades_completed` (
  `staff_id` decimal(10,0) NOT NULL,
  `marking_period_id` int(11) NOT NULL,
  `period_id` decimal(10,0) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `hacking_log`
--

CREATE TABLE `hacking_log` (
  `host_name` varchar(20) DEFAULT NULL,
  `ip_address` varchar(20) DEFAULT NULL,
  `login_date` date DEFAULT NULL,
  `version` varchar(20) DEFAULT NULL,
  `php_self` varchar(20) DEFAULT NULL,
  `document_root` varchar(100) DEFAULT NULL,
  `script_name` varchar(100) DEFAULT NULL,
  `modname` varchar(100) DEFAULT NULL,
  `username` varchar(20) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `history_marking_periods`
--

CREATE TABLE `history_marking_periods` (
  `parent_id` int(11) DEFAULT NULL,
  `mp_type` char(20) DEFAULT NULL,
  `name` char(30) DEFAULT NULL,
  `post_end_date` date DEFAULT NULL,
  `school_id` int(11) DEFAULT NULL,
  `syear` int(11) DEFAULT NULL,
  `marking_period_id` int(11) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `history_school`
--

CREATE TABLE `history_school` (
  `id` int(11) NOT NULL,
  `student_id` int(11) NOT NULL,
  `marking_period_id` int(11) NOT NULL,
  `school_name` varchar(100) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `honor_roll`
--

CREATE TABLE `honor_roll` (
  `id` int(11) NOT NULL,
  `school_id` int(11) NOT NULL,
  `syear` int(4) NOT NULL,
  `title` varchar(100) NOT NULL,
  `value` varchar(100) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `language`
--

CREATE TABLE `language` (
  `language_id` int(8) NOT NULL,
  `language_name` varchar(127) NOT NULL,
  `sort_order` int(8) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `language`
--

INSERT INTO `language` (`language_id`, `language_name`, `sort_order`, `last_updated`, `updated_by`) VALUES
(1, 'English', 1, '2019-07-28 08:26:33', NULL),
(2, 'Arabic', 2, '2019-07-28 08:26:33', NULL),
(3, 'Bengali', 3, '2019-07-28 08:26:33', NULL),
(4, 'Chinese', 4, '2019-07-28 08:26:33', NULL),
(5, 'French', 5, '2019-07-28 08:26:33', NULL),
(6, 'German', 6, '2019-07-28 08:26:33', NULL),
(7, 'Haitian Creole', 7, '2019-07-28 08:26:33', NULL),
(8, 'Hindi', 8, '2019-07-28 08:26:33', NULL),
(9, 'Italian', 9, '2019-07-28 08:26:33', NULL),
(10, 'Japanese', 10, '2019-07-28 08:26:33', NULL),
(11, 'Korean', 11, '2019-07-28 08:26:33', NULL),
(12, 'Malay', 12, '2019-07-28 08:26:33', NULL),
(13, 'Polish', 13, '2019-07-28 08:26:33', NULL),
(14, 'Portuguese', 14, '2019-07-28 08:26:33', NULL),
(15, 'Russian', 15, '2019-07-28 08:26:33', NULL),
(16, 'Spanish', 16, '2019-07-28 08:26:33', NULL),
(17, 'Thai', 17, '2019-07-28 08:26:33', NULL),
(18, 'Turkish', 18, '2019-07-28 08:26:33', NULL),
(19, 'Urdu', 19, '2019-07-28 08:26:33', NULL),
(20, 'Vietnamese', 20, '2019-07-28 08:26:33', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `login_authentication`
--

CREATE TABLE `login_authentication` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `profile_id` int(11) NOT NULL,
  `username` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `last_login` datetime DEFAULT NULL,
  `failed_login` int(3) NOT NULL DEFAULT '0',
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `login_authentication`
--

INSERT INTO `login_authentication` (`id`, `user_id`, `profile_id`, `username`, `password`, `last_login`, `failed_login`, `last_updated`, `updated_by`) VALUES
(1, 1, 0, 'admin', '2637a5c30af69a7bad877fdb65fbd78b', '2019-08-19 23:59:43', 0, '2019-07-28 02:56:33', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `login_message`
--

CREATE TABLE `login_message` (
  `id` int(8) NOT NULL,
  `message` longtext,
  `display` char(1) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `login_message`
--

INSERT INTO `login_message` (`id`, `message`, `display`) VALUES
(1, 'This is a restricted network. Use of this network, its equipment, and resources is monitored at all times and requires explicit permission from the network administrator. If you do not have this permission in writing, you are violating the regulations of this network and can and will be prosecuted to the fullest extent of law. By continuing into this system, you are acknowledging that you are aware of and agree to these terms.', 'Y');

-- --------------------------------------------------------

--
-- Table structure for table `login_records`
--

CREATE TABLE `login_records` (
  `syear` decimal(5,0) DEFAULT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `profile` varchar(50) DEFAULT NULL,
  `user_name` varchar(100) DEFAULT NULL,
  `login_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `faillog_count` decimal(4,0) DEFAULT NULL,
  `staff_id` decimal(10,0) DEFAULT NULL,
  `id` int(8) NOT NULL,
  `faillog_time` varchar(255) DEFAULT NULL,
  `ip_address` varchar(20) DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `log_maintain`
--

CREATE TABLE `log_maintain` (
  `id` int(8) NOT NULL,
  `value` decimal(30,0) DEFAULT NULL,
  `session_id` varchar(100) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `lunch_period`
--

CREATE TABLE `lunch_period` (
  `student_id` decimal(10,0) DEFAULT NULL,
  `school_date` date DEFAULT NULL,
  `period_id` decimal(10,0) DEFAULT NULL,
  `attendance_code` decimal(10,0) DEFAULT NULL,
  `attendance_teacher_code` decimal(10,0) DEFAULT NULL,
  `attendance_reason` varchar(100) DEFAULT NULL,
  `admin` varchar(1) DEFAULT NULL,
  `course_period_id` decimal(10,0) DEFAULT NULL,
  `marking_period_id` int(11) DEFAULT NULL,
  `lunch_period` varchar(100) DEFAULT NULL,
  `table_name` decimal(10,0) DEFAULT NULL,
  `comment` varchar(100) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `mail_group`
--

CREATE TABLE `mail_group` (
  `group_id` int(11) NOT NULL,
  `group_name` varchar(255) NOT NULL,
  `description` varchar(255) NOT NULL,
  `user_name` varchar(255) NOT NULL,
  `creation_date` datetime NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `mail_groupmembers`
--

CREATE TABLE `mail_groupmembers` (
  `id` int(11) NOT NULL,
  `group_id` int(11) NOT NULL,
  `user_name` varchar(255) NOT NULL,
  `profile` varchar(255) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Stand-in structure for view `marking_periods`
-- (See below for the actual view)
--
CREATE TABLE `marking_periods` (
`marking_period_id` int(11)
,`mp_source` varchar(7)
,`syear` decimal(10,0)
,`school_id` decimal(10,0)
,`mp_type` varchar(20)
,`title` varchar(50)
,`short_name` varchar(10)
,`sort_order` decimal(10,0)
,`parent_id` decimal(19,0)
,`grandparent_id` decimal(19,0)
,`start_date` date
,`end_date` date
,`post_start_date` date
,`post_end_date` date
,`does_grades` varchar(1)
,`does_exam` varchar(1)
,`does_comments` varchar(1)
);

-- --------------------------------------------------------

--
-- Table structure for table `marking_period_id_generator`
--

CREATE TABLE `marking_period_id_generator` (
  `id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `marking_period_id_generator`
--

INSERT INTO `marking_period_id_generator` (`id`) VALUES
(1);

-- --------------------------------------------------------

--
-- Table structure for table `medical_info`
--

CREATE TABLE `medical_info` (
  `id` int(11) NOT NULL,
  `student_id` int(11) NOT NULL,
  `syear` int(11) NOT NULL,
  `school_id` int(11) NOT NULL,
  `physician` varchar(255) DEFAULT NULL,
  `physician_phone` varchar(255) DEFAULT NULL,
  `preferred_hospital` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `missing_attendance`
--

CREATE TABLE `missing_attendance` (
  `school_id` int(11) NOT NULL,
  `syear` varchar(6) NOT NULL,
  `school_date` date NOT NULL,
  `course_period_id` int(11) NOT NULL,
  `period_id` int(11) NOT NULL,
  `teacher_id` int(11) NOT NULL,
  `secondary_teacher_id` int(11) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `msg_inbox`
--

CREATE TABLE `msg_inbox` (
  `mail_id` int(11) NOT NULL,
  `to_user` varchar(211) NOT NULL,
  `from_user` varchar(211) NOT NULL,
  `mail_Subject` varchar(211) DEFAULT NULL,
  `mail_body` longtext NOT NULL,
  `mail_datetime` datetime DEFAULT NULL,
  `mail_attachment` varchar(211) DEFAULT NULL,
  `isdraft` int(11) DEFAULT NULL,
  `istrash` varchar(255) DEFAULT NULL,
  `to_multiple_users` varchar(255) DEFAULT NULL,
  `to_cc` varchar(255) DEFAULT NULL,
  `to_cc_multiple` varchar(255) DEFAULT NULL,
  `to_bcc` varchar(255) DEFAULT NULL,
  `to_bcc_multiple` varchar(255) DEFAULT NULL,
  `mail_read_unread` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `msg_outbox`
--

CREATE TABLE `msg_outbox` (
  `mail_id` int(11) NOT NULL,
  `from_user` varchar(211) NOT NULL,
  `to_user` varchar(211) NOT NULL,
  `mail_subject` varchar(211) DEFAULT NULL,
  `mail_body` longtext NOT NULL,
  `mail_datetime` datetime DEFAULT NULL,
  `mail_attachment` varchar(211) DEFAULT NULL,
  `istrash` int(11) DEFAULT NULL,
  `to_cc` varchar(255) DEFAULT NULL,
  `to_bcc` varchar(255) DEFAULT NULL,
  `to_grpName` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `people`
--

CREATE TABLE `people` (
  `staff_id` int(11) NOT NULL,
  `current_school_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(5) DEFAULT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `middle_name` varchar(100) DEFAULT NULL,
  `home_phone` varchar(255) DEFAULT NULL,
  `work_phone` varchar(255) DEFAULT NULL,
  `cell_phone` varchar(255) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `custody` varchar(1) DEFAULT NULL,
  `profile` varchar(30) DEFAULT NULL,
  `profile_id` decimal(10,0) DEFAULT NULL,
  `is_disable` varchar(10) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `people_fields`
--

CREATE TABLE `people_fields` (
  `id` int(8) NOT NULL,
  `type` varchar(10) DEFAULT NULL,
  `search` varchar(1) DEFAULT NULL,
  `title` varchar(30) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `select_options` varchar(10000) DEFAULT NULL,
  `category_id` decimal(10,0) DEFAULT NULL,
  `system_field` char(1) DEFAULT NULL,
  `required` varchar(1) DEFAULT NULL,
  `default_selection` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `people_field_categories`
--

CREATE TABLE `people_field_categories` (
  `id` int(8) NOT NULL,
  `title` varchar(100) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `include` varchar(100) DEFAULT NULL,
  `admin` char(1) DEFAULT NULL,
  `teacher` char(1) DEFAULT NULL,
  `parent` char(1) DEFAULT NULL,
  `none` char(1) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `people_field_categories`
--

INSERT INTO `people_field_categories` (`id`, `title`, `sort_order`, `include`, `admin`, `teacher`, `parent`, `none`, `last_updated`, `updated_by`) VALUES
(1, 'General Info', '1', NULL, 'Y', 'Y', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
(2, 'Address Info', '2', NULL, 'Y', 'Y', 'Y', 'Y', '2019-07-28 08:26:33', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `portal_notes`
--

CREATE TABLE `portal_notes` (
  `id` int(8) NOT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `content` longtext,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `published_user` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `published_profiles` varchar(255) DEFAULT NULL,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `profile_exceptions`
--

CREATE TABLE `profile_exceptions` (
  `profile_id` decimal(10,0) DEFAULT NULL,
  `modname` varchar(255) DEFAULT NULL,
  `can_use` varchar(1) DEFAULT NULL,
  `can_edit` varchar(1) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `profile_exceptions`
--

INSERT INTO `profile_exceptions` (`profile_id`, `modname`, `can_use`, `can_edit`, `last_updated`, `updated_by`) VALUES
('2', 'students/Student.php&category_id=6', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'students/Student.php&category_id=7', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'students/Student.php&category_id=6', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'students/Student.php&category_id=6', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'users/User.php&category_id=5', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'schoolsetup/Schools.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'schoolsetup/Calendar.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'students/Student.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'students/Student.php&category_id=1', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'students/Student.php&category_id=3', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'students/ChangePassword.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'scheduling/ViewSchedule.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'scheduling/PrintSchedules.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'scheduling/Requests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('3', 'grades/StudentGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'grades/FinalGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'grades/ReportCards.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'grades/Transcripts.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'grades/GPARankList.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'attendance/StudentSummary.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'attendance/DailySummary.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'eligibility/Student.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'eligibility/StudentList.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'schoolsetup/Schools.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'schoolsetup/MarkingPeriods.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'schoolsetup/Calendar.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'students/Student.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'students/AddUsers.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'students/AdvancedReport.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'students/StudentLabels.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'students/Student.php&category_id=1', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'students/Student.php&category_id=3', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'students/Student.php&category_id=4', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('2', 'users/User.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/Rooms.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('2', 'grades/Grades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'users/Preferences.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'scheduling/Schedule.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'scheduling/PrintSchedules.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'scheduling/PrintClassLists.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'scheduling/PrintClassPictures.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/InputFinalGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/ReportCards.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/Grades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/Assignments.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/AnomalousGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/Configuration.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/ProgressReports.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/StudentGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/FinalGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/ReportCardGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'grades/ReportCardComments.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'attendance/TakeAttendance.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'attendance/DailySummary.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'attendance/StudentSummary.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'eligibility/EnterEligibility.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'scheduling/ViewSchedule.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'attendance/StudentSummary.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'attendance/DailySummary.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'eligibility/Student.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'eligibility/StudentList.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'schoolsetup/Schools.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'schoolsetup/Calendar.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'students/Student.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'students/Student.php&category_id=1', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'students/Student.php&category_id=3', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('4', 'users/User.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'users/User.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('4', 'users/Preferences.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'scheduling/ViewSchedule.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'scheduling/Requests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('4', 'grades/StudentGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'grades/FinalGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'grades/ReportCards.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'grades/Transcripts.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'grades/GPARankList.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'users/User.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('4', 'users/User.php&category_id=3', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'schoolsetup/Courses.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'schoolsetup/CourseCatalog.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'schoolsetup/PrintCatalog.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'schoolsetup/PrintAllCourses.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'students/Student.php&category_id=5', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('4', 'students/ChangePassword.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'scheduling/StudentScheduleReport.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'grades/ParentProgressReports.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'scheduling/StudentScheduleReport.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/PortalNotes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/MarkingPeriods.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/Calendar.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/Periods.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/GradeLevels.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/Schools.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/UploadLogo.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/Schools.php?new_school=true', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/CopySchool.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/SystemPreference.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/Courses.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/CourseCatalog.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/PrintCatalog.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/PrintCatalogGradeLevel.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/PrintAllCourses.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/TeacherReassignment.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'students/Student.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/Student.php&include=GeneralInfoInc&student_id=new', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/AssignOtherInfo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/AddUsers.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/AdvancedReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/AddDrop.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/Letters.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/MailingLabels.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/StudentLabels.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/PrintStudentInfo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/PrintStudentContactInfo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/GoalReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/StudentFields.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'students/EnrollmentCodes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/Upload.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/Upload.php?modfunc=edit', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/Student.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/Student.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/Student.php&category_id=3', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/Student.php&category_id=4', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/Student.php&category_id=5', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'users/User.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'users/User.php&staff_id=new', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'users/AddStudents.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'users/Preferences.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'users/Profiles.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'users/Exceptions.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'users/UserFields.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'users/TeacherPrograms.php?include=grades/InputFinalGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'users/TeacherPrograms.php?include=grades/Grades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'users/TeacherPrograms.php?include=grades/ProgressReports.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'users/TeacherPrograms.php?include=attendance/TakeAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'users/TeacherPrograms.php?include=attendance/Missing_Attendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'users/TeacherPrograms.php?include=eligibility/EnterEligibility.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'users/User.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'users/User.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'scheduling/Schedule.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/ViewSchedule.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/Requests.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/MassSchedule.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/MassRequests.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/MassDrops.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/PrintSchedules.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'scheduling/PrintClassLists.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'scheduling/PrintClassPictures.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/PrintRequests.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/ScheduleReport.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/RequestsReport.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/UnfilledRequests.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/IncompleteSchedules.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/AddDrop.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'scheduling/Scheduler.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'grades/ReportCards.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'grades/CalcGPA.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'grades/Transcripts.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'grades/TeacherCompletion.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'grades/GradeBreakdown.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'grades/FinalGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'grades/GPARankList.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'grades/AdminProgressReports.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'grades/HonorRoll.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'grades/ReportCardGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'grades/ReportCardComments.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'grades/HonorRollSetup.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'grades/FixGPA.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'grades/EditReportCardGrades.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'grades/EditHistoryMarkingPeriods.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'attendance/Administration.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/AddAbsences.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/AttendanceData.php?list_by_day=true', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/Percent.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/Percent.php?list_by_day=true', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/DailySummary.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/StudentSummary.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/TeacherCompletion.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/FixDailyAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/DuplicateAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'attendance/AttendanceCodes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'eligibility/Student.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'eligibility/AddActivity.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'eligibility/StudentList.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'eligibility/TeacherCompletion.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'eligibility/Activities.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'eligibility/EntryTimes.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('5', 'tools/LogDetails.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'tools/DeleteLog.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'tools/Rollover.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('2', 'users/Staff.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/SchoolCustomFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Student.php&category_id=6', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Student.php&category_id=7', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/User.php&category_id=5', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/PortalNotes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/Schools.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/Schools.php?new_school=true', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/CopySchool.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/MarkingPeriods.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/Calendar.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/Periods.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/GradeLevels.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/Rollover.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/Courses.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/CourseCatalog.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/PrintCatalog.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/PrintCatalogGradeLevel.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/PrintAllCourses.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/UploadLogo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/TeacherReassignment.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Student.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Student.php&include=GeneralInfoInc&student_id=new', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/AssignOtherInfo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/AddUsers.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/AdvancedReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/AddDrop.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Letters.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/MailingLabels.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/StudentLabels.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/PrintStudentInfo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/PrintStudentContactInfo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/GoalReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/StudentFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/AddressFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/PeopleFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/EnrollmentCodes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Upload.php?modfunc=edit', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Upload.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Student.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Student.php&category_id=3', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Student.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Student.php&category_id=4', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/StudentReenroll.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/EnrollmentReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/User.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/User.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/User.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/User.php&staff_id=new', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/AddStudents.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Preferences.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Profiles.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Exceptions.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/UserFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/TeacherPrograms.php?include=grades/InputFinalGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/TeacherPrograms.php?include=grades/Grades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/TeacherPrograms.php?include=attendance/TakeAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/TeacherPrograms.php?include=attendance/Missing_Attendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/TeacherPrograms.php?include=eligibility/EnterEligibility.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/UploadUserPhoto.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/UploadUserPhoto.php?modfunc=edit', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/UserAdvancedReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/UserAdvancedReportStaff.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/Schedule.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/Requests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/MassSchedule.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/MassRequests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/MassDrops.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/ScheduleReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/RequestsReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/UnfilledRequests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/IncompleteSchedules.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/AddDrop.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/PrintSchedules.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/PrintRequests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/PrintClassLists.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/PrintClassPictures.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/Courses.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/Scheduler.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'scheduling/ViewSchedule.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/ReportCards.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/CalcGPA.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/Transcripts.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/TeacherCompletion.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/GradeBreakdown.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/FinalGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/GPARankList.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/ReportCardGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/ReportCardComments.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/FixGPA.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/EditReportCardGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/EditHistoryMarkingPeriods.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/HistoricalReportCardGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/Administration.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/AddAbsences.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/AttendanceData.php?list_by_day=true', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/Percent.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/Percent.php?list_by_day=true', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/DailySummary.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/StudentSummary.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/TeacherCompletion.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/DuplicateAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/AttendanceCodes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'attendance/FixDailyAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'eligibility/Student.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'eligibility/AddActivity.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'eligibility/StudentList.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'eligibility/TeacherCompletion.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'eligibility/Activities.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'eligibility/EntryTimes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'tools/LogDetails.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'tools/DeleteLog.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'schoolsetup/SchoolCustomFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'tools/Rollover.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Upload.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Upload.php?modfunc=edit', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/SystemPreference.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'students/Student.php&category_id=5', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/HonorRoll.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/TeacherPrograms.php?include=grades/ProgressReports.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/User.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/HonorRollSetup.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'grades/AdminProgressReports.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Staff.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Staff.php&staff_id=new', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Exceptions_staff.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/StaffFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Staff.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Staff.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Staff.php&category_id=3', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Staff.php&category_id=4', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'messaging/Inbox.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'messaging/Compose.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'messaging/SentMail.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'messaging/Trash.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'messaging/Group.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('4', 'messaging/Inbox.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'messaging/Compose.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'messaging/SentMail.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'messaging/Trash.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('4', 'messaging/Group.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'messaging/Inbox.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'messaging/Compose.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'messaging/SentMail.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'messaging/Trash.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'messaging/Group.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'messaging/Inbox.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'messaging/Compose.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'messaging/SentMail.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'messaging/Trash.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('3', 'messaging/Group.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('0', 'students/Student.php&category_id=6', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Student.php&category_id=7', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/User.php&category_id=5', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/PortalNotes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/Schools.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/Schools.php?new_school=true', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/CopySchool.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/MarkingPeriods.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/Calendar.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/Periods.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/GradeLevels.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/Rollover.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/Courses.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/CourseCatalog.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/PrintCatalog.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/PrintCatalogGradeLevel.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/PrintAllCourses.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/UploadLogo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/TeacherReassignment.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Student.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Student.php&include=GeneralInfoInc&student_id=new', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/AssignOtherInfo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/AddUsers.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/AdvancedReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/AddDrop.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Letters.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/MailingLabels.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/StudentLabels.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/PrintStudentInfo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/PrintStudentContactInfo.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/GoalReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/StudentFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/AddressFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/PeopleFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/EnrollmentCodes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Upload.php?modfunc=edit', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Upload.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Student.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Student.php&category_id=3', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Student.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Student.php&category_id=4', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/StudentReenroll.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/EnrollmentReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/User.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/User.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/User.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/User.php&staff_id=new', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/AddStudents.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Preferences.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Profiles.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Exceptions.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/UserFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/TeacherPrograms.php?include=grades/InputFinalGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/TeacherPrograms.php?include=grades/Grades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/TeacherPrograms.php?include=attendance/TakeAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/TeacherPrograms.php?include=attendance/Missing_Attendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/TeacherPrograms.php?include=eligibility/EnterEligibility.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/UploadUserPhoto.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/UploadUserPhoto.php?modfunc=edit', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/UserAdvancedReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/UserAdvancedReportStaff.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/Schedule.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/Requests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/MassSchedule.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/MassRequests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/MassDrops.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/ScheduleReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/RequestsReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/UnfilledRequests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/IncompleteSchedules.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/AddDrop.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/PrintSchedules.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/PrintRequests.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/PrintClassLists.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/PrintClassPictures.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/Courses.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/Scheduler.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'scheduling/ViewSchedule.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/ReportCards.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/CalcGPA.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/Transcripts.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/TeacherCompletion.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/GradeBreakdown.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/FinalGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/GPARankList.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/ReportCardGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/ReportCardComments.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/FixGPA.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/EditReportCardGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/EditHistoryMarkingPeriods.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/HistoricalReportCardGrades.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/Administration.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/AddAbsences.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/AttendanceData.php?list_by_day=true', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/Percent.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/Percent.php?list_by_day=true', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/DailySummary.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/StudentSummary.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/TeacherCompletion.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/DuplicateAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/AttendanceCodes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'attendance/FixDailyAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'eligibility/Student.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'eligibility/AddActivity.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'eligibility/StudentList.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'eligibility/TeacherCompletion.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'eligibility/Activities.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'eligibility/EntryTimes.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'tools/LogDetails.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'tools/DeleteLog.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'tools/Backup.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'tools/Rollover.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Upload.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Upload.php?modfunc=edit', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/SystemPreference.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'students/Student.php&category_id=5', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/HonorRoll.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/TeacherPrograms.php?include=grades/ProgressReports.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/User.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/HonorRollSetup.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/AdminProgressReports.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Staff.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Staff.php&staff_id=new', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Exceptions_staff.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/StaffFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Staff.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Staff.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Staff.php&category_id=3', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Staff.php&category_id=4', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/SchoolCustomFields.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'messaging/Inbox.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'messaging/Compose.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'messaging/SentMail.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'messaging/Trash.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'messaging/Group.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/Rooms.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/school_specific_standards.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/TeacherPrograms.php?include=grades/AdminProgressReports.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'tools/Reports.php?func=Basic', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'tools/Reports.php?func=Ins_r', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'tools/Reports.php?func=Ins_cf', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/us_common_standards.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/EffortGradeLibrary.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'grades/EffortGradeSetup.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('4', 'scheduling/PrintSchedules.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('0', 'users/TeacherPrograms.php?include=attendance/MissingAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('0', 'users/Staff.php&category_id=5', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'schoolsetup/Rooms.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/TeacherPrograms.php?include=attendance/MissingAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('1', 'users/Staff.php&category_id=5', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'students/EnrollmentReport.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'users/TeacherPrograms.php?include=attendance/MissingAttendance.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'messaging/Inbox.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'messaging/Compose.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'messaging/SentMail.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'messaging/Trash.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('5', 'messaging/Group.php', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('2', 'users/Staff.php&category_id=1', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('2', 'users/Staff.php&category_id=2', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('2', 'users/Staff.php&category_id=3', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('2', 'users/Staff.php&category_id=4', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('2', 'users/Staff.php&category_id=5', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
('4', 'grades/ParentProgressReports.php', 'Y', NULL, '2019-07-28 08:26:33', NULL),
('0', 'schoolsetup/Sections.php', 'Y', 'Y', '2019-07-25 14:53:00', NULL),
('1', 'schoolsetup/Sections.php', 'Y', 'Y', '2019-07-25 14:53:25', NULL),
('0', 'tools/DataImport.php', 'Y', 'Y', '2019-07-25 14:53:25', NULL),
('1', 'tools/DataImport.php', 'Y', 'Y', '2019-07-25 14:53:25', NULL),
('0', 'tools/GenerateApi.php', 'Y', 'Y', '2020-11-02 17:34:02', NULL),
('1', 'tools/GenerateApi.php', 'Y', 'Y', '2019-08-04 15:33:56', NULL),
('0', 'scheduling/SchoolwideScheduleReport.php', 'Y', 'Y', '2021-07-22 11:38:34', NULL),
('1', 'scheduling/SchoolwideScheduleReport.php', 'Y', 'Y', '2021-07-22 11:38:34', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `program_config`
--

CREATE TABLE `program_config` (
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `program` varchar(255) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `value` varchar(100) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `program_config`
--

INSERT INTO `program_config` (`syear`, `school_id`, `program`, `title`, `value`, `last_updated`, `updated_by`) VALUES
('2021', NULL, 'Currency', 'US Dollar (USD)', '1', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'British Pound (GBP)', '2', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Euro (EUR)', '3', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Canadian Dollar (CAD)', '4', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Australian Dollar (AUD)', '5', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Brazilian Real (BRL)', '6', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Chinese Yuan Renminbi (CNY)', '7', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Danish Krone (DKK)', '8', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Japanese Yen (JPY)', '9', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Indian Rupee (INR)', '10', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Indonesian Rupiah (IDR)', '11', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Korean Won  (KRW)', '12', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Malaysian Ringit (MYR)', '13', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Mexican Peso (MXN)', '14', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'New Zealand Dollar (NZD)', '15', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Norwegian Krone  (NOK)', '16', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Pakistan Rupee  (PKR)', '17', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Philippino Peso (PHP)', '18', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Saudi Riyal (SAR)', '19', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Singapore Dollar (SGD)', '20', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'South African Rand  (ZAR)', '21', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Swedish Krona  (SEK)', '22', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Swiss Franc  (CHF)', '23', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Thai Bhat  (THB)', '24', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'Turkish Lira  (TRY)', '25', '2019-07-28 08:26:33', NULL),
('2021', NULL, 'Currency', 'United Arab Emirates Dirham (AED)', '26', '2019-07-28 08:26:33', NULL),
('2021', '1', 'MissingAttendance', 'LAST_UPDATE', '2021-07-01', '2021-07-22 11:38:34', NULL),
('2021', '1', 'eligibility', 'START_DAY', '1', '2021-07-22 11:38:34', NULL),
('2021', '1', 'eligibility', 'START_HOUR', '8', '2021-07-22 11:38:34', NULL),
('2021', '1', 'eligibility', 'START_MINUTE', '00', '2021-07-22 11:38:34', NULL),
('2021', '1', 'eligibility', 'START_M', 'AM', '2021-07-22 11:38:34', NULL),
('2021', '1', 'eligibility', 'END_DAY', '5', '2021-07-22 11:38:34', NULL),
('2021', '1', 'eligibility', 'END_HOUR', '16', '2021-07-22 11:38:34', NULL),
('2021', '1', 'eligibility', 'END_MINUTE', '00', '2021-07-22 11:38:34', NULL),
('2021', '1', 'eligibility', 'END_M', 'PM', '2021-07-22 11:38:34', NULL),
('2021', '1', 'UPDATENOTIFY', 'display', 'Y', '2021-07-22 11:38:34', NULL),
('2021', '1', 'UPDATENOTIFY', 'display_school', 'Y', '2021-07-22 11:38:34', NULL),
('2021', '1', 'SeatFill', 'LAST_UPDATE', '2021-07-22', '2021-07-22 11:38:34', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `program_user_config`
--

CREATE TABLE `program_user_config` (
  `user_id` decimal(10,0) NOT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `program` varchar(255) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `value` varchar(100) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `program_user_config`
--

INSERT INTO `program_user_config` (`user_id`, `school_id`, `program`, `title`, `value`, `last_updated`, `updated_by`) VALUES
('1', NULL, 'Preferences', 'THEME', 'blue', '2019-07-28 02:56:33', NULL),
('1', NULL, 'Preferences', 'MONTH', 'M', '2019-07-28 02:56:33', NULL),
('1', NULL, 'Preferences', 'DAY', 'j', '2019-07-28 02:56:33', NULL),
('1', NULL, 'Preferences', 'YEAR', 'Y', '2019-07-28 02:56:33', NULL),
('1', NULL, 'Preferences', 'HIDDEN', 'Y', '2019-07-28 02:56:33', NULL),
('1', NULL, 'Preferences', 'CURRENCY', '1', '2019-07-28 02:56:33', NULL),
('1', NULL, 'Preferences', 'HIDE_ALERTS', 'N', '2019-07-28 02:56:33', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `report_card_comments`
--

CREATE TABLE `report_card_comments` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `course_id` decimal(10,0) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `title` text,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `report_card_grades`
--

CREATE TABLE `report_card_grades` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(15) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `gpa_value` decimal(4,2) DEFAULT NULL,
  `break_off` decimal(10,0) DEFAULT NULL,
  `comment` longtext,
  `grade_scale_id` decimal(10,0) DEFAULT NULL,
  `unweighted_gp` decimal(4,2) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `report_card_grade_scales`
--

CREATE TABLE `report_card_grade_scales` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) NOT NULL,
  `title` varchar(25) DEFAULT NULL,
  `comment` varchar(100) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `rollover_id` decimal(10,0) DEFAULT NULL,
  `gp_scale` decimal(10,3) DEFAULT NULL,
  `gpa_cal` enum('Y','N') NOT NULL DEFAULT 'Y',
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `rooms`
--

CREATE TABLE `rooms` (
  `room_id` int(11) NOT NULL,
  `school_id` int(11) NOT NULL,
  `title` varchar(50) NOT NULL,
  `capacity` int(11) DEFAULT NULL,
  `description` text,
  `sort_order` int(11) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `schedule`
--

CREATE TABLE `schedule` (
  `syear` decimal(4,0) NOT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `student_id` decimal(10,0) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL,
  `modified_date` date DEFAULT NULL,
  `modified_by` varchar(255) DEFAULT NULL,
  `course_id` decimal(10,0) NOT NULL,
  `course_weight` varchar(10) DEFAULT NULL,
  `course_period_id` decimal(10,0) NOT NULL,
  `mp` varchar(3) DEFAULT NULL,
  `marking_period_id` int(11) DEFAULT NULL,
  `scheduler_lock` varchar(1) DEFAULT NULL,
  `dropped` varchar(1) DEFAULT 'N',
  `id` int(8) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Triggers `schedule`
--
DELIMITER $$
CREATE TRIGGER `td_schedule` AFTER DELETE ON `schedule` FOR EACH ROW BEGIN
         UPDATE course_periods SET filled_seats=filled_seats-1 WHERE course_period_id=OLD.course_period_id AND OLD.dropped='N';
 	CALL ATTENDANCE_CALC(OLD.course_period_id);
 END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `ti_schdule` AFTER INSERT ON `schedule` FOR EACH ROW BEGIN
         UPDATE course_periods SET filled_seats=filled_seats+1 WHERE course_period_id=NEW.course_period_id;
 	CALL ATTENDANCE_CALC(NEW.course_period_id);
 END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `tu_schedule` AFTER UPDATE ON `schedule` FOR EACH ROW CALL ATTENDANCE_CALC(NEW.course_period_id)
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `schedule_requests`
--

CREATE TABLE `schedule_requests` (
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `request_id` int(8) NOT NULL,
  `student_id` decimal(10,0) DEFAULT NULL,
  `subject_id` decimal(10,0) DEFAULT NULL,
  `course_id` decimal(10,0) DEFAULT NULL,
  `course_weight` varchar(10) DEFAULT NULL,
  `marking_period_id` int(11) DEFAULT NULL,
  `priority` decimal(10,0) DEFAULT NULL,
  `with_teacher_id` decimal(10,0) DEFAULT NULL,
  `not_teacher_id` decimal(10,0) DEFAULT NULL,
  `with_period_id` decimal(10,0) DEFAULT NULL,
  `not_period_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `schools`
--

CREATE TABLE `schools` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `address` varchar(100) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `state` varchar(100) DEFAULT NULL,
  `zipcode` varchar(255) DEFAULT NULL,
  `area_code` decimal(3,0) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `principal` varchar(100) DEFAULT NULL,
  `www_address` varchar(100) DEFAULT NULL,
  `e_mail` varchar(100) DEFAULT NULL,
  `reporting_gp_scale` decimal(10,3) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `schools`
--

INSERT INTO `schools` (`id`, `syear`, `title`, `address`, `city`, `state`, `zipcode`, `area_code`, `phone`, `principal`, `www_address`, `e_mail`, `reporting_gp_scale`, `last_updated`, `updated_by`) VALUES
(1, '2021', 'School Name', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '0000-00-00 00:00:00', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `school_calendars`
--

CREATE TABLE `school_calendars` (
  `school_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `calendar_id` int(8) NOT NULL,
  `default_calendar` varchar(1) DEFAULT NULL,
  `days` varchar(7) DEFAULT NULL,
  `rollover_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `school_custom_fields`
--

CREATE TABLE `school_custom_fields` (
  `id` int(8) NOT NULL,
  `school_id` int(11) NOT NULL,
  `type` varchar(10) DEFAULT NULL,
  `search` varchar(1) DEFAULT NULL,
  `title` varchar(30) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `select_options` varchar(10000) DEFAULT NULL,
  `category_id` decimal(10,0) DEFAULT NULL,
  `system_field` char(1) DEFAULT NULL,
  `required` varchar(1) DEFAULT NULL,
  `default_selection` varchar(255) DEFAULT NULL,
  `hide` varchar(1) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `school_gradelevels`
--

CREATE TABLE `school_gradelevels` (
  `id` int(8) NOT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `short_name` varchar(5) DEFAULT NULL,
  `title` varchar(50) DEFAULT NULL,
  `next_grade_id` decimal(10,0) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `school_gradelevel_sections`
--

CREATE TABLE `school_gradelevel_sections` (
  `id` int(8) NOT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `school_periods`
--

CREATE TABLE `school_periods` (
  `period_id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `short_name` varchar(10) DEFAULT NULL,
  `length` decimal(10,0) DEFAULT NULL,
  `block` varchar(10) DEFAULT NULL,
  `ignore_scheduling` varchar(10) DEFAULT NULL,
  `attendance` varchar(1) DEFAULT NULL,
  `rollover_id` decimal(10,0) DEFAULT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Triggers `school_periods`
--
DELIMITER $$
CREATE TRIGGER `tu_periods` AFTER UPDATE ON `school_periods` FOR EACH ROW UPDATE course_period_var SET start_time=NEW.start_time,end_time=NEW.end_time WHERE period_id=NEW.period_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `school_progress_periods`
--

CREATE TABLE `school_progress_periods` (
  `marking_period_id` int(11) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `quarter_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(50) DEFAULT NULL,
  `short_name` varchar(10) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `post_start_date` date DEFAULT NULL,
  `post_end_date` date DEFAULT NULL,
  `does_grades` varchar(1) DEFAULT NULL,
  `does_exam` varchar(1) DEFAULT NULL,
  `does_comments` varchar(1) DEFAULT NULL,
  `rollover_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `school_quarters`
--

CREATE TABLE `school_quarters` (
  `marking_period_id` int(11) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `semester_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(50) DEFAULT NULL,
  `short_name` varchar(10) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `post_start_date` date DEFAULT NULL,
  `post_end_date` date DEFAULT NULL,
  `does_grades` varchar(1) DEFAULT NULL,
  `does_exam` varchar(1) DEFAULT NULL,
  `does_comments` varchar(1) DEFAULT NULL,
  `rollover_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Triggers `school_quarters`
--
DELIMITER $$
CREATE TRIGGER `tu_school_quarters` AFTER UPDATE ON `school_quarters` FOR EACH ROW UPDATE course_periods SET begin_date=NEW.start_date,end_date=NEW.end_date WHERE marking_period_id=NEW.marking_period_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `school_semesters`
--

CREATE TABLE `school_semesters` (
  `marking_period_id` int(11) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `year_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(50) DEFAULT NULL,
  `short_name` varchar(10) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `post_start_date` date DEFAULT NULL,
  `post_end_date` date DEFAULT NULL,
  `does_grades` varchar(1) DEFAULT NULL,
  `does_exam` varchar(1) DEFAULT NULL,
  `does_comments` varchar(1) DEFAULT NULL,
  `rollover_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Triggers `school_semesters`
--
DELIMITER $$
CREATE TRIGGER `tu_school_semesters` AFTER UPDATE ON `school_semesters` FOR EACH ROW UPDATE course_periods SET begin_date=NEW.start_date,end_date=NEW.end_date WHERE marking_period_id=NEW.marking_period_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `school_years`
--

CREATE TABLE `school_years` (
  `marking_period_id` int(11) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(50) DEFAULT NULL,
  `short_name` varchar(10) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `post_start_date` date DEFAULT NULL,
  `post_end_date` date DEFAULT NULL,
  `does_grades` varchar(1) DEFAULT NULL,
  `does_exam` varchar(1) DEFAULT NULL,
  `does_comments` varchar(1) DEFAULT NULL,
  `rollover_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `school_years`
--

INSERT INTO `school_years` (`marking_period_id`, `syear`, `school_id`, `title`, `short_name`, `sort_order`, `start_date`, `end_date`, `post_start_date`, `post_end_date`, `does_grades`, `does_exam`, `does_comments`, `rollover_id`, `last_updated`, `updated_by`) VALUES
(1, '2021', '1', 'Full Year', 'FY', '1', '2021-07-01', '2022-07-31', NULL, NULL, NULL, NULL, NULL, NULL, '2020-01-21 21:18:02', NULL);

--
-- Triggers `school_years`
--
DELIMITER $$
CREATE TRIGGER `tu_school_years` AFTER UPDATE ON `school_years` FOR EACH ROW UPDATE course_periods SET begin_date=NEW.start_date,end_date=NEW.end_date WHERE marking_period_id=NEW.marking_period_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `staff`
--

CREATE TABLE `staff` (
  `staff_id` int(8) NOT NULL,
  `current_school_id` decimal(10,0) DEFAULT NULL,
  `title` varchar(10) CHARACTER SET utf8 DEFAULT NULL,
  `first_name` varchar(100) CHARACTER SET utf8 DEFAULT NULL,
  `last_name` varchar(100) CHARACTER SET utf8 DEFAULT NULL,
  `middle_name` varchar(100) CHARACTER SET utf8 DEFAULT NULL,
  `phone` varchar(100) CHARACTER SET utf8 DEFAULT NULL,
  `email` varchar(100) CHARACTER SET utf8 DEFAULT NULL,
  `profile` varchar(30) CHARACTER SET utf8 DEFAULT NULL,
  `homeroom` varchar(5) CHARACTER SET utf8 DEFAULT NULL,
  `profile_id` decimal(10,0) DEFAULT NULL,
  `primary_language_id` int(8) DEFAULT NULL,
  `gender` varchar(8) CHARACTER SET utf8 DEFAULT NULL,
  `ethnicity_id` int(8) DEFAULT NULL,
  `birthdate` date DEFAULT NULL,
  `alternate_id` varchar(50) CHARACTER SET utf8 DEFAULT NULL,
  `name_suffix` varchar(32) CHARACTER SET utf8 DEFAULT NULL,
  `second_language_id` int(8) DEFAULT NULL,
  `third_language_id` int(8) DEFAULT NULL,
  `is_disable` varchar(10) CHARACTER SET utf8 DEFAULT NULL,
  `physical_disability` varchar(1) CHARACTER SET utf8 DEFAULT NULL,
  `disability_desc` varchar(225) COLLATE utf8_unicode_ci DEFAULT NULL,
  `img_name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `img_content` longblob,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `staff`
--

INSERT INTO `staff` (`staff_id`, `current_school_id`, `title`, `first_name`, `last_name`, `middle_name`, `phone`, `email`, `profile`, `homeroom`, `profile_id`, `primary_language_id`, `gender`, `ethnicity_id`, `birthdate`, `alternate_id`, `name_suffix`, `second_language_id`, `third_language_id`, `is_disable`, `physical_disability`, `disability_desc`, `img_name`, `img_content`, `last_updated`, `updated_by`) VALUES
(1, '1', NULL, 'Admin', 'Admin', 'Admin', NULL, 'joe@pshs.edu', 'admin', NULL, '0', 1, 'Male', 1, NULL, NULL, NULL, 5, NULL, 'N', 'N', NULL, 'admin.jpg', 0x89504e470d0a1a0a0000000d494844520000012c0000012c0806000000797d8e750000200049444154785e7cbd6793acd9759d79d267797b6d1b74930245032a24853464843e4a31f3cf3931214ba00151205cbb6bcb9bf466e259fbaccc7d5f1478118daaca7ccd717b9db5ed69fdcf6ffe69bd5aad4aabd52afc5bafd79b9ffcdeeff7cb6c362bbd5eaff83aaee5bbf57aa56bf37ddd6e57d7ad567c1fcfe2d19d7629836eafecefed95c160a07bdbbcaf15ef6cb7db6a03bfe7f62c96eb727b7b5b168b457cde6997f972515aedb6fee6be4ea7a3dfa34df11f9fe7bed00efac07396cbe5e67d7e67f367b43bdac34ffe73bbfc5ebf2b5f9bdb92c794df6993c6aadd521bca32c6bdd9f74eab5d18b9758977bb1f6e37d7bbbf9b67d6b1ce6df1bcb45badb25c2c354e7a5e1df33c56baaf7436fdf5bd1ecbfc37cfd9ce6ded4b5a07b489b6b216781f63ce67794e9aeb6dbba6f2baf9744d6e165b9d1b8f839fd55c8b9bfed7b5c0fccfe70b8d036df258f9bea7d602dfd117bef3dce6ebf99db9687ec7e7ee6fb37d5c9fd7a0d7b09f3b9fcf35beb4d773c43df9bd9e83bc26dd8ee6dacff2c0357eaed790dbe7f1749ff2dacc63eb775a36f23af25af6b39bf290e5c9bf6779f79cb8bfac21f0877f5a4fffed1f7fb9f662a28112a4cd2484d06761cda0e287941613b02aabe55a13b7edb80168597add4ed9e9f7cbdeee6e0016e0834856e1c993ea811278ad5be5e6e6a63089eed87431df2c108349001d6d0d00ecf6ba655941ac39211e8cbca0b210e6c5ece77b4c2c045c9f27d1939617ae1779730130c606e6bcc8fcbcdcbefc5e0bbf8187bf1917b79185c83f3ecb8bbbc548cf17da353c979d5e6c2c6a773b80a1bd0ee1f3a26982257fb3689a8099370bb78531743b737ff2ef3cc7639d81378371bc4be8fdc9bf0c204d40f01cb91f1e6bdacefbf2f5065eaefd14886353c820e67ee78d9bb6b9cf06b6e67a6b6eaa9e83fc9c90bb789f9f437b69137fd36efe76dff278e5e76d36a52ab71ab6ba817bac0dd81ec326e0704b13d0f306e5fe66b0e47bcbc4534094c739af73afa93cb95ceb79a2cf795c5bfffde7009677cc2dbb42f87bbdee46b0fcc0bcaba9c3ed6002dee05be24ddb85cf73b8a2db6d9761af5f768643b1b60e6c63bdfa238695855b03b75c97bbbb3ba1ac173b02f614f3c988df8675ad6327cbc09277172dac3a9908845a0af36b0718ad56ecac3003041a96b2105de4afe83377c433e247803b7fd44757a18df1d0aeda6aeb199d0ec2bad43b049cb591161a4f705ed44d01f746e367e77e66d06fd3b8e56a034c6a67a7b2348949b4bb53b62cd2f390d95f06412ff27f49a03d5f5ec879d7b59059b8b5c9548134c3d80a5f29b0c4d57a5d964b04b7172c0960ae9a81053be62200d8bfeb5db024b1f8f6866d66e035b809b805925b0d827b98af2d306fb58278d1763e593f5c9fd7673c33d6052b87efb760c8a6611617efce02ea0dd01bdbbf24f8fece60e635d0dc1468cfbfc4d6dd86fc2e6fee192833cbf3066536e779cdedceacd2c0cbf7798d19f8bce9fa3906d7d67ffbf9376b2d86ba9b6c169027bcaa8979d7c8682bd0d9a87e3c2726c40df7c4814fa884bb3b3b02acae906ebd1196bc70dd493e9b2f565209a7d3e9e6994b01110b2326380b5208420590581ffabf586ca5b40361b576b488d7ecac00f37637f522f4e2f277dbdd0e9009359107b98f3181a8c35082f8def76e01a0a3775bd03576f53a35ab0a1bfdb390ba1b1baa5fc71b5036a3ccccc863efebd78c078065394680aa006abcea7b5b559dce4c236f207927f69ce7456db38155c0265334d3e1f91ecbfc9ca71859661b5ccb4236b059f00c321964fd9dc1d20c85b95eccc3a4c0700082deb8f83de0673b0f75a9c47c5599100b42d0d87c2ac8e78da6b9263d0e7fbc4e6313f35a70bf361b7305f1a6469001c7e3e8671800bc063c267e7756d932481b4c9aecc86c8af14280bc06b6c01e8cfc2970f3e7f48befdd57bf37036cb38fc6233fc3e0dbfaefbff8c5da8df240f8ef66e37207371d5b0443f02445a3c2a6e497f11d0ccb36ace1702876a501a842e481f6c07a012c57a55c5f5f0bb0fc2f5375dec77f56453d7181660695b8b3c9b6048cda1da3bd7957e0faa60065569091dffdccbb2acf6b0aac9f395b2e3e01b94dbf92cd0af57a0b7ab150bccbe479aa647033360685dc163861300c686030aadce7261be061061dde997fcf3bb3c7dae3d21492bcaeb240e5f5e545ec35e4f66f813b04daeb8b314500002ef7c14268c664908295e731b380e4777a736c0ab6dfbf19d8fa4b5e23ea37a6c865d8b0bc413cd5ef2c4b79b3b2ba9855d53c3e7e9fe7a829ec5e67b9bd1e07337203066b2036b9ad6d303ff75fea6b666d9ea3667f2d5f66689eabcdc699eccb5e636e4b66e1791e33806a9effe72fc38665ba6bc1cdfaa807c9a092770cf62937c883d7ed0200db41617cf80fc0c286b5b3b313741dd0aaf6134fa817fd4618da5d31acc964f2c96ed46c67068da7105fbb62520f7d7fde719a8095e96f7edf53029a77983cf116882603d278b7032c3720cb8ded60bbcb45b0b44cbbb9ce866cdbc1b01f7a5edcaeac4678d7cebb9bc7588ba1daadf43becb3b20b039305398346de207c5d5eac9e4b0b5e735c3d966e6f737d6570e23b0b9c551b981cf702481bd6f98491dbed7c6a6e3edd60ebae9940c9f764f0796a5e978bd84c3c8f9e170b9ad7575e931ecb6c278aeb430e2d7b1e97e686e877e46737012bb723af01cfa70136ab9fcdf7f8dabc99f833af21839337e3ccf03cfe7a6e18fb3ee99fdf2df5be3a66f8ddea60b37f1aa3fff1cd3702ac4cd9fe4888a0cea814eccc805b454aa699bfd9c1a1c81904d6ebb0fd84a0e2b56b959dfea00c30bcefed85fd0ac0b2bda1d24a4fbe51bcb43ae5f1f1b18cc763754483578dcd2cdc8ce692f704be9ef0bc3b7860360b2879007d5d9e380ffa0640eba0fbd9cd1dd78bda42eb859159e127e00ad5b64a0e23a4fd32b2860adbc1ae6315b0ced32740d00a86e9beb3302a370bb5857b44ac42ddc1b01eb818147f031aab7559b6700694d2c5a1c02693cc011b1b9b0ce5a112d36ed4abad0a196ff1ce2a55b402606c882bedf0b180d7627c9a3f0ce1b56f5ea4dacfe4853668c773596bdc87fdca63c33337eb25a92719b8336b311879beffd4e6dc04ad0cb01650c63e6b0706aa7cef530c96fbb31a26bbe97aeb5dcd6d3499304878bef32692c174a39d546f78066c8f5366347e6eee530626afadfcbee6069c556f6fac668d96852623cbc4e7934d3bad19b369645d00f73f7efe8b756e7016060d0c4669909f895983fe5dedc442cc1abae050060fda52cbb61adf652302d416a5d7e994bd9ddd824a28a1d065b1bb19653db9fe7bb15a0ab060589b452930dc8635186cb9c73a7d5e101e7c7fe7fe7ac0f87b77775728efc9fd1460d6a5dd7128c75a6a80052b7e3aac2254d3fc0cb739bbf83b9d5e81806a174400bbe109d2a4ad4205e3be2ea124d8c416f19d058677ea3d7895daebd245fbd578471b03d43b85b1b38362be0cb02764027b96e463553720d4ac563b3c8e7c5101aed3a65f4bcd35f3be5c2d75bfc79b31eaf787dacc0091566b1d9e599ed7635c2a48b6b79e1efa27e379b5198aa103d8d81457b1b16dd763bc6bbdde3a4e002cf5b41ae1014ddac533e410a94cdaf3933d631618efe09e93bcc9e479dfa852c9309cb589a64da6b95919ac159e22b3487866f997d56c6fd2b0b5fc8c6cd3f27d7e7f93fde78d3a0383afb3517cb399549b921d4c7983f53af3666c80f4bd065aaf75bf9beb31dd64534a667e5936f2e76683d8b6f93dabec1e0f13130156b667b8b306248389d5bde64ed55ab74ba78b97cb1eb252e6f27c758547ecc62053a7bd2a835eafecefee09b084c8ecc09585194cb260aa23ad521e1e1e36b118b46f3e0b01de08798a4172fbcd623255cf80d5dc2db361b0b9136ce2cdec21949d7c2b58f1acf0863699581efccdd8b660192d010a821b7796c28255ff4bbb4c6761b3d3eeddaa3128351648f385e361b528837e6560eb96d4bbf061c67ce0b0085e8cd381b8a8f092ad6573097b5607a01133b51d2f549c10dca2677a6cb69f738da123ee9513432c6a59786b5740be8d6102d4799f9954660d9aa3cadc3c867a66655d6bc05c2c7deb7df34266bc0c4a396cc3ebc8c2d6d41abca9642664e176db3253f1ef59d03c1e0647afb9cc762a9dddd8e1f226b9995f8399ec6111f282f07ad3b5ec75ba9d129bc836262b032cf7d9f191816f039c0da74a9083adfdb9b959e7fe6450ca2abd5997c739bf37039ec7c8636b1666a0ccf2e877f95a6dc0f69efee32f7f25a3bbe9db869a55fb863a5b3d2a79923d689d5657bbbceeab749cdd9205cadf04eab170bb9d5286fd9e18167158da112bc332727b02b38ad3ee7614d600cb32fbb260735fa6b61ea0a6fad5dc953c11bedfb45ece800a12cd582cbf3b2f468f4706474f40bece63ba69ff3ad82760355bcccb6c3e0f405e07db0863fb96c9b05071e56b927b8c376a64b8fa7b3ddc068055c4a109bbd7a5cc97cb329b2fc47e168b0844e41984aab0e8a5c8b7c2f682e9aa2d063513f3328bb2a0f4f0ac2d82a1f17c0009d6cd1ccba0bf09f1a04d385222464436199814a64a85ced81113aa1dcff3baf33c669b8a8c09b1a7d571d902a085d0f3c5cf762fe2943228e40d248353734ebc66b2b03499c2536bc07d304bca80b611de1af2928579cb22b72112ac6be617e69b0326fdccbcde0cc84d8070dc5293e57b7cf3b8c558fd719075739c32b3f2f89ae498ed5b869e62514d99c8cff7ef8e916b3e2f131881decf7ff5bfd7d9aeb3e9100b25d9953c309ee80d452db005548cb06d69e265748f3b6c4769b796656730f804b064e3a80ccbf151cd4945186cc3dab03cbd736b03f08436018b6b4c85b37018cdc55e6a843dd7366d1e9efc0c8c1efcac1a784c32e5f7e2ce3b8b1adde996d934023be9db783a2de3c9588e852e68b15ac92ea4a0c15e5f6dea1206d2ed17c05b13c88edceb6a37658ea4b6a1e60144ed30604ea7738121147d3c1a97d5029028a5dbef463cdccece96e996550114572d54c256b0a3b216e3533fccf4f81c551c800208896607e8642b09752c335a818877c63ab1303b05b256db8fd99baf356bf13ac8e39c37817cfd062452a8465671b2cd270b6c66c95915c9efdeb0e2aa42f9bb2698359997e75f9f2b0c2e6cbc9842229e2c3201007e54da18e7306978cd6e65213247cc009ba098c1d60c2d035a13e8b27a1996ca6d5882fb65b344738c0ce8595eb319c632e5679a816d58627532f1b741ceebc673e37764666535b4f58f3fff66fda768b3d132b32f0fc40635575adaa136d4851d76935099225e85dd745d7606fd0458613c67f13b46262f562f745808420703a19d6a4b4d21d97422a9677e8681c2d778003323e33b4fd0533b6e5eac5269eabfd81d23c66a516d31312edbf0884c9bb3a0f14cb1ce1a3ff6381e4be51d3d3c94e5625e96b0ade944cfdadddd2bfde15076a555b54975fb3dd9dbb25abd5577aaf3b5c62bd1bfc9645a26a35159ce66b203461c138197ed727474587676433d1fececc8260623625e606106fc6e3bc091f41e54f4056a5fb561c2a2c21684506e036361455abcd5f6d75a55b574e3568ff83dec799ab3c5bc8a4ea8db4d15c200e035e9f1cd2ab737222f78b318afef6c47f4069581cfc22e60c04edb883bf2869659a0856ca39958cba86132d9abcb7d56d90c2219580d56195433ab0bf00b5ba5ff59f0f9ae1914dd64711e336b0f02cce4a4cae3fe69df439e73fbf33c6c35986895e7c1b298c7ddd7e671174e5459cc72d39c47ad89fff58fbf58478e55a4786c76c49447e79778a2f2c0620fedf6b6360c4d9c0ce9a1f62c6a80272ae1a0d72d3b83a154c25e0db977b064de91f264025836ba7b6700b00c4099c2735fd3ed9f19949f9b0722ef0e19a00c6c31719a864f62b5105c582591d7f13c59f1361ea3fcaebc8305b0398ca494d90c06342ad3c9b48c1fefca78f45866b3492459b6bb6257ed76afb4fb83caac50ebd27f8a0ec7901d11d6fcc73f8393bc81ab65193fdc099898e7f17852168b9936981e8c6b381438767bfd3218ec44cea5585347bfcb980fe0c8e681ea8513868d24c20ac2531c0cd5b6b04e373cc7d270e5b90c90ef080c01836084314e72096e16bbe6b1aa5179c7a6edac9d1cb99dd5fabc233fa54665016eb20a33005fc3fd79b3f3b3cd7e2c60be3eb3982cec96077f6f606b320fdae3b59bdbe2eb9af7e7f65b2eac1168202be335783455b8003a622103fcd86cc47d2b06e471888d2becc67eaf599141ded86020f2b506203ef75cb92f96bdccf8f2c6e46766106bfdfc17bf940d2b03c65306b42cf81e0435a005b38ad005830f362c10d9ee7aed669561ed0e77b4e8b483d7c0513778b36dd4c5af815c47a43b610d6677a82aa6c71e08a3b96c3235ffea938ed6c1ce6cd1efcbbba377083f37ffbd59948a8cc773b8655461ab8b7134e3c96db3c7476927edd80de9c77c3a2dcb05ec675ceeae2fca64f45066e3919847abd3930a395faccb542a5fb7ecedef6be2b15d21f8dd4ea439118ccab8fa9d9aec1a3e309d8c4a6bc586546d67cb48249f4e27650a7001b62b361ed2a686657f7f5fe01500d82aad4eb71c1d1d6d1c1d249f0b34043aed30cc7702dc04c678973bb11eb6b6130cc9d5355dbd795bb64e22fc36019e2c080beda01b2a521340b2605918f92ce751e6cf3d2e5ec75e2f9e2f0ba2c1c6f39e9d31be2603c3b60fdb5cbae6b3dcd6e6c6e5f5b7618b3523233fd3826ff0cc0e103fcf2423f70df1b35c192832bbd9ace56a4fcd1bac3774bf3b47f37b8de71c563f777b7dbc3bcb5fd6863c1ed94e6ca0330e791ef2b3f51d0ccb13db1c5037200b744659092d6ca755938e2b8a868b1a06123ba85e54b061f5e52544b0c4c158dc552574279a838a27edfefe7eb310351029acc003a39dbe0255de493318728d75f3cca04c6f336837c742ea129d622554c0a2cd18b6610a736293aa1b3f98c6360833efbe3cc32a332a163148abc5ac4c470fe5fef6aacca723fdcdf304203b7b02acf16c5e06c3bd0896ecb41586003beab67b65b083dad8966769b9c26e352b7777f765310b63fb723629bbbb3b1b26335f447a8bdebda27ac5aa3c3e3c96f99c5d378cf37b078765ef60bfecee025ebd324595ec852a193b2eed06b8661175de6a8ba5ededee09fce6cb99589a62f73a5dd9cc223015173f9b4a787eb09dc996894341a9566160974d2c2641c0682528331acfa73750cf19e3a071ae71669e8b9c9f9641249b44fc0cdf6f41f24f0ba1bfcf1bb905bdb9c965503443cbc2bd01b84f423a3eb5d166d53733b8bce97e223b09b0721ff246ac7bd775534a55413c9e4d00caeb1a8d02db2960e65094f094a7b4a6543525cb96f124cf4f1ed72678b98f02c9fff9bf7ebe166a572b3934de0ddb804d0a21f0cb366a159b292e7206a8d27a33ac60203589743d2fc37ebf1ceced4bb0ec4aff3469f8d3922e3494dd1c95103b966d58ed56788304b4128aed4e8e40f379d3159f07d2f74a986bfc539365e58580213a041b50ea82c4113c5b22dabad5ea9625ccaa1d4e072f62ee935d81a04c26b78643289c6111d74e2793b2984d4a6bb528e3c7db321f3f94765996e96c5e56eb76d939382afde15eb91f11e95fcaceceaeec5d303158a759d7cedeae0cf1b162eaeeba5c95d9745a26e371198d47525f4f8e8e2ae8e0910c40601c468f23811600dcebf74ab73f28eb56abececee96a3d3338122f693f96c2a763c9fcfca4aea30eae2aa4c4613b1c45ebb577afd7e217018a3bfd653b75bf6f70fcadee141e9f5fac1c4e5aa6ee95d128c0a4a8459f0fb60d02ffd2ef62d3609723eb7de2c9e47e028e39c19558c7584896ce63b5511d06655a3ae599bdea804585c2723782de753d7bc9981412fab38061ada6f99c9c6ea2c984af6af1b7a246107043b4f546de88449c68cc9cc328362bcd3ab337e3e25f84c6e5edb99a16616c9b23478bbbd7ffcb37a67b5896ced679918b069b3f16560ca1b7513a43e91af94cbfc14301b88350edf7cf32b19ddfd400649610735a23d74ddf06278523c896637a803a2d8f51a332c79cd6cb85ccd65c3da02564b6a44688edb803f3a62afa56c65ab6518a5311c1b5caa0d2bef681e000f5813a03cb1d9586870c920634696272d006bae09e9760702acb9ea2961c322a938d4166290ec80a0ef5603433d0ba3bc4077392bd34984322ce6d3d242c5eb14b1abc9e89e75ab500ee8c6c1d149e90d764be9f4cb68342dbd6ebff47bbdf2707f576eafafcbcdcdb5e6a53f1c6c6c04a19e8527903006fedd3f3c88a94e46e37274b85f6b92adcbaaaab26ad77c2a00007cd75428e811ceb02aab56ab9c9c9d2943e1e0e040f3056029d4048096477121bb19cf771e64d8bc3a02829d8383b2b7b75f86bb7b3220c4cedc2efd412fd8deb2865e74ba2a45c467a890f2aa2d67a523fb64478c1ccf24eaac18750aaae55a8358de80b6eb366c6a1b1589f597bc55d9cce00c8c50bfa36c8fc1c86b8defb2973333bd4f206553c5e35370f11a65cdb29e080f6ad78a155973c8d7d99e9ab51f8311d76570939c2ac0b8321f0941782c83e9627f8c3a774df931704681826d30a7375f8f8937fd988b788ab1436ba36a3e6ea31d6cd6ea9af29a5542cbace55c9b055e423fccc0e11d231bbdb2501bc034592d22bf232e274f3841bb4658baccc609605925dc78a22a0d76e38cfe1bbd7ebd1260b95a43ecc6db6a106e4b06bdcc0233ca67d0f2ef7950bcd8832186015fbb0880ba22d23f1c0ab255a2caae56f2f8013ef67611ac80a0e17de3aaa8ba80e047302df14cab16f6a3913c82d3d148aae4723e934af4f8782fd51981b9b9bb29fb074732ba1f9e9c97e96c2975afdbe995e160a75c5e7c2cf7371fcaddcd8d98da70274af7f0bdd8d07225b6b3bbb727a6c27723b128d850083c6c69369f097408ec7d188db4e87abd81361bda8c7acab50352ab7676cae1e9894013d0222463319d95b5ec628bd225da793412db5aad01674257bae5e8e4ac9cbf7859babd4199cc176a1b7b3535d21052c61e008f8db12d2609fbea0f0665d0c5f0b08cd00079a4c3c8af0878c50b46d02c00bb590f8afa77c58c00ce10f260fc4fa964798d7bd33400781d795d6a83ae829e37f2a6ea63b0f1b5664ff9b98eb9f21acee0f11483ca9fe5f7f179de903fd9b4954511c0e436c8c65c63e8727b2cc71ea3ac32fbde8d7cd6f41f9ebb94a32815aadc44d36f5923c1e2a1f2d76296aedbd5a08d2e00ba014eb3531bdd9b54ac896e9e3077c2bbcb62bd281d4731273d78553d619a28768e1280e5c051ed8604473e51c02faba2a884b02ba7e6e8bb9a58edc113a828d567ab9235778c4c493fd949d356c8352c5425cc543771d8adf05a45cd2abe4308d99d7008e07183690cba7d0921cf1e0c0765b0610e4bd9dc22e23fbc8a522fb1358d468a779a4c461278800a0339f97ec39d41b9bcba2afd9d9db25cb5cac9e9b3b2bb7f24c6c358688111a376735dae2e3f96873b406bacc5707c7256f60f0e050eb3f9b24c51df143ddd934710e1bebd8b0a18ea2f693b35e585e188b12eb26369deabe06be1b661733be5f0f0406a1b2082a793500cc23214643a9b09900173fa3d99cfcb7077bf9c3f7f514ecf9e17e5878ec765b15a94f50c461f6cd035cf186304eff0f0306c5feb95cc09fd7e17d80a55561b25867f3429e2bac0c52d40595d512a50b26735d98885dc73ef759201c6c29ced5a5e3606190398d7a46da49613aecf4cc6d73581332dc78dd66370709c5f7e4e665a065c8147d5460c5abeaec9608899cca0970139ab9a66974df534bf87790d43c9b64a8ae72133c6a62c66ec319bb27ad97c9f6c582ce26cb1f72e951989a99f63378cba2ca01e3b7a4a57e15a18162fd3ef2b16725b3b78f612cade905442536a0f5456095dadc17624aecd819a1e102fc0fcb727cdbb4fa6ee7922373b4f8dc1d92c5e5441528dd831f0e4d43a5e21acb3727f73bb4971e019c449c16688bcd604cc61627331518cdad3d948bb3c428e20de5e5f892da0aad1eef9645cf67677cac5d595d4c27677503add4179f1faf3780e399d18c2c713f279cad5c70fe5f1eeba3cdedd94e59442878c794b06fb672f5e97e3b313b559f636e71a768a54444af72c6653b5935c4f8f3dd7c26cf1180e7a7db12cd43098ca7cbe2c83dd9de867351f703f6b88799260af16655413d695e9d885659d94d3b3f3b2b3bb5f66d399daf3f8f820e0e559de246cb744053d39391194c2eef08cf606bdd2ef7714dfa5405805db46df56da3cc3c36826119bd3b61a89802999383cc7999567db5630be5035b38c646d8477e5fc44d6a89ea1a201dbfcd22cb45ebb19e02c53cdcdd640994b26670291c1f18f986308b11e69b03688e8ab9acb9bd998dbe47ed82b9ac18c67195c36e4a6135e60aecbb2e6fb9bf1967e869fe3798bf66de31e0df63c532a21c26537a581c90fcb34d5b62b23b83a5696c4e76e54285e2ac06b07054750160b6c2fddb23b1c94216ac560203b442ee0e74ee79f7a7e55092d086a7ccd85b51eec367ac2f322f4c270db2d901e7c3f23f78da0c16cb78b5d1c7b5a5497c0a645ea0b1300e8a09a89e676a27ac4e1e151841854db1c0662ae95676d09431a09d06022f0b6f178240334aaa1fa3c9b97dd9d41198dc6653c9996bda3e3329d2dcaf1d979e9f50712386806aa13a08517f0f2c3db72f7f17d994f466531c7e6c062ec97de70af0cf700ae17b207a1924abd26c8b3d352fb61b012465543280213d6039b8c81962fb8976793c643fbb19375f8496ea8e3c1aa3d0b0700c0197dabc05d8a80697fff50f7625fbbbbb92e8fa3470914dec483fd7d7924efeea8e3bf2cbb7bbb65d0df29bdee50acf3e068bf1c1f1f8a2d467c27e94111ed4fac9f42346abc5864714770aa054900b63993e0e9d2304d75c5eb58f166d540dc646d99b95876bc963383c8b2e3ef6d7ed8d868eb3b0c96beceeb3ab3bb0d58d400d0cca8aca918dcb26661907000735c93cb8c472115654e5481f3fd760618944c4c7cce02f6b888e88f8d43b25e8b252a4e2f19e7dddecce602a042758f3ea89711666395d083e089300ae798934c4d37b6020c2f146e90413a6c0881dc35525a551e164af7d8dfddd16eadc5aeb2299bb8b54f6236f2443af9198fd866e724f6abe92a71947d651046f90dcb4b870e78d1f19d07dd931092f3a9ab5741938ae80f5590576b1289c29f4ccafbf76f6583c25e440acde1d171190e77aa9d044fe2b4cca5264dc570107c2aafa242713f397d4a569e012418b15b657f38d47d0fa34939397f5650b14bb757434548b1e9495d9a4ca7653e1e97c9c375b9fdf0bedc5c7ed07cc088e6389e701274fb6244f47b77673716524d54464515eb00500904adde31da2bcf5dabc81b3919a3e2cd0468b9ce110000200049444154a2d8cf7ae425f607a58d9d89b2d7f4b7839325026a43680320c301d10b4fa976fa888ea7fda4e8d84609633d3b3b938a78598b3632f6bb7b07a5d3e96b8d757a9df2e2d58bf2ead5cbd2c53b217b1bf991c48345c9e9cc3294105ee3cf62d9c7bfac9664969dd987d79b37c41c92e075eeb227069dcca2b24c6520f1facee0256da2715887d770b3ad995d653699d55203407e57d65cb2c6e47664d0b0acebddb5924614c4a881a6327f443e30f3ad77d7ff5c265a450fc4da3f7536c4f28b0a1fea8bdcc69509cad616261e03aedf29f590382c3e30d3b080bb435987f4c2ceaa584d25dc24b36e769e6e9c50237028e1968661a11242f5454f3918a152d20d8d4ea7d46820d72b31008466a3aa56a37b73a731e5a57d9efc4c439b93e8a46ef7cb0bd334d9cfd3a4afda8a23e2b339362ce9eae4393e94776f7f2cf3e958bb3e819778f67676f7c285bf6e95ebeb4b311ad5705269e60891e0fabbdbdb321c06c315a0a1ce2d16e5e5b333a5d4dc8d46e5f4fca50061325b946e35c8e31d3b3c3a1410dcde5c97c5e4b1dc5e5f94c7ebeb32aed52d000fdab0c47656d9c1b03f2c7d3e5bc5a11e5efc94b051bd31556788446585922c660216de71717151e6b3b96c60ac0b3c7ed82d861c2c022092a04d1acfa05f3a806bdd10c2d01dec91be597d42d871c230a6a87418f007c3a18254191f97c6468504784328c26b797e7e5a5ebf7a55f6f72232bfcf9c0b7c63f5afeb0625804ae5bf35d78d5016af7964c035d7366bc171848d28ef2cd01e47b316cb8c052e339b0c304dd0a3a95cebebb30ae6dfadae89b924826050f3bacfedb79c18142dbf4f81b3dfefe718ccb8d77295db6299926c2a73e8d37848e38ac137a6c369593e3b219c209ff4d7a588d306a3c06454420f42de25b27eda1c703f5c13d25e4b5d8afad681a4ea44b7a74528d73ef14932c8463d2cb9c695eeb13d8482c63acfaa89ee19b0023cb6b5a9bc7379b20d7c5e18fe9cbfdda7263b33826f768f2a6006ac10945a595505f66243409dbbbfbb2d1fdfbf95e78d18226c3afb07c76205b2d5cce6e5e6ca80352d837e1cbef1f838927a347ab8971a84e1dec27c7575555ebd782e61bebabd2947a7cfca60b85b2eae6e3546bb75fca47e1e1d08d0b16311703a797c28d3f148a03505e4e7b332003c6bbd2f40d37991aa0ad0e1649688c39b4ec702a9a80211397ef3f9549fd156c6f0871f7e28930a88e1c91b8a69e13ddc3b3ac455a710076c6cec920a4de811bab03d5a8b3992aa596d1dac0740911dda3652deefd39208a0e519e3f1546088378ab9393939563ee4f1e161d9dd0d0f69cc3b8e99ede93f80304c1210b600659665c0e2dd022cd7daaac2929949b6b3e44ddeea5c06812660f96f838dcd303e4a2f3309cb923fcb329155477ef798190cdcb78d16540949060b8358567f2d2b222bcc4df5e465e6978985c7cda0e6fb15e25035ada6d71282e2aa2e9939fa59fe89277ec37c95f6563321ac121af58cda1bbd34215f9e6c0f3e8085413a0ccae92cbacabd35d92ae8b094d11d95500cab0216ae680f646677de2160581887114a830eb98479e1e489cec0e4cffd7c8729b8af99716550567c76f538ea793596250485e28552c8a52edddfde94ab8b0f653e23b073a6949683c3e3b277705c76760f24ec0f77b73a7463311f2bd6aad769c9bb28c1ee86370c1b1ded7bfffebd807e3e9d94d39363d9c58e4f9f09041f47b3727d73237b118e12c67b6f6f4786f9c7d1a8ecee0ccbe3ddbd0072747755e693c73279b88dd81e5278542606c10ddb0efde033c244d47f1dd716b6b9bc78a52e2e39a18618ce55b9bfb92e9717970263e6525525ba5df57bb84f08054e17aa39602600b4c8511c6c8ceab03e1ec6bbb0cd314fc491d186d3d3d388cfeaf7cb18555a001b8b5755584bab4c66718e00eb9171383f3f2bcfcf096edd09164ef509a988e135c6104fcd3655b690fd645b1071c330d3d982ded8b2406d8427b9e1bd46f3e6fec9665b376f838381c46bcd80e2783d6b247eae8981efe7efccb0f8ddb5ed7d4f96a50c6cf9197fa469a4d4bc0c6a4da6e7f67863f84403a963cdb3b36d2bcbb49e5d0f40f1b3b329c66327b0aeb9c89e03db985bbff8e657aa386a15d074f1137b54a5f36e48de296474af75913cf97a492d3416a63c54c228e06795108151f1fe6e78608cc84de46789baa6bb1bef382c0fbc3fe7395601bd137877c86df340e7ddc58b4e4058553f095e15de5587f6aa60afe2aa001bb4d987bbbb0a58a3329f8d65903e383e2d0787a7a5dfdf2963bc66d4a3a284c88210883be5f5713f400c7339393d2da4cbe041a4dd78ee2e3ebc9757ececec9942018e4e9e153468e2b01837fe7b78b82bd3f9a89c9e3e53923436a48383fdf2e1eddb72fde1c7b21cdf95d1edb554a5b5aa24a0f20058a5745b7d19b501ac88dc0080ebe114029b6a0baa1b168c673419cb4e44fcd8e8fe412a62d4d8ea2bd0145bc6d1f16919c29660d535d730c02fced88379015eca7620a8541ec84580f47c2ef60d0846fe42a84832b0ab9a292a0775bb8ac2352cc0381f4e8e4fcbd9f999d2890024955d2e2dad39953faaf5c5f05eea742044428e92c89660dc1d0c99d782d74d53789f625d59800d4299e91bb036eb3825049ba5e48dd3cfcbeb9bebbca6ade2b9dd06d5ec40b307f129962400aa4c28035e966f814c4a71727fb2279536abadd5cce03e34fbc2bd3187b1d99845fa7e8fa9351a6b689f0033362c8344a6b37977913bb171f2b13b68269219999e275a1849b65c43122b867616a393740d2a7e97a9a4dba167973897900137a89961e55d2f2f329eaf82785545cdc0e445b3e933f13c7683d7c869a57ed46058206a468230d1ee1528880ee6dd78d888a5222c613e9f94d50c6fdb5cf1524727e7625b0a2568afa5aa112d8ffd6a3e9e28bde671f4205bd7f1e96919ee1dc8980d10a1de7d78f37d193fdc9483e393727afea29c3d7f597ac37d81e6643c15d8ddde5c96c7fbcb32dcd92ba7cf5f96fdfd2319b6ef6e6fcaf4f1ae4c1f6eca62f658a6a3b1180f2a205e3efe93c3934c50b211884151980879a191dfa95231a9dcb3027d3b9d6a4bc4eb392f93c7a8b38f7a2bfb025ec0fdbdd291917f20708a6284643504936ed58a0e380db0a5b57b04ba764b9f18b47980312c160706ea9f824997ab321c0c14004b30e952c9dada06157b06300e06bb52c1cfcece4345ea8430f26c722eb5f363ecef532a27aaaeaafa83d2c4189779545fadc507617299396d420354237f5b5cb1dbc8ffcb009765a8b9615a133038782d7b7dfa7aafe12643a26d6e5f96db8d8c38f527791c2da3662bd9cb9edfbb799e807d1b9e947122f7677befd6abc726229ba0360e5d110e11a999dbf49eb06fc6b98d6c7ece9555e0334523d3a6a2b5840d2bd7e8c903f51425f5671b54ac610c768f065651bf29766da12a06e69a5787ad6293fa5369b8272b0396275b45eec66309e8c628576d585cef49e0bb6cccdbdc5f6d5719edf3228021469f5c65214ac560b08e818cc549350419fe17eb08bed4010cd4ae1a971b8cd1f349594c1f94104c1eddf1e97918a5e546c19b3812cb924ab25895fbebabf2eedddb420ee0eec161f9eccbafcbcece8184edbb3ffcbe8caf3e96bbeb0fe561322a27e7cfcbf1d98bf2c5573f15cbe2dd18eb57cb69b978ff7db9beb915401e1ca14ee17deb97d56c5cfef09b5f97d562223b96de2d6f27a15b2c2cec80d147b1c86aa353591298aa22fb31daf7948fc8bd1c82cb529bccc65261d980e8cfbb77ef24fc9c8884f713c339e93d3b8ab087154e2ba36a9775153497c8616303a823813b6c802a1f4dc1c12835aa1af49331ded4961894c262fa5199c2b5e1b99ed83318ab054e51ffddee461de57a4079776f5876862483c7b994f258e3d18a5a38f25c2e11945ac935af253103053cd7e3cf9cf6d230cae70d3d8352937558469aa421331eafeb26d3723f9b2cce6bd6cf6c825e136c32186e36efc681274f0168b38ffebb69bfcaedc8fd7c8a61f93d3ef3203331c11e80956d53f9e1190c72a73e6136d5409919182f85d27b07c0450ec362a1e54a9706a03c89cdc124885076a087874d50232a619e242f0877ce543203ae77245fbbf94914be54d2d8d985f23a0926ec3db139b4b4fb6318471d74bd6d8cb893d163b9bdbcd4e22fab99d816c2f3ecf92bb9fb490c6767c1be45aa0aa10b5c4aecd4fb1fdf94dbbbbb727afebcbc78fd45397bfe4a8c673c7e2cefbffd7d79bcb9286fdebf91eaf4fcd567e5b32fffacec1f9c9545cd94a7a6fb6c745baeaf6fca78be2c8787a752e5a8f3de6fafcae3ed75b9b9fa2826e612cab1a10034043bc6293901f6db923db401c051110554328116ac6a19551f5a4b8177d4860f7be2f7df7fafa13a3a38901d6a5e4ffc8935b056d0a9dc14aa23b60d0aa48a6aaf3b9067103b16efc6aed9ef0d64f8f581a5a878d831590f80d2d1c971190c18df5a7542b69141998a59af15ee01d03ac939e2c6f05cb6a46262f73adcdfdb9c421e31473e94370c19521deb46266049de45c685b30b8802cb1a818fb37a0a80cc44bca97bad4b5e6a306b664b99e1b196bdbebdf6fd13b9520e683a25c79bbfd77dd82eb7e72eb82d99a56519968a576dd256ff729f36f6e46affcab63bae33813086b81d6e63965fe389ec8d36d8eb64f4c52735ea05882ee067016e2260d62f9b01637a793dad84fb1da76286e51d419f8bb607609961b9a1990e7b208dd664fc03563c6373fa73add6e0b6baf3be27ef30de9dbc489abb0e797dd88ea2adae431e2551cc0e01011887ec00d4b0df246b2f6450c76b46dac86cf2501e6e6fa27a44af5f4e4e4e4b8be0ccc9b84600adcb98da54eb5659cd26baefcd0f3f965e6f58da839df2177ffdb7a58d8b7ed02ba3ebabf2db7ffadf65b8d329efb167757be5f4ec65397ff17939397bae4c82874712a5a3d0de74be2aa3f154e38b52f7e6fbefca7c7c579673a2e167b2e9287afdfeb1bace51d9a39f52a1547122d8b073cc9481bf2a65318f2aa4fc53ec4dbba8740de3818acf7803e63c9ffff677764b67d81758b001e04d947a4000ad4ec6c6fb188c9571e3bb882bdb53891ad81600b3b155d4f2ff32d24f23fc837f305d22e10130b132c6b5dae39ccac53d360f046071e94af7f21fed072cf9c9d885c0e051961213b6b09ac5e1247f09be0fc8488783e6cd363392bce6b216d0641ebee71355b45ec49acbe06376c2f37cda4c063b8346663d99adf873835406cf0c62765419ec2cd34f910183a23dccc60bdfcb739b8e8526b0fb1964891814dd5761035ec2fc2003863b9f51d737ba43ea743502e6921902bfc601a994f963609db6920124372c5361ae712e21a0b5d1fb579fe62a79b0b38a987713a37f13acf81b953002d86b299c1adfc23d6258d8aed6308410128497364601be45b9bbbd2e2b1de859ca6474a754190ce3dcbb7b103bb8eec533e5782422e9679332bbbb2fefdfbe2b65dd29ede16ee9edee959ffcf99f2bd6eafef2b2fcfefffc53d9dbeb95c9e3bd0cdc07fb27e5f0e445397bf9baec1d1f97fbfb0719a389fd42b57a1c4dcac1e16169af97e5cdf7df96f56cac749dc7fbebd2ae763a31a3aaead2cef92cec8c782361367132301906c1c474fa91c21baaed6b0d40460c108c47d56349139a4e6b806857260a1516ec476554a52955c78a9e5b8fbb8a5cc64878e63fae4325c44eb5bbb32f4091b9426720529d35ca6473ed641c81b8b483f4218cf5a422d940ec137b0049bc9966203a10a5d6c6e7396c2cdccb33f6f433422cb41174425d06b0fa1c6fa7a0c618af8dd1b9163a303bcb1bbf41c66b512cad91d7e8cd36b3a7cc4a9e02befcfea6ec34d5c34c06b2666459687ee6fb9b762ee341b39f198c9aeffe04682ae0660fb47124836e26211e2fd6d82644e397bffaa7751e4423201799aa660adb9c90488ba016f8966e9a619916f2b347b50632ef319eeeee6ee877de9532bbb21eec12c92c4ebb701564fe44a47b7367b051dfeedd0c5cee876c58f694ad223a5bcc6a73e840d439f7fb3862cc9306eb988c1f4b4b3bffb82c66a332a7d4f19878a671d93fd8af8733ac25dc0882c20696b382a977fef858eeafae55affd87371f4b676fa77cf6e517f21a62207ef7fd77653cba2dc35e4bcfbdbcb82d9de17e397df6a2bcfec9d76552190da927a4c73c3e8e1525fee2d979d91df6cb3ffde27f95773ffe50faa4dbcda35d11b4196a8cf233a9d3be26189684eca85d15ac9912358011154d7b4a7a06ccf0d8dedfdf4ac0bd56000dc064e3ee160b0ba32b0cebe0e070938f1727dbc4380f87a832b42b4a0731a5d4a077f026ece9f4ecac0cf776b5716893e02420589f8a0f4622b8e6b91b467ad2a21867bee7f9fc8cb4ae589fa311850aa9a5151e4b8177a713c9e29d5ed9d9df2bc7c747e5ece4309ceb951504c3dc9edf88815ee76d12d29303701b798c6624cdf59acd2d5e9702d074282ce3da240cbe3633a4a7e426138f0c8abedf6bd840e0f6d086ccaaac65980c18c8bc0165d5331bfcddbe0c50963933c50c8ed9b1d7b45bf95dea932b8e66ca9707f04f21e8469d73b068a3d2602da820c0e41900160bce54dcf75be53485cd13a9c92a21ecb25fe800056c16f5b0d04acbbd607caf75dfacd337772df76b461d266c2bb2e544506ab41daf45bbccaa406d6265e6dbfa48d83488bfeab7dbe5e1feb68c1f1f143f8577946a05c445e14da3be396c05b589087002a07ae40d2e966574775726d379f9eec7f7a53b1c8417addb2e9fbffe4cc6dfe9e8aedc5c5fe8a41b8cf9b70f93b2eef4ca8bd7af0baad3cecebe42091e46638536c0b62e2f3fe8f9d8b0ae2f3fca63b8900da928b5464e1072196bd4f9c33df97e6d01031e595422d4380a136ae1a94228257342b5c3b170737fb71126c54c8d517b4b94b0998ca5d6ca16b64065c114102a587710ea5ea8678a8cdad856bc3079d6ededbd80861009809fc469ec63613f245a1d8085f906eb0a5d2fbc5a8024293e511d3554296f780034210e00346aa972d6b05df67a722ae09d04f00ef6f7cafe21798bc73580312a9fea9f3cc85ad96180af9b67167a039581c372d034836421ce60c15a3780e567e50ddea060c1cfea5a7eef869d3c714e43be37035f663f9b0dbab264b32d33bd4c08b836838f3716cb7953deb3d6937fcf7df6b8aa7d18dd7d616ea45fea01323d33cddd0cce13f959029f4fce6203b06287845d99bd719d77113fdf13eb41c148cb020e41aa8256d5b2ac479b1a6f76c40a661b235e054ebf4f93584f0d969b5c5eb396c0d0211918cc29bd32a9c5e278070c2b98033b2b86f665d91b0ccaeded75b9bdba94478e646fc569b5e31059fe23b71063fe74429843295d5420e2b8ee6f65607ef7f1b23c8c47f2d6e1d1c3dd8ee09c9e1e97373f7e5716b365190e774ba73b2c97d75765d522c76e5f86f6e72f5f96a3d3f332a124b22a07ccc4ac46773702bdc7dbabd2afc67f421064dfa9874a70a418c674b1e1569c2329a0e77fca078d24249537c6f00b63dadd2bbbfbfbaa620ab3b2d7944dc59567b1ddd1676c6fca195bad557687d003d4be18c3f8cf867bb3a0009899e2d1507b238996fb09127d26bb55945c0e3b1c6da04fa369782e793e9f711d41b9b29d91900b635128c44c8025e002b4a9ee5a4bb20088f9508ef367a7e5fcd97998016a655e6d76aa841af15c060e838fd7ae01a0c9a6323058f6fe9480667078ea3ddee8b32925b33ad534ab954db28d9939b6c69201c11890999d8b233c05cc96affcceccc69a2a30ed6d92922cc706473e33101ae445a4b061f18b05d9795e11d8b73d55b709581b347445d1fa819fe568714d2e09aa95d2b318586c0626d3c3a7004bd4b0dd123321ac81f6f0d96c5abd7795d5e5cee580573a6c036006e30d2da68225210b54ad14cb8a53a58119957d2e045062e40d76c233f8de4c42d9e4cb85129547a387f2e1ed1b790109675a2ea66521f7ff5802401d0404188b35954209c07c71765aaeaf2e243418b7393ff0eaf2b274cbaa0cf7f6e5e9c2be0268a2ee0d07e4270ed49e09256a5aa5ec0c8f95cbf7fcf56b8116cf22a5e5f69ae7accbdece4ef9e1f7bf93430095cf2931301fd065f4f8a82879a949dd383d4965a775002b424e50684b600108c97b385fca504d64b977cce39363ddcba1b02221ced4af61059edf29259875c005ead9487622bc8af493f1c1f327c197619eb19f6b0c6f6f6fb469cd660b01d1e9f999ec75c4b1694dcce6e5fe114ff24a867be65875ca067dc5669120ad228af204470a0fac0b1554004de58bea55d4a6dceaabcfc4959d9e9fa8bffbfbbb11eaa0983c405d70a1ffcf6bd04297b5168359663e16440381bd725ec3d984e1fbb2fa69d9b12ad664716e47530369bed77398d996d9aefbb02110c9f4d36458b98d19c832f3f33bb2fc675264426420561f3649d5eb60588e6ecf08ee067b30ac57e60157276a58832764e3b6ac6e62818c625a428db391d4eff480643ae84ee99aa4126e76939a9ae38efa5efe76f6bcdbef9fdb5d7c5b735dacac8fc1d8769db6580a8b3f540f76a199023c794e18dac31b0a08e131238a9d2a14e893949979fbe377b21f8d47f7a5df6d95fbdb5b091e3612a2e011a687bbfbf2f87057869c7ca3a2736d090e418e8ff777e5e6e27253f30a2f29e3b0b77310850b2bf05f5c7c90b70e7ce80d76cafed191824c49c389834a17e5c3bbb7656fb82bf0240a9fbaed37b737fa7e7f6f6f13db063bc1a9319944a233ec704e65d36e9c4788678fd08383a303e50d92f6828a8b1d0b10449d525cd6200cd88c0f210adbda0851c0503b2f990d9bb309a35c2fe3038bb61dece0e04819111bd5b18577692eb645b2f90da7284d67e5903e1f4564fc40398dfdf2f018b5ee65c0af29410017bfd35e959a5945ec15ec8f773aed4bf6c56a1ba3147630ef75d93f3a2847c747e5e5ab57ca5924bd2c76ffa2123cae1061969fc189b5e9b597d5b9bceef37acfe09701a0c9a0b22dcbc2eff71a9032705a46b226c2670a6c4e15403303f2fb73bb6d17d6a654c33ce43daff175f658fa7bdbc36c97f4334d20dc2e033eef921dafda058d131b30cee565b8388397d4844666b51fe8ef32c8691075f454243fe67bd128ec31b267c99396771223b3df03e5f7b984f6f4c8305cebff9875f18c6c4034ed7c8a6e7e32c1b5e431aa9062b0a89039999635bb314c8968fde52aea52edc5ce8d41dd02c184a376b0f83fbc7f537ef8ee7762937801db8409cc38c1e64eeddddbdf934d6632ae611ae347edd8801f51bd9c5a138bad5d1eef6f95a7c862004054d960ef4035b9088398899585970b9589360788a2bab5cbe1c1a1da2ec6b45e959bbb6b9d097975755d66d8860643b1aba89115066c0a073a7c0400e29f032f191b420f90d2fe20ec518016aa210c0f3b95e66e5582152e383567f1093851dd92f639cc00b0ea75d8186a9031a131293bc26cdd9e650168b757ee1feee43515306a63094f29cce9fcd933a543e11c602c09cc05841f468feae3f1c9a94e23e2de08848d247cfed6a11ed8fe1e479b9399500f586fac59bc88af3fff22d4518258710650c71ff55ee3c889465175407daade6c6f9a0612cb8ccd1716621bdc9b9b77068c4c18b2b0676d286b197ea7af35a1303065c66399ca4420039c65ccf6c77c2f6db7813d037466814d59f4df666a4d1037909a34e97b72097343b3a07b2165a4f52232dbf1cb0c3aeeac51d77490da453c9b8977f910beb3315b02538dea198c987b1612fff14ce9e115b0dc914c7ddd1eb79de76703a6fbe77b1517e4a8ef9a74c977a4cecc6613d992504f26a87a35e9385ce533f585f71d715044af57ae2edf971fbefd5d59933b88b19d40d1e9442c0be1dc3f385094f56c3cd6b3887e078cdd56420b8804579a0b2acdedad0e99e0d41b2f9cbd7d180c552e5ab5bc4b9cff2875461ece88c4671e886bb2e1fac3c5477d3e9b4cc5284e4e8ecadb376fa2dc728d68e73df49dffe89f0dd59e43c60e8078f6fcb9d432f245051800c3ce6ed4b8da0defa10266532ea1171fed260d478b5dea2546ef964efcb100632f73c4ba63f0bc56b806a6445fe8079b01e6021c02382ff89cef31d4bffff06133f7ac39fee159e5508ffdbd7d317faf3f7ebaf4741434245098f321c3038a1aab323a831d31add3b3533d2fca3b0f6bedb06a98571a54adee51e31369bfcd131904b2413cb3a80c1a4dc135f86420cb8c250343be367fded4a6f21c9b68e4eb2ddf06239e6b5b95d4e31a406c96d76c8fdfe738ab0cde1b56952aa3e677e7ef3f39483503935fe00773935993d5430fbcd1d53ff33d31a81c81d5fa24d2dd206354b64bdc03ec01625d23d432e8d69d58b97eb5d696db956d555ce7b636770d2f50ef34cab103b0d2e9b600d878f42006c27b22921863398723105cd89590c8e5afdae347528d47a3fbf2c3f77f282d0cf50ff765d06997d9845cc34bedfa080d91e294d9219add87c33adc801aecb8fdb1e5a0d83d3cdc8b5d517de19e53746a12b1424874e2cc5007ab2268d85b3060dfdc86f062a0d7f982d8c2009fc54c60c5dc0044d45ee7bedb9b1b9d3c4d7a0dfd3c3f3d2b77f777e56dfd1bbe777b835a3b2b074747f2beedec109eb2a336a08685a19af2308c650407bade3b0c2e8cf20071570c53ea35f5b214105a0f2490413f720a950e44ae22605a332408bb37904a852b6bd9b04e4f4e821562781fa3be8fc4d298274095efee6eef5440115014c325f66cb994ed0cd6ac833d6afdae005b402a4aede031c5b3ca3ba971cf9cd3fe972f5f95d79f7fa6f7d2e60362ee6c9457a142aa9844f1ba5087b635e7cc6e9ac0d3348f3c652ec9eccb8095595306a22cc3594d353865b5329b50b266e4363ce569b49c3fc5900c6c069e4c2a4c763243b46cf33eb3326b71fc6df6b93935277734a3a93bda1c3cd3c12652e79764558f0005c7609952726fb62df91d991a13b80838b093baf3808b6c2b55953158e5c1cdd4d913ebc1f07334714a5e2d4a76765e1df6166c2608383b3c2e7aa56ed4c45d16b423a951dfce4ecf6413194f1e556561391f97fbeb4ba95844f8775aab727d7da5dd5c8045fa49ab25d5067b599c301335b7ba0ac4e44cbeae581e6d26c1fafaea327229752c7db50961dd6fa352523639cae0a09af1bb000b5600f811c2400df9093981a1e6e3de17cbab01b11f3f7c50ad2bd4a457af5ee9000caaa15ab8187f3b640817c09645dea0ea96578f231e3352781e1e1e37ec8aa4654203ec1d3e3c388863bfe429ecca801dc791717a0e204c9e209ec57a60abbc7151d6c691e88aad9a470604fda08cf2d1e1910afbb92aaaec70f3b9fa83fa4b9f23f838aee72422ec5df40350879d863328e2ab149756cb49e3a0e0de7b6a981166b11f8773c098a9b31f8c7159cecf4e140a0348532d961ee8bc031fc29b92f1a459cba50000200049444154ff2526d204250496b59a4d1e4f693fb62f31af4a22aef7e5e7651667a0b3dc3cc5cc7c7d062caf89e6fd59de2d7fdc6f56e5f6e436985c641cc9f29f4155bfa312baa1bed0ba2a9f4b3da9839577866c68cb089fc1c100a1ef6bbd727634196babc1ce3633a3b45535de19ea5ce4adb16036ed4b35899afabdd19bfb338b332bf4aeb041f47a002c2045bc91a3a2b56b8f270a6a9c2f38128bc45a4e4126fa3a2a844661c149393b39ad796dadf2f8705fc68ff74a8bf9f0ee0da1f16577d0535501248f858c60701c1621d4327613c344f587c54a6a1e76298ee3522ac872a5827c24590392b100c2ab899aca093c5a1c9c45d88f9a57f403468357915239620f35a444875f503514f73e25981f1e37292a9462c1f6c362375ba67d2e07c35a60f300d9f14632f69c30fdf6dd5b3148400900bcbcbc964711759a6b55a5637f5f07a36a5eeb91614e8b71b9675570c050be1b2932de98005e6ab76fec4e843dcc38f0b51f0cf4f656ac0a9679cc1164d5dba9a479d8d57c5e5ebe7c19d7de5cabfac6ce70af1c1c1daa28e0e871ac446dec7e3e411b46aa5234b88b300970e662ddc000303c8fca25ec0fcb175f7e213be668fc58ce61a0bb83d2aea57fb16d31e66c80597e0c585938cd7cb2b0fb33834ab61b658dc8ebd96bde329959505efb59f3b0a6c4fc3256961dcb68dee0b37d8cf9303ed0be4c62688f65dbc482be36c12adfe33671dd2648bc568bdd5ce75c42a3b31be99f19c43c78f9e7534c86cf6c3cf74f002b18461841f320e481cff6ab00ca582ca8851e58b191145d6c903282fb3a4fe2539396815525df74cc76c41ac976339d69018e658025f8931df52822c03914411530c78a15d2d1651ce38e1d846872d489c95d79bcbd5155863ee7e8e9e4e8f0a6f47416e04440c0c1a35277abf11fa3fae1216937f76247ecf20fb77791da23061147d1c364f0cac12810062d54c08c88ee12de586c5d3218c360aa419eeaa678c06cb0263402b527a2c8e79b64537b75788e6d4bb6dd71ad4b0429fe89f004826701b7e1a05c5fdf968f171f63716237a258614da4a5a63cea9923d407436ae01f95172f5ec8eee4136d508d0120ec43aa1f5f3d737d1c0e549f90dabf5258036a5e84862cc3d6d8e9aa7284d4bdf1a45c5e5e2ad483cf781ec78ba92f5354c75d3150369e76aba3b6288483fa5bcb88dd620d8f46d14f368208625e28825ff98b655d3effe28b4268076d83f1926d80e7586a2ff5c8529966af5d6fe816646fd64f312caeb526d1b47bfd29152bab9c4f6decfecc64a1692ccf6a6456df3211617c3ed158aa1dcaf71aa07c8dd53b03a31996db92bfb7c73f3be274cc9707a249e3ac4b1abc0c004f7933f2eee097673b135e42bb993735dd1bc5c3b8cf6ed0ad7a17797c00d6867d358e5ccaea6a06532f0c3f33ef4ede45f00452a31dd6a1da7db54e363b3331588f30bb16df63c33812683d8ea6da51f9f7fedd3bd50fdfdfdb2d7bfb87aa91c5398193f15dd91bf6cb5b929067e332502996380494c27c78ea100a4ea8e11d18e5873bbb6546602ab96eedce264608d5d2c17fb8e5e9c7fd43d8f564ef99c5f982dee5026448ad895c3e3c8a4473cb2ba7ef7a623c301a3fcf0b8bb9cd0264dba10517a649f506dae0e79b91333f1164b894e08a09fa849aaa8ada43e8b5e6bc42efc2b23d96104e794889a593317f374edc393890aa8b0d4da043e9ed5e782817ebb50e93651cec1451299a76471b0bfff19d6d5b3c9bcf6ceb238711103b383c285df299a4c2f93cc1a81012f6ae50b9e21d3b52c567ab7579f1eaa5008f3839ca361f1f62d86f87765103a99b4420834216da8d0650ddfc666756e9bd963d5f9e7f5f67e7527e3eec518702a71a59196cccce0c486e430652cb9ac18de76d22cf9dd5924ecace4e2e33b24c2cfc2ecbaafb93555a8f8bd68c03479b46eb3c00199d2de84fa1af51b86960d33d9561d98e650169227f663e316011386a37bbd4959a3c9be9a50726ef4e9e5c53d33c78bc47824965cca5cea6aebbf6521918b02bf2f7b0dd10c6d0e2c4e17ebf9c3f7fa588f5a8b4d99561fee23dd5145ae5c58bcfe42dbaf8f0ae5c5f7dd0515dd3112ced4ebb2d270711043ad8c1f3b828836eaf3c3e3c961bce1fac7dd5115e055bce8eec223028178f533cd10097fc4af156b00231311d7915555bc55c2a53d2c2809aa39a557b06e30f5b207c638f5aef0aa9588a31e119b3eaec5d9cbf0121c69d311380f4a254906c919a5b4ab64419e4cdba59b70b610c767230572eebacc336c8c3849d11b849580151fad5e0ea35c6b3e4e1a53c0f27a5ca7639ac05fb86e5f4d979d8bfba44d0ef94f12c2a7af04e0cf2b2a9d5760376b49d3a62303e364ddec7f36f6e6ecbeded9dc231ce4e4f55e78c33a6a9bda5937d540522bcc95c3f99ce04a0949fb9bdba56ccd9bad52dd3e5b2bcfaec333145347e52890ef761df5d6544346526ab6fd60a36ebb271d49781c23f9baa61b61f3d255b0626835096d57cbd9f9355c6cde65255b50c5a5923ca6ae853406c42c23d665856ff2c9b66f326455ed71b7592e4e7edce188bc6bba21ea27892882b69322bab5a6e5c46420f8c07a0df8bc5eb582cb337a3ad07c5d76f27a6d4a0c630000b796be13e4f5ade19943e5263b4bc33f87bb7ff1323208015a75e29c649824a913b6a4d551b1676a9e572aa24e9ddfde372707824db505b27dc4ccbe5c70fb25bedef1e05435c2dcae3c38d0ea8a0863b9e428ccf61939aa99e1420747278a4c8f81f7ff8711363391ec196a24cf326dea5d63942b5913d07956eb9d2e9c9080d5e3ed42c980fc2cd0e8fbd86fc43e282081b207095be01883e8e8cca0968c204b3c288a2fa425781a0da89550b8b1376968ac267fc60218a14032095aac429d1b1c79ac90206c3c16e1c6c17505c7a1cceb17f509d17543a8d60535616ea5594ccc63617b6c7f934c22f7014847d8a78ab588f54d690fd6ab5920aba7f78a4228014f523f480e700eef403f050b6bf4c0811dd4f6a0edfeb20da7afa11c6fbb76fdfa82fcfce9f95fda3182fe518eeecc9c368c042e956ddadd5aaecf57bca629891f7497db0fe4060a9ea0f3b4339594e8e0e4a3b9dede7b5dd5c9ffe3c6fba06010b3b3fbdee7d7d56b79a80641935f3cacff6b32c1ff9deac1e1a0fc2cc104cded77a83db30ae2a7b6e6353ddcc9f3f4538784e84e804a375fb4d3a6474f7cb3d00be38834893c679003694ff89ea09790060584a7eadb14c0823ffb2d12dab950648d40a273f6f74f77a48eb1f816b2afa9fd5d8e68464636238a3a0b561030a1b1687404c65408f3a4f61f406b0063bfb3a110701c46e8505e3faf2b2dcde5cd5ece908e160b1dedf5c959b9b4b9d8c83b78ad233083ccc09bbc6c9d1a1defcfefdbb321ec589c908efe87122410119b469d468f21906e2c944ec0b5548b5dd6bd8878ad5393792f754f60677248c02ef21ac504c68672823366a236c519ec601a937d53ba6582c0e87088f1776a750d1e621f8b2f9c526e623cb0049ed8e3caf7a0ed945f1fa0160ceef53a9190590461e215e421d942ae7ceb6ca2bc0a5382819d843fdf23caafc8dd4eb0866e573fa0b93dcdd275d076f5fc4aa11440b1b5532770d6a06b738bc152f28d1ffa1aa730aebba7c7cffa15c5d5e9593f313c59ba9be5827bc96caa9ace72d92a2f4707fafb2330ac5c01e399b97315913c4a551abfff8a81c1d1c968343ea7c45955a144d3615fa45e0af93b303043e2db067c6c97846b8c5b60e7a06ab2cdc194c0c08cd8d3dcbacafcfe091dfeb7b6d83cc44c48062466cbcc8661983a29f6f0665fb546665669919d48c339b3e7ef3cbffadd41c45443798142fb33730870e34e95e6eb029add5315f6bc002b464575059da6dbc147fbb1d79c0b8c62aa1f55c84b4d9910c8e799032b0daa696815851f9da7d59db1d092defe150d1fbfb3b811601a41c2f8fea7478745206e4bc0df72488dcf8fecd8f3a53efe1f60a62a484633c64f3f1a3c00a8685374f7150a83dd860ba9db233e440d996d43ae2b27030a0e63d3e8c0522fc53a238467116ebba5d1e4623d9b83096e3dd22a38db63fc82911419faaf8403a4b8d474205babdbc12284800ab0d504c0b8f1daa5c3dad9b936a88195202f0ceae401030b37195efc6d3b18cdc52076bad7b0085d8350cdee1490a500378ef1fee952d40b234c085479176463c18ea24715d51fb8a3003d8600487728c18694e23c55745a9e62858c73fdbd5986fada94e4f8516095b404d3b3c3e92511e15f8713c2d542945e55368483d2b001b96929819634c0db345b9beba2a973797626718d3795fa787da17ce0c181a8e9fa80e3b8e2c061532841dcca4e6ba8613211327cfcecaf397cfca90f31ab1d3ead0d03801087533b40d827eb739b2b1c2b7475d6595d16b3d8396d7b9e31ab7e01ee110fc6d9692595ad692321b335b360bfc97d85c532bca1a5a96cb26b9e16f9e9f81d844c500959fadf100b07ca3072933924c493352e7ce79b00c40da496a7ace8605adc205ea789c3c19a6bb1624b7c3d7e4c0518116092d55c7cf13bb01c7548f3aef021efc3c71514986818b0584e78d7fabf942a7d2601007b0e60b72f1b07d1047d42fad6e57ae6dfa495e1f67003edc1195fea83cbda3fdfd72f9e19d0e596d2d17a54f24375ebee9b4dc11cf33e8899df47b9174abb48e769c908ce197e04d045bf9741ce040bf297d03bf5161fe1803dcfb51ab7d258611eef7602330130ce0080a9e2bbe43adb46d887140d06c087ffef2859ea1cfa9e2990e3fd5dc7318eeeeaec0917bf80c9b1c0c10c6668fa2de3d8d6c00fac6398b5c0bf301187d9d0fc7b5c7900d0146140bbba5432708b655b917ce62ac5e52422f7807f733fe7c4fbb0ef60ee2b0db4e44e4733f6cf2fcfcb98a1b02f6f497d00757be85bde338413d84057316249ee11f3804641ab62e024cf70f39b66d4f2a29798bf2d4128cdaef85fa29cd61a77a6717e5fe31da469b5953e7cf9f95d7af5e945d3c902a00b83d4139d4a6a886ca1af63a6db29e0c2e59462c279663b3261bb0791eef30abc92c4c0cfe89d2c99281e4d9cc4c2c8357f373b7cb009b41ca842336b458075ab7f5675691dd970cbc7a2f362c330f7fe9976594cba06460309bf2cb33f3b24eeb4e131ac080f9d41c0f94d994c1ca93e467f277f3100a1f6a1a0213bb87dbdaa4cade71cc02ad0e6e909b8924fd46876dae3695524957a10203b41f3b4d298b72757523150c9b06a102cf5e3cdf14c29327f38ea8f147d9ae9e9f9e96e57c5a6eae2ef41fbbaaec42d89c6673d2b775fc3bc67c16befbe1536614cd5f538048b826d0540b9b1d7e1627d5f82c3f69139c76a34519c66f3c812443c667dd329d87a7d5e5a971f323ac6627fc84d57831c1b024081a976043e131242138163f734cdbb19fa15ee51428bca83c4bc19d7517c546c8dffc53b27717fb4fd84348aba13a0520cdc6413fd52f9826f5e6d94c7a3dc5531188caef00e1870f1f743f80757c78528e4f8f36a60745e113857e04633b92bd0e8f29400efb72a551d606e7415e5f5e095050e3083b21be8be73366cf9ebf543141c25ab067650f38ed76996d408b353e96679beaaeeb72747cac7e3e7f765e5ebf7aa95c5398a985390b6a96bdcc843289b0e07b4d678d24cba0d94d966bcb874d3c1998f2bd99106450b39c1924758f14db6dd9187d56cff37c8a5565e2d32449d6cc9a36311d0d86e30886d5644e1e340f4c930d65566317af553c5f6b54af0446ebcebb615609f3bbf364651044d0f0d66d0737762e062fdba3fcac8d0eddf8de6d33886942ebce1302bfded4f1e27081c96424c022e76fd06d29ede5eee15e0c0b032fe919a820d864d8b13fbe7d531eefef752e1e272f737c3d2111e3873bd56f6752a9a344c92d166d9ca41335ca235f0d3b5178fa182b84d0bb226040691b032de32130aa8c50718aab38ff0f2040c42300b457f68f0f0b850a19779e6b558abf9d16c498eced0c54d1d3865597a51e572fadc7371fdf16edaa81a8d3e9c6d3471f00049820eaa3c216542e3e4ad500b68c19e70b128089415d11ecb04d808d0aadbb7be5fb1f7e50fdade3c3a3f2f1e347a9cfa8c45f7ff57579fdfa75bc8f54a7ea78604dbc7cf94220cd3fd60740ccf98ea8a7c3bdbd32afb64ed811e37b7e7eaeb1213de90fbffbbd6c932f5f3e17f00158fc47723595609f3f7faef4a9a8e8115e51af75ec816c1838312cf097d7b7e5e4f42c12a407bdf2f2f9b372767e5a86d5661745076b899a124503b8d72cd473e1356d106ab22f834a936d65db9381d1cc2fb3a10c2c262219cc4c58cc7cfcfea67a9941cfa0d8d4c60cf6f9735f6bc0727b14ae520dfdba06864563f8d0bbabbd693e0124d33ea935b59c44ee841b6eb6e3b81a030bb61dbe83aafbe082ccd47c5fd308c7fd2e7fe285617533daa929f4d86f7e867d2016aced2f7eb681516dde246ec65354a84ee714c431edb8c1471cf6c0d975e4a5e97c41d268d6e5b32fbe945d8bdf89a172e5d1f7efdf4a355ccc67653a7a109b5a632384314db03bad153cca7307c4feccb6658269a3170c60e03a51fa9c7c3ad9a9560a1cd586a212385464880464004a5e4e5c802acbb250091d8ccc0640d370d966485aad0e13ec49b02740cb5e42bc678456f099d540e2d35c0e06631a73c47731d7ccc95a204e9e226b8577ecef1d4ad0a3ce5a045fc290de7fbc2a37f7a87871f803419d845aa0127ef9939f94efbeff51ecede4f8b8fce4abafcac5878f8a56c7e605a0905e434c19d906a85c04f1eeedee840d914a19f7d82067f2ec129c0a34e28b847569bd2b0a7d51befaea2bcd3beae02f7ff94bb1ebbffdd9df6851c0463fbc7baf82897800a97eaa2284d579c0f884a779ad7a6091e613c9e03061421ec8adc469717474509e3d3b17a832d6d8ad38155c6bb21eae92b50e6f12165adb7b0cc696af4f184f8d67ccda8565cd20c1cf8d9c57d5df75a7fc2cbfdbc06539cacf3263e31a872a30c7c68c0c8af979b9bdfc6eb5d0fd321ef8dd1b15d3a93959a7dc50401bfd547cbfaa5fb5e6747839c2eda841b0872efd6eaa188d8ba446763276bcac12ba531eccac4ef29da3a9b30a983b6ccaeb418a018d803677d4b14cdaf96a1daf1cb221878d6a89d463db7568ea5cccee81ca9d8b485940406001f32545ec8ecb6007f77d9c784c3a06dde774e7dffdee372ab1b29c8eca12633b0655764f0081f81f8af08d47f21ea1fa05cb9a567b56b8f959008c31ffc2dbb6aff008fa0bab11e0ca78cb661081a69b88fd1a02000b9041b71ebe60d0769a4f5ef81c0fc63ccba626c10b062b2a4e29e06a7bc1b8cfbbe82cedd0998035199d549f603d5dd977a41ac21ce7cb7271c9f1f6b3329ecc36c03bd6dfd8dd261a97297157b56a06769ffbfb47bd17833b1bdd4f7ef293f2f6ed5b011e00fcc5175f08f86452984dcbde70a7bc78feacbc7cf1bc9c1c1d97a3c34319ecaf6f6e748a91ce33a4ca2989d6b59824ef47605ebc78ae300ee6fcf77ff8ad36abafbefc4921fff1e6faa65c5c5c6a433b7bf64c01a20af06dc5262c7342cdf1e479302d8771dc3f10214f1db058ff3bbb433135aac992c1407c1ee1271c70e27f661cd99e957765cb8f41c04c24039a4944d646b2ac59de32006535d36cdee61ab7a9a93a66f9f3fdd6ce0c684d353093066348d6ec9e6a9b24d4f5b0bce01820a75de4f82b23a80724ebb2eed846154b797c3438686e44b147f9d9a80ddea4a1794278a6af7158039fd96b992971f339015c52c0822da55ad6466c7eba6d2c5ed428420a383095fec3b050ed30badfdddd9405b980d8d346239d51c8effc6fb12465e7b01c9f9ce95d917e53cadb773fc843b8225feff6aa74c9e1e3700a0e5c58af0a716914f2c320ceb844ae598c95ca9b0808e6aab4201b920e435dcb0b777874a8bc37fe4680a2bf954d89c50e656b638e30b603de0811ea1481ae7c8ee15ac05dcbd990d4bb334c49c7f5c45e3127255caf14b2804b1e505622342c51f5f6e3241ea2f68f8f4f22681321ec7625fcb09cc7c789808fa874bc983e657ab65ae8b9a4d470a235611baad3be8edaecb777b74a38b6ea050062c7424da32616acc9b98fb0306c889fbf7a558ef7f7e4e52489fcc5ab57a141546019a0b2d5e0450cf0d823592300350028f05ccdcb3ffff33fcb49f2e5675f88b1619aa08ac5cec15e393b8f93bde9b76db33ebe4c6597e751ed96b54e3fb067613fd3679c8edd6995572f5e0ab4f0a033a604307b5d66e0c86c451b6e250a992159ebf853aada1fa95655260c7c564533286d584d4d60ce6cceaa5b665d59c5cb6697cdc6b7292d1ee4c766a4ac065acbb3c6e7fe6ec6c5c77c99866ed4a66a28cd3a2a376575ccaa85d598cc9a3c7056e3002c76227b676c4bc97632ef26991ef24cd40f1b88fd2e4fa2d958a69e81eae12a6e4e6013bca4ba8a42f7e4c18239c930adb3e822529a18ab9bebcb30eccf1d134482e6b25cdedc962fbefc896c46aa43d5820df57133ca6b38babf2bdffffe37022e2a372000b3c554ace1f6fa46a91b800a75de6317aa79922a7ed756dbe6cba8b0c07f08d3b45627c59347fc4f543b18c47beb422404827164ec7cb43da10ef61c310e5a6ce430e29d138b8ba3bb9c33a8f6d452c59e47841a3546cf9d91a274bc51f1298fc33f58d6fd7852eeee1ff41fc787116ba5854b258caaf6ce17ab3259c6a9d06c161c082b96b25a4b15a6201f658f617bbd5afb9df902b4186b3c9ecc354678808d9f30beb25894672727e55ffdd9d7022c0aefc5357762461cab86f710e3fbedc37d3939c5587faaf1a02daf5ebe2cdffdf0ad6c6ddffeeef7653a1a977ff5f59f8513613c2a57d757a53de8abaa05cc6fb843e9ea882b8c13898a544398a7ebc333eeccddddc3a89c9c9d862db1dd2aaf5ebd542a50bf7a7db3166140e2a939bcc85e5e838b05dfc060d9b0b3c32090199301c0ccc74c28834e564db3ddc9d7da7461b0f3b31c0265d9ce32c7ef5e4bd954c3b3dc0f3fcf58c4772e3fb529e0973be00e469c4da805ee6cb67399055998cc667cad9fe9831898009f9ae3c679503205cc7497ef010d7b9bfc0e4f62b3d3db1dca87286c8f04cbe0e541146b13480d2534d345354e6be10112cbf2707f573e7e7c17f6ae7ad828f71333747bf728013b398910076c45fb479c93b75fc60fb7e5eefab2fcf887df95f1ddadce06c4d08e019cf4998fefdf2b5e8a00435402c060533fbe96d0d93f3c90a70c1613c19e714a3591ecb02d051f76b640e40d416a152a161e3c18d0127606c86e4fd3d5f7aa6b1e41abb0b5486406c4e2c00ce61e00d382e573e50bb665cf61cc6076189b19434ebaa104338e8339a7732beba053ee70382814a35338a10726869a88323b5d4c4b7fb8a3f828ce48fcf0f14200757272b629e14335d66e2f6c2e3646930f886d0b405712b962bbd632ceb3a91c10e6b08b7af85ca9377ff1177f2135941ccc17cf5f29c68a68fb771f3f288484d82dd8156ab7d2c70e7683852e96e5c7efbed709cfcf9e3d2b7b8707522f013a98aeec73fbfb6545c8890e0bc6fee6a3ef621c51cb75b41dfd574cd82800b9d396cafaeaf54bcd658f24f99a4e25fdc0e6963a9756c59e021e6b3c9623039c412dd8fff6883a838e377a5f97012cab7106bfac59f91ed607f3e2f6e5b66420f4f71988fd0edae1fbb2fccbfc319f6f37da6fbef966dd4457b3283f8441b0d12f7b03ddd9acd34ae5aac170fe5c8bbdd6c3920e2f46b08d746fd2508389c127273fe7b63607340366eeb4a96c938d698060341c7ea3a3dac34d8f71d87dc6584a9d75d4425270f6b0394d390ebd680726ba994508db423d01145081d811382a8a93973fbef9b15c7e7ca3a27e844810c848ccf2afffcf3f69d12a6eebf8200abdd55001d577e758b04ea7bc7efd4a0b9977317e0845a8300134043daa3db5bc0ce34dd0286045647dec505d01856a7dcd2347cf8e11025ab57174da5279010c543f11be38c35dda351e4998a84233c6533dff917318a7f3f2fee3850226f1fa29b073dd963d8a764b9d230e0bafe022c2382498049d629f9acd54339d1371003ca9cac35df56b399b97254c771e45075fbf7a25d04725c68e86da49b58677efdecb3e0893a2c22baa36c6f7af7ff213a9a5b0d8cf3efbac5c5e5ec9b3fbb77ffb6fcaf1d1b154e5ab9b6b5597208de6673ffb991c177dea965191633492c301ef2163f6f9e79fcb602f355db5c4422527293b6c5761b7d31cd784776a6bd146028e51232953ad03446498ef95172f9feb1ede1f259bb749e324cb53ae1b15556b5ae72b46c4bbc1c9c4a169efcaf2b1250f010c4ffdb31c5a9de3effcbbdf97377b6385e52d03cf8620a4f4beac85e5df0d787e5f6c8c7158c9278c0cc0caecc62f3405f4df5be6128770e601cb7f0b045472781b00276168c54ed804acacebfa1d19c0f88c856186e5ddc5204467b2c3a0d9aeac3a9a2de6c983bd505664320914e71f6ef62dddee28df0f95f0e2c3078521847d6b1de7f4f5073a10815a56a87d51573d525e48d1217ce1606f587efcf677e5fb3ffc56cc8aa46a54adefbfff56465776fed7af5f56af1f07528c759e1fc0419b0856a536398b9e49f4e4e26dc4901fbb78bf3cdc3f485db4decf010d20cd6442e5d4000f0cfbcb791c5a4af439d7523902bb0b6341cea002b12b00f6b087ad97723450348fefa92afa7077576e09f9804dadd665349eaa5a0281ac1ad312ee682dcafa3c5761405da2cf7c874aacb5d6690b6cd48f8787b2bf7ba0d82baa9d0230cef97bf5e245190c7ae5eae2522cefeafa5a2042f8c0e8ee56cc05767b77775bf629fb33ec95bff9abbf2edf7cf38bf26fffedbf552ace6f7efb5b9dbaf3777ff7779bc36da9f9fec38f3faa92c3dffcec67f2242a2b40c1beb3f278ff507ef7bbdf0990502189c982e9527f4c553310ae2ae05142694f4500b1db314e5c07403d7bf9422af3c78b8b7a284657156b0f8f8fb569edf429bb6d8d06ff405be720aed6a44a0166e160314bb10a697b6f93443465d34cc96be42915309b693269c90c2ab321dbba7c1fd7652dcbebd59fb94d064e9732721fb2d9273344012080659b9129a3512d23a0513553c9dc6903885039190fe3e52b0d3c936dd0f23bf380657a9a7700332cb3bc8ce6b9f359b776db32e267b0735f71bfcb9d4e3cd03cea2361789730d51810fc8d9cd672f1fe9d0e90a0289b18d8721975d5dbd44ca2b8dd6d248aab8201eefda5d2729443d8e2549df7e5e2ddbb32af1515287bcc35b8c5312cebbe6ed4d982f53046114a10210aa11a92e6437aca5085ee4e8f0ea46e849da717e7f2c926045b6b9711b6a609272b47eea1c603be5b4b0ef319ee7f9f7ea3e3bf6a61417e47100954bd21968cdc3b2584538f8ab0ec52269491519847b031d257e421ec6c4d09ca24204f7219f158b9feb76a46a91e38a92e1d1941cd54030000200049444154ec95fcda6a9783bd43092ff6a9b0a791a2d42e5f7ffd55f9ee0fdf6ac360ac50cda94d45bc187de7e4662abc92e777ff705bfefefffabbf2eedd5bd9a688a5faf5afff596add4fffe2a7e5effffeeff50c009410845ffdea57e55fffe55f96af7ffad358affd41d81da73319f9f150d25ed81a2a218c0995154645ad2d87755010d025b499333c953a05fbe850eda5c8211158382968f3e1d171d9d91b96634ea0ae675eb2c6d8f4f03e477826c66a52ad636de68db7492232706d984e25110606cb839f6586e64dbfa93636595a06a58c0519d86cf2697e969f6d8698352b9b998c2b9bfefdea575171d48dcdecc68d6822a31fecefb92723a100ab166f0b06a5a8282d009f4b68f5cc286b435ba69dee88c31a8cbc9e0c233bcf720c486e53063da37fd6bbb5207a9c4eccee853a88ca85dab28808875aa31ba181a17c7cf7aedcdf5ec98e255040d551d4f7b0ecec1e486d0c508e1ae697971f958243ecd5c5fbb7a5dba2dcf18398001545ef1519cf81078bf026e1891ac7b1ea935a142f526d268ab0e66875c680770064d886b07b6073c2854f7df3e3232a465009612c50454d992f66e14d5c854d050f1d608b011cbb0f9fa9f8df1263fa442a23f8888d877143e5231f90ff02f3b09dc1903a11c7545dfa8c1f694351ac8efa67e1750488502b296e88878c923ab02d629ef8176126e447c629371b1b8d04b37a50b11d12543b7e2c5f7ff595c68f450cf30320016ada4db8c0fefe9e4246706a50b6fac53342084e6483fceaabafcbeffff087f2e38f3f16720bffcb7ffe2f6a1f20892deaf7bfff7df9f1cd9bf29fffefff476c0b86841a26fbe4e3a38257bffffe7bb5fb6ffef6670a8da06204695bcc8d723fa1af3a8e0ddb151e4e182a400fa8ed94d367cf35c71f3f5e283e8b14a2d3d3f3d21d74cb2e75faf7e2ac45e655e9516b572d70727478bfbda6c3cb1c55140c4e1974f83d7b140d1e961fcb60d336e6bf379b7b4de3f1fdf95d6e4f26390646332eb7c3edce642533c66cbaf1359b7b60584d23587e90f560d33a33160f90ffce9d4625fcb4b394c50d5063c26cc3f2b38ddc46630f8407ca1547fd4e835b76a9665d3bef36a6ccbe36a379805c840488c4b422799512c53224f6a3daa46874bb5d2e3fbc2ff778feee6ea596a07e608f20729d0a0e568100337e27bf10b0d29980f7f7023b9da6c377d3916ab63f3ee2f21f29660781bdbd7f10b0b0b3a21ac97b49c02a019035621cfb9608470b410a7b040cedb3d7aff513cf55c404cdcbe3fd6339393f2d0f2a39b39280c31438e00201a76fa82fd8848e4e0ea5aaaa3ac27ca6c87e9eb533dc29bb07073242c342a9c965559cb984611027868a497b95d4dca3e85e14d95305d70581a7c4772d54278b77c8b03fab4791e1d65fadc53e783642cb9c29c3615d94dba84c80d944e3015be270093c8b4496db0b47ee21261a4ec5592d16e5eafa42671c62307ffbe6c7f21ffec37f14dbfbaffff5bf6a3dfea7fff49fca5ffdd55f09d87ff8f10719de7ffdeb5f4b0dff8f7ff7771b1b9bbd54f4e7cd9b370a79f8f2cb2fcb177ff6953661de7b75795d6da1d8ef6691cfb8bb2bfb14672a3276bc8773174fcecfcaddedbd62c84813a27d47276765b5980938013aad3d186905accc3668bb53a1364eb24a1c580f961d3315cb6f368e67503308190be4c94d719699a5f9f9590dcde0c9efcc919d2419b0b2a69631c3606bf293d5ccac194925cc8df143dc8126d5f483f2e7cd6b5017f86c6b5bc222100c8b4974c5068389594fa684064d9ea360434a0f5743715375745bfdb9fb93fb65e665b0db3a163858159544a602b12cd432812947cad79c367ede5c5f94dbcb8f653e26f62822ac5119de5f7cd46e4ac551b34022aea7b3b1d43fec77181fdefef0bdd4c2d9fd7de9b6895b9aea205662b7c853e4549abb8747556bd001f18af20fb73f45e330d412a2c0c2a7cfd8da5c65230aea452d2bce1fe4fb1fbefb5e02d3eaf6ca9dd49e4860a62a85a3b231cafb1c494ade04db6cab72675c8f1da52b9b8d538850f1691373a2031764a45fc50112525538a895434b3be55ea05cebc6ef87fb1f30c4b80c785edfdd978f97179b8d01750b3b0db15ad8b42eaf2ea5c2522a1a218e5cc82207c7c3dd830aefd9f8cd5870aa0fce08129949b12154e3608f330416e5bb6fbf2d3ffde94f95954048044ce9cffffccfcbbffb77ff4e9b28cf71423540ca774a2f6ab795e1e0f84454cf7ffef53f976fbfffaefcf5cf7e563efbfcb338a79193c451d85ac1c6983f839658585dc3b065da49b9228e22634c88c4275f919a660c3a763895e2a1428e1c42db20e8a656d2049e6c32c96a9cafcb0421cb9cc947666fcc6176c2f99a0c22be3e93818c137e8741ec4fc9b9ed624dd5d37f4b9e0d581961b3faf454c3322064fd77a33ac2586acd751bbaf11232a9560b4d9df3f3334866246621c2b2e4fdaac89d01317730d3cde6ae90f5e8ed2044cc56c8326ad1aa4ca1d7d5cd6a6f26aacd947231f7d469bf2eb7b754098d72bb08d80f6fdf94b373d22d3059719cfa9116da623ed531ebaab8d52ae58184da1fbf559551d81d58867bde6aefcedebe023cb16159f5539e617fa818317665540c98201523c43aaac72a3c897108ac6b8f61db9acc1765d50b6092770fd6b44b39144212a8148191775d0e76c26603fbb9b9bf8b4356555c2ff2f38802e7146c4ebae6bdcc0b82091344d015708b2e59d6656f27caefe8d091830305e0d22f25291f1fcb81007091080ee07dfb873f4402753d090961e63e6c59d8b0e4315c876d716f6f4736a45e97432896e5fa8278ac96420d68179e358ce530abd1f8a17cf6ea75f9fcf3cfa406321e2423c7316d3d05d20262b49ddc444e0e7afdfab3f2dd773f9667cf9f8945612b233d879017ec62dc07f3fb877ff807794efff6dffc9ba8167174289009b610a0c573a95eaa28fb6eaf8c26719808f3497e2309d6d8f6d834cf9fbf540a12156e9de04dea162115a10944a84af6ccc9669c52e5b2966266d39489acb66510f386ef7764cdeb29b03151c984a1695fce269e2cd34dc293d9a3fb90cd440633019651d3179af96460cab62dab726e80d98b11d6e55f8cbc52af3a5163890955c914aa63a6ca8546640fa09fcd7b7d6a4e56214d893d89d986e67ee4896902ef460f27f15495318319d0f687d178534540aefc6a3be2041cd8958ce7efdf2a75835d985829dceaef2f6ecae9c9a980e9f6eea63c3b0d1b08cce7f2e3850cec80de723a56450772ed1e6e6f6474575a0e75dee1131d0ae1cd258c8c190188a8d9a88431c6d8dd5602158cbda819d8e2f819c5f162111f50e1b394f2eec34559b7234e46875d28b62a40d9762a25a7b7223835aa0b9043772b40855d0272a865f4796f7f57aa23762304151b8cd8c5120648dfee373154b031408783476115a8bfac07c60455e9f8fca43c3f7b56669359f9cd6f7e234646c239828c6341aadc87771a1fc56075c303adc378178b727ef6ac1cee613fbc53102feb06a33b9b045e4254c2617f50bef8e2730112408601fcdb6fbfd5598ffffedfff7b8d176dfec9175fe87833c6fce4f49992a109f224860b76744d2cdd9a7084888c07f4fedfffef1fa44effcddffcacbc7af94a79a204822a5a1fdb1e6108fd3087005accefcd1ded247eeb406b8f3a61382bf60f4f74ea0e638d6debececb40c7a7d059806ab8a4a199683bcbef3facfc0f014c3cadf5bade333870f6410cb9a8ec1d800696da289139635471a6435cfa098b521ab8399a9f14c3082b1b04d4beff9e52f7ff94799c3061203596eb43b961131038906a8aa847910611a4e5570d2adbf77c74d753333e2d95609cdb03c51bebe094c4d4ae9ef0dac5b0a1da79a18b05422a4dd5164394cc5f58e6023241b537961351b97cb8fef5481e177bffdad06f3d567afcbf3e72fcbc78b6b2d78d4916eafa37aee0808467bd49a38cc9363ec01a791ce309c50f972f4282f244da1f228c2afe04ad970eec3b6c3d97aebf012a2260258a329713f032560c3beb06961c0a61a29e32615bcd313a05c5c5ee973048630018014958cc957a23409dcc358200026de2f989716f1220e824030f9f9f10af0c59112763f00dd99050abbe0a08cf55c866f82290147001875272a8d4691bf5894ed727a745cbef8eccbf2ecfc5c81a61c00f2e6dddbf2fefd47b5b1bf3b5074b9d6de3a6c5ef44d0b79b12c278727024ea2ea4965c2a900b8a2ba757b6dc56f1187451e2649cea4d50036efdebe553ff80c20267481e8750ceb5f7ffd53d9e668c75ffed55f8911b2411092c29828da7e3050ce215ec7cf3efb42b6301825aa347165d757b7aa0b4f3506806c4fe9427b71e86b3dbc15f6a62c0e8a030e76659b53fcd778a4df99276ac26fbdea91fe65cdc6e06059f0df992d3df57b261b59bebdd91b3c2c8bfc6d5b1972481bb3169571210350134873c84226275936dd0733c90cb02d7b09cd709ade425f9cd1d494d19d31e2fa0508961b63d4f6211418141d1096999d3b99078836f15f5325f4b5564bb8277b1932450d6f4bd8d4ac9eda20296096c1042f4a9476a11cae0e2aa536fa84f8aab9bc73146d83255232e6f6faa28cee6fcb470af4bd795b86836ef9fcf32fcbe1d9b3f2fefd85ec5bc45f51ad14b58a5d19aac24253adf5614f418d1c5681a08cf1becda92b85908fa3781ff1508a0f9b4481bd7647e92d52dfd654efe4249d8e0ac5719231b15244bdafdb35cfafd66487dd90bc8b40636ca74e93ec4435dd3254ed500965afa0d6935494ae5ce9a831da82885c5faecac9e971b9b8ba88d82915528c382b1de4aa9a45a13275da3c0fbbe052fd72780660ccbd2c7ed53dc7abb65828d7ee2f7efad3f2675f7d5d9e9d9ec96e461029e56538ecf6dd87b7e5c3c547ad2ba98db51a2e0e010091e7c14e285e88da0a3321e66a388c8a14fa7bfc584e8e4ffe7fbadeecb7d12dcbf23bd448919aa518ef9077c8aaccae325c59fd66fbd576c34f860d18fd66c0fe4bdd897a68bb1bdd40775565debaf3107163d22c4a224591c66fedbdc81d5f45e9e242210edf70be73d6597b5a5be6168a09bbdb217f83598f3f11a0644e483af9f6b6fde5ef7eaf1c2ac603f38d71873979fed132add79b09b03019bffced5fa84721c10e9e157ec05f5ebe90ca04254683ed6dddf3c6faa68e8b191b91e828169f2be76e28d92236258aa4f105a2364b22ac2a2d32e753735c0a0f91d4ab759ac864000a46c6ff614ad6d7796efedb6b9caf7bfd5757cf873e6700ad6ccc8ccae0e34dc9c1810ab25d53d4d7e0cf309722781391f1c535d887d57592752fb2cba22a1bb27d6b660360f9fb0bfbb94531b305fc8cd6a2f969c2d8a4acbb85cd53fc2495615544f6c3f020fa7a2a88711cbf6fdbdeef9b6edbdc72f67bf88aeec55e485b585d63106f948a7071f6b64def46ed87afbf52038aa7c78fdaf0f8695beb6f293a48ee15fe2a8a9d09e4459b32cc30aafa0940a0223a0f71407c50b777d27927b114d95ef29de030f66d457d5f2cccc5bdab0f6113080108988cb043310fe470325b9da25a18010f9f85c5f890eca9626a69cccf6476e3c7f3f36065a8838ff69e15b5cae21a90472155c0ce7e24512c2dc37763d2632eb217846f261423227748d78a5c8dca9c42203074b3b0567bbaceedfea09120fa2959e5c3edf6facdeb367e98283af7edf7df45d7202a0a46a348d8c48426274e0a09dbd97076451152ceab7b52d4945e823b910241346e306c1f7dfcbcfdeddffc41323fe4517df3f5d7edddc95b99da1fffe6336dae003de62ca04c44956b8f39d6530a05f7ffd59fff2c20c47c0438502bfde8938fa55041863b4d2d98c3440825ad9d3e2e360a44ff42e2a727bdaec74f9eb6c9436c3c303e32dff776869228c2adc0e6cf06cbd87953372362c3515edb43346e7d8f9d64a9cf1294785e4b21c1cacebc36bc567c1cbb72ea7917665e2925aaa9105dcbc6586382d365647c9771d7469dbee4051bb3496814b3bd59598a81a89eb8a639541352df4b09e3e5e7591ca1dd6c8964534a3e6380f285d7df360979d8be26031c7ffb3a0c761ef4eab3aaf7620657a9af77165f87fc3cd3709cb2a3864f2b7c179830f8586059b757e7edfccdebf6eae5cfadc764de3f6e3b87876d5f2900e76dd8efb7cbcb33d522e234c63404c028a0c563a6c81e8b0953872eced3289701f08852b108c3040c354f83819f4768a3c362664a76c5845101b75ab947cbab986034a00e3386fbc64fa4ac77ccb47e142c333948a750aa07f58a983184b553544e6383c3570a10b4668f426c9b829ec0cbdd3a72876c1278923a88e18d8845e748142b70abbfd90ef70f94014fb4f3f060bf3d7bfc246a0fe7b3f6ed77dfb6eb117231672a66e659294522d53d8854c2fcf01f593515332ef24e6732e3b87ec659bf27f7ed77bffb4b89f8d14bf0f3cf7fd37ef8e107e5634d1e664a73f04679767ed19e3c79b660eb0c099b10731a73ffdb6fbf6d9f7cfaa932ef197b72ce8e1e3f6a3ffcf853db3dd80f609ac5e6415721521f487720c134368ad656d637db8e924877dbd9c5a5e474300971475000be81a48d134061b729ebc433637c4414940bb7d487f7faac2444a93a4a808e0454039eff5dd73aaf99601840ba2425d1f1bde3f8d97789435df35e7b5d0ba9ebc631f3eafde94f7f529b2f1fc4e8eb0baf60e283f3db136f71b7e5a6ff39606155c400d9f1ee28e1877680ae1d6e79993a88666e9525793750e42c1dd49509d607576d7f0fbe5924bb14ea9e3c4c2618ea97e7a3882ae1c8a559eaddcd75bbbfbd6ea3f3b3f6c3b75f87a2e87a5ffea227cf9fc98c90298b93fd7edceeef2632f73009e587194fa4e9cef5f5a901ec050390c01fe094c5c25c33af3bba67a088fca689aa0a6053008eb4a4749c30a5d969d5525ec272917345912f20279a6e9998c52e16b95f2483461921bb6fe4a1f1e316f038f699c0de01bd692cce4b9d606a83d549eb49a884d5ac9733f3e23ea3089bd65aab4a802519165fdec1ce6efbfcd34f1519c4b94eb48fc8dac9bb1301170b5f1500eae748b67998135c3fce7958b2555c1917ea2a890ec2b6c8a703209f3d7fa673ffe597bfd57730eb7ffae9178d1fc00373fbe9c79ff51cc870df3f3850e44e2098fe312ba2729d9899b461fbf2b75fb653fc633737d286d7386e0dda602b8aacf1a5c1e0613a443f891ece5656dbd1f163156ac3ec606e544c90d6410f4af2cbd8e4ecc30b9210c9da5a9730effb6895551952fd7be926095df50a6615c02a1b621e7a0d55578b5fb3495af1c4c7ad6bcf6bdef32a2c8e60fad592635e29609785d53a2e80e50f56275745daa5edfb7e5baeca4c4c010369a374c54c4017318f2ce02e60f933665506a5fa7d06caadea3d686659664c7537af035101d1285daf5b11b787d88df8acfc2b1beb0ae54710939e73d3361ad3c0e1344c5a4cab77ef5a6f76df4617a76d7406687daba8d6eee141f4b05b998b1590717e37c2a7b5aa225a1a6f12e9e2fa7118a3df8432298b05a7348c83c926bfd074aa85c87547b71b942ba9355b4e309a2b84b93891c319b390452d13945cad292dd927ad476353a93ad0ba6ba3d11d87e36036b298197f767d998b2c201034d516a4b08aa315534a4ef428c2d6f7a769e252149dfe94984fa1ddb5d841e1ddd96bcea5438c37e6a1cc463619ae657ca72c7b4f70cd97deaafec7294f713249afe861c1c6f041e20c27ca78763d6a6767a9f38599389d0a7c7a2b11e50c1f0b8c2ed21eccf8197f1275ffeaaffe5a2046941146438d1fa27de46b7dfa9b4fdbf5e8b67dfffd8f9a27441cb7b668ed7527c505f947efa7d2862711941c3d9814a6f6279f7fa6e7426a8722b0f3684c31a45e3213404977e07a767689d0f6dafee1515400acae0be8c8dbe3bcf851a920c0c455d7e514a3949e161159ae03bf6cfa24cd9caa4fca2c29d6c9d29765707adfdff5beff0bf0b0d3dd7eed0556a483cdbeac4a7aaa75a46b4c89a125702e53a1bc16b966e69a8039d3a41425ace8b7308b32e7c380524da98a82d5d6f5a0a073e4eff9a2a1a83569d421522fbeea90ab60c58df13f0bd06691afd76660655e954a5627a04d40df9fdfc31780733258560e246b55465b7838b5486774d1b951b89dc9022b1a8faedbf8e64a4cebfce4b4fdf4fdf79a90c3dd613b393f951489a474610fa3db36a561038d416721318c99b82569941b818ceac610054c313f6789c77823438c8e7854b0c77dd0ec34248999488ca144ea325021932efb1ac2b2a80924631e87b2c0863ac25476c0c9eb26a6009dd514dc6e3ed2803430d1e24a09a2a8a286fa82fece7a42227de8b2e3a4874572bd34d190d657b279cea5b6f27117bae7f099f5da7dfa5faca6daa7a38c12327bedf8f0506612e17dea0361722465324428419c9c9e4503d664a95297c84458ee9bab204522f2b5d6dadeee9e9444603a24a3c28e88f0ad5126d4efb7c3c3a3f6f5375f4795c6602840fcf6bbef6442623e5e5e5fca49fff96f3e1320f1cc4899f8ddbffabdd43cd4f1070d2ee6168d5f017ac046fd0c697917a93ec8123116302cc61e073d59ff3068fc58f8d8b451a8c3f6bac693f1b0d26f44bb035c14f9cdc0c6872c20af91584700b7376718e352d820d8b1db6dc63337c0569c581080acb1ad4ef2ba464d6abaebd57f77995e2531fc5bc7254ac807ed90aee6d4d21fd1bdeda5564fd73ee66f00abfa2e74d12b614676fb121afcbc0817f43273b4380e60c5ff15042b35b5d9a485918366b664a05df84c72b173dcb8e7608d5233d0c399295286bda4ce333c7c6a09154e9f49978a6a7b65c5b0d8efc7edfafc9d52134e5efddadebe7bddfa14251f1d860202bb2299e538c35756dab5d407c244415d81e42542f05a6463227fd11d84340758971dda948af01d32bb7def30134c0d83af580dc9a44494f031217f82990098494a27a3a56bab91e332b9d7ff36a1621ca27c84681b3bb5368ccc7e1700616ad21731c190f15d4cc4b6ac29d546b0c2bd079b21535d40b11a4103161c810716273e1c01094c31951c04780255020d30deb9180c1f3c3a385019124ce3fcec34ccff8779a8b34e1f02a431a509489032d0a2b427a28b33f9bc041c38fed56b30dbc63d3cc8fc22ff6977489b7a5a843d92440f63f2e6cddbb6b3bda7ec74d21d3efbec53a52d50f2f3175f7cb928572268c298527e737c74acf9c09c22daaca8a04cf0002cfd9f9b108e7ad82073787b7757ef31d73efaf8e390cdb9bad2751361a6105a410b67e5648c30167fd479566ba58241974c18882a637adf9c5caa039b2557d663f624399d94f4ae669fdd47953474cd4b1fa36bcd75899200ab9a430c88598d51d45faa376a8ad665399ad0622d4b5acf6e48d095c5c48ea33286526d6e2a5aa378d5aec5afe2f6505d5bb8dea0ed750f4c17a117d435a9745c7bf8bb202c7e082c542daa957058a374309da33a41c30614356fda5bda3f513a81b76776affcacb3b7bfb69f7ffa5e0987dce3a3a3c772f2f2831f2ccc867bed94a7efde46a9d1fdbdf4b0f083500ccd3551d623c6b51a12c4b0314c15ae95c5102902110d8495b8bf1f6c48a89b1de2ed63f298d1ef90dc2dcc23ee1173989c2932b81d4983a1b1b898779a54bd26a0e0b3de1828caf518078309d03270ca5c17b8b1db3fc8812e3e98be0a7c618084b4e26502df6b2147fe164043c0c1ecef41010005025248d2dfc3cf850c32c0c35878630b532aa29238ba9559ae5c314cd000c5ee5c20fd8461735d20801ac99bc7f24729bc3e9f4793dbd6540348e9d510099ff95c0c9b2462a71a50b60310b171fdabbffe6b6d222844308efde14045f63c3b58146c0bc7bd52686031caa6df6c1b540364030d4c505aa12133b34da13c6c3a5bc71139aceb024558be6ff0a8fea12ea0f0bd0a58261a5e4bb1f603b0eca837dbb169b9b0884a2fc3bafe6b60ec435852199f8f156e85f7898fd63326a181c90bdc68dc0507a3a02fb48bdacb59b044e405b3c9b4062684bbe6705edbb31f3a96ed6516b69c932a56ced55804cc3e64ae566665e6c582eafeacae6c34bac0449fb8ac804f6aed2e267a502be46611aec6790d1b98489d8194061a4cec6c6fb5b393976a4f7ff2fa6d3b79f336c2ecc34827a0090439483421a5e81933e8fcfc54e604939cda314a49106a5337619a1664af41a7226cf599e8a1ae699f0c8b5b0aa4e95bf2ce45d6b9018b71b309ce8d30d6302bd403788fa4464daa6938f003f452d34c99d5f4455cf67ef423f07c8974862568c5a6156de801171617bf19b875e56a455f3ed896584ec33783b911ec4bba52444849d2248f0b9f0cd78d0c108b1af690217defde62cc1b24dc866f4e73778e6244f45764a354a8fcfe5e99e536636d5df05ea8af8e255bfce4f838ccaaf58df6e429daeb87edc58b978a12cab4ecf5dac9e9dbb6b1958ef3bbb10acf295f027c70c0abfef561da9e7dfc51fbdb7ffdafb5f9908f2505d2ed5d0114caa7da245642ebdde6143975a89f52584f35c2c1d123f9e326935bb923e4db83adcef1432d7d9a8057accf603b5ef4de4c2acb3158d9e7ebb5e8f5ed0ddc568873a22a21a816919eb925ba4b9f42b3b2caa2fc395eab44a5bb3eaba5a6f9f6e73f479baf8abcbec90a506661bec0eabbf20d98824a2b2919560c1ad47bd997b036a130589a8e1ab82ad2f29e01cb68ed6bf30d7b07a8514e87622b7855aa1be78639c036d8c1898284c9a389d3a2f0337c2f38a311aa43c9208a7f8966bd7ef5a25d5e9cb5e9fd6d1b6cf4da743c6a6f7f7dddcedebc6b77d737022b76d3fb39da59032d46941b480c2512c5a2207ac8422491f1e0704fec8aa4554b22cbdc4162a60406a46d05aed06d25fd425cb3226d94c860d6c999bc2a530c7f190998310933204073d43cae18d2781a80e5c6b4d2978f1d98efc724c39fc6ff4bc6e367027bb02f6b25cd2c09962ad1601ea91c9881ee07490020bbf1ac653f45c972e3d89dcddbedddad142cc668c89395afce4db3d69b4799176347ba4680636bf77398e26ab49c7f88a449a82241079959db3b12fd739bfae8f833d546921e08dd23ac1865d9c383a3e8f8833a04fa57bb7bede5cb5f051c00dbbc376ba3bbdb767c74d85efffa4a4c14473b636fd0524063a5d7fee66fff20473d4d2cf0651d3e3a168ba4eb1259f4b018492ea7531b96c578364089ea808d4d95f6acae85298dd01f810a795ad5e0251cd3580331ef97b587959098997bcdd7f554d79ed711e316ec7ae97caf206580d16b25d0e6f5cb6f036105b325182e3b6f5533d26bb6060bf49aa384d57caa0bbd3ad0bcd89d066080aa34cf2621afb17bdb49876e1327b7e2a82fb8ca76f8f84678ffc61c8cc44ba450c8658948958f617034927bd75c9a30e1a308d3cfadd023f33735ed16b9609c83281f0ca8f5428389244bad885ca4e4514d2753652093d14ec63b6c6b6552e96555000020004944415416897d48219fbd7b2bbd27f2ab0014ceab06a2ebebca8057a7987164b1637eb0a8f8378d24c86e663796c4711638dbe4e27a82e247be15cf8a0893368d1e9a53a1cb44ca03757ba1323a91d945ca0d8b3cb2ddd7a488a0e7436ac42c7c8c4a08cdd56b13c02922eaea437e0f809719ee9c57d1cdcc925e676757e38cc8e71ac00670ae3f4cdb0c4140e9445139b0aec8291bc5e6fae622e2551710e90adce3954a7c70f7c105231f0ca50a4f66155d83b36d26b6a2f998d7c37778c63663a4f6b08a9ae850638299a668689ab6aacb5c5911f0f456e886bd975a65a173466b37fc43afdfbed17d8e27f44c8ccf10454629421dad6711158769f12c1f3f7922c5d3ab1b8ac547127e7cf2f4897ca2839d6d8dc9fae6964c7ff980a908e01ed736a51ec2fb3033fc611485f3b333d81635d858c36f45391685eac12acd32eb9aa84cc76b3cd871f8a40d5215582ac02d494b4817198caad52375d9f463f9f3755d6bad52c32a3f63fe951a6aeffbcddc3f80166acb9e1232092bb29a26561bb4b21d23b39ddb46dbfa79ad8ca484f2d320e1bb1eb93b062c0f54a58095e5d5e3b99690ddaafad52a609915f2bdcab20cb8d526f7393540c9067d5c3d68973a642e11755e5381553877d999494798c36cb483dfaaa5d7cdf5a532d7f91b87fcd9c93b95f2b0f372bfdabdfb7d153ec35cdcfa5d75860005404c5718458836c43034762a8f09162ca9195851464d94b640d227fd09e7e4574d55922251bef9bc5d5f457a438013001dcd24e048e8afb358c35f154d5a994df23ca54caf1ce6dcb74c8d884ce18b9239427947fa8b54383e0d1001c8194318a8a24eb307258102be987e28b646c41865835924cfa62f4b8b20d5554927e1fa08001001945953728b60237c1ee7b81264d1da4a8f8136a80c1228e2991ba84a89521e0770e31984122b1af9a135cf1872419877fc008ee4d71dec1f2aff0ad394fb437d948822cf804273980f80c7e643d4afbfd957f0e4028dfaadbe1ce7d4250276f8a34830e51ab441e26fdba2512b4d47c207c8b5e00f461e48d1664516439d147826c20c63dd5c8761868c34a932580d92e12fee936af154426070ea828a3f6f0ba65a5b5e4b76e9d4356ce0ab9852894d7501993c7ce81ae49f4d82512dbe8549e82fd51c0a3327dfb8cd36236bbda9cad0cc5a6c36e21b00b0b48b64a4b09b78eaf357bf99ffcd8234c3aa036b30eaee2275802a65f540dbb68fad25541a58c4f219856876d8d5a972a99081531ee88e42e223ca0d1312426fd5fc003998f1dd951ce797e7e76aa24af71672b00038878ef155a182c0a2810d494f2a4b6bd8b145f3f33ad40b10936525cc1cc62c4a68481788054ca990fd84da8934f851d8ccee2bbf0c4c772d22875cb38e9b4e6dc0ece11e26190e4ee5a149c5349819c764215286120908ad6d9238ba4a867e8020bb65a42db073c2a2a3f81b70944084cc969e5413422f2bd2bc3655e7176002f049633e1e8a0013860528f13c487c5566fefa86a4a023d2460a446c060022cf04808c0c8a002c9eabe65ab6ded2b5228c27d33f98349156de57be591c590a1a6a1c4b6639ff51567437963207ec4b735a3d1f638384f933762498f21b3003947165487e3ad312fef0b77fabd7de9c9cb667cf9f47ded7e14148d10c860223296e30bedaa856e4c702b06076aa7d3c3a6a5bfda1c61cc0da5807d842d537b4aa978055d748d75765d2b1f0f9e562a90131aff5ee67baae1baf555b547cef43c7afc73678193b0c8afe5ec59705b861129abad5855e29a5177d1708ea898cda1c98b212232d27277972633d165c6df36593c3eca18291018cefb37078c85e986681be467fb63bb806dceaecf377163b466f5d4e678399cddd4829ca044ffc28794f5ad413c08a6265c4f99a246728a7e9add0c18694859bf6f6d75fc52c487b98659639f722fd75fc56141dd31126fd73dead94a0997e1316339f556a4396b0f01edf0db36fdcd65a809ada79a904651699dfe9188e48df6a1bdd8508a2c4e0641a868f23260d93bd27a73166904c4015829312b1d17a9995ae5c2fc0ccc98a64964b81811e87e1086781c944c34cc9e44080047306b0515305f9c1f069c6a4162bceddd493580ede749e6352f33fe081f948022c8b3772c2c207b2b146f004869845eefa6ed4c979b7065c9434aa1a18975f85bebd2a0232e8a22a074a93188764db64a6b3092013bdb3bfa7c82149a25bdb3b8bb404ce65a965ae9f1a44fc918c27008c0f935c2fe6c09bb727cad343ad01e6a5644f64781e3dd6f891d2a0462634a5a0481a60a21b113a5f3b3bca035b6db0d900abcd8d556d0c7261c8c71aec937952dd20d527e4f556d787e744252015acfc1d9318039501cccf8fdf1ef7cae8aa596aabc6f8522d2cbb754c9262e35c8f3c2c239917b801c4176d40f3c9fcf97a7315f4e40fce1d97130998326dc0b584bcefe880bfebdda0eb687394d0e75fe61d052be8026e656975802bc0197c67d93f8f63701e25a7cab90cf98a3e7102caccd7d2f968e04072a7ba398f541f7833ba560487890e5b8079dd8eae650e1a647cad2c541a1ba87427eb040d12808ad20ea6f7294d1339724a3b68c11664fea8d516e718c99f46c4497231d9be9e7f537ec2bd84cf2a800e534e0c23cb2ca2b92a2084a9144107180c1b0c83a00cf409b2343d992e004e3f178319550056b015fbd2003bc64e4c2bd316e4af94430926959b01cef80466f2d560609a77e8c017dd721d17b336a38872290026987b19e081f109fc92410292612e4732a5eb1e091af09a43ff02b67cce985d521e1dd13422142bd80cc85c07d0480d011831dd3059af4637021df91f497349f353d2d1598140871ffc955c3f89c5f8a13636b6daedf8562046d49ca61504401001dcdb3f543a86c23eeb714cfead059b8c113923ae7f7d9d082c2dded830185b5017461830c0bc725a4338d0c3d4f25a37d0182c34ce39161fdaf0bdaefd3d838d4984d755d755646bcb669ed7b89fb131c56e1e9f5b3ee59adf4594b0fa77cc560c02159c8cd8155d0d08ef39ea63035d38dc3550298bc143e561fa826d9f56b4f7777d3e3ea3a69619a6ad83ed0750fd599e3446e7bac378800c1eac1f18862adc9369495d945d311982e457e4980e673f400173c2f943df41000b538b234429ccada2372a6666b1e7ce4ba63afe207650c60bd3911fd501a65928f684cf2b0884169676dc5c0c2c68f95012b05015609292718d194361b3ea0481ce071a48903641ed59c4eae474ce6456016146fe226b9aae34e9084fe54c520f285dd1e393337bdeb68783f499a96a54669bbeafc912ce71a2978ca364851d82abac35736ceccb943bbdf4cb13334a0391d7f99c8238f99c2c57bcd8b18942af2c1dc8988f986191ca12114dcf652dae540971bd28913887ed95cf96d151b3237c8a9c0b291fac84317a6974019aa59c4f89b47b6e5bf51539660ae68380f6d4b98791c3a9ce064e1411473a89a52c94dd9dbda8556413608359c397066845672140ead1a3676d3008196a4cf80d6e1d0d34807c46f7a24869e82e7cfe7630ac0253c5006d44d9cba0ae4583531713fc5d3fcbcad80c5c9544983d797d733c075bcc082bdbf275ea7e00ac8ab266557591577a582309464d9fc4686886c5f7588c4c04e99a67629e151bfd7da3ba91bf4b5b0d58764c1bdceac0d66355a6587704df870723063ed20264374be344de4a395ec15d32ad5970f8a8f033b810dbcd4689d0005833985926f021cea7cc6e648e933da0f72420c9c5bb99512980981fdd9ba260619eadaf475e18fe2f65aae7eec8fda8112a5d732e2fdbe919ea9e93a859a4709a63a84169a438c032a83fa37b0f2da5f03d91fb05d090cfc375c484234560d2b687d1529ed723370de023d8907af0a9cdef67261ccb09bed8d0b28487a174130d7ecb1f950bdb3bade719a69727bcd824cef5e972775d9875a9be6910d31c93c9b911d266806a96c1d82c09f9eb2837e2c751271271356f225f7c91f2c1fc8065f2b22b0d42272d41758532a928b8c664f38663531dc6c5f3e19cf8bb985fe76767facd339394f2e696c6835406799d28a9627d6cf5dbd6f6501aefb49cebade1948f9e876cacab1b5cefac1d1e3e6e07478f93111369450228aa2a002caa29ecd2f03d7b5d849f7269321a8896e3151ba2d74bec55cbfcc7eeebddcf564ba9ae356f487ead825277cd566b480c33371c99840bb691e1434f22b3ad0a584653a3220fdc40a2078db9923b9a27998e8f8e4f76cd615731d8f81ca69275707c5e2e9685bd302fd36cf040fb0198adf9758343656fde3916f714aeca58b4d2900abf88cd044c2b4dceeb6b4d3afed6ae8ba9b7dada3a85ccecd83071e967d1cee94647c5afa5da410a8a55b34756fa9dd8183957385cf18330d12371321e4cdc0f9134b2b383b580f784c0838985c9487f40c00b5f0760154e78924aef9442c1316056043c0ef65026e80b04c04c4a6630f7a29b9162d172320fa84290ff81485584c9398e268cc6255ade4bc239fd230298cc14f7f30364c564d24785835b8ef08cf46901a4b31d80517da21651d42aaab516e53b2497668e4f800ea66994f2c8879585d694cfe06f8eeb8ecc6fe6a224a04938cd6bb5e26924d502c8a1ae1a0b324c5a39de25421979676263791d4ab4755d9bcccfd888b92f99e824fde673e4dffca0bb05f386fd5ad180a458fe8de39d5a48da8501dafc5652a84cc5edb64ac67b3f925ef1e991df86e37d6373d89e3cfb7811811f6e6d286584682b63a7bac225c6c4c6938ccb9b4d2527758d1b2cba568fada8fad90a764e35aa00564d44e38cd7bc01cb2e0e33375f5f353bbd969587558169f14647a7aa5ea4272a176056644aa78b908e54747bd1cd2b2f23c08cff9d385a296617a82a58f16fb57bca9f6a127ab7f40eb0d8b1d361ab05567613d34b0f8e9ccb94c247d8291cb0aa61a3b0f75e40430f3c3a09e3f8d7e4e4f5c93877b5d606fdcdc8a522fc2ef963f2a266edf6fa465d95e56067336824748e5577c875e338656193fd8ebe3bd7a6b1c9d0ba85eeb421a83c261448e5ef4ae9689cf4ecf4c8d56cd2c8330bb90979dba445746f7f6f47c5d34403493a74df408206687c91a2c1b55222a4a458f2bb522982c90ffb5aa4a24416611c3fe93c6bc345d1dc07beb2eaf055fde13c009905c7677966e46261064577e7303b356113aca4fda4129ff8e1d8245af2a31a4f813ba53ed1b7d11ba89e6f58490bf306701253957989626a4f4014ec3cfc617c29ee2a563b4c8b6b97644b980e4a2fc02474e6bd5d055cb7593480e8ffef6e6e153de4395fd37da7df97f283942ad6d694508a763c19fdd410ca4c9cb7b649ab33008b7a43b4fd193b12471531dc684f9f7f9c7598b3b63de8b7758c03822a294d04f07a93b71fab1204f99693b91ba4ea66efb564c664c032905440abe6a5dfb7d5535d397e86157378bfebb7e673361d8d0dc20400abdaab5ec81539cdaa0c66debdf88c1f50d8d2213d4101a7d176410f5748688b9dcc65129a7445feb4828ba25b45d618866510abaffbfb1e808ae215ddebe2e1bc0bdf57e6ab84c4af642fdb784cc428f272d8d54e4f4e42771b7548c2d7f82fc6341cbd6babf3877014c3a2702e93bc897946e45085d2a194cab1149a271de22e765e809c8914ba4c9b912c7a933b740b9066f2f299c96d64ba8766544606c7b76d4c48fe61ae31755986fbc94dd5cc80aec83b6d7b27582d9e21d5cda9460ce0c18fd297098819a35c9eccf70ad99d0016d52fb220d3b96c8a5e27a099b6126a61dab9c06117729c923b94fecb701f2093326f2be88fa1b60aa8c38c94a91d7e24ca9bd8400c21bc2f864e8d6302442455c6dcf222019c463721d9c218c47c029400acc80a47422840b827560de0313e9a67523008ff211f25174b0b36b3ed012d958a691b4a935eef2dd5453c36daf02ea2410699f164cfa3ab453a851af9ce665264f8e8f3df0880081a30d70e8e1f29e31f50a39b1280bad15fd7f701acbdc3e328df7998b45dc00d8181de4ac800a1b596a9385c93d3882a7b3210f03b7c7db12e4c44fcb74dfdeaa7aee665b56ce45a4936670c31a65446e7f5c8774d6e7cde4a3afc3c7dac85a67b6556f5045de4331a9ad17c68e2c24e2aed74690e37ecc451237e0541dbdcd5b6f564f0c237ddace86f87bb07c40fe29f997f1d8d2e0fbac04e92c1eca019114cf390dc1b7c446aa4a0a43cd638da46578a02ca2c5cc5d7c4e7eeb2d0b7a7081d8b9b3c2c7c5fd490d99cc4770263aabb1dd74ad133bf012e261cf73c9944b7605e87b5d857c52eaacd02e6938998ca66e71ed5d034141a186f75b551fbfa909c651726070a9d7039da0117161b818334b7012b710c5426b2530df962e4232d7c94322fe3599bc5f21d9944e954b75fb3fa28ea6b0001df07706c1af8d92e7c9ae47b2d666c4f1144fb9ea2ad58303316bfafc77300e2f61eeb865172dfa17790652c9114abb9ad7c3718682c5c6f80f805ed47e21c21ddd38bf663e95f61e1f15ea4a20413d6339a45813aeaa2fc262040ad1f80251357beacbdf6f8d9d3607f80f9c686d21e28c959dbdc50163c515aa99df4fb5226ddec0fdaeefea1ce83be3c667e1f8964fc8c6b580b91216e4059dc4b3eb36a72799d5732e0ef79add7f5c2bf05d8a576d0635e5fab78e171aa6c4c532c999e01dea0ea6b311ee97a5d9ab39c0fefebb1fb222bbba92619af1b55f520614cd952aa4e1e2b8e5a13ab36a2f080f81c465f030e03633dac3ac8be91ae6dec7b3165f5a0f160bb00bc407d8316aecf5e9445508e85de135d69c804b719c66286d9c0b2e60f93361d87ff08cb01473bc081463b80311ddf49471db506cc01ce37b905004331c0ec55cc69fa2036c4bf77541a42181dc7f986004e1a5a7372bbee43179c6596616b8386d21090ff25c112139cca7f16e86a2482aafdf9c34cac4a499151499a4eee48a5e0476667aaa652606b538b67859f4f638b948b13467367754450d1f574d69ada2ffc59295ac731bcd9f01947433dbfcc260914c05c752efc34a95201cb217ac77934b9136ccd16c225b194605e802b027812ba8b7b8df9916dd07ac10e01ac38e68a188ee6f95af41c94899c7e321c45f2876550c9d1de605a518580bf13b0670e93091f4d81a39988fc78a9650f1003664824632212e5c4e9dedf1e2c9cf4f8bbb4e9ef2077bddaf68f8e8309c230e7adedef6cab201a39650229dd75ebb5e1b1f058d74ddf63523719130bdeb319e90dc573b86288e7b63fef637a4d9a857d08140d62156017a0e9b4069fa0322dffbb02824fe08bf4818cae3a4eee87464a51752b26a6c44c75b41991bd137a900d584c021eb627a2cf59cd46a371b5af8de815a43cd85a7869766ab13b81513570982f385f5704569872ec7aa83704b0c462c699fdeef52b3545450679a537932f4b0a0c387a71d0920d4f3ecef45e85af4cd6f51587db63b1e04ba1bc84d6eb1e3342dfb01f3abd28a58316f1240ece4392577e22fe9e3d48bb899f88c60653c0c473981e60a2858d5ec779fb6040c31713114381962290d1c599a08136a06c1986967814874760c2ec018589d0648ac5ef5d57c99d39a666ce7cb73e773ecfb8f85ecc68bc09da07045845d22799de6172c8c4949f35fc4b5e08ced9096db08880d6f3ab8e8d3a4675588e1c3b3e1b3586805466ecafaecb690d90015ebe4e3579701da5ba1405d3603c6c8a19b45c52a66a081a53a4539ef7c9dfb26a6b6c242b91d640a410b5d2bd5d5a6eb7fed6b0ed1c10318c3c30007a6bb0d5760e0edf032c3debc97d3bdcdb6deba494e8f92d93460d2e7533afcca95a355edb75dd1803bcbe2adb32181903bc162b61596c1669ee77ad223f278ea1cd245d45c61b63811856fd7045de0f01560506df64455621e73c1ca7fe894519664a95495e7c2077c8ee00d69dd626611df06a3bfb5a3cd94d592b0856d4af202c1385528815406c127d151565416f0a7f11027e948e44985bdf95e6c643bb383b555de1e8e2a2dd8cce04d5eca6241eb2f029cfe13b507cb2a4e5c8bf9ba46f0b7008868a53d6a278f1e0a399eaf5e84a9fc5390db0c894eb47289d5217647ae9d68c761360c4f13047511cd0a44011001362216d4b5e55f6089433fd5ec7235a88635dcc4fbe43cc9d488d909659a6672869361f029f257b5d49a88e102b45228b90332dc2ce7a3f4f6f3cf28938537d231a43787e99b58bbdcc9953c1765c0b8849a66e3ea973a5c8d97ab4f452894d2a67da77c367d584947ba19bb28202f16c893046c132cf222a32288bd1e6a1dac60445a5be44c020ca8732fc9fe01e0aac917cac4832a6204c5c91e1488300f4951c3c89dad1ba0973549e156621a0a5e8e180a4d241dbdeddd7b9873bc3b6bbbf2f1507929e873b7bc14ca980b8bd6d8708ff496b6c219eb0588b66ba663706059b68068b6ad279d377aa892d037fb6aebb9a875599b38fd7b5cc2a6ef8b9fbb58a1fc605ad658a9f7d70ef529546bec79c1284ea0dd9dcaae06486e5d798d0518b168e77b79cf204ad68eddd500ed8f483d45a42838e07b922bf6fd23bc387d8a06fbe3249d9d00b6d2ed40ac2f4c06460de4ba5442663d07f4d32e566dd0990d49aebf46d1b5d9eb6ab8b73f9122893a1b330757798841c928c69be0ffbe1da643664c48f7161e231b199d0f8cd225951682eb38248e0eede8e227c0004c5b5e18beab7dd5dba3ca3fa40f4ea4120a67bc5713dd852a34ee5c4adada48228783b8bdac595b8362272eed3c869c9c6a72a1f2b32007412c9acc96816bbb67cf7b19b2f266a430174ac8c6dc0d4daf992cc595d91bc0e8c06c6c275bb5fa177577e2b88a36619b1fa14094c4968a51764c2af9a6200328b44d3f03f053bb28c7088f7696eafd1f927ba3747ba7c30352bb6025e0665ec72de1380a2c395797aa1de919af42a31a2fe90e8f17d168e47afc708c0d0f62d6498d5e928cbad8840cb2f48ad6476388265114cd8dcda6a9b2833ecee294238a089ed66285f10495c57079e159506e1e3544deaddb81dedef2560056b3601a9ebe5436bc06bbf06a7ccb4aacfb1ba6bccacc4c43b8e7d3be8f98c592ff3c5ebd54028eb2bd97ff5a319082bcb1316390fab7aed2b8d3638f9c6eb0e58696435b1f001d589c783b4bc0c171fedb24201d214b3227617049da45701ce8355fd5406be0a9e15d07c0e7fd7e0a8cfa7e09b9dee2a567dc081fa20a500c996b4482b80f16cd0befdf6469d9b516a60c18e6f2fdbf5e585b2db651ec0902e4245948c73262bf5655077c601b0603c63f1851c32efa955791fbfc546bb9f4ee46c97537a15861a1af4b009f9328603bd4ee44c639e7580bc66138b7b21542f3f9b4401a313734ca670e60708874fca0ab11a6fe9cb479e96cd3d1846c8260793f66f3546c8e4cc99506ea9e2ba643acbd7f41c9c3e9063c1b1bcf37b229b85c9b12fd9a51417a42336ac8a28233ec749f4b3635c18437e8265c62df0ec88f2b2f017e6673adb43e0304b8c685a9185d41c3fb4cfd27f854aab7c5aec69a852044b72b43cb155e7f7b3251f2f9cee99169355143c6fa7ebb03968dee383c41c4282a7bfd98e9f3c5522e9467f202608909105bfcae6763f6fc3dd6058da08c8f9daea0bb0d4a02385fd0c3cb63ebce9fbd919c04c4e0c6e3c87fa19af5703908fe7fbe43af877353f2babfa107b92999f3e4d83979df0d5825a5c0b26a12fd06909be90aec95701aa0245051bbd9ebe01835b3098f0b1700e221df6657c88fad51bf3b5e1c38a64bff7c5063d797d73be797fcf03564dddca107d1f3091c8f6c16888e25825c0ba45969e72f83cae2e00a5713b3f3f6b37ead87227898fc1d6ba924569468049883980d39d735f71fdd940f4ee7aa409cd24673c22ef662eb0020cf99bfc1bd80d112629b42eeaf442a5c052beeab29269087af8ce634af090be02a65986e9f16be00f03b41887a8dd4b5508c1476c223287d408953ac3d942b981a816668d4c03014674e65dfca4b0e00a0ee34c6ff066a8f48c34a93dee30379b199ebc75e1687ea8c34282619a7aba3e693f5168bd1abea449a41e786ec57c8d2822c756b178d665eac554518dbcd4607464ae7b0e6b1d4839016687cf0cd5d3a6bcacf74da4657b2a2ffe480389c275e7cec9d93e0eb35bcf96797145a542e8a2c975808f8c2a0874c2002734e18783b635d8963a04d1c4a3e3a376727129adacfe605b828202ac5e93fe187351b5a005b03cff1907afb90a08753337a0f97797b4d4e0099f8900438cbd371c9bf406391fdfa4a36289e78ec63f6b1dfd5a657e5acbcec3f2e2f164358a2e67e2d219e61be6607236a6f0db0279335c6cb387f02ab2b8fcb0d04461f3e22a6079a27a703d601c07c0f2ae6510f26e5e07c5806686571f84d95c7747d1e02dccdd68041b05b46a6fa2b7c82a6762a9ff1d0bb9f5a4cb3ebaba68bd79b4a06781c3ba1eeec3d4c314a00d3de7836111c6d6e2469e8686a7c9ac6cf279f13b717080ff622b7288a0fbdc13c27764c03349d971d7d7fb9a80aa5b4b87340f3d98542c24d5483a115821ed8710bcd32309b624e9e1d4bbe279d9c1ee92aafbec19a8c9dbb24144f6c78b6cf860749e882c72d7072e18586a59194004865923c862e5ba0d365e585a086926a99e77366f53f2e3520f9de261c04a6038b52aaaeb1253ba26ef5d6099c100cd1d351ae13394bb64b17b2f5566e5b70a79629cece48ac90fa6b658805b24a9e2f35c6eb09c3fb5f033758039739712402aaacee276cc6fbe6fc61efead87d062232a8aaae8f6b00db777651aeeee1f083891a2e1599f5f8fdad6d68eb4b29e3e7d1a59b2f3791b6e6eb42dbaeaa83c6b59e4ecb5658089fb8e355959546c044b250f7fcfacb70b245dc251d72edf710dac372d6f6edd35cef518e48c1bbec64a300458d57c33421ad9bab4d1a8ec13b3989cd11e5479ae856e3011a266f34a6ed67958be18fff680187cccce7cf135c3db835a178281cadff380982dd69bf643f0bd68914947895c9bb97c588e12c2b048f27bfbf6448b51099a0f5325028e2838bebb69fd0d76e09eba3dc3bef05f1125c4f93db9bd11d83211c9c352834f8a92b36c8385862e16262663415a038045612be742465949b32951bcbd3d50ce0defb1a0107d830550fee1f167e2cadc4ddd7380c3795119c857d0202a1022ff4ce39f3e43b53d53af44228731791fc8e1ca458806fe8285e575d50520e6960c8bf1f746c1679651bc6075646dfb1933168e0619bce5d827f113fd2a8901a28441e2ee582c948eca4289f43932178389877f8ac5cdf17d5c95e3aca6237d5103194ef5303dc344a1dd9698a9986d1330d0cf91fb52ba5ea6232c9275d3b487fd46d79a000469efd3fd086db43b1856cc0184fdb8424aabf81b668dcf4fcf6d6d5d395834bdbd9f3701178d55d17ce7feb4813dccdbfec1b17c59c8d3a89e937666e46a6dac291f24c7b90000200049444154adc10cabcb72fc3c2a93f27a35b01888aa49d7f527995579735904a4920dd7e75e81d0a69fafcbebd073a5628e4175015ed6c3aa265345e34a07fdef6a3afa86aa63cd7578ba2049d4469b2f6eacaa35f8462b4a9b1256f4e7861c2af6753258f2c96441ad77770394777a035897f21a9817e70e911d256c4a4b5b6b6035fa11dedcb7ab9bb1800205d19fbeffae9d9dbc6d6bb40f5f0d9f0fe7c734c4d18e839cebe3dfb7d48fe1ff4945069cdb988a7af8e4dfececc839cb0463712d021293fb36ba1ec964901993ec030736be2f1cf2aa3953290d0d6ae91abc11d9e50b31bc48b350342bfb13c6c4417de241e6a64c48fd3b002c36dd605dd6babf47d32b33c59dfae0a2f09848a1c6ca6f9e2f0c5091d56c505b9f296c2964e37b6acb152278b1c1794198b573df3293e86c94811116b836c54c5a846189ad4b529824d868d221f056ad60e85dc5820c1f95989d9de76d255a6fa90b76349d500006a5cf45e2684f89b711958c46165631a5e038364b27d18610e0ea7a30734ab59096216957bed851b473a3de937b08b2406b353e170e78ae1bed795a8821a58c6ac3bae6c6bedacdb1cd40d41f3f7bd60e0e8e17b59dcc4f825b7d525a249bbc9404af4eeeca6ebcd60d08752dd6cdbf5a5a954c086093399b747401a76e5a06499eb537910a92feaed76b053d5dabf5b07ce1f502aa8d5b51d98ccc375e4f1eafbd5fd91daf858debcecfdac5b23db56fd4e063b6e49be37d6508a70fcbef734dd517e6c1ee461b0c7ebeb77a5c0f5005368e6b7b5c349e4e39985ed387f6eae54fede2dd5bc9ca10f824a581eb834db1a8f151702ce95c014ed723b5abe7df0010bb2dc0c2aee8e043e85b67c9496b626477e8319163943f36a1193740c1e53cb386dae550ba492a6e66f12bc207237a68e44f29c49f3b7e388723a911b622d13785d871b887170f200be5d2283ba1938f9a5860c6701c2dc488969a15393c6f30f0eee9dd9431d27c4a1f0a2aa644c3943ed2012c0569b2dc460b4d693231107e5edd39a33988ff67654d73252485c36f0523f275a95f5f012c228da82b705deed128477d3ae0179f279a89b9480993c404c35f837faf5a2391ea1075a9cb791a9dcb177ed8997d5b5173cad8c1beae29bfd27963433a3c3a6e9b8381a2d5942701ce6ac1b6326fbb3bfbed93cf3e6b9b1b7dd5a7f25c6832cbb1b650725584308228be3eaf036fe69514d40dbd5a2315c08c0795757581a51ea792063fe37f89ed55c264f2d1b5fc745e67ba57fbb102559799f80616be8a5c0846d19818611ada191708fa7e23d52e2dec227cdd05e281464baa7a7e4dac52815e91dd375d6def2e28c974491f8adfab93cff7349dafb4fbde6abb383d6d276f5fb50764874757ed861ca9abcbd07ca24423f36fd03fd2b8f57aedea9ca2e90b4d1a3a0903342c267ee46b4a1601c473ad518e3351efb99eb4bac2d7459e16d7ebc08599c27027cc479570582a86881fbb3c6b46fe28f4a96281293fe881a824757060daac3d8c31ff229b3df2d042e7ca139ecc2b951da6a9897f8ce330f680a7f38eea33ad54dee6a398793667f5fbd11f71b9db3ac2e4b109948a456ca7b9e706bfed64e778f45cdcddd98d7e8819add23c9ca6b99f2174d8ca62d13d44a90e45d0025083e75ae474e93a6190aaa98cf409d22cc41485e6513db1601912508c67cbb122a03017a3e2d90680a2f641f506cd72632340a5f67682965af68894c6fba0adb011f50792e8c6d9bfb1d597e2e9d1e1a376fce4c9a24bd2d1e1a198371a6ccc33ae18b65537ebbad19ba02c76440735f205038b9f795d17fe0ef3ca636406d75dc7f538759caa89d8b58efcb7ad2083aee6b101cb27aabb986fd0a0b59864a560b922a6cd42762d33142660ecbec186ec745f4c86cc92aeec4866408938f0fd5af260b034607507534c20274cb58fc32c0810f067fc7717b03da135066db5dd3eccdad9bb77f25b4de87c7275d1e6b40edf8c9c2af955eeee16daf3caa55209c658b57b66835ed41c97cf3c7af4288b8e234b1c60e6da883262321c1d1dfdb3f297cab2b8a53efd0afbc11234d6e993c3ff84bf4d796439cb023c30dfa261819a9866872687e7c929c244351bd37728a67503d55c901e236f247543d02e2da7751432f3bf18754ac4749db8ded5fdbcfcac3c1ff9db8e7983bd19f7a20e11f38e0cf5f49be9588a7ac63357f35175c60e2d76229ebd95d4e94a15062d24dd277eac300b89dca98a46f95e9b519c2cfdac3501569d4b21d2b7eccf170b395c1a38d663e31dcb54bfb95906926c45a8c83e4d6b0ac25737fa6a0516c0b5d9867bbbede947cfdbf1d163552f703c5816ae05fc8ec3ad2dfd3f7b2088b16cb75741c1ebd8c053e7bad7a15f33f1a8d690d79d41cf18e0b96d3032a6987dd7f3d4e7dd3dbfffae80e575dafbeaabafde9397f14dd4856e1b73e1542f12ab15047c11665806bc188488e0b891aacdb60a78d594f36070fc1a5d31d85410f5793dd875e1f838be1f0fe6f25a9705ae357fa43e60a6fdd9e595f4b030d22e2f4edb9b37afdb70ab2f595a72ae48181c5d5e65c42d540e38971ab026e0721fec7a6bbdf4cdacad8939612efa338e16f9fefc9b0943c2a9fc598b6e31e82485a932a46bcb46441459a14aa2445030f5a7600f067199832476de20ed3c6a9bca2d0a808add8c24d90019271f56c08261d55db63bf934274833206158d1b530c9ecfb54a3d44c2254be5ace273f7f9be47577e758a00cd7e885c0bf0d5afb7bfb61ae5137b498c4a16241930dc695efc18691e1c197a88450729b36fabad690b68986246a44a25c414cf00029582a6c8c0d597e476a34b3e30af7c66724459532365aec52a90d4d343607450dd50b32fc9a6c6ade8061617afe09885459a08bc573a50b3409a3db7bfbed379f7fa17bb9ce8ee0242ae33ed8ea6fb52d0aa5256f1d40ea355841ca1b7cb5a4fe25d0580085d365d27de13566b65bbf6f4ce89ebfae4f6f3abe77931d9ea9e701c7a96b526bf9ebafbf5e482457b6516fd4b6a42fcebb9e11d51376b9c822b7a6523917d84a3d005b3ccd3983a027a9f334340132b7433e224a1cb28b8b4d0c4f5c0143d6add501ecd2d90a8e952d86191b21f9fa609d7c4896fbd5f56d3b39791b358d63545423f31bdf01794d98521b4c9aec9ec2a4a4c6f0eafaa26dae6fa86fa1c70dc0b2e489cca195152510727eee930607dcab3aa964329eca2f28c728edbb391745cc2c3274c05da6220d7565a613ad0c93e53ea379dc1fd7aae4d14994e19066415a033f4e516131c1c202e45014e7a338e61fb4383cd10c3c06c385b98625450e93c736cd2d3fa745c0241795bf176669388beb315d24ac722747354917b9b9d53da0b13e18ec085474edad27062b75dbf972e2737ff81171e233c70082e8e3b76c6db686ca672a3a680e631a521c2d939c46104d00a75a40b254d2ac0d20d0b20afd79771ea25fa0ccc250f4204565015acebea7c7e134a4b2b996f1387a0b90cf067b263f8c28e19367cfdb1a150eac239cf2fd7ebb383d6b4747876d6f67279a5248d830ccb5ae35e139e8e7e7a8a3e7bed794c1c2669fbfe7cfd775e6f78c19de500d50f57db326cf8bfa994a260c60de7bcc9a176dbe2a921a800c385ee8f580dd05ee13c7eb35ec1b4cc3118b9a87d56542be31038da9b693efbc9bfa2154dada052c33ab7aac0aacdd07e707e587ecc1e737937b743b6e67e7676ad1459639a278ec6ce7672732058906015cd4dc855f67d2debe7aa5b484d1d575aa7fc6b8acad84d9a21407d5aaf5140d04c86df63891d0627ac81987233c9a50bafb105d6ce82c4d34091345bb1b4183151a4d503614394bd2552ae547d2ba8211a057af0ec83097ec5d98663c80158b30bad1c45836e9c03b6fcfe69e372f8d1bcc428c2436023da7c5b9c3115c3707efc89505c7b2777ad1f2da350713b03489b30e94e786ec306277a495f85ea3ca22b4b2742d9955adc83560ace0cf466952013b8ccfd9b7260d2d99b3f45a4cb9628227f8b188241780e5deede4f7a64c4f47e603d7e04451d43c621c2218c1f3a0d311f58768efab03104c6d039d77125a37dad1f1a336d8dd6d3b3bbb6d676f4f45d04a449d8cdbf670d88e0ef6b4a190e3157effe5265cd7675d07f559d4cdfa4380c46b4e37f1daf4f72b9bf233f7daf3f9fc9dea0ea858b360c62539bc1e4b73825a42df182f54c65351d0206190a90bbb9e2826c632e3d5ce3833ac2a2fe39b34f05433b43b79dde68bddd73baf07d8035301af4b4bbbd76880aed7e0fbefdadc4485c80147e2f6cd9b77dadd0ef60fe4b8be1b8d94404a01f1e5f999fc06383e957bf53055e9ced9c9895ec76f21c05a8d66a8be7e7ec30ab8672716720d9c4785b8ea3f4761f3b2db0ccc81f7c96f1c0e71e4874638c7d8c4945162287eaa28f501b09600cf2209d604d8c2b062e1f833f8ea43d00d566570f3f56e708f8b9cada83cf073d60476767aeaaf6bce582ab9248f7ad7f4f3ac93b36e8e8a722acd244a72a26f6374bae63a296216339c5215409a4844ee821d9136100103f9af94478599164995ca85cf5402a72a38a21a11505ac547ea4368fe2feb09e5d7015c321731d611a931c1d403ec9175c63f1919eed23acbf229c6cc3e4b3e377920bf2c546ea54e419a0abeb2541c45c4eff9471fa98bf4a235dd3d4d3136dbce70d8067d36b54928766452ac376e9b567593afe3ef6bf5e7cdc0f87cd755e27566dcf0d87a4df1dbc7ab9b918fed79549df6954054d665dff20240012c839407392249cb90a8d9864feeddd493aaa2779cd8f92fcbce1d96ba70ad57d46ebd9f515b4d3b0313bf99186767670b56e244d57a935d70ad4ef4cae4fcc02a83329879d7afac4cd41839e2e943bbbabe51eb717664cc36ae0321bff3931365a09f9dbe69344a25a99404d29ded611b8fae555f88af28b28f1fdafd24160f39570094c2dde994f5c367722f4a98a6d1f63c7338a5ca604733fdff60583866ddf001c0823929f78da26b32c38b681b9b0766a1522b89fec9a4c51f145158fc59ce230094f52cb2f7208c063bc8e328004e3fd4a29e8e059342794ee4d4b34ddfdbc27f95da5d9ef8b5deb0ce3fc056827919fd03bcf98efd3f022785e6009660538ae2a5d35f89c005608339c6a6aa5cd45434b5b3dc2915c1c842f31fd38f9c31520cd4d55a951af8ad72135a34d8c8362209ae1c9b56676a9c9b2538dcbfd43c6a24937931a3d03c944c4963a00a80fb59ef0fda436faedc2cd2618ee849986285b809f6f776d3d13e166b96dff461d9f3b10289c1a4ae9d1a20e375b328038b13422b09f03c3590f8b8063a839381abfb7ac5944a38fcb9ba89f9b39a73e86179373200d9c95e17ae2fa8d2c68a945ef471032e798889c2c3924a569a3266595d50f479dfbbc02c86957c30fdf5522ba74b37abad5d1d777500fcefba93778f5341d90b8bc5873317bfc2f5cdadc2fef4a9e39adefcfa4a755be85e2199ccbdc2b448ff63f75feff5daf9e9891814ae6a250bae86d63d13857b127b4d96e2fc26a46330fdeccb135825e8902088f92647fc1069992da5352867484d45d7642a6861f6e6caa48fa816fe21400906824aea244040a5423885e9c673af66a98b893d8f86ad3872d56999129acc9db29f6161fa141d7d9983f88828e0ce42eb603c29419ccfd566977d5af6617a9391cf0906085341d205250a29828672062610c70748014498a6170bce1c2282a2382a290a3393b65814b2637e693e2905275899eaf892d16a63cea4545223a44b9f0dff485455afe5cc8c97691327ce348c08366853ee51101c3e5dfb62795d797a37d1e908409e91fa23d14135c5546e1d26e8f6deae36a4defa6af430dca4b3ce404d5369668272ec6c0ab30ab50df9f9328fac028a41c0ebe09f138d30fbfd3cfd6cfc7933e9ee718c035e3b8bfb2e6669655d7eb6d52da0f12b9254da4c4a9b32b3c1f7bae6541a5e291d5f36e5379331d878400c24ef394a8ba2269f730e919deebed18ab0f5350f8043beec503e4f05b54a67fdba07c503517ffb5e2ab3ac60e6ef2ecdd926472df2327480567b749a02cc1edae5f98574c927a39b76b8b7dd7ef8fe1b35ac8049d164157f02d1b81e3bb3e44642f2d83b949caf99b30630f0bfb2c5c9be9e86428217b37742228b5c1bc7a16cc3c5b8b1eba7c09db2cfd163bacdaecccb1a316c24c0473b27c9af9409217887a281544d970d6a35dea9f71d6c29c2f2bccedfd555e0736be321c11155892c25910b2141dafe2f6f7276f4ab1e50cefe5e282ba8f34f74dba12f2480aca4cd95d02cd7247e48499787882ec9610eb8660a43a88546e90e3f6a35962537a12ca356140b5035cb233d027332646db88600b3301f090e86e6575b71130babedf29dd0cef7c658c7480d4332315691c312414671627533f4e931fef19b89399363b7d16fdb48cca04c717fdf1e1f1f8a69f737d75552650bc66bc173d873c76bbb9a715e6bd5ea30d8787d7b8d788dfaf8f6b5fabb5d178e9f6d250015477c1e5b6bef6d6a694ad7f56f1fb51896d1cce0e38be8b28f2e02fae6fdf90a6a95717133fccf83e0c4ec125e7cfe9c6fa0026035d59cc3e26b5deca29d3c2e03931f98afd1c7e27d9b2e4cceca18f94ebd8785899a5121a24da45492a078af4605bd46471404da06eb1b6d36b96d2f5efc2827281a58e7a7ef42a218b6c1a2c8d6f4eecb2893329554492a04181817011a2dc3107ecb30af59a96aeb721cd16adf1cf4b538ad5ec97705be0f31e641e7517cedc94cd44e97d9d5c1d8e2332ae791f060a86230d1dd2ca4fa1a22e93472b29c9be367166c22da4cb9b104e3bb48c5c889e8c9c9eb5ebcfe9c370e006be1bf50b3e8003f2de495f578862ac25e9aa8dc1ba539521575e76831aa90a0d19c611c8a42aabeb3162cce9baa98e04a809e9ce0323149ccdd50a430e66aa836f428e149dfa4522ea49b15da69cc3d473d7d5f351583e3c8fc5367ec5575e8be41c39f28ba9aa8aec87fd5ef0f5b7fb8a31cb3ec8ed69e3e7ed4768603359e70bda7d750f539d5f96d96538949655975e3f7f5565033cba99fb32f3bc62c7c7675edd7f55d01cbd8c2f7f99e99b5d775bdee3aff04583e4977f156caa6dd295311ba685b91d0485b99922349d2ed49754d2377656c15b42ac3e3fba6d215c93f64ee7507ab9a7f7e601e1c97f5f89875f7f1718ceceadb328bbabc3b0a56314322d6dfcedfbc534fb8b7af5eb68b73cc3fe492998ca13caab011e60c3beae45e131d5a4fd63be010827d777296ca414e5e1211a90c4b33a1075b5b8bb226fbff50a75c97c67708e431e606e128b789b20f757a4ee1be68b6112544000fff4b148f948acb8b783d9dffc3c120d202f2b861ba20a8178aa46e4daf678d54bcbcdbe91c4f4653e78a5a9d25cb52f71945d722078c5ca7e5e2894d25d8baba03cafc8161299f6ccdcc0e247b50ce19e6af4a67547748c798488fc0ffa8c4daad7e3c5227b4661040e75174745935214695e6b5e73db2d94a7f48b053f30bf9b752d521fb734a1515df17da17c5ccf1a6cd3d7ac364bef16f9e7da45a4cdb349535002dc6141397861348251f3f7e1c6330bd6fc3415f91c1de2cc4315dde55376c9b770630af350396d75b35bdba00e7e3796d781337f878d3a9cef1ba06bb9852c9501714bb38e4b9e3fb50aa5405ac0fd9a09cbcd2c97a01663bdd9bb42fca3769803033c0a4a94e35ef4295d1d59be67533113be3398707ba9aa11528ab59c8f17c5df501d5ddc6e8dea5d51a4816a81a81e24fe9a9879c5a3ff556da0fdf7edbdebdfab5adf7e6edf2e24cea0a38dc87db5b626030259b0230adc1f6a01d1f46063b8b1676757a7a2aff8a329d53635ece6c49d0b0e8fa0a630ff0656847273a181a4906294f488d4176731118bba0195f996a024928a5b946d4102aea46c46a741df585099414310370300669a72bc583fc20d71806fbb08aa80b93e576c6074ed91142760914360fb51b6b81e3830ab38cfbf333aaf32a2675f8030124808e6899e68c7c57002e4c066a87ef2d4cb6d0ed427c9128da60d129473eb4f4c179c12ad13301ca9b17fe23b3066d6c70644ace9249e8d9e0632999f59a6fab91702a9f572d5b53ba0391d9e834ce064134308aa2efa3507c75458a0d946e0df091dede08a8e6f82b37faedf8d1e3a8dd241a3cbd97b37d63b5a7aa8445b3db5c3875a3b0496a365301ab826a771dd7b551fd5675bdd945d3fdaec7d663509fa93feb355c7d655d90afdfd3b1c874afa66035f32a85d464cd7c93ae29c8416bd8d4a062201255ce626706dc3e2c9fd76cab7ecfa0c26bfc381cec84540f8891dda0a805947e9c7a5f36f70cca1e688ea31d3581b982b64193ee260acbabc4865f3ded843426c069fdc3375fb7372f7e6d6beda1bd3b792370a583f2c1e15e285fcee6022426e6c1c161dbdf8f66995a507763757f268bde4cc64aa48e2a114de4f35ed8fce69a25f497a90ce19c8e88aa7c592c8cd44857fa827c4ff7cb8613f016cc29dab1df85e3bf6761bed27ade938b63457496148ff087d93fe231e7f866d38097ee83f15d8fccfe481308ed29a9a0e28f727badd2f9daf76436424a085c86852ee9e86cc211a91b21050ce01261c35f25f585d45907ee30e530af349f13b0cc9cb4b0f162ad44d98ecf8d149ae78516d41ae668a44af037ce71452e57a3a6d08cd0a547f66169ddd8b99f32d20613e6b84d44c612e6fe308f71668cb8cfc93dcc8b7e9883f6eca38f142904e8ee6eae1bf583c33e4ab898cb711dde6ced27ace06000ee9a84952898e554d3ae6e845e97f51e0c323e9741c626a4dd3f76b7c486fbbe5aadc7ddebd0efdbaa339958747ef6e2acecc25f3253b12d596dce3a0815652bbdf3c2e1e4d6c3f24dd4ef7877ab83e55db72a8e766d6503a3efc137574d5ad34a1fafee006234e94ff184ac2c2cca6cf0ffc40e0e68d19482458054cc2fdf7fdfcedfbe6de7276fdbd5e599d84234fb8c482072336767e75253e03d004bfa4777b4951fab5815ff9273b0643268928789c7f8e1f7e3dffe9feb8c861ea156eac565300308bc51448fc1a5143364c4cc2bc4fbd254c5bccac2e6fa0cec0c5f98ef489ca45fd2cfdfe3591783e78b3790585191a7e5e3a3d955776ccf35fb4662d2278be21965022ce7b5ef4dd9fc44f87a51a6946d7c743a581066a2540e143d8b929aea7b0987fe3251541b1d0d49b3c01990c31c745b3025c12a29164d84488eb53f4f662f1b5c2fc04ff30d90cfa26aaec10e6dfbaf0c789387591bdd9264bc269686539f0ed3a39b3bd512eeedeeb54f3ffb5c85da5797e7edd1d1713b3ad85d3478f1065d375faf2fbf671787ad0ddeaf40b200868e39dbb5620c587eeed59ae9b224cf9b4a2aea677cce8a199e5f8c85099218d63ffdd33f2d4a733ec82e44c99759b39e7ca6995d703005d4644946e60c754eee0cedbac06ccb7ec8dfc4715ca6526fb8de6405560fa051def764c0f283abc05cbfe381afec21060fbf529805f8ae24be326f526bf8f19b6fdbc5bb93f6fac5cf6d6363b51d1e1e2cba302beab5bad26e5442d2531e0dedc1507400845d5b09805140ed490c6085ae54b026765d7edc09da6c8085c435ab4d553a3df58cc85d4ae9e2780ed4e9669fbaec542375cc94e6d5429a8c175d973da1eb26e08d214a7b625ed4095527be27b8178cae2dbbe87881720cba01d997e845e0676056eceed3f8e92883c1f4d33317d39b65a9143d16019248f4f479c3e784733c1cc272c66711fc620e0904c3e4f586850f4bccdfdd903111e90aad3243eb6991911e60e7e7035889796594304033821dde4c6c3544194e8c239b1512cc57a3cb281427023818c82cbcb8a47b386dec77dae3a7cfdb463f44243f7afeac3d3e3a50de55775e7bc3f5fcafee133f5b332013057fb68249776d552c3090548656d75b97c9f9bb75bdd5f9e5d7eb713dd6be460196c1a702962f74f1c14e9e4445625f58bd71038423429c8309c083b5447277302b1db5bdcd795ce9ce83f6eee4e377afbd524daec794d2ffb6e9ba70a6674221ef9b967a12993d702e255aca4702eeac08b498cc276fdeb6efffe99bf6f2e71fdaf8faaa1d1f1eb4ed9ded767216eded61467b07fbedfa8abac0adb6b7b7db4ecfdec9b7655398e3cbe44de95f33acc1201cde809416b75a94c76291ce7b4af930a6067b7e0bccb24b0edf0f532d3bc6284e108e6a2d261243d1cee2dfd9f9993172ce9b9f89cf6d2968d37a4f389b827e6e9ec4062e5695fc3e294bb3605f2a278f1fdf9bcfcd77232aba34d96134eaa2a3308632a1b478f981a586dc317eb714041478491d4a9f91595b34b8046c59ffe77b924f9032a7cc19d306b086f06038da63ac0314753dc99ef47d090386febf17e0c24c2447aea482d884e6fbd240439cb017e636a0872febfa865e000f2ae961fea0f14e279dede156fbe8f9f3b6bf33cca6a94b5d750351f719798e18b0ec43aaacd6ebda6b9abfbd86ea7dfaf9f9737583f2f9ebe7bdfeb8860fe18de780bfe3755eef41a0eb365fff1245f3cd19f52a50d59bd384c944af4ae17c63364f6aabfa7a9166443e8e4d46dfbc9dd6de490c305e0006a0ee0dd6c1967996d2325e5006d9eeb5f8de96af133e0fbb9b05c31c47a7fdddeb37edabbfffc776757ad2ae2fcfdbbb37afd241bea93c1a181526c8869430c78a0c525fc875604ef23ee3c5f89c9d9e29ad407ea8d59efc60618e85c611be20b5a24ae5567661765bdf977770edd02bcb22e228bb89b07de47c65876785a0e78a5c6af26601349ff3f3aacfd80c1795554f282f029995e9e7f2e4f5d80af0e7212fed0dc3cf6f65be6c9a5977d6eaf7a44e13f318760bf3812189b1a5ec0d8aa93060524864b2a7848dae43fe92002c2d1a257f860fc5d7a9be8305303567b280d9630a6049578b5483f4b7c9c16ff0cc4447152cab0039403690b5d754dc956dc554e997fa6251fa143a68987eabeb311efcbf351cb6b727efa2b05f09aaab6d73b0dd760f0edbd1c17efbe8d953359c48f7dc07834acb4b88b95b9f97377daf5b7fb6b2248f8bd76565bfcb1b5c7632aaafd53554d996d9af01ddc7f4dffe5d199fad87f7a2845d6a18a6502411769d5f15c57d61dd9b31085514b6d3ddfe810f31b8fa9acd0cfb772a0bf34d5446e4c1a800681033d87940cca8fc7ef5b5d5410c3d74226f596b8722c074dace2f2fdbeb972fdbd7fff88f6d63a5d7befff6ebf6e2c52fcaeefeddef7ea7eebd44ab6eae476d67674f404689ceb568ffb4edef45790f6a93aa3d04f0e764d5df2b4d828d9a4441990334d6545ac89a1cd6fcf037f94144f26ac0424eedecb2c3415095083f564c2cd22da22e3112b3233f2c6469fccca3a92b9f0d93549f4b15085209885c7aace39944b6b8ca7a2273524c471db573577526be7659120230d55244d03e20cecf3377b1f062e786a1a56c31a753967a3aeca354483ba64cfb088aa20000200049444154426d4619d90cf00ac96b355f9536d85c3e221d9beb580d9dae48ff88ef93246aa96cbaffa81099245136bd6cc7a5e0f14ae492293000eb929616ac24c6ccba5ba463f0137599adad67f0816bd1e64524f9f6ae4d1f22cd85674cc3d413ba8aab248926ba5bede8d1e376f4f8b81deeed2bc39d1c3f72ec38bf98592ac386b6fcd29de30dda1b4d05a20a2c75ded775dbddd0cd942ac854e03381f079fdb97a4d5d10abe6a7ad9b7abd5aa7ee4be845bb98b089c63ea1c1a18ba07edf40e209e628450501ef569838b6f9bb0cae0b2e1e182b71769960bd1eef1e1e389b908a9a65e4d0df3710fac1f9fa3f747f9a982c04f9b142a0ede636da8dbff8e9fbf6eed58bd65f5d69fff93ffd2799115f7cf985a282c74f1e4bd1613a4eed6e726e106d9b8edb210a91a9d6c9f5c2ac1c31c2ef457f397acb29b2b6b1defa2832a82b7084b505c8a43dd9f722f6b4d49d62316ba7266fca15fcc980012cb497b4c3a624ca6c769f52c9a5ff602922f644d384ce9a3e3f6b9bfb31d923f5439dd210024c3396ea00aed77e2181002c865212cfb5041431ce69f4f5d32e9badea1773305b7df97da4a9b5e8f06fe5428dbcb4343f5c742e3d31ccea2860262d85cf33a6d1511a6dfd305b4963d01ca56ed03d0bd354644321074e8d5c138cbdf9051b02406253f1b82d167616987bbe39028deefb28f3f1ee26b702d0c3e3a37671356a9797d79294a1e0fed34f7fd376f7779583c5a6e65e92717e802d032af82c4b3db0d7445dcf060c9be2262115b4cc72aadfcbecb4ba67bc6e4d14ba78517162f1dc4ae94d3501ebfb5e9fc6a5f71447bdcbf9cbbec97a1195c17c085d7d330ef39adefa86ccb054cc9b110a5f609731d5e33b4ad80596f777f9809b0abe7527a93b80d99677549b28dd87accfc95c08c08afe85bd763b99b6d76fdeb4efbefeaaf56693767779d9fefe1ffebefde10f7f68ffddfff0dfb77ff7c73fc64ecf3dd23855bc3dccafe1101dabd004c35f43de16e53b2e3de2753e0e600180d1776e4de664645a67ef406931c1c2703887ebc46c383ae264cb2949b06493d50c20709fd14c352276f29b292f6b59c26320f27116ac357bea7917f5b3e673de1cee916096e916e69676ff8c9ee9fe3209d926a2ae3b1358f5fce85e94133a5249969d98a4f595dd9305b879afe462c55c0af3891f6d023255fbd11095c81de0948c2b6a1e71b05330be6424fdcd819814f951aaef235d423af4e1d341f521ca76a22ed41683e78a374631c6340161804ac5483f23d78a5b01539f861cb83d94443cbe6dfd014aa35b2a05e37f008b6bfcfcf3cfc5dcfb0811a2379615f11c2b4cf2907fc644f65aa9ccc56b8d7bb03ba5bbd15752e035a9cdad68ce55b0eb928ccaa2eafaf4bf3d1f2a307a3d9a58d4e3bfe77e200fab0253653ccec87514c7eca3825617402a92fa73153db920332ca37705927a337587b20fab8258bd9ec5622ab92835d2e7c88c07c6bb4a05492f229ba4cbdd31dcbbec666a0c01c3ba9bb4172f5eb61f7ff8b6b5fbbbf6ea979fdb8f3fffd4fe8f7ffb6fd527eeeffeeeefd4b519bf0a85a96ede80a6d5a347475a38b0b0ebabab36a67d399da3b35b3060be3d1cb41d1caaebebede8f03876ea95e83a2481b7bb687661eaec6bb5ef8f67075be04759e2e9941e4fa2d89609add21c358a0d3633a39557fe78a33108f13b145357da6a2e8e3ad19d7def4918e65028734ab921d333bca12925e061aeba4cc61df638a160db6a01b3a8a1d44251367c688899191be8b4483317cd0b47f7ecc4e2d5c8f77262aae6643696754491f79d7cab616e144d035261629185cf3d605a32ce30b26051919f05782dee5b11c8f0b1796ee1bf337b217a6bd092d0722a5bd88fc5e6757b7723b1befe604b0a219c9796f400e8175f7ca9c00d3e4d647e98937ef6a4cd70bd1c0bf0362bf133ad8ef13aeffd1cbdf6bdc6ba1b7c052c1f93ef56d3ae624905287fde78e1ef54cb27ae3b2a042ae839f752d78949e8496f80a827eab2acc58cce7f78d1f866eac2a903661030c36282d70bf3b9fda0fd5d0f88c2fea9625a778e0a5a15a53db97d5d1e0c4fe43a5015a0b83e4736970b20cd1c74e909ad93087a71296dac9bd1653b7dfda27df74f5fb5f174dafecfffebffd6a0fff18fffcf8259e140277d8006ab80c8eeeeb6523590a0a1e6d040a585b3ba26e99a274f1fb79dddf05bb91b0e8b89eb6352dede649de15a9a7ed07f293244e2a819a3163ce621dd9ed3997b734bebb16ce59552c80fb3a9766c31af6cbdce7df0b7c752c76491a6b969a664ff9977e1580c24a5667fc76420be269e99e718ccc52006e3531da2ccc0f091f11d4c4c40cbdf73ce9ccd3171d7144414604ba32a0ab063bc429e47a62ac0b31e290bc1da423d42fe2ac62fcd483bd7d1b652d1f5eca16df58772bac7b5d3df90c515b5b1006fb01b9cfea98795cd5715a1958f2d94313c4e0a96485679dec6f713f93a2fafaf94e48b8f8d365f67e797324f71b403b0b8120e0ef6dbfede9e7a10dae1bedc90238aa93eb145dbde6bdcebc92caa82849fa301ccdff73c30c855c666d2e135e97bab44a67ec6a0d8b5641c41f667fdac2bd91116d5365f0b73a2684157f4ac28e90be23b66609e405d703090d4b406759ac99db052ca2e201ac89cdac0df75d06572950ce24a33bb60e6056080aabb20ef0122b57cc4e70a500ea96098d2dd64dade9d9eb5cbabebf630b96b2f7ffaaefdf0ddb76db0b3dbfed7ffed7f9793fb8f7ffc779296b91fdf49f5535d71243eb8a2ba40c0035df1d39393e87c9260802e378d291e3d3e16600573c95c22f962d0818a7a43cce4759ab82eba078563987b095337b2ddf1a36196e25cc7e5ac869ec8f12222a8f18cf6f3284b104d54f991247659c461322e9deca41184a40bacc592c50635b5ccb2744cb6798ffb263f2a6afede63b01ad7343752942f902916bd981e1d9ddd953a9364d54731cd75923535d11fb24d59ceab6041e9842f5231b71418ab483c180ece7c29bae0a857748fce3738e6632c55076a41bcf459c1baa454aab10ebf227fc3b6547a83bc4bca2c4bd050e5459191cf380728476f46c0097fdfeded487a6bfc96ff8c529dbb7bc95b1f3d7e226df7274f1eb7c78f1f4ba9610dff1a9b61e63b3237546ba814a26521b2d730c35aad884a4c0c42fe5d37954a10bc560d24fe9cc1cd6bca6bd284a746e8bbc0e78dccf751cf57d7b3ce492d616537f5264cbf3f0428f5a00610dbc5665d0688ca7c8231c4ff95567a729a8efa423d102e12fe10955d3e3057d22f33a9bdb3f89a16a6423a623de0be0723bdafc3f710dd582201f06e7cdfde9e9cb6dbf1440d294edfbc6c5734a8d8e8b7fff9dffc2fedfafaaafd87ffefdfb739d1391233c7b712f8533352a27bebebedf6f646a1ec603ab1e0905e967ae4ce6e3b38da6f3bbbbb21dcc7426a014c440c011e00031d78002bc2f24bdf8d2289e98455e22a7e9334096927c56b44e1d49e5e95f291082a71becc57920f3f33c3dd50433a4db081bbd04a478a18f31e2734c7749f45ae8f68a116ef3d85c844f848c28cc82440a067265f528092cc954cd9e05a70bafbd9c9b7348f1c2a33bec53ca52c2c9dcb1b6b9b1a173602d21718d3d128e45c76f7227d840bb819dfb6eded619b4edc5f30248957572347900824516022b3344dc584440934821d91491f2005d084ff8b9c299ea572e2d24f866f2c6961b0cdf41b46567ea4c6e0239316bf9aaddcb457af5e499e8871d6b861e6cd5adb1c6eb7adc1b07dfcf1c7d26f07b088710258b66a624cac069b5a5ca5e4cc6bd6a055c98137119b8d5d72e267b160c61990b1d9bed874923dcb744e3f99bf5b59553db7bfebfba860e975b8588f6e555f41c65fa8c85cbfe8c56da0f37b76607b52b1d8ec0733ba5b26c526a1c190df36f9ccbcaacd6c4583ba03983e567bd7e05819a007b9be575fab206d40acf71b0f135323b298093f5f8dee343101ac8b93d76d3c1ab5b76797ed7ffc9ffe4d7bf7f675fb8ffffeff556768b2c7690d4612288e6f76d79bdbd1a2dc46403d9db6cb8b4b810ce6204ef6ddfd3d695df19a58ec4a248dde4f421238ca7af05385b96a0d6f5613bb7f7ccfadbae66d8a544dcac6005a91654d294e38a663cca791f8584c09162e800ab809ec51cebcbd95ef8d4e35d40b6ac1ad462e192a14b11945c490eff39990bf894ed3323132839f45edf942e2e782f5e2aaceeba0ac80055e3744cf0dae9bf29bd85c63b1928ae1450060fdfaead7767070a4a005e03f994ec267767bd736b648ca45386f5370aa1e852babd1cd2875d84949603c516ee5b30017f73ca02b73e91509e8f16cc8bf835d599dc4761be34883107ebc56fcdc3039e92ace2684e0235143fca6686029216575ad3d7afab47df2f1c7320719d30a584bd00ac6ea2e551ec35a4d504d7daf27af7f83991992d7869f0be7a9ec8a7b311e5473ae5a3dc6093329dfbbc1cec7ae2059999bbf2f370e99ee6611f50bd5eef4cdf8775dcc3eb0994b05112e8c9dd793c7e6a37596ea0d1a4cfe2536e7e267deb7bdeeebf5f55730ab28ed41af0fa782ed924585c448f5c72de92b91b8997c15a4348cef1fe497a03fe1d9c9ab36a245fd6cadfdb77ff337edc5cf3fb7affff4a7b6dd5f6f57e7e7ede2eca46df6491e5576541bdd46ab7afc11f8ac70b462de315ed07d406bb8bb23a7abc6bc85cfa5a536390b87521f8e4194488b9528963abb40fb53548e06092c108aac118e033c4723654dab60580d1d426d94cfe19b63e706f4bc41304ebc1759d9d410623b856ccdcb172fc406cd66000435d668bd76b0bf2fb384856f950ef8068a131edf60c6cbcecf5286b07f2bcfa1c501a0a4ee944cc4f4116961a6d2675c635c1773ce4288d72334ca5e88093e7bf64ccc8f940e6a3019f7fb7b4cf3a9d411863b3b6db0bb13e916f2df453a8a021d98d7ca71725fcbd6fa88ea0db754a4cc1cea9318cbb3a0dc6833bb73a34291f593624d2a3a8fb197c92a4dad00993180754ef2f1eb65b1f8c6a65c101bc3617bf2fc79fbf8a38fd48390282180a5de93b536337d7dbe76cfed6a8679fd1a683ce72b69f1f7aa4ba86282d712aff13c4d36bcd66cf554f667aba99a8dd53dd0c583babe17fffee69b6f1626a16fa4da8ddd9bf0e0d836f54d1bc92bf0d4d7b4e0d28666123b3fc717e20bff974088856664377bf2dfa6b1ef53e3f7ebab6c72764197eb37087a07afcc2e1e74f49a23139cc542fe0d45b884cb2f2eceda7c7ad72e4e4fdacded43fb8bbff8cbf6d59fffd45ebf78d17ad3893accdcc0b086fdf0edcca6da3d5d9e84139b16f6f247adaf8b5d3d79f4a80d88040d073166c9aee6d3f0ff00562c1e26ededcd28e4d7a5aa1b111685d8696d358f1ab5e9f8ae5d9d9db68bf373991b2c68162e0987fcc0b894698d6f0c3f4b4601f9ae2726ec80425c981693d3aaa76767a7024847d9584c7c0e36bab98179bbdd9e3f7fde0ef6f6520d61b50db7063ab7c4f466d1d24be32cb334d54e13b034cf66bd88b6e64297033b4d1db586cf08a6010bb38aebc5dc847dbe7bf74e80a5aa83f57525eff2fbe4e4ac4d2668a9877e3aca9ed2a392385fcc8bfe565ff747a5023fa8262ca2b934375da755585ffafcc866c3ce880ac2e0b67776dadefebe9ce7625d6c309992e228278c569db6f18d8e6fdbc5d9597bfbe6b5d8b0cc4b006b7cdf36b7b7dbe1e3c7edf3cf3e535770b4cac861a333d2fb269efb6c2e93bebd9ebd36ab15d1b54ecc98ea7aa96bb2322dfba5fc5c1ceca9acceecd96bd478e179c5ef6a3a7e68fd9bc468bdbbf8d96052994717946a9a40d7cb6f7f578dca19002bbd7494909b73de1737b17880c5b7540194056dd3c5035481a5e65399f256e665b6671f951f6205bb3a8866857ac8329722135a911e7278503f984edbc919e27dabedf4ed9bd65bd9505793efbefeba7dffed37ed617c2bfdf3fec65adbdfdf6bbffefa528b60727fa7e26474db99c444c7d8f5b520865bede38f3f6987c78f5b2f419ec5ca75868861282560826daef7a3eb0a668aca4f829eeb3ed0bbba7f682f5fbe6caf5ebd6c97a727e9bb223f2aa60585dba3eb6bfd9b67740d73a3a64dc044a9cd83161ae7405b5ce030c3418e065398aaba1f144b95b4385342259af33c2f4cc2bddd1da51dfcc56fbf6c4787fb72d80fe4a7db51c6fd466aa8fb9939a7cb9b48304cc63e7d32729407e3bcbaba96eeb9226ce4305ddfca41fdfd8f3f6883a1d1286619ef71cd98e56281b489bfbe56222ba6fe087399e7f9100c0dd552804432cd5bf89042f205df133ff8e800e67d491687f96d1679f8e83006572aa51b02b1bda303358e50176fb191f0853266602fe0c4e6337998286a7cfa8e3ad491cc6ffa11d2af10c5d1e3a7cfdaef7ff7bbb68d1a48bfafef862f304f999db9bd164d122a4b8a4bcb2f9462efeadbad9b7ab578eaeb7c9eb1e5d957abaa5a39fe6eb5e0fc9c7d1dfedbbf2b8bab0465b1a65dfcbcd8e58ac4a9d1cebf8dd05eec5c88c1c6e0e6d72a13ab035601cb4e541fa3dac2be70237d9597e95e976fdec8ee81f242f435d5ebed82537dcfc773485c722816a58369893f24c3baba5028fcf58b5ff126b74f3ffda45d5f9cb73fffc33fb4c9ddb57afe8def462a1bb166d1ddf84651bb9de1b66ee5eaf232544a575694a3452bf2c1f6be9cf82a24c9728b48f4238225fd0239e9315fee6e279adc8008cc82fe8800151127ea13d9856f322d040739418160626b627744aaa8d78369705f7734c6405e59eaa3d96710a734dd789447148d0e309bb469cc9b4c4916194001bb20f1530d375a4f6286d4bc7dfaf147edcbcf7e233f0ecc8be785cc6f5d0895251b10d53f51e66874b476f4933100546f27917c7b7579d32eaf2edbeb37efdacafaba7c4e288dd2d908f03c38dc17a85fa919ee7d1b6ee1835a69d35e6b675757022e0008c91b65c2932386e3bc176a186e044200656b830ecbeb6d633da584d22f450418bf1c7d03f1436226c2dc505e387e74dc0e8e8e348e73ba4793a10f5ba78f22fd2c071bededbb77ededeb377a1eb03c000b781bececb4a3474fda179f7f26b0a25b8edb9ec97d2ff61e35888b4dabd40e7a7dd6b5624bc5c0669f9259cf87bec3f739be41b10260fdbc5faf60554d3e075a78df9b549d07c2f3d2e968c1c2befdf6db796537bee1eec4318decb21b038a6fc43ba32fd460e58be1213b9a5469a2df378534633298d5c451dbdc3e767d40f526ab79ea01f4609b4677a969457503a03e2be0889e785a282ce8d983e43f50227df5cb8b763d1eb7ffe6afffaa5d5d5eb4fffc1fff43a30d036dbe4edebdd1a20550643a2964376fdb832d395947993c0a803f7ffeb43d7efaa46d0e77d5de49222a4a33086767b4e25216a316d5da1a45d577020718004280276fdfb59f7efc410d5c017a9cdd3869b59b4fefdb79faccd43a3debe070164f53d320d8d18a6ad8eec6938562a8ca3e8884ad6596749a6f2c14cc3f8158ca3c0386800563717870001590acefe79f7c223d72ee8bd7d7b27d58e84b611602c891c6a01e8224425294adc618ab1a7f820de1335951fb35729790ebb9be1db7d76fdfb6ebeb9122785cfbd1a347f2d911a93d3e7ed4ae6f47d1c862dedaeece9e98d1e9e5553bbfbe4aa998d53625b0810697d23242fb8af9b849363c80308f7cb49ded9d1064dcdb17c0f06c2970a796744faa1d3bf2d96defeca9612ba6e19367cfdaeede9e72c5a25bd183d4329812eb838d767179d9debc7aad4d0529eaaded5d65d86f0e866de7e0a0fdf68b2fdbee36d2c8c1f8b5c9a7c6be5ceda57ed06bd973becef5ca8a3e042e950979bd558ba5ebfaf15aee92890a5836193977b82596fd4b4d98f83ec7360e980d2e7e1bb0aa23d427370257b3a9fb5a45da0a1c5eecbe00a3af01cb14daaff3f99aab5107c0290d355bbd024ea5b8667f66579539fa1c3e27d7ee413468fb81d78827fe9e002c4c2f6b7923933c6fa39b1b25845e9c9cb557276fdbefffeaf7edfef6b6fde37ffd2fed9eae390f53f9b7b0269474c93f5657daf670bbf5e60feded9b37914e80f4efd6a69ceec7f49ddb1ab6d58dadd84567247dd2660cbd2c1612c9a1113ec7ac617c007480efd7972fdadbd7af948438dceaaba8f6f4f45d1b5ddfa811acea171f90651e29fcaf5d999cab95b536497f9274de95204b3fc669bbbd0df6276774fa7600dcc9fd24595e9600518b472226266676de5151f0c343dbdddd690fe3bbb63b1cb48f9f3d1358c354e8fe02f30414145523033e33c39d1def5a48cc72d8a67ee3675327ec5ebbba19b5ef7ff8a18dee27edf4f4bc8d6860b1b6de4677e3767cf44811497c7de488c1c6f821dde2d1e19122aa2f5fbf6e1339f3e33ef034cd7ad19fd1ac18c716a6edbaa2c598f308eaed6a3cadf15637c59dbd9da84ce86f2a9ab8b13950d4f7f0d1b11aa16e6d0db5692121cdc62117c9e69a4cc2972f5e8a7543f55089a025fdeefea1f2fc7efbdb2fdbf6d69692771da0d0f890c09fa5334e00356099ad54c0a9eba2fa99bc5ebdbe4c0a2ab878fd54505b443dd342334e18c0ba66a81996afad5a6d06c37add76d1f4befefa6b09f819205cb4ec0354a6554fee1d9fd7aaffc8a055a3069a5c34564887b0bb1657fbb59a9b15f1f94ed5c3f2e77c1e9b7f5d5f946f96d7bdc3704d35ffab3bf07590dfa7c338b47b5a2c333cd9593c3bebf5daf5e8a68d6fc7edfeeeae9d5e5db4c3a303edc05ffdc33fb69bab33f91b26b711a1c367c4834236049388f03549a672364fc3914d240bd0eaf5076d15f34499d7f79231160ba534481aec7315e5ca1da26a7f224c67ea424de3d68bd353b11b1ced2c02e527c9573691c9872c0a39462a6dc14f337d906f4dec865abcde6ae43765eed23de7239134f21d059c1cab3e7fc69aebd47345ef3e1dcd98b51b4acde8b5617fb30d3737db93e347f2efed0efb123c245bbc2613334e76e4abe145fab02677a9ebd55b6dd72324596ea55df5f5375fb7b39b51bbbcb955da09cd1b88fe698344d17536d3e602c8b261ec0d77dad65a5f32d7e32911d2993620c6013617fe5598e94668c7a3a001cbdad808a7f7d620533d48cc0d9f1a8e77be470de03eec91e44ed21f86dbfa3763b973806ae817625b8c317aff00174e74b4b07856bffcfcb3d24656d757db0da6ebee4e7bf6d1c76dbebad6befcfcf3b633d852fa883a3c93709c0d5f7976ded4ede2a86bd62e1793890f11127fc6ebc69f31e0d4efda1f6ca2d135e3fc5907d8ecefaae0e4f56b70ad6bd0d65b65883da284d561fe2133ab5eace99a11b7a261a59c3e993faf814d9388895945e7fcbd6a82f9350681c5b868e250c2a8bcc7c07a37f0aee1fbf1393d90de3d38767548fa750f56a5cbbaf7b0c0e4c300b0d889550c4b0d59a351ea459bc9bcba6bd7a32b994cdf7ef555bb3a3f692bf8aed648146cedecf424e4938743d580c1b66e28c548e504920f91c07df2f8496beb9b6d9d4c7216119d99e5e38a9e7ab4640f09137c5621fe77c3e2bdbe6a3797976d7c3b1260d1811a750844e0ccaac43caeafe590863d318914052342764f94f05eeda6606e2865dac10d97d138c77044f7209cf1e93793b01d9aead92168e18f0495002c229838e55757daee70d88e0f0e5a9f02e2e9a43d7dfa44113c40ab3e036f70a1e515e9261c7f7c07f0d20ca3497e856bfbe5e5afed97b76fc4946eefc81edf1460f1194c307e2ecece235d613e6b83cd7e1bac036a93767b3fced403360eee19f334b3f2b3e409760cabc2390e40a9ba5411aed6b6b606f2472a9d8442eacd8d7670f848811658d5c6663ff2bce6ad6ded6cb7e3274f1be632638e298e0f0b009acda37ae1d5cb5fdbe9e949dbdcc27fd553cac5fad6567bf2fc23a5356cf7b7c4f6dc5897b925733a35bfeadaa944a0825875f17863f0ba31b9f067fcdb6e9f0fadf91a90ab565325431c3f6a614b6d6506d9eccaa9d755ada8057132c3ea1ed8c8d745689b5abe78fb7ce2e1453e892fc8035027a17c019bcb4e2f3e8fd843895ef806789d85e1ae3915948cd475e7a82a10f5185cefc2c4c8a6ae7caf26b6d66ba8bb4668294d956d0e6845eb748a7a235bf9ee66ac76ef309497bfbe10607dfde73fb51945c553941a7aca0ee77f581451326e750c684c42d79d6bddd93f68bffffd5fb5bdfd833699cd35c9d737d664de71adb160b99670b2ea21667356fc5557571772f85f9e9d0a0491ace19c32f75770ce47f48fa81aaf9d9d9f2b9d8185cd6e3d18c402c21f831a859a60907f358dd4015848d821617e286a4baf469e91ba43afcba40b533b276676bca115997ae8b579db1f0edbeef676dbdfd956b359cc45521f1c6de35e2d3f14098f2185ccfc20a2763f897a479820d784a3faf4ecbcbd3a3b6b1757d7625820099b0ac0ae2040af2d5247d4f966d69472c27f98fbf8b5c83ad76626bd3334c956a204666d5511c1b00c36c47e38fff636a9127b0b873cd13fd465a950a0b30f0e77fedd436b9e8c781a465001d0df6a3b7b07ca05e37c1c0bc09a4eeee4d3c487c526b4b2d66b938779db3dd8d3ef4f3fffa27dfaf1c732f5f1a72df2b9d85840add22dd973d996c887ccc26afe5573b192165b3b750d573f995fb78967abc9af1bdcaa45548943252bfe8c8f5faf79f11de76119880c0206aaeec14dcf2ac0d51b309055d032e21ad49840d620afecadee0c46da888ccdc4b26003fc5d07e74303f221e03330d66bf58ee36badd7521f26efc336f05f913e20dfcefdb4dd8c27daa16ff00f9d9db5e170d0cecf4f65a25d9d9eb68b8bd3767b7dad5e85fd3e11bd8836d19a494e72cc4cb2e771e4aeadcb39fbe96fbe680787c7da59010544daf0bf2cd82b71b2344999d4441b011824976f47d72af94175e1e2fc34dad5cf5159b84b3f15e63149a17792355981fd50aa32ba69b7d415421d336a737387aa4374aa61f192bc0ad031dea3db51f4ffcb6761d54d3eaf494654530348fa4700208e688a7541dcedfea6d8d5137c486b3dc9ed90800a6031869c037050317256f762624a7c8feb99441002a7baebf15ebd7ed35e035817572a4247a113b3952b018ca55f4f0a00fe489ab2c286085ec0dea498106aa4d4722ad582b21799809b62b89861916745c0e5219fcd66db64f3219de0011fe4a0edeeee29015502ce38e649f2a4510840888f8e71180edbc6d630f4e7b3907c93548ad943bbb83c6f2f7ef925ea3c793ee4b8f537dbf6ee7e3b387ed43efde4933610cb83b5477a42b4404b35c64c55306074ada34a4000976a09797ddaa7e53558d7a581cdd68d81d1e4c000ecf7ed3ab225648253894ea4922cd53838afffe6fbefb9679ce96e1ad8cddda834b032163be92b1855943690d4502917c2f19de96ef436389829d994f340b193c3040c5e554dc1e65b4574ce51afaf22777d489cb732a97a2c8319c7d5d8c06e70f8dee3eba141e7431b4b1266d2debd79dbdebd39fad9fc00002000494441547aad8817ce7334c6f179bcf8f907652eb77934bb2461747f77a7a1b709606def0cb54009a753eb36dc396c8f9e3c5319c94cbea2c8fb222d81eb50804005be2ca7d66eef480a1d4b09023685e43285cd73aeb7cddae5f9c522ca46390d91bbb85fd8d3ad7c30ca5c274523a55db84716fcdded5d24c942e2305bb2e0f901b5d194f5753e11262aa6264c4c922934e7b8be8984d0b555dd372fd2561d3f160c1493e6f9e3c76d6b3324731490a02bf876a47aa849284022e69dac8e5c33a949307e940951d739d60672727ad65ebf3b558a067e2dba1a8d274412d58a3a8ab8314d37506da5ac0586c506c4d388fe8a800fd508f48e549e99544657f439e9eb2b633db4d655d8dcc31cec67e2ebaac00db310750dfc58a43370ffab2b51a3d8dfde6e6b5b9b6d657353c5d4f41a84c14921962a055dfb75fbfebbefdac9bb77627e7b87c762658f9e3c55e2280c0bd3946b925a2b164d3243b1ac8e067b251e7523afd689d795d7465dd3dee00d4c3518562d9b4a744c001cd0f235540ba63240d6b3d79e41b3b2ac9aaab170ba1bf17c129b73463bb18c749c57f3cf4e7adb9bfedb37ede33a7251a3845d36e7cfd401b3d946689a63f1ff7b37a31c9df06f8444adfa0047b5bd550cf410c384aab236362f05aa592ac16794295e34ea152e56a81d6737e78ba255da8a5f5c5cb65fbeffb1bdfce1c736ba386fd3c9adfc55c34144f8ce2ecedbd5cd952626dd72446a24313c691f3dffa80d77902c41c980b64efd7670f4584c8bd20e9591dcdeb5593690887bc421be22c094998c031d80c16cbebe6a77a459004077773225e55bc0ef9589a9b19b6d0854c970e707a6868a028b13f6a268538f3c24ae33227272d4b33800abac27247196eb819d11b18bb15f8976420406b43b46863c4c299cd891d10e683d7b74dcd6b1135b1350717e0b1be2cfe27e63b3403c0f90211bfc2e1de3f18c393799e0688b5d5edda833cfbb9393305f498d48c5d398b3a11e8a1f92e7b08e44b39a49ccdbea267ebc502305a561d28016d74082afe60db7963d15f15fca7ce433248eaabae0ffe7eb3d9c64bd8e2bcf2cefdadbe71f0c0110200892584ac3d598d888899026f66fdd112991949be190d488462245277a10ee01cfb577e5baaabb367e2733abee6b71f705c167babbeaabefbb37efc993274f423b7883b62a84d1e4dfa042d8e9d25fa4205661cc58dd3dff119712acf4f3d7333b393eb00fde7fdff69e3fd3bd6ef7966c637b5b29e44bafbc6abb3b3bd66bb75555e570d47bc9ceda1156ee9ddc8f652a97012b5155c94d2578d0338ef6b4fcbe125094412fb3ad3228961956028e4c13d30de56610e419a9a52b8674947166ce8586ef9606a972d353bcc58b27af93c8243f445e4c7e80fc9065742c4ba9fc5c06980c46a44469e0973733a376feeccd0fc4bf27e9aed79b61eaefce01be897425715279595d63d4659beb8e9c1a0c2c219adf5ecd3b89969012f2e67d005924ca12e4474d08da990039fcfdd160a1793af8e4533b7f7e60e727cfec82c9cfc727e239fa94ab9796adde6e6b2453ad726dbd56c326d7539dd83e5802ff2d1a42f0576adae6ce8e6d6c6c0b0d91b2299812248b011f5cf7b0ef0ea59743afd4d1e2321e22b140a8ea24bcd2c531bcc8a91634a248345cbc9e0f85a54918174c90945bdf703f414c84673adff80567e6a3da5cec48ea845343f61f0a858aecf681ac62aa48b5e29ac569496ce815358235cf04a29a96259e538e3bf3598b6d7959c18769ad7125e17c009a0030715ff4fe2a1cf8f4ecf168aaca2101323f8357b0af25065595937bc5bc47d20ec4975a032ea2e573e12eca22e9343afa9e4c6508840472d9f9d0130af2e27e1ad5565a919c23e5c338018d2d90f781e2b2d0595ab24a13e942db5addb6e40a8d169c186bc0e724ceaeab767c74601f7df09e7df4e11fd47cbdbdbb6b6b1bbbb6b1b9630f5ff98c6dacafa97f51a3e6aed0def95aaf4993e51ef513d9f1f8face3d75732f274552229d4cbf1248649634df073139ab4c3773af96fbfe26979dd98e52f2184597b124f75e09906e5235e5f5a83527cb937921f962e50597b0ae24d6ca8bcb0bcb9b90812e2167a2b59435943073ced1dc18ec9841cfdb523c356291287085c2375f274799fbe6f6cda70f5f3171169c8f72fe54893c0216afa6d33fc7af4740bbd1bec002251d91ac018b916ac5ce2eceece0d9339be28b35e8dbf9d1733b4203757e610707fbf6e4f9be02d675b5aa168f7bf76e5997c101ed46cc2ef4d0ca46d702aa356de7d66d7158d75411c32cceb547dece91f71eab65ef1364c0049e5194de49e5fa1e2c2fce6d3ce8c7941c1f2891aea0b25316b2f0d61a3169424348064cd5c311832964e75b9bdf7711f6ea2f5ce8ae7478840a9dd7204d544aa0c0b2a80639dfe2dc112a78feaaaa5b070f294f99b21823d4d2748707a5b052d57bf0f42a9e2309d271fe635d10bca998d2582edeed0aaed3d379ee11cdd3f95adc5b11fc1a34e1b217b785a9a9b508c4d489de413933a4a23f44ae22f1793631422c7b01738f703d5e9ff0e93b7c0e94ef15021d138f3a2d7158043ca61e2948ca2fcdece4f8d08e0ef7ec0fbfffad1d1f1fdabdfb0f6c6be78e5dcfaab673fbaee43088909756e1c69a42aa3c7782b1f47c1cae14451442bde52a0fe6041ae5e157eef9dcef3783490293fc7a19b0cabd9e9f3f5158a6865985cc4a22d794c1ab0c9cb9076f160a3233d27527c2caa092705002472d6c7784f453dc1760a9bbca796f7f2c2ae7074d88c7dff9591e78ca1aca087ff3866400e403ea0465ecbbe602d27fe50b37233627208f29d1a14afe1184d4b3857093c51725692f93bb950aa76bdeacfcace5c3936092253063a3501d0471991d1eecdbe9de736b31466b34b4e1c5990dce4fed68ffc09e324de70f1fd8e179dfdefcfc3b1205f67a6d6bb6eaaafa200ee5f328e8405e53156c75eccebdfbb6b9b5235e22bda93215564a18467604707e9eca1284bb14e0a381240bf4034e82a322902df59685ac487d40087a6632a48338bf161fe4ae05033bbd385321419287b10b4c4180040cb464a0caecff8348efb4ba42adc9a750a2e7de9182f34b0103123cda44c04c0ac455175ff6963a927980baf340d3da905be702e5ceb955350afbf34a17097e17da94f7d854ba2a14e7aa780ebc325aaf3694e271d6a8d52ad29e85d60b65ffb5f8220e3ef9624da8442296ad4b0601bfa51411ae8b14bfd9b456cc8ee4fa5c154fb632b5e904de6f316003d12ae4392d43203c5a6e480f7b4b2b12b40a0d4d679a5949dfe7d3a79fda279f3cb2870f5fb6eddd3bd61f5edaeaeaba1019cf90eae49d3bb703196251e43299dcaf79c0f9b358f8eae7ba2e115719b4ca342eff9cd951fefd6660cbe75466460b10e1f1a3042489e412017abaee0a83bcee3c9c33c8669bdc7ccc571988f401385d2320e40f65e4cda0c6efa968ce8055be61c963e54d49d23dbd826ef25565d02a212d1b3b37370b03a5b24e3894d134de06aabae464d7845fb7129e93ef71324b5625cd909ff81c8594aae7ee93d2b778307ce173c3a05c3b77443a0861fde80fbfb7fd8fdeb7de6c66bdb68f653a383ab0e74f9fd99327cfecf1e367f6abdfbf67addeb27de6b3afd983077754aac6858105970e14bcb70ce41a2d090477766f7b05310e887910a63525603e1b549553f5293af1aa411628dee94d9c70ca7ba0e8f596d5f346c0aa36bcfc8d5bea707069fb87c7767a32502331e31218950e593d9016cb3dd7b93e1729ba0db3f452d243d1787da553bed36aa921981e3b9e1bf727477e6981d28c1dee15ed0ee4745595c24e17e9865bb16410d021148dbc3cbf178a289a76df70cb6111cea4a2ee36810403eb9f0c6083c1c86613e71ee524ea86ed12643aa2b91237479554c35521d9995b38ab487ec2ebeb5a415ea46d1a6ee176d3e4a51cbcf40b2eaf2c3bf2595d09590fb71869c495384f796c85b404445585cb6a75acd16a598ff6a0565b82d67aad6967e72776b0bf67fd737a23cfa44fc337de2a2e4005f10989d6ebb6b5b569db3b9b56ab7b86e00730cbf75af727d7f0fc508f8ca3cc9c94ae478bcc4dc090544fb947134525b7944026dfa30437656a571e3e65c0cb6098012e5fbf7c4ffe3c7ffddffce6b752ba2fca8a10a90e28759a07d955be617e48500a2771c961250ae335f38d9c78f71bc8022ce1ffcd9b71f3a6e5d7d39f29039fa06e44659e4ea2a9440f72b20c074bd58762220ae571ae45c5050d5e980a5acb488d4a912c8983c40f7b605f0c75b30969d3ccaee00f26437befc73fb68f7efc233bfaf4235cc4ed2b7ffee710199aa6f3e9e3a7369dd5eca73fff951d9ff7edf6bddbf6fa5b9fb1e9f554c42941122494268704890c585bdbbb9ae69b4336f39e8ad20eed180f1a2b5dac6b4859e0ae86177d7bfaf8b1ac731d314f6557e3010b9b92919d9d9fdae9c5b99d9e9ddbd535fccbcc0e0ecfece4f8cc066336fda58d2697767276eed36502e729c55321a32eee8d26df24cf29c763038d78766579c97a4aef1a22a079e61247aa2711cf7a9e7f4b720d9f0a84795e532a710216eb50083ed06f220455ed20a785307050f02210a80fd9048dd7671758105d2b00510c515fe21402c1a7e8f077aa9c437ca7e8dfd435553403b0ddee38b12f4f78fe0d3b19779fe0ba48c3b6d63774cd6d449e4826665369d9e0cc588f547cef3fb82fceca3d5edd70d1d347e7235bbd9e46ce3358a2122af8162682acb5eb8a9d9e1ddbc9d1910d0717a2327c7d9042cd6c6969551e69eac5ad7bc57df7f6aef5567a3abc5903206dec786661765a0289dca7992a96d9531ece1918fe58902a414782894445f973e57b24c029036489d232a670ef325e64a5325f3703605e6be5d7bffeed2cf3f8846a79f17c785d88ffc30ba8435c4a8c41ba79912fa455fa516f60cd8005fc4f84c543bc697d9b08ae4c431351dc849a4a37853adc5c2ddf5b832bc34745374cccbc0736aa2f73f41427a5f27c5a878278d6a601a1b06c2b58dfd66d36829f319bcca6361b0dec831f7edf1e7def0776f6e4433bbd38b6e6ee6dfb4f7ff1dfece0f4c44ed04859d33e79bcaf727bb3d7b2ce72c7ba4b1d7b78f75e702e13a54234239346acae6f8ab3585bdb946054153626d5a855c683157f97a58cc6db5f2825d48cd7f1a54d86633bd8db13d1ae53b36ada44f8691d9f9ea97ac64984471327fdf169dfdefff0637bf4f1133b383cb6a9614e38543ac61d029b70bf944ac5e82827eb25feb1ea6c26fb18344a4c70a105490e0d9599faf428f9bb6abcaa531f8485d300c18afb49d51414566f7a5b4bae0b9dcc0df76277c2de51165ab536dc4f0b170b1ab9e911bc50a066382d7e5e58bf10b04e8e4e84c2096ef480fa6b5ddbe1f1b15d308483d494e937eaedf4420d3f8fbc43fd9a4c600eee0cb4bbbabc621beb1bb6b5ba66776eddb63bb76fa9797b657559720e3a1cfeeddf7e2ea477ffc1037bf3cdb7c4a19d9d9e4b8bc67aa7d20d0a5f466cdae969a664bbd7551b9126535f9952c293a363ad3ddab6483f7db9d67400d02ab4bab622012ee872e7ee2d5bd958d767e05eb591474c6883f081b119b072df64d0618f659a9d7b21bf37e340c6851244f06cf2e7329b2af7eb1f4348b98f3340e5ef19a4f2efc97195fb3e035c06bfca6f7efbfbf9982fdd9642adbe70cd295c216f8e962af2d39b37256f8e7e9f39f9c7099aa7280f316f52f941f3dfb858f13b31024bfee4a14dd20761a3869fb7df742f7597efebaf859f382a1cbe9fe079a5d42e1f04d725bd4df880b37cbde213139f69d3a857ace6eeb636a6ac7ff4dc9efee847f6fc873fb0f1de27763a38b6a3eb9a7df6cb7f620fdffcac3d393db32787a098ba1d9f5da8347f55b9b256a7693b5bbb722aa54a46f0d1100a9bd9d6d68eeddebe6ba8a5b310a2fec786abc6f93705ace1d0ba6d46409dd9c585b7058d074391afe3fed046830b3ff1979775ff9e3e7b669f3c796cef7ce18b76fffe43e9c87ef0cf3fb6479f3cb1274f9f69a0865268cd36f50d0caf023639bf703909fb5a835cd12d454b0f0584cb41df5af4d131964a3ee37062a8e3a7b61e9ef44266b870f2ec4106343a8b6887f4ae2a60811a0858fc27294270583ae9a9c0d1f08dbca0d3b52afefa32c2a37adcb733a4239813f6e111fb6af4ce49da3e5ede9d6f8f4e4e454a6b2c57f8659da25a077949c0e913a3bd42ecbe672ec7f0748baa218af75ebb2314f9cedb9fb7070fefdbdd3b77b42eb9073ffbd94fecbdf7deb32f7ce10b52efd338ce218073839c33ccc262a6a9c0dbe51eb53ba2564058f41262b14d0704cf8ebe45b78e8603f57bdceb34ed80e24e7f686fbffb45dbbc7bdbaee0cfac6a1daa93086b298b16697506ff5cf3ac63ef978c611eb16f4ae494fc5e19589262c9fd5a06970c3c255f75b3629819dbcdaa605ed74d0129af991cb8d01701eb264157e6aef374248de16e04ac92bccb0f91179c91da118ecf9fcb3ec284ff49d4710d79b1f93a19b8d28d2005a39ce05460f264d04dd069e28334fd971bcaf9df83500d6d91ab20dc3490af2747a4401a36272006a12e91ae8c6e32eb60184315ad31b38be78fede37ffcae9dffe45f6df8ec631b5c5dd8e9f0da669daebdf35ffe9355d6d6edf9f9c84ecec676723e54c06c2fb56c724ddab4a63234a9a8bcb0186f65666b6b1b76f7fe43dbdcde12a2f2d37ea2cd9c0fd42b8123a1520216ed380cbba0e9788ad480cad96018c477cd3e7df2a9ed1feddb4bafbe6a6f7cf673b6b777643ffff92fedf77ff8d00e8e8e843a29b353c51c5e5fdbe9c585522ff812d4f0d89d30a4827b01ef464a77394296d0b0cfbcf450eafabda74fed12b3bc465dbc149b8c3411fb94b412a232094fd54053a589d0a496703b26c1269b91ef4d275638a5941470d30958cd76db1a9d251f3d5fe3fe8ce5504177c1e1de9e26ccd07540c042cd9fc58af1646ac767a7d24541a00f2f2776d6f71ecb59a52e3f2c7470a472a4a7484634799a908dbc0494888e0fd7896e4fbab7abcba9ad2faf68b0e967df78dd5e79f9a16d6d6d68fdfce637bfb65ffdea57f6ee17be28d33e2c70185441303e3e3d755a84c0b7bc62ede5e5407a3ec91b5f2fdc35a832c34bae2e2f8b33a398b1b3b36b9beb6be22d1f7ff4b10eba77bff2a776ef8d576d2a3eb76edd6adb2a97539bd608d41e6ccb009201265151899e12c5e4cf64716db1a73c8329ff5eeed5a4804aee2c8358a67d656cb849fc97e8ad14879708aef26fbffcb56f6989fe1688e5666521dff8a60b43092bf3039701d0830a534f3c0de375d96c7992e6bffdffdd58de93a095682a53354e240f2ad5b9cf770e2270cd554c3fbe221d40be407f19e42a8b230865797573beba9870ceb5c11f6876a23b355056ee559a9a4f376d556c70f0d43efcd6b7edfc673fb6d1f38f6d30ebdb7438b3c175c55a7776eccb7ff117f687a787b677d4b7fec02b7ebd95ae5d734d5510c992bb308c3d0d61716d6e6edb9d7b0fc471f0de20413e3bc121d1a57a19097052728fec94be41fa1407231bd10d301a2b7d27185ff4fbb677b06f9bbb9bf6d63b9fb39ffee497f6cb5ffddef6f78f6d389cc8a369636bdd7676b6e5dbf4f4f8c87ef5dbdfc96c0eee0b0507af2133f9ca4c691bfeeafbcff76d737dd53ef7e6e7ac41b5747f4fa9e81555cffec09697bbb68e97bb744e15b5bb90d632a98680c7bfe1f7dea262897ca3ee431f32680979eb7b5c27453a4965921ebc6677c92af8bb33cc767021be8716a8b3e363bb1c5ed96874295907aa7fb82da419f417c23bb2c0498d87542de54fb56ab566d30e4e4ea43c5fdbd892cdcec1febeb824640eeacae07a2a74394c6d73754d7d7fb45ee1d0b1d25bb6975e7e289ddd3bef7cceeeddbb2ba1eeaf7ef90b3b3e38b4070f1e58bbb3a44380fb4705f6623050ab4d7769d93a2bcb724de5f953590461d19e834dd0c9f191dddedd15aa459a410abadc6bdbe5e0c22e8e4f44817cf68b9fb77b6fbc6e53a80cab5a7356b71a2961cbbb0c121094d90f7f4eb2bb444a65b67333f329b9adf2676eeaaf1244e45ecda094e025035682a212f1cd79aa088a19005f08a43ffed9bf097064a50028efad02882d7d0e1ebf2425d446f720c04e56caa86e9418f11ddfab08abff79346663e202c06bc287689c55a880931b116f91debd007e09cc08262e5aa42245b99a88e3082b4ab88510edc5aa8423ac9ba7862a8a715dd2eb848327276322adecd66f6a6398d2411881f68cf97555b366d5cef73eb58fffe9bb76f2f31fdbe5b38f6d361b59ff7c6ca36ac34eab35fbf29fffdf565b5db5c38b813ddfdbf7010934e2f6e8338340ed29e0f4fb8cfa728e03390315422a4f2d88e548c514686300275ca04f8af61ecb93c3031bf5fb9a007339184ae9ce135333320197855caf2a70fde45f7f66a72767b6dc5dd1c6ae579b769fdeb4a59e14f7fdab99fdd33fffd0fa3469e3c1de26f522555ef4adc1930d4f4feda5fb0fece1fdfb6afa2625a3c91a94070743b0586a37e54d8fd0d1476155b5d173416b0c980493ee9dd5edb6adb7d493f50eeb8351605a5e72f361c232ee151db5bc308e0b721cbb9ed3d313f56a82f0fa1723a1cf8bb333f55fd28d30d67dabd8f9706c8f9f3dd3f3ee7597151c377777c51ffdfec3f745d8af6f6e4972b0b77f2031a8664822fc65980aa9fb7064db6bebf6faab2fdbd1f3e7b207b2cba952c7dddd5da1ad2fffe9ff610f1f3cd0f379efbddfdb6c7a6d4b2b3d6bd59bb6babea1aa2bad434bab6b32e46bf27948e32aa6fb077f457bcefefe33db7bbe675b1b1bc6f8327464b2e0a9556c323cb7f1f05281f4ad77bf646b776e5915ae8bf20276d97427444a98f73b014789886e7eade4b03278642a99dd1f6580f2bdeb594cf9fd99428a0ac843a77032cef7c9ef2b2b8cf97e198f12f0287811737efcf35faa4a981f28e11ce11bd50f270327a2fb9afb98277924c5afb4efd50547f04808e7f9aa8bc466156f1ec6e08d0a583640fb8d08bd4a4809149d5542ae49b52b61204844291cbe661e3cb310c0fba63790227854fce4c62e8983dbf82a9a7b8cd5ffa1411a4520c8ea9b7f7e67eff221f8b0d26bab5dd13ea1686efdc327f6c1f7bf6367bff8a98d1f7f60d52b048b66834ad34e6b2d7bf9cb5fd1c9f75c27e6a99df7878615537fc48c3ce60d36acdf3f9f230c7895cdcd1ddbdeded5c66d3619f44925d4833ef759a43bcdcdd7388f5eaa87904d83fd31aaf6299b6a30545ac2c6e07eb1a8cf8617f6cb5fff5a85874e037f2ef45bee3e41b95f33fa481d3a3d7bf4f4897df2f8b1d53a4df96429784b82d01277768d154abd6eaf3c78c9d3434dc971233a5c32e594798d6f3b1c55db6eddda512ac98d4bb70c69e4ae66229451bc73addc0f781e7ca2cac5ca7aa9d409606eb7c37a6cd14c3c9b29605d5c9cd9d9e9b1c4ba9a6484afd778e4aa7fa6015d5ddbfee189fdeefdf7ed6a8671e2b2adafacaaea4b13f2f2caaa3ddddbb30f3f79a471f0ddd56579da8384e08d50b56365439a8dbbc35bafbf61b7b637a59502d5ed3d7de2e47cb56ebb776edb4b2fbf6c5ff9ca57343b90435ace0e972321cc8dad6d1d20a4a37c9e158291aa9381b0c6133b3cdc53570756440cd9a523a2dbec4a4726dd174cc894762df480357be7cb7fa28035a34841964065fcda9bb9e766efd17398077aee5df6690620329fcc72ca0a617e4f297dc81891af97a9f74d127f0e64225edc4c2db98efc9e32a0de24f139d0e701eb473ffba54457f98379112ab2b14952a3111f5aad1cc505b091ca0f90102f0318888db60f7a2344bc521969b98a99fe2995beab3e04d45b6db889289bfd84a54f4cba1af89c287f7a038277eef3bbec7f6f28e4cb94364ba53ebdb8a82462391c1a235e27d35db5f9c410515e972a51b5c642686883d73a0d9b9e1dda1fbeff1ddbfbd10f6cfaf8036bcfb06499d885d5ed6a7dd73ef3a77f661b0f5fb20b520059f81ed9f575c506a3a954cf6c602a4b200d163c55a9f5b54d353eab9f8e0a962a59c143c8a9809980a468ee81055fd53f3f51933396b90c78b8d6900a6f9fa14c4f2fe3197e58d3a9bdf3f92f08fd3cfbe4893d7ffadc50cb13c478161ad06a5559cd8ca6631b4dc636c262051404638897194dcbf4c8d1cf28bd03ad4a5108d1949b2b3b3f3f530700d7c2e0d95bb76fd92bafbca480c42f27507d73b0c009586c2cf83c4af6f240d79a8bb618a1fb8a35db5da11dee8b744931448380406a78717a26f21c240acac4db8b6bc032f9fd0f3fa25145eafd66bd696bbdae35d4cb47ff60db261adf7665fdf148819bc2cd009f75716561c93c1a8b4f7af5e143752b0ccffb767939944442f219dc1698de3c1ed917bff825fbdcdb6f066747501f4a0e03478603a9aeb352b51e867f0ac2eeb84abbd3fefe737153a483b45711e45bb5962d757c4ee26c32b22efd98f2636bdabbffe79f5967635ddd14fca229baa1f67a1f4397282a83d04ddea8444765012b0feb32a824124a957aa66c19eccae0334734413795682edf937f4b12fedfbd5f64702f043962d2bffcd453c28ca419ddd4401c13797910e507cd3c947146d25e173967be71bece22879eaa1247c04231eccdc0e85fdacab5f51a81226491abc58d8d0bfc15a3b14058e936b9107596c2b7f2642038a6fd465e7b7913e76423a47a68cda4c87623e017c878c22324b1a8b85945c3020ce2f3a7ff629ffee0db76fdc98756ed230b98d9a4bb6cd7eb77ece53ffd33abaeae1baf38be1cdaf9b14b17207769d190827cea691ba9697238ddee92e612b2a959706c68b813c167796e21e89cbad81117cdf35311cfb25d198ea5c5e1f33007912085ae8a4db1b2be6e6b2babe267aec753eb9f9dab0f929f63100569d7d91928f15ac24682c7f3fd3db91b745aa8beb1c3a92a6d81ed54a5b2db5180984ec7deea421551e86ee27e4e387baebaa892a09f8de7e88afc340e457c15bd51479549de370f18898cd143b119e1b49a6d6b77e1833cf8a1ea87a426883b51aed28b1ac209a4e8d49849f8e1871f0bc5f47a4bb268c6cf1d2d59a3de346c74b8ffa0b66eaf2b829cf79bd22fca84201d28572a348847e32025d5a461bc56b1f60ad631b8b35edb03066c5c5fdb0f7ef003fbf29ffe89bdf21281baa529429251a83fb42e225f6d3904674df6667f790518c29ddf0f48f54703edaf76a36dbd5647fba17a35b2865dc9e976f7ee5dfb0ffff9bf5805553ee9197b914359e3937c0f25c75b0689dcafdcc3926b2a1156997565a52f53387e26dbbcca02dd3ceb2ad2bf12cc64d0fa6301ab447dfabe682fba19c82afffc935fcc72c396c4b7d2bfa83038ca08ab61766d5129d08491a2297281d0bc252083009b8cca1b7a400217561ce9879d3287f28641968a6cc7ce2553c2d8b80975b3af6e7e5354fcf360a37431846a346b3c00002000494441549679eda5282da37bfa51e57bfb91e4b9f90271f9ed9406ebfacadabdb65510617ef49ebdf79d7fb0c9fbbfb1eaf19e4d6a5736e9aedaf2cb6fdacb7ffa9f6d50ab8b43b99a8cecfc84e9357e4f2f5954a158666d718f643fd2a6abbf23c29b94581aa886f3577a1ed81253ee96adb26b9426c381885af8155244501001050e88723a2a6b4e767cc1e18330fa63c39d1e9dd804357b5c1369e5e3a7cf5561137a958f95eb3810dd727e73c0c0a1cdc7b2379a32d49323286d3f2d1f6b45d58f47905a30384cff7c2f8e9a97e11f7211dd0b577e53ad742f2c4fe10912f2ed428bd56a5bafb7625599039ad022fc197c15a80abb68ee0deeacac371c57715f3d3a398b3ec5a68255e56aa2eba63549076a6af6980aad866a34ff205be7cf98144d006e375ab6b1b61e076e43076db50b215f51ba4765f5f537deb0dffdee77f6d1471f69821268994a210713af452f21c1937b58a35732ac93b1bc41f6c0400daab2cc5604692169b91a8dadaba1ad3d9b8dfbd63f3950807af5cdb7eced2fbd6b33642f1aca5ab70a868af0cc555f1fecedb2da572296bcc7f3bdfd8244c8e541b9b7fe18395e06a01289dd445789c4f2b51620c6a9a89bef9345b49b68907684ca0f7efc33e9b0ca28ea5c155b79a169d2948e1b04b707270f669992255c2ca11e379ec199d8e4e2be49395b8da7a1cb424497f96fde18780d297cc3e2041b11e036291dcf2353be0c96e58d9df35b81feb8967c2865c4d6f593ee45bb4b3e4cb97a46b3b14e2063f6dec4c7b16b5844c7aa5797363ddeb35f7debef6cf4bb5fd8e8e3f76dd6a95a7df396edbef5aeddfefc9fd8f16862fdf1c09a35539f212d3372f7241d6e77443093a6e2b5cee7475bc5025f61fc57a4e28842a545bbf4d4187d0e9b8d6b55e9777aa561aea413a4b1f2458f962404aefaec754af69cf2703cfa7052d9633a4800628193569ef5077676469aeabd7ab85f8a1b44d50d0ad150cfb1d22415552268f2bdd42240103c20c8e195a5156f7752baefc43d62d1dc3cfcae169396bf174319f87950163f8f7e8a83aac528ad76c3a7044938ba24c7034d0e329395f0e9c9b1382b3a66601608dc47fbfb2a04e0cc992572de47ed44a8e1cf2f8478d5d9806c02ed17de5db2ca998a1fe23dd427a93502d7b7a400224986746a33abb4f8b9a66dedecea6080834b7a0154caf394b77dfc2774c89e21ada510d1eb698de3eea0807576a6d7655c19d206b47ad7346fb37f2a356b372a1a1f37bebeb62fbcfb65bbf3ca2b56c52e287a5372932772ca60510697445d19584ac091c12339ddf9c11e9d2b3cb70433fcce5ee03df2bfdc67d99b9cd753665ebc47820dad9d621c59ee4174922edef69c674e597def5f7ee2b2a460fcf30534898f16966ccf502b848f3557e00af4e517e89b3e3a6015ecd4e71553795910a8a22183b1196970aad6b0a285cb62ea4857a66a1ce33e5b0d55b4a30a8293363596213a315c9a900131237b19b0f226cf85af89109dc0f2a6e9389134813810e29c07d34275a4c67fdec07b6d5794b681c38da63e4f65d4b7473ffda13dfff1ffb6e107bfb359bd62d5cd5bf6f67ffaafd6bbfb8a1d8f2f55a29e5e0eccae260a58f017dd6594e62dab4b3038936688f740a744d0220d425ae0ce75d1102aebe24b051895ebb937b28fa1817ae01635a14ae729cbf39dea5e785b71df20f6a9d462de07ba3a3b3e998fb067a39e9d83549838e36d2cee8ee1e57c7450fc0cf7036e2bed7ee6f75882cc687142a6d05e9278946b207584c3f2761d4fe74420a38baa719d34c4773d088445712ae4d1252860c09fb53a128ed224ae49dc54494f8e45be83aae43041da3c1a4adfc6c467fe9d0095de682a005d31169e0e020eb2bab82eda6d10a6cec965b2d0105e5229a6258840cd7d40a6410045e03b918abd23870dd249fa0933cbc88abb1a9659331a1b460702ad33e1ff2ec70a36fdcc4e8f4f9586833249e7f7f69e6b60c76c72a5e94b330e36e88966cd7a1bebf6b92f7ec9daf060a4cdbee514ec24788d8afb9ce2b99105657a57a2a10c2a194092269aefa71c2b56641f19c03286dc4ced3250f27b098a52185d06cdf25ab24759f6dc5930e3d0facef7fe390256a63dde3da68829aa921a907b41f14124f094468807ef5ed2ecab326a972966222e0203e90705bb2e0da5114428dfb318e06c387920e8335029505c3b92409dad0a5ff005a9c2e5aa057d23182d72efb08c8d0f9b0fc37ff7eb55c9350218a9a4c843595f2cc4766a1b42b807daab7895b436a32ac9f8aa4b3b7ff2817df2fd6fd9d96f7f61c71717f6f0ed77eded3ffbbfec6456b3b311bcdbd05a68af74ba8fa5b666c61c15293e3736bafd3ea42cd63798c535c435a1ce26d8700e680845783fd13100c2a2ed84dfe156c46bcdc7bc6708f1fe4752436d7e0644a8c4194ea54c77661a0c3d884c7b463672c944e4bef8aa3c0535bd2536368152f633130a09201497996851cacdd7dd0c40a2cd2a6921d7e04e9ecbcb3d79a0e7641cbe8ffb9f29a1fa1d499364a39cae037cf81862cb6ba2c32260d1c85d737f2d4dafc6fb6be2435f418e5c3f010bb402798dfa7d6e27cc1ae6209a7acb1169aee436d2dc558518f81cd9c709028767e5b9c33771182f69662496312b0a5ced6e4f1c589af6f9525cf0a06aa92138c35511a8e0b2b0048e75a81ec65acd2e4e2fe44f0f8fc75ddddbdbb375745a5733eb9f1c2b6871ad0ccd78f38befd89d575e16da4c765d835e299ed3039d76d585195f793097e959c95795df9328283de2ca433c8142f96ff99af9b532fd4cae2b035812f5370356222939d7c6a0dc6cb19383f73f7cfb1fe708ab7cc3b4949d43b6d02e89cfd290cd6b95906900cde89a41212369963b931faa5618495451c95bbd719a12dcf5fcbeda90762415b1e97945599ad3106e01ef257ea1cd42395ce6b854db5233b688d4be996ee6ccf9f50cb2da38b1811c122fd095c352b763a1d74eaf37bab46a0d6d4cc566a363fbcdb7bf61c73fff57db3b3eb1fff05fff9bedbcf2867d7a7c263dd368746eb5d944842fc42cd521a02433e6e032e0b3f0c39236a7dbb315faf2685b212d94c6cdb92b715f1a56e181cac96efca92e553e67f3661aebe9b507270576a85b3ccea74cc5711e0dde874387d762b28e0765474ea44d541005eba39b9faf25eca7e49f08bb3cc83439074709e9eddc91419441ddc9f79595251fd810955a7d6f1dbe0d1578cf6d5c7a3d77749541df95d24e59281358e07c085a4dd0106e1cee9a8af7174dd01c08c3018eaf153bd83f505025702960e1ba7ac91a72fe907bcab57ba5920a286927281104e45550022dfb80e201288f8049b0eb2ead480e0112c51e262b7d3a78e3f3cbe1820338a8051faa81f4c76715624b43dae3c1de9bee871743dbdbdf5730e6f3525060424eafd9b0bd274fac12a3e04843df7cf78bd6a473a0d5f1c35fc423590031f4c54e909b295f52249955dde4b532ad4b1eb7dcdf259795a8298350a6a199a9dc4cf5721fe6cfddac4a9681cedd38a242ae4e96901afdedfffcf67c2ea18f5372289cfa1f05acf0f599072baa5dd23bb96b657ea09b1583ace0b1d8e5e05a05b1cdac8bc627830422c0502efb082bf71957e5d0203c7da493f2e620e86ab5960266f981d30a976bc9eb987352457f617973f3ba7320c6426be2af51e6d99a0253f17155f4eb55ab4d1b5f8dad579bd8939ffed03efee77fb259ad61ef7ce53f5aa5ddb347cff7c4490cfa2756a72f8d3c9de1a7b5a6f5d6d63c60355b924250587082b56e6b2b2b0a5c6cde4c09734230c18381126c4e369b84ae575e9c984c182f1f267f0ab240e9ace630f4826249565f992908c2a2f5e7d2875568a8a74f6d61d3ab2f713c9e2313fecc67f014c02d6792b0972120f73d382cb5fb80963804a808b79a4257a02c55ddae20f339f8ea4a6f48055903e8be40dca4b769cd9c018bd726f5a9b76916c6a594b547d0be74b34278522a879a747dad60c567393e3c564554c123fa52258f41561185a444107067007d3f952ad29e69c06bb7a56781e401627d458ddd5e20819312070b42231f51e00bce341ac63d887b33b76438d0012d178b7280f0f9b97ffdb3bec696b1b7783d0a0ad8f6741a757bf6f1c72a96747acbf6f29b6fd8d6dddbd6525b4f539577a2bc643e15373b64ef94b4c9cde090812741462225be2f0107f7310ff32c40e5cff1b5b2ef2f414049a097ff96fb2e8352f2c6194c137c4430d1c14256a09edf929ffbfadffffd4c7ee64a9d42a025333c3f2d176fe4310e082d125ddde17ef23bf48750f5c9171908f28259a0331c0eaeafd4fcca43c8a1947e63f9596f7fc8864d6e1c0b4495304687334a5d0f0458edf6b349c67162e7a9e001d7d3051669dea00c6437c9f9446d199cd2583021aba73804ce2b6b6a3c949fb8c378fdd6f5c446cf1edbcffef1db32e6bbf7e0be9d9f9eaab5429a20d00b15d24edb0683a1d2c19d975eb2d5ad5d63c6b03b0c30ba6aa420ce58a856ab3b1fcca05389210320cb31d5aabe028bee4ba4648982b32ac467cd05cae7e1a17bf182fbefa429684d44fdec4a04b44e53500afe508381a33708f6d0d9cda13f5ce66418b947885ae7a3c519cae0242c6433f71a3f295013698eebbdbcc2999cd2f22aa80bb7025a719ad28ee9d90605c146244523089046e176806b035d037c8dfb22eba1e1c06ae8a92663f9e073fd787cc11b1e1d3b29ef9bcd477f95ad5e7e30381acde7cd2193a922d54f55f7103cf79684b496977dbc17874ebb8dd017df2cf70293323fdd264074b48585c717140a92060feee15a1ae89e867806dfaad9bbd1d4b326d883ba3ffde0431b5df46debce1d7bf9edb76d6d637d1e4c726ddf0c42193c4ae23d4144499267353f69807c9d0c78f93a25a19f812dd15449c6df4456f97a1eb0dd0433bf273b6614358ad8a1516cb42b85d4485f06a17eed1bdfa4a56c6e835b09065f912f4dede7d27b475fb281a8fa34144af50423f95d5369919d88dbca2a6dd44578f3335ede9a9882b77595914add18b90e010b2fe1a7587e4027df17ce92b29ed5503c2f396b847c044c9dd87162123c396dd4d651aaf28b16828ce409cbb373bdcce17311d3bb462a00ec66302a1e497d868e22476080c1e0c27efdc31fd8f6ad2d6bb7eaf6c9471fd9e9e1915d418ed3987c79a95395ebaeb5dab6f9e0816ddf7d6093595586730a0ea381f82b52648d37eff4e623a0e80c62111340b02866a0841702a64ae5126a97903c178416e335e679fefda4f3991226db75ce741d716cc3a8447a1552eaf9f04ecf43484e9d91d295a7693eb30cf43889aaf28995109a27062f84058ace7f90ea78ac3624f8a076ab2bdd93069dc6b3d3e122df79e09bcff5eb211e6db422b5f6fb02b12ea9c7250263d270af26532400699d1e1f0b6d11a4e17698b89c937fcacd4e60ccf582f0943fc35f61b808e205f5d31e24c27d754d2e0bac0d487314f404a2ec9290277d389f48642b08eafd7d729b5016e3ba2c0e693e2bbab1e3c34349329273e33556699b3a39535af8dae73f6f0f3ffbd9f96b97d56ffe9ced650934f27924224a34995fcf033cd77dd2370adc37f49509404a729ee75ea67a65b02b11d61c99c933f345507333d0eaf5d21e7c4ed184fce1bf7fed6b330871e5daecf0701b552c4c457b08f2a46d8a51e59c80f04aa003af4af9f72b6d9495af33b1aa880057af4109948f4158f4123afc578583e92531d5984522519a1ea0fb3e2970493489ab01e51b1a9721f03d607965d1e5075c03d34f685d2087ccebf18a8f075c7f10713bc36b897f4b1b8b3c354484abcae6a73f7200f940b1302037cd6c05eff1cb4b7bf4dbdfd84aa769c7c7fbb6ffe4a95d9c1c2ab8a8b33fd266b88ea58d755bbdf7c076ef3db4b3fe581b8faa1da8899450cae64ed7ba9dae8f7ea24a57f049a46adc73c911a8d80d403b8baa692ea0322d26ad96fd6f8e809a7a6ac9f380d741cf248e0a41e438864b505449dd98a64323f8f58e0238134729a33902d7691c5ee9aafc0a7178254c2a79b9bafad4228a0bf9ecd8d8c801d8f8f0489e3a81f6481b196c189559782c6600d287da5d726905df21ca024f7ba66333f8d511161b5ec59a11763ce1732febe84bad0d9f6abdb0ef4dc4e12739316451e5961574a0448a256c02d247020fc5110272abe9643de92a6b051eca830538da6da9795da1b56a5daeb59a9823f2dd912a4ddc87fbfb8eece41586987464ab3d5c2eea9a57f8cebbefdae6ddbb2fb826a45424d770c9ed264a4a64c51a2f5d5172adf3b9b5d6e71d2d8b405406af123d65a02ad3ba0c3e65b0ca3f0bf90b5d2db49bc959e75ecb008b283dd7b55f93dfa3ca5f7fe3eb335f20de62e1a7a693bdde8b5754e14297a5481ea24210444ea0f566e3989f17b04f7e4204344d4c713d0edf23d7ca2e3cc0921e1c0f1e482d9219be27727ecda0231dd4490f92abab0a82560634e7efe90157814bde413e8e2b4bbd59115455302c633c60f9c41da51c737e2cec73839cd60dd458f89a2a6a3ab995dbbb42b9d3a859637269e77bcfad3d9bdaa30ffe6007cf1edbf8ec821c4e3d6804ac4b025da36eb71e3cb4bb6fbd6d57f89257e9d7ebc8d84dde5bf22b479b836b27bc8ea30d36a30e8848d1d26f8a6bce31f7b9581365650a272446493ce3338710043e153fa6466334488a78e97c15afe79c98ebb3f2175ff32c0ce7047f4ed820bb2ece5333784f82151ba20d318e11601c646c54d6963a1b72c20bf7154b9a70e864f312ccb8662f3038e9ae608288b4d3513b8b28012406e28dbc23c3efc9c88b123889ea335e2a98b1e909ecb88c8efa031f2e1bee1fac89d4004af210d7cbf3c839840a34c8303a6d718f52ff23c655a0f582860e5cc8f3166aff861792eabe3eab332f5211b4281648834540539b51d83d1bc3822fecd3478f7468b85f585be43feeaee8d4408eafbdf9961c1e32d86620e2ef3cb39216c8c33ad17119d04a6454662165c02ad1d71c6117be59254a2bdfb70c50fc39519b826304ac32a065d0526b5e7c41cc152d60a80bd4abe99eef95af7ff3eb33e0b4a77611551369851383c8379a50737a6e7876bba89093dead83e53f654ed4f15abea0dd1c8fef630182b0d404dd6c681a30ad286a6c6d305ec9c727795ecb43861c75e4835303c3124037b480e86b71f354fe0c0b5f558238750351645aeace00c0f4d08c450b0e9b24a66dc45c3dbfc19a3f1868caef2105019006fc9813e87ce6161e5f7cead1c02ae727f6e9fbefd9d38f3f9205c8158dcad389d2315c0068c979f0daeb76e7cd376d30bdb6eef23a83f244141328f090e2f3d133c722d5e00bd18915a11d3625818b0a9e94da78b39f9d38491b62cf440a19b0b4693d2977142d6fb208ec31f599fb087f85699dd4efa1b399a3b5a242ec699a5f9736441d970b8683a00f4253d754006153b379a5c943f4087f3561fc95a3481ffcc1236f4873c608327e4e3abb08a84af328f80411dcec767d623215620d2df5efd586107f3554e0d75a8e8005c5810c837b37ec0f2581c08247fd8220aef01b0325e5c19ba81ac4a82da4ea212d54537158d829737042bc7bef23dc5b4b832f586734710bf96b706b53cf511ca27a46291e30e60b22de8d0a5dae6336ec9fdad3674fedf8f848e89a0a210e179a8b08c9bfd4b387afbca2aa24cf667ea085975c068d32407886e2443af75e05b04200ee944dacf072a84b88394bc49401ac14879781ac7cdffcde7c3e89cc40a7644c37af91ef777ac7afe732d64222c04caf2b5ffdda57679eb239f4f6d4ca97b84672c7899c37285fb816952f4e338e2c47655e3950454fdc43c80ab861d2544cb4b0904264f447bf42991a28cd894543a7deab5a975095b410d701df6c9ce6a8aa19c6e0be5a122bc643512534822e447fde80fc371f6bb580a31ec0dc154256bd5297537563d69d7b70f9a82d2747fd737a75743673a78316bc068ddd0482a3037bf4db5fdbf3c79fd8f8fcd4ae867df576614637ad55acd1e9d9dd575fb5db9ffdac9df647b6b6bd6b57b39abb7a4ec6720380e720886bf2714067b68d4e19d230aa7b6c38214844a734437b4a38470871dacef9273969f8d41c5e53159f1cfb3ebd9c4b1ae08b54ec0847512db2e09b72e1f9c259dcc7a408f95d089682953465dee00eb27265375ee97e4aeafbb4ca7072ad596f9ee279a107c9017205a5bd117cdc71b46955cdf55bb666689574ca079abf9e22a89d08ed710daa726a6048a4bae2b0aed507989f9167cc2f4fc3164523a585cc5fd41a40d200c1ced73d781190c5d982a61a2d550a55a492acc0a911896035a90904ef23eea5516b7582a3a9e93de4945131bb383bb1d38b130d51e519dfdede35fa8d3637b76c092facad0db995929138ea58c86f725fcef767a47799b6258ae2eb659a98e963069012f99448a9445b65302a115406afdc77996296a963ce10cd343315f179f8e46b38667fb1c719eeb1f2d5bffa9a2747e20a9c64f540c36ef114c5038d2f487ea9c1750a177025611f290bdf271b979820ecbaa0a98e0e7d5d2fe9a5761f61e50806a8cb4357593be6d0b11808129c5817438cd826e2c384dcb4225cc3251577fce2e55de01864a1fce69de7e1da0842ce4e7824e7da326069e8000b4b22cbf83a22d750658390385101f56e85e3545fadd25005a8d9acda6ab76bfdc71fd9e3dfffce8e9f3db3cbf333bb82c3c21a9a85dded58bdbb641b776edbf6cb2fd9c5686aeb3bb7d5644b599e71f40473ae090409c2cab14d98cb65c092068bb23fff29b040303b6f98c186cf9cc24edd0f68bf709f840b2953256df64029b3b85fb9c1739c97d64728feb927e2075589f4d31a3ec751f5622ab7261385205355311d08791879c93dabd010d9e5a92f84371a7a991e740aef42c0427cd96a5b6769d5405b6e75842a9f830c14e5ca7c05433d63b76acec358e9b30a157e18f19fd2a8683d72ad54045c82979306ba7fd28fc50830be4722d7b0baf14defc829fb2c53a9adcf59f1cc81fc43a3eb232594de8b03205adc0ef79fdb59ff4c2eae5820bf7ce79eda7270a8ed6cacd9ad971fdaeac6a6a652277d53060ca7735eecd2d0e111e4ff82f259980764f0ca407133e864ea99cf27511c7f4ffa21af21bf270356fe3ddf57714534cea27f300366a6ab1988c54817a43f6b4eeff7cdbff9db19d057171a2fe4080982dba19b5f989f428e7e6af387cdcd900326a714c6fda4031a9585650741a2326fca15ba4267a585ee553e4e274e631dcdda18ae15e23f0216299e20a814c27e024a15af493f4d2dda34156453728d0a3a31565dc950315fd1916010aa5145cc079dc12e1f623665ab670828ab115f6ec95299d5ac4eb5698c8814fbe025bb7cf2a97df29bdf28605d8f2eac4a1a37bb16f75241f0b8b2626bb76ecb0ee4aac27cc22d1b82e6421345c050cad4ea2860d147c77d90323b8316faabf1c4a6e38955e067a6a472bec9b2678e679023c4e08c88f1a46e1a4fa548e3c19c369c442382de1327dc73c111b04a484f4a07b7321f6ea0de50178a268acd0527b7cb18eb8e944348b6e2a858f79f7619da8534b61da4eb2d3b4e3bf0f93810e1d168410205f9b8fa4677c9da8835a58af7341fba008e54e82ae88c4c65f43aa0fd481121e6491393ef9907ac98c2936b40e43f6e129a5ec45aab0929ebd0aec0c5fa587bb82bd6095982d668140ed4b5a18c65aa116ba022096b097a640f28e7914110e8a35c7b7274a080a5bec841df96ea4d9bf4873eece2ce2dbbfbdaabd6595ad17ccc32c09774803291f895d44c1e3889a2127824f2c9f59fbfe7f767f0ca433f33999ba8ec66da56a67bf9e77c1e620862e276aead5c33bc5fca18c8a2123c004e72cf56bef3bfff69361f855e5db4dfb05858d4f9a2f39eb180d8992e68c2c8dcfccb1f28951a37eff74087ae879ec44aa0ab6a857e3c1febcd2fe6b1f1c0899818fd11a888a8e309937d7dda8ed785dde55464a87cbe1996ea0f28e1bc485836b84e780fa0e4cc7026514388e0eb7a24b78c59e4f1bc6eca25e6ba9c8aebc4186d37abfa8c3d5a3b68d1a13b1eb4b9bcd2b1d6f9a97df4cb5fd9fea79fd8f5a02f4e4a65084ed5ee9275b7b66c7df796f536d7addeec5a6779cd4e2f06de5a232471a9fb477ad1a69da3d908ed19a78d6f1c059bf1a54dc753492cfacc25144199e464758e1e847a154c1c51264a126ad1d0034757591df580e5c36a4129b91015e3b05d89828ac8779ddc9ef695f72f17fb25690e4347716990658c57d0d8e4043ede816a63bd11680b941df9a552d9d150a893caac863068924ec39a3dbcd057994a2191a60fccf5c0c0faf245efca7f4e2ade4b8521158f20e4a9aafa67e71ef075dd035017fd8545ba9a5e647c4655b9c306498149ba438a382e53e0e055e148d982b7273999ec02c8942ff8987b0a4715fd0c012ce543278787d61f0d6c343cb7ebcbb1b598a23d1aab80b1fbea2b76ffadd7a5e3a3ea944123d14db9e94bf4a56719a96306b30cca37d3c0328065d02b5159a2ad725de4cff0fb7c0f86ae2daf2dd78402222e2437382cc96d8263cb80952921cf4728341aed2bfff8fd1f3a0125ad9ef344e268a49c75ed4e0a4a9502520a979ec7ab3372470e04c369440dd015f3f46cd1fb444ac96949ef218bcafddd395d8554a2c157550041661f2e00b10d59ca422b4f7d3f35bc6a9027cba225274e1ecd09af6951e8a345253191889f9871a2cf477e05ba0b94e9e55f17026a761d9b433e46a158c6f580f96ffc36bbb25eb763bdf1d83ef9fd6fecf8e9131b1c1fdad560e09e3420839555eb6def58677dc356777784a2eacd8eec44509b6b61a9cc5e13870592c1463a51aa9a7d55713299f4813c553504f341c6073acdb490df4b5b5b2dce9031f03c52d7912993bc39b4d163d3eb20e2d9f94461de6baeb50b1754360ed70919cd1ac8b61fbd17c1051b6c90a5505ea22bafeaaa1526ec8fddd5d479496ea8109646cfd38244a1c1a7d6e04a00e9de5b5db34a1d5d9b6f760fd6f49de2a2eaeb4f95d558cb0c70c8cd83e91ed983772eb9e921f742f75396338b0e078e9bd4e769aa92e432d7424bf3ef530b0e6b91ca209c9623a9399294eb00df5f17422388f3677ddeb09c91acc1cc0ef69eebb3cb6efae2d41a642ec3b12cacd7efddb597def9bc3519c211b6493791507ec67cf609361251e9e02994ec3753c4926b2a834c22e8f2fd32d89581b20c5065704bc49e994f56e8bd056ed13a97b486fe3d52ce04445ef49a58e57b3ffec9cc4b86e899a28c1d27391fce8345a412e1ca29e1a8aa430c6ef44199397959915f6918f2044758084b095815b54378591d7b5d16289b900dab535528c0115106172e9e92bba6238b2b73f2381789a77b7ee280ad9de8f3aa0c0bd89ba417caef749bc8d300a2d6a1affedf07a5c6a67512de8754b0e1f8bb2be1b95fd1884dbf9b0656b46cad5ab34fdf7bcf755a9acf00002000494441540e9f3cb2e1d1be5d9e9f5a85afb311f110bf77df1aababb67eefbe4e72ee37e8530b65ee9f5f15094d854de9573190561d0952a44fe61e590872dd55210a1cd7d97de069af6f6697a7a021e399819c794a6cec0c96f49f81dc321da6849e9c4ebacaead9cad0ac22e1ef78e8c67d04da24b1fd73a14e77d5ba1a8a31dd437314ed584900fbc6ea84811de93c2d455712c65e5f5d3278501c1dc853e3c0d038c9b16159bfc369e1ea219f290a0dd7f8d4bb3056f734d68cd06ba4cce3318af7f0c0229844df283788c66fa404f04fa499491a975401ee01695ee7fca0bb2fa8f249f026c083bed05b050723ca43ae276410cc6174b2ded3434f9d095afdb35379d46bc6e3c5990d0ef6ac36bdb6f5ad0d1d76af7ce98b4a87a56f0c1453068ce49732fdca6799dfeb5cae0f35f9ffaa2866fa979c52f2a389c26fa68d65bae8e8d6638517b35c2b9701cb11564c7a0908870a20b9b005e7e5e9f7828e226bf21fa87cff4704ac14b92d7c6d724c3aa7b1735ad9b643540c9f765591fc57f94158202a917392fb4e51c0a20ae6c32daae2b914bca29f8a1ba9168bf130fad5dcb82f6f5c9e0ef97a4a0f6393b329d80c6e45e1cdb29a351730d51f98938f7c56275b3dfd62137b6b912ffaf2c1641020b594d2999c50c1cd3fb59f089e46e393747b79dd0e1f3fb6e71fbd6ffda3e736383ab4e1c9a94de1fdba1ddb79f8922d6dedd8dabd07e207792f1aa49526696cfaa5467dc97a25a41e6c02ae976b0571a9ed240491da10d75e01f367e4daa85c24f3934da4a03f8f39bfa0ca2afa2cef07d5e2c0f32b36592e6c3e1be24b5a6ef435b90154a48f52a5511210bf87fc47258c6b5959dd905d0b71944a7049ac6bb3c421833c44e835f8308223c35149dd48f14059a4b01c54bc46add1b65ab3632dc6b6375af265cf5631f83c54f8aa3c85a58c3650a4bd1c7c3a1c95f63a39cf679e57b6635df37c41578b2293f3ab7ebfdd1a87fbe329e14214cbda125725d2300e5167dfdc7943e3eaeb0afa2a34e1daa08ca1224e4ba4fbd9992db79b36383eb6e1e1a175aa155bdddcb0953b77ede1e73fa74a3315f492772a91d5bce814d5d80c5ef9dc137d6590289150f29019e0ca00c87bdc24de4b84e62086cabe072c2faa2cc68c25f22f49f6fcf9f4368b50e2872cb027688efc7cbad6ef7eeffbb37c302f041da9ba7d33e6e9e4e4fc822ff1cded553817f0399949199805e19bc703968222a955b52632199ec8354dbec071f2846ba08935034799de64b4f5a9cd9187eac6b84b8378348cf9434d4d8fa08af2ea495ab4e864d4cf6bcbf4351f5c09993df0ba24800aa11603bae5a23a49a011d755add9ceeaa64dce2f6cefe30fede8d38fede260cf2e5878a3a1aa5a6b3b3b76fbe5576df733afd909ad2293b17fade93edfb421adadadab3d873482b489d7cec5c08353ba0c994f30073845c0ca0add3ca563e1845a1b44a6e67305f82c38b84e8e1d384f05129144c93c171cd29524704105da74ac05be3ff475e28c420ac035b4da3de9c9b436aa0df5dc2527a87523a1a99be451e6f7859c3cd3d8ae698d11c73416e90ef2aa12c45b04ab650da660b69fe627f13a22b92988b8085a7c5b10b75405c7e3a1235121380e095f8f19ec4433306128848ab96955548a2ab8d04c206da70c4090218789b58c360ba1b3505810efa8e0a5a5f31be4938cacaa82035380f833def00707cfedf8e0c09608f4088e2fceac4d7fe9c6ba757677ecc15b6f59b3d79372be5caf5ae305ff979c72060de7d2b2e2efd79d81e526d8288386a3f34595b1e4bc4a5424741bfaaefc9e125df1e7dce72983f1ebf78360c18365e654f7ac26ada3828363e251e5dbdffeee0c189f6f949b91bff3a1aeae17c4bb364ca01eaa2622cb22e54804a6a0179df41ee00a47418cf86573cb29518c8e8a2a64c5a229173b1959effacf66095a28222b9aa103037e67ff96e02bfc8078275945cec9c9fc7c8b6a850b5d41eb4aef92918f8ded37cb9187e451b580e1e1d594afc7b56535717b7ddbea8c2d3fd8b7e3478fec78efa99d1d1dd8f1d191b43634acde7af892bdf6e52f6b3e1ecdada7e767aef49698167be0ae2dadae58bd824f93f36c1944f97c0aee70576064a148362341cc4bf87384685edd55aa2db3ba85b36aeae0f80c9e86b9dca451f5859c8b393745166574781122e8850325d94c078c3799bb295ea3e544382d572dcde323c0b3793dd07b0334012bb4610cffc4ac30d209f7faa2e97a2ac29da6708a0be202e5e8d0b5eeca9a9c315abd9e7cd2f85dd5e8e4bc7c17ce4d2485d4aedc11839e4d78d46c77a270c3e752918820178afcb2e72e371bd7cffaca67efc830a43ea025ed4634671cc8c1594972e2aea6a4396a43937d8c13ee707ca0898bc1851d1eefd9c9fea12dc391317ce5fcd47a9db6f53636acbdb5610fdf7edb1aedae78cc0ca81960f277aeb5e4acf2be6650bb89b0723fe4eb658a9901a74472498e974126d748f2a865f02c5f3bf7b26623c4219941ab4474f9e77c5fb154a5f9e0d7e825c40571eedbbed03fe8c262928d48f608623a284887546d7214029befa9419ee03c06df08f2930a64467510833ad21b3fa1e01e20f859a35ecae67db2a72da36f062df760675391be2c227442cde45d646b5df53691f2062751cf75f2e70944ad6e48f23d3effcc2d503c689530bb7cb079fac2ff700fb7b76edbe47c68753ca60e0fedf8f9538d9247b94c70223850e579e73ffe99302263d24f9848dc6e6990275c0fbe59cb6bab0a5873ae821399d33de73c72afd9f4a2a610d74224bbba5b467ff085a46ed3a9109cbaff6b757d1f3c61bbe37a233dc780eeea13a5c72e025609ef552009712e120b9c2b0802c96da19277efab6a4ca241aa40bb956f68f5dcd5fd59e74690c62c0e96f4705770c53a47ed48974256343613acf48c509cb73ab6b4ba2e9b694e1bbcadea8d7620230ed08558390b0afc9baf5d47f03877624ce85e5f8e90bc4884491f29aa4fcac9f5c9754b84aa43762130f5b510d37d94eeb9f0550247d11d9e428b64e7f09464a5ad67202d969c1b908954ecf4fcc49e3dffd40667e7d6e3d9d3f3381cd8e6d6baad6c6e59efd68eddfecc6b0ad870c1b9a13360644028f9d73cbc12a1e7de9c1712428e5206a5445489ae592389b4caa05806b4a44ef27bf9fefcb7fcd944784ebdf933025de7f7cee917a5bb4e2f28780620518c61cd7ff5ab5fd54f97082483976fd4ac9e654f97a7639c9062ed83484bde405b28c5a7339a6edda747a88b93ac52950d309e4f94bc314993fc4025686c565cecc9a67384e0692801312d41c4af870d70a288bc598b00e56669521d07d3961c566e1c696c828fd20d8be9be3a194292e1d0d739ba6ca0f6f7f6d4585f97615ac5b6b76fdb6c34b5f1f1292232eb9f9e0899511ea75fb00faa1a0dedfe6bafa99996315f83d1480a6e4cfce8536b77bab6bcba666d9a697958908fe9790da252f5cb7925781a0a1a7ebaa16df2eaa193ead07353d9276b402d55bce017ea2df8431790ce0316ef835c222a85de11105c9d2cb1d38596c673bcb05c4c2ce980526797b4c0cb48901ba4bb0e43366c90eeb9c1f40cb8a6998b30e13679c65a03b40781b228dc842e4c285636c33e97b08a0c46955b14e818e731e9263eb782b717c6b561c4c35201f51413153922d23c601d61e1e0e04267b46b8cb7cfa28bd66394de1578829bd12109e28e4667b9d64a8358719e4a0119a2d97b0645ceb73a0a621ca85e3dad6876e2c5e0dc9e3efdd8a683b135982b381859ab56b7d58d155bbfb56b2bbbbbb675ef9ee43f7e582f827fa66719504ac492d79a95bef27b93bbcb2097c1238351eea99b087f117c1602d4bc8789aaf2673d307980d2b388aabc073237c664ffb38ed4772a6e9afbe619420abd15a3f8da37bff9cd99504e7011f29c521ae44dca2e0928bbab1955151354a253dec57e6103c24f85884f8b5f29a5669088a02660617bc5a22035f43e322720a58a6700a84acc082289aa8b5c56e56eaa42d117977287f2fae68b0c3c127d6939253a95ed126782ee4865486fe63d89a9c687480ed3c0797fd3cd5cde53353d3ce95867b6b1be6ded4ac38e9f3cb3eae5955c3debdd96eddcdab5fe79dffac7279a4adcea75344c952ae6fef1a13621843ba472b7b7ac09c1540a2598cbb61c6d0e346b0c53cd1490143a8b148e4e082c4cd6514a65335900296029ab8ac203f293a8188108f273e021c07d7764e96d595a6c81aec4232a35f3f619829e9c11c26e5ac4790c5b907f555a2657e999737b997c3ed275f17a336f2cc6275f692d8dd75002e8cb80dd709b144f5aedf09c02a5e00401aaa21a475f9e4f9fb9a6f548de5f70592ec7503a270b69d76a81b0f07cc7e6285d5571f6a4699b0aa13a26e0e942dc981b8eb528a347c4c2c1bbf2799ab5a65bd580e0a83a06aa54da179d214c0b87af52e186f55621487be042e600d278f2fc899d9e3cb786d56ca9d9916014f4d75be9d9f2e686eddebd6f4beb5b0a84da4fd1fe93c8aa44fe899c33386580c9cf92ebbd6c45cac09629a1b7a515e2cd78bf1271e5e153be6e79bf4af4946b49eb27bcaed4af7be59d33bef73d1b736e73c1adaaff9565c835fcf537fe4a55c2fc10fc2e022de604e6bf7b6ac6d75c33e4623a0f266cd82ba6eece497a571db3689c2047fc176d326c42b95fbab1bfbadb35d0d22d65f234038297e95bc25945ddd878e5a9913f372790d5d7b5a8eee83a45903abf203e820504e19dd6344a915cf1ad1462e2e574491d108a6a647d9e18ee069076356adf68b66da3b36ca3d30bbbbcc0eae4d25aab4bb6b1b52353bfc1e9b9da75cecf4eacb7dcb1b58d0d7bfafc998d690a6fb6ac3f1edbf6ce2ddbd8dc54836d1a9de5c9c97369379b768e8326a4256e0ba38104b43812106c08687035d71314f8ae61a3f996cf5ea606725888797889d066d7137978dd84e920913c85d55e027f3982b077d751ee694a4bbc911ddb1547cd7e9f31acf3feb7f474e7f92ae8317bb0d3f34a9d5c1a46baffa8bd093ef04df05f923484cc440254052c2402fcb9a98660fcd4087a2e78e667e364277dc50b5fbef8970a82a218b02f62386d4ccb6eb6dcea45966bb58638a744a089dccb0a9d8286882949f23c85919ed0650edc03ddcb8aaf351917c7300af84a973e30bc76621f7dfca15d9c1d689cd726a3c448a369889e8cadd9ebda67de78d39657365c3e5659cc1c981fb6a1472b914d1e44f96f739418c127d3b59b4479c6805286a20caa20e033189688f9c55891abd67fcffd4b46933d96fe9a8befcbef297fb24492ca6afeee1ffe763eaa9e7f70efa989167e698d2c2eaab096f0ef0df5f3bc0d217bc91c99a9b6260e8bd2b2f7beb931199c57c05aa984bddde18ab2727a50dd28a3963703bb0e36029e5a4a05226d90854736728b4bf305ebd5a91cc6e04250cd46c480adee834c59a4996e89339191bf97b6557c0834e51a5baf547a85c94bb77c5fafd3b1e576cfaa97d776bc7f2c24c2e9b8b4b66a17a7e77676786c93feb99d1c3cd76766b43908e87c34b2addd5d8d88bf73efbeb82cf946e52cc89817c7fb50b1cbeb84cbe060704b61f7b3f216949134553ab940801504a05e25e2974e4f19c92de6466281436b10db2d031b9f49129028806863f2fa33664cd663a86a10cd28d9b130d6c82947297896b987b95b09f3ba6a15c2de653490932cd5d5558a0c6c501061bfaf83c2fbfed0f9cd34919a197eeae7d36b9362415a37256f2032cbdbbc59d7cffabdc0dde2d28d248596b3e5c8536a3cc0484941881ca62a1cc4a6f70a5fcd2e0bfe528137da8b12c1702f1a359f4f90014b482002563a3d5000020172dd1a5116a73ccdd47c26d0f52f7ffd6f76717260f76eddb18dd5758d1423c81d5d9c6a1dbdfadaebb6beb2295b9d1c26921c5516cacae09507775e6b56ea323dcb679960e58fa598f91a73a4588ce44a647733dd4bfa8507955f5ba037771c055527ff9b41d06f8a077fedb52882a93d8a2c2033bdfff1ad6f2960f1831267caaf5d3151014795b9d890f967020017a1726f346ebaf813a89a2d1d90f0de630881aa49cc7e398ed4e010702ad5453ae4e383f0fd8b9b18920999f951fef7539a91efee06e0256194f78af4881fb581174aee45be9d93583c600aceabc9da4dff34d0342c2dfc10f3cf4f15948d07e7805e49daa5e0b7b8686d08068de263d5e9d8faeaba7abd46037892a916648f89c2a3a19d9d1cd9e9c9919d1fec8b9fb97d6757c8e16274695bb7eed8d1795f29d5d6d6564c9f2e1e7a38455035cb66653635a08fc93929becdf42d3555a415a4d2798afafdc3d3ca53e1742bd0c28ec115e5e9c941953c552e263f18fc94178f379dce9f4d1bbb637530d4a43f63843ae9105396d39f9d89cd2c06e70f6bb6b6ba263f76aa81dc278c0f3934786f2d6c5e47278557c03230caf4afd3536a08194d41c3b929d76d5d129482ef2420eb44a7621842656413e9d8aa749734c4dc071f6e2a7f39b25b08219de3459ee022e54cc77c6a8dbb50c8988f039e8350693dbe565dff1984a5388dc0dfc62cc45ffce4a776717a640fee3f54518a21179da5253b27a56fd6edfebd879a202db7124dcc766b9d0c48c9e566a12011b15009c58a108b261f35a7336e64578bfdb298057833202662531612920ff9d333e8744e23b8185b2262ee55980e38ede9fb3aaf61ee771f7128ef27a932df93a0416e23ffebdbdf556c9bbf710e6ca8b8b010b4e515b4b42fa15dc155bcbaf050a0ba0d4b7059e6de4df31b2bde890fc069efa9a51c1b706384a8e4e2a757b291a17fd0a1bb57e7904fe4df331aabafcfbc719ab40f533036a68c08af11517a5b865296172a2a2fa6be8e385cfb216340161a830704f55d3fc6a7f481172eb0f4e2821bd73977d310d12df1e7e5d83636366d7565cd266336c3955238fec373fc723c503a78b2ffdc2e87035b5aeed8cafa868cfc76efdf97c7bb86c41285205e191b9f0e14e69553d0aa3b1190e28cb9e1e262f274951ba95c0e3c8df3b4da15edc97be8dfa3d9bc5cd8782b3a17e98b9cf7936e2b6d87b27bbef058cae669d6820b29836cbe72e88f0f989005ed2904385aadc201b5d1696b302a5d02fa1ca4b2e22927720fd5b583721a3e5d997ba889423859847f1a5374d067b5ba4b566b33ce7d6aa3fe85ebc4b2d93e2ad9cecf454145433cb0b08e4948d12c0f712f6346b453c1ddfa86f50096cf03fe4ecfbcb0e1263dd6c2d333f3293c3e7cd7c9630ddda0c0d06098464b81880046c5f20fbffdad4dc743dbded892cd526f794566850352ee76d31edcbfaf86788186c2ab6a4e81a49d79e1d690291fcfb30c70b977137494fcd74dbeeb264f55222be7981d2c107829c694082ed764067edf6f6ee297b4835fff623640223f39fc46955e874f14882adff9471ff3551274f3c51f6a709d3e41c296d1551f3472785fb01e00bc07cd3711271a624779c5a33ba18cdc40cfe20185b15fd8657041a3c9c87dcb65d3eba41f41485f0b9f6e7f7fc8401fcd84999b6a0b39124ba96b140ad28934d2395f787e73f2c647d6a494545df8aa66b91034dd0ee1e652c8a63625d99af84921b81a0f8aa0bbd45bb28db50d9b5de1523191a21f14897a1b6436e89fdaf0e244a5f55e0ffeae65e36bb39d7bf7ad2281a18fe36a53aa0f4e50f739b444f02fdc5b771b70c706de273f0fa90edf4fca96e4303fcefd7c8184f5dc7671f088b37429472e26d7dcb938347ff9337564a660177d99c94f8934d5c3e085ea6e655c6f88546fd08e22d74937b223cdf30a61dd2ad32b057390a1573b476a90879b83df23a5a4e229725c5e5855d92537bb3d6993a4006f76b42630351c0ffa2a3c4c27d838b32679eeae6193a343545c4187be29a3a95e34c6cc9a7538da058291a23d6438b93f5866c82ae497a69d16e3dd43c94ee0035d2a60a9f99f198d1df9fa5fb3dc701fad55edece8c41e7ff2c83acdbab51b2d7734ed2d6976e575bd26e3bedbb76f4b9ae202a1858dcc4da494cfb87c8e19844a0e2a03cb82eaf0aae38b8164fed8e7eb64918d39cacec30d8445e623efb382accf203f0f74da7ffebaf95e0a62417b2478e277aff7f833c87850f9f677bfe3d963e93d13703f1f4c06ab8cd2f9bd8aac02f36ecee788ca79132d8ae03c5c28e80dac8caaa78f90e026af28da16c4694dd1c6bb27774c33ce6a083f8f8e694112a67d6af802cd1b60c35a8371568515aba7283eed396858d72c05ca43212fcb0b35b03a699cf6213703b9b89eb9c7162e0b8e383df5f22ae8eaf2aa755a1d713cf4b6712b4668a5aee06606361d0f442c2f773b3606552a603db43a29031361a68c26a76da8e8c3028d92060402c9800532d1b4e3a8ea5005d3f30cfe8e85e227948b717331719db96873638ac32ada97fca0f2020c8b792e2b094ba1543767aaeef289f02d527a50f32668d235366ac50797f20c9822a4c9e23494733031e5e6e4542921888e8a67a27264116c06d6018eb532f2439cdaed599d51f04def2f247091760dfa1776714ed01ad8e58806745256d212e7f754798c411712cd4600407e92ad621a3c5b0c649196aa20ab9373712bdfaa55c3fe67bec5731600d9887ce2bc57525c16920c5c2a9a3ef3f2e2f4ccf69f3db58db555e91d84dcf1d6c275b6ddb6d5cd75dbdadcd2bdd5a11b7bb5e49f32702cd22cdf1b49e3248a927c230ef0fc994ceff3d927404974f5c750d3a2ca1cdefa724889810f61abaee1b3f8c88505941073b8ae94482ea50b19d4f2fa72eca0644d79b0fcafef7c5b7bf866c52d2f361b6b79b33cb11316f3a65753773ec81ba253b7e2e5f3795485fb89961d7110f56a9488a5ba50a5c53de4d97843891df173ca0de13c8b93dc1e79094c3e903483ed3c9845cac969e766342e925e4473ffacb260467e31f5c66bd7d020af60337825d1bbecbd3c9da912a7653e6837728e464f2f2d69b375db5df1104cf2a55a27e1a5063ce03f756567a78776351e5ab7d5b4fe7044b9d4eebffabab59656c4d5d04622eb9ab87e2d98e06fe0fe386d329880b0280ed044cd732060690c7b10bfdc3b9783384af241a69e9a950bc4d1721831c6f4150f64ded85ef215d98590a767ae07aa6ddc5bd10853e79d68495a5a5db36e874242479f8860c52b93fa362091a94c3304b57fa1a1a7171767eacd04690a55786158d78de79a26d2d49b6a53e1de55eb2d69d8ba4beb72ba60a8074eace3feb91d1dee892f5deed2ffc7ebf9783a823caf07474930e720ca09cc6ac28727add5163d94f3c67abf0e47bd4eb6ebef78ee6bce4134e07370230cad35d5ec8ce56f130b1a24353858743b0a5ab2bb1e8ed492b3b6baa42119ca020882cda67557576d6367dbd6d7d6bc22ab801f8742a1c5caa0e3fb23025b00063fb4bc389420220b30f9efb9a6330826d7957f9fa3ca9400cde73f78c6e2c168614f95f728e3c25cc42ae4fd22ff96b6d859dce21a7dcf459616eb4f9ff17f7ceb7fce4aa8981f488824aa4a19a8f274ceef71a8468a443f189bdb15e3f92b37b954cb9243f8075bea01dd5d5daf2a8b08383ae8f16d1f2930b10193bb12493f75fb0f7f308839631c547069bce7226df51b27b3b07903a66b80ca5fc947b12921ce7dcc14d0bf25a4c5c92e5d515c2bbfa3c88048e4cf99fe64f91c50031f03aaeab43b76c94052f8a568a7011d5d4ed0015dd8a87fae6046586d2fafdac6adbbb6b6734b0b5a363b72e1292077d81753b62765f26732516a09929ba771e1c9ce06e279652b55f61ae60294e83416f03c985fbbcce0c513d875588b7bef5ab93cb9853abc241405114fe12713b4534debacacd8ad3bf75429ac23a0242d8c197f22c221d999903d1cd99021a81c204ca166904438a0ca370a1a00df78faefa83482d2db5dbba678827f185eebdd55c9419c73c47e676817a7c776b4ffdc6ae24b793e8df9ba726707ff2cdc03d6034dc85432911de4c6f1cdeb15bddc0b3ed1c86c0475118363531728825e41d52bb11aae22845fb319d78da6acd78986fa8a5d1c9f5afffcd436d657ed7a82e462223129528df6ca8aeddcb9a5c2840ee110a3e6bace409541a9dcbf2f2cf682ec4ec45412df65e02a33a90c38f95a19b8527294ffae601805378f0bde1c9ef73603e0440e560924bc7053b6d6a5b8d93fd7a2e894b28acadffefddf49389a0b30233481c7a7dc78ef5446edfc9079018ec0f2d409f41241849f7324e09c84bc878c05d1b22e96c19c3611b0dcd685810d8e787cd12fac6d400d0432a2aea8b21bbcdb1cfa46c9346f64de70d7942c90605e9b067b16c24891c66a0770ffa59ce402614acf9fcfa7f340a67c3e0de638f5a4da6e1aac15ad4c93c1c82e8743051ff814be5727ffe8c287544cc60a8a0ca358d9dab6b5dddbe2759077c8f72ac66c094566c556a74ef6588edc372a8863ae27251e90ee890c35f62cc65acdd33af470510116d220158cbecf9cf2eccf7a3237d62b0f10bd57343127d796f7d10faaaa4af0bb776fdbdd072ffb983419065239a3b4cdbd1868bad0d9e9b19e35e9e265c836582f9a98a3e128ae3e67ed70df979697341e0dfeca9d1b7a566fd130ee9c9826d970ff41a297237bf6f8131b9d9f5aa7dd703b24280b3d731feaa14d4ec1469399c6d24775ba2b4e2344358b8a74daca08f1eb305c1c9aa923d3e11f0251efbb745e5423ec095c6eb56b141c409a20ddd3fd43a1cb95959ebbd822a804a9e1dab1bcac80b5beb6ee322382017b20da89323024da2db9a00c4c897632b865d0c9ac243f67b9cf4bc49631210b2a297bc92037df7b91362bcb8a009920224111155fe79c1712068195421d90296999f2ba926066956ffccdd7251ccd08564240847b996bce232dd588185d0fffa0d69b0868a52ea424f0b490a353ded10c379c2a1f63cce18c38413dc5f3eb70b5723654f26180edf058aa76893758b49ab862366c9e0b6458dee8ec9ff241148b8a8f4ad99cf41a131592852ac1c8f53e1ac7c4e90aa1abf1e458a520520c025fa253a6b6a43a06a45fb3063e5e8381260fd7a4d7f0eae8b03fd074148d3d836b4353566f5b6b75d536efdc57cbce9471e311b01221e59c3cd29b0c58a48e57a47f9a44e28dcede1789e2fb455706afa2161e59a12a2ef90952c23c1d73c112d0f335791efce70dac3ebde726bf316fc066f6de6c660f5e7dc56edfbb6fe3f1546b8069d3e234e8179d8e6d7a31747ed2f5075a1bfc1a5c10d447ae238bbec356db6717d2ce45a50dd706aa84fc57a9f9a878970b7414b8b8894c353a78fec49e3efad87a1d7cd8c948102f4ff52cf220f6f2bb3b3f68a24dbd3d976ef846750e2be501dc0731b8584f4f839989c0af4c045706fcae44c0fb0108dd20320314de69894ce7b0397ab627a16cbd4eb1c445b82052d2e97aa7a380b50c011f1b9b609c8120d1713e07e7f95eec9fcd6090fb61014a163cb30ec5225b29d15906a6e4fac9c7010000200049444154b83273ba89f2d26c8a6bcbfdf6026f0a5dc0815564439ea62e7a0f17d7e6ffe6bdbc5e0cd09afce6df7e433aacb29cad05af6367110432ff2d3fb43e941a4b7d3c1355b2c5b4e7221d634babd2849050c871bee9bc69b6a66a1a62408dd012ec757b9a4472fc4ed012d98c8fb954f78593446c504f637d786bf900dc868687e2efe77edc304a1e4c241508c902c16a4a1b11b05fbc898f23a76ac33c3ac8509fc30017e463a824dad4497da5b4b00957a27ec2539b8d2f5df0c8b4e321a4fb5016c026f4d2b40a65ee6ecf36eedcb32e23a2c2c257413402b1fb1e7ab0d798ae90359012b2e873f15091550378cc72d47b8e5de09abf94d6042a2b390b37ca8be1b481beca2934b946bc0aecb312b5a85874190cb349faca2453b9fbf0816ddfbe63e7a7e7d63fbb50fac7f5c0134184231f707f35efd9d4e13999d8e9d1b1a32bae35c6c749d3a6c3229c2d96572569107788ea5d36361eb0b065668e60ab59b7e1d9a97df2e107d6c67183bb2be9df6c7e0f52fa41f55acdfe6ab2ee2e7a2f039d27459208054e8ab4d653e285ab86f8604d048ade4a79e3fb48b30c58bdf5556f7a9f4cede4f9beec82ae6713b5adf1fa9ddeb2d642677555018b351597addebbd4cf25cd91d7b4a045fc6927377533b0e5f7bf00500a5784fcac996a66402c0fbd7cedf9c2e290d23e74bf33716d181a168e1858efa87f322acf9912fe7b74b7e0b9d2f9569cfedffdc3dfcc92ecf20d01ba717d94c4bf8546220380f4343935437db5de92e08bd61d0e781d6998c8ffd53ceb1a15c6d5bb7777e8b180e490b34ab562aa4a8cde72433a6ffde035f17ad76693c5afeb90e4f5ac9e3357e83bd7e12252f584e18ba54ad0c205d1ad885de0970300a49057eaea9b56520507aadeeb46a54bd5286f4e56b7bd5a0f3de585ec56d5919497c10ad1dc8b187270eeb3f0b832fa0b670817c7439be172a0f6208654746d9b80b5be6eb33016949fb9a61939f2931e2e4e1d21d1e9c446a0932813fb4377090a728bb4fec981a772788d610caae4c64a4b5f779f6a9d682d867fe04020623af45d7063a00a55587d43243a172a85c7bc725ff5c1f8d2b6b7b76c6b6bdb8e8e8e55057cf2f4997df0d18776787424927b7579c55e79e565dbdcdab0e5e5e550f15f0b990e2e060a70eab9a395ab56971649d536f13bab726cd0194d6addc1d4cf075b903ab6ba1dd91673bff79e3eb306d206d240507338ae121053ecc8c6a09d4ad36c38444257e69b7b31fb3137b366692ac5c16ad903775a3dcb1891c287b85d2a658ca06c29b0d69800beba226907c5a8f3a3133fd0c3ce08a1b286e9aeae6abcd7ceed5d97f028a02c640d8982e71c6441b26780c96b2d03d60ba83a52b14430c95fa65854b8a5ec9f8935b31837ef07b702917cf05ef4b8f2a0e672a7ec17e49aca80952921afb42870f91e2533e0e7c9ac0438bef1cdafcdf2873377546a11255c2a5c25e92ec1612a550914cd7444f04fe2d6bb28965d7b9569a2b7f678b069e21d24f8bca8e2f96cb685dd843ccc63d001aaf6d4677969dff54120a2abebb123313afd119bc6ec3b8db5c24521a024af25b57d7cae3c89e4d31d296d92e882fb39d441d5bfaa9f96b5862df556e4f344fb4c4e5691a52ea91a880f5be8201f9d17922a574e087059049931016c3cb4465498809dc3eb99adddba632bbbb734b0428e5e61518dc38007254732723388a1124cede1f33bc272bf302de43079131f220d9ddf6ba59a32b973db9614c590de714fe5281a41310757e4d8773563a36dd2d4230e828570309f17819e7b2751a686754cedd6f6b686963e79f2c43ef9f4a93ddedbb7738a2a1c8ed1f644baf7a52f7dd1de7cf30d11e3c78787767a7cec136462206fa7d1d6fa6228438d36a88d4d3aa7dd6e980209ed41b59902137d8554d950bf7398e2964130a55d8785ef95e26bb522f10ba29be7a93dc02147806cbaad7372373cffe48872cf80b27243b386650218a720f741f30cd1a3b1869034d042d4eee8ba1ad88c337793e9db502688231b751bc10d12ccb7b76df7d6aef5569695f6274a765a63a1274c8453fedb7cfda6635e049ea47f146622052c915252402502cb2096df2ffe374ffa087842df9ae5c7fa4922dd63816312b7e291eeff46a531f75f794d0b47e1780d553aeb56f9fad7bf3663012671569a6be941fd3ba1a5730d22fdb8044dae5d480894c2049199290417c422920ba9cafcd98ee3e99f365b41a2cb233e9ab0457ea77a3a60f715a66e0a8c531b8d07a19cc78ac4355291162bb5ca54499b351e5ebe9e87807090882ad1a20d8092b70b02d527469bc0ccd4bf886b245544c637b9b5480c168dc0c76b72da365b75799fd7b0d040e13d1c89739ae1464073af902c2ae186c67eb5d7d66dfbde033c85631664b8bdaa60114eab4a65a26f501e56ee89cf2f21dbe0a10858fe6f8ebaa8cae662d5e82b82806a01ce5bf9dc491a712904f809e8fefa3eb146715715612ab60c88c8b6a9c52c48ee7bf9cc41ab70510d2c5b9a2ddbdfdfb74f9f3cb583e3631b2001a8981a9f21bb0958f7efdfb3575f7d45cf90cdbcfffcb9f5cfcf156c409acd2afda31dd912a1c15adbdc16794d5a7d767266cf1e3fb6f39323559aefdebb63f75e7a686b5b0cfcf049c904590a373e6587cf3fb36afcbb57a42a31b824467c6970aaa7bddcbb9cab98450ad6750b733e9e4990c25ea2cf8deb554d7706a97bda8a4a3f3456b4474d498f31412450c21192557065d5aaadefecd89dbb7744ce7b6742be6e483ca2209601ab0c0437f55699fae5f72a9044cb5d06b7f2e7f3d04e994a990e0b581436cd89c2244c8af5e4bc945f67fab17b405a54fecad7f44017038393d689fbcef739689a59e52ffff2ff997151d32bafce654ae170cc55daf9624e3486423d240254ccb2cac01b666e5d46726e0c761e0a865713696f5c45ee6880340e989e9c9f5709dd49336f5cd9bf68aa9e858739e82309f8181fe450c215d57953f241499a102557dfd0ce7565c95a0f23b8998cf894bad51cad0929aeac47b99d53aa790fd2ad0e2d26ecfc1843a6b2364dd6701a57f4255685c2c627270a5e34f7ea52e199a6d756eff4eca537ded4ef58a538d2a1cd692c829be72854a9d6159778b089bde5e4c580c5449be407781d2a853c3b99f88d98808c3d8ccf944cb4491b94771400f1a736e31a54a5f3f491ef05654daefcd9e873ab29d8db5420a1250d086ffd517fa003ea686f4f08987b7fdebfb0bdc3033b1ff46d6575d55e7ae9551d78a4836beb6b42a7a055524504a08f1e3d12d2c25941955e46bdb7dab6b1bd6b1b5bdb7ac67ff8dd7bf6e9479fd835d6c77665cbcb3dbb77efaebdf6b9b76d6d6347288c07d8a07d0487560a3a18f9291d24ad6796a6fbca2b5de419ab06e4283f897602566e74d017f7ad89656d704a4254e163af7517a856010e470bd020ca7e826eb727233eae637871aeb5c37d1e4fae84b0ba2bcb76ffe5976d757d5dfd8d9e1d684546afe6625f964829d152c945e6fef443c8c1869e71b4bf95fb20d77cae890c1625a7a510404d3952c50c742a3f45a6943143d75692f905baba1904e7d5c6107813f012e1269551f9cbbffcef3379ab5f3b679141244f11b94ac6bc4235374b5fe824bba40f1258fa64db4c275c85bd1058926a01e37dea331df8aebc9012968a4ccc69cbdc3a5b4f32f879da10c6818a4ee90a414ae31b0991615919cbc93659fed5830cab98f94399dbdf2c6c44129165eae4f0c3d12c119e9b8fa21dfe42e3d73531c5fdd7b3a1589edd52feba5304f210a99423780d4f4e64e6373c3f77b48ac30164f3ac6eafbff5b6b81990ab171a706700111158a34d8653380979a5559e12821cb26138ea25c5c08ce0a64067722cf5c50b0ae2e3c9deb811c36c35bcd5aba72294e783267cf0c408b5788c9af27552d733e426257d304200393369d186e7677676726a87878756a957240c1e5e8e6d7777d7defcdce76591ec7e5253bbe8f775cfe0aa28e593467efcc187d63f631cda58cf706377dbb6efdcb5959555bb1c5edafbbf7bcf1e7df0915526235b5f5db2cd8d75dbbeb56b771ebe6ccddeaad098fcb9347fc06c42bb1733182509e1d0f0544ec58a19ae2168a0bca7344bf89e027a953003842353df90b9c165372e2ecfc7d6294034ddebadd35bf1e059a9870d76d54e8f8ea4eeef349bea7a90ad77a3693b77eed8ed7bf7f479b368e2286fa1252cb9a5a43a928229034ffe3953af0c58195c9283ccea6219c8caf7c8c0a4bdc430d8509fe7bf23352983678204b731823107b0b8c34109721259e5752a0edc904639cd30b5ca5ffff55f29602df88f1ced159e3b39726b76e5a7aa1c1cbda2e31fd86f624652119751eed6b499306dab57e007900fc0c7b8e52de4ad2268cc212ba1690ea848ee8af7f2665c885336accf3ce457ba47b248787d0f7c6e579b793dff02119b0b4b3739a60ccf5345d0151b34da78321de2140671c89f4a83126839083f6f711da4874db748d1e70a5e0f92378879052bb900cc8c2507a9cc5827464ba95880aabed1b2975e7dddd636b6dd623760320248ee798e5e5795304e4baa813e56cdbdca42b1217e294fd312eafb9006f4473e5986aa22320cd22eaa769e9efbec499fa4ece92cbfe0c2a40aa77d24ed56487909569a28434ae063da34492bac8ae0688617e8ad4edd3684dec6aba9f59697ede5573fa3804710e41e13cc84baab55750bf0fbfeb3e776b0bfaf67b7b9bd65b4aad09fc800876eab6ba38b81fdcbf77e60d3f185ed6eae8bf7595e5fb7f5ad5b765d47feb0e41b453e52ee4bafc9e47888319d673e6cc1a5350a34c14396e99ff7b0ba366b9e4ef1fda12cd7bfc77cc617aa7715cf3c56f139ebadca3a1a590cf7fdd993275a136d04ad32336cd9e6ce8eeddeb92b54a651604ac19c6cd75e091493426ee77abda05206981239e53ec87b9b7f9fef8f948f44f04dd23d3390041389fabd5d6ae1cba5f5118b2faf43d71d084b66810687ed6d7319605f589b710d7aad4062e56b69ff7fe31bc81a5c37a14719d536b936f2439166a1c761117bc072374b9f94e20fd0cbd29cb66e78a7dfe5c6e9033469b1985bb348f8e8ae89bcafd2bd087a5c200bde5b85dcf226d354da75c64804483d27f4dbf97c407f5d1fd0aae656b53471a2fac2f286d1c2bf7c8e20fc6bbaa931405586caea870c070b82ae1a7669df59782665afa23433d17f8823c11c71925a68c28c436f900c2958abd550e91a4e89467016f27834d1e2e481f756d66c6969d553bf40a96c2a2f2ae079efa57e522d3e1bd54755d034c3d037a4ebb1fc10a1c29ac14ce967c806d47910556129d9d173458025a05c0687a5459f7aab9c7d180bcb17b5cb4812d1ba0e8b93d4d1afd61396c4a3d11ccd559b4e75537d5d5d5b8f1494c15ad776727aa28aabda62da6dfd8e5e0ad25ea86b6bd3c6acbb5a5d9ab50e13862a757bfaf1a7d61f9c58a36a1296f2babd950dabb6b19fc93627afb8225f807087cb03b571e09132678f9e94f2d9b151715b18559955b6f74245222f9eb9238e74e8752577ea90fc6b669757d7d6659641674932194d26b78a7df4e10742bbb8ef3220f6ceddbbb6bd7b4b814b12819c5215d63faab0c773c84d7f33186550d2c6bfd1cdc0f594c1225150069f7990899fcd40955fcf0052a684f93332428f66f81235e5de935291a2cf7c7f6747ca82fe48ae4d33230ad75bde6300effbf77fff77336fa95978942744244dcc6194c0527f014f0bfc545a0ced2c459ee58d927d4c74b4abc750fd5ba9c3f294523631d580e46175930e967933bc27ce15f0ce93309875218e94af91fc8d10a5024db93331372f9e0aa7ba1e56a149920d08646bf054e299e6cea91eea14a8bc78fec20c43ef1ba3a9360630c80e07ef710ce662b841d1ae942eaa8c39e37e43442b3087fa5b2d1d8caf021168bab30725493820ca6584e826857c4e119ce298fca453cf201c21690b4de5415e2ab0055fc6f7896887030ce989de4307d55836bfb971e70dec5181d5f5870d72fa43415467aa924331f57c288044f184fec0174e520d6bf09f5b5e5e91c893797c70661c4af06c3a3302a181ba38c40860abababd6683795e6d1a3c848349c158617430dfc984e474a31795d865380b04033ed36f63678870d225de33313fc27ea5de49e49d717955b47df7e68f07a423032a7f0cd95e4324dee3a0882af4cb239496f393f80acf93ae2636c96351ddadd403ef9e4d1ffcbd59bfd589666d77ddf8d883bc41c917366d7d473b3499ab644d072536c716a8bb444c2302cc8324d1ab0fe0403364c731607d11c9a6cb626d8f28bfde0071b3060410f7ab30589929a4393ecb9ababaa6bce2932e6887b6f0cc66fadbdce3d555928646664c4bde79ef37dfbdb7bedb5d7129995f2f8b9e75f52b0e5356673acd2563b1c8c400934c32fd668f65870c41c6efd40994c307bc8c98013052704c51eaf0c33c12c15473e63bfccd4fb33f285c27006dd0befe6c0e56bfd890005d3da7f7add4ef8d3f737196bee75aa0a097396d76182a6609f7ff12f08588b41626503a581458921cbfa720c5650535aba60c826530a60a61b57c25edc5883ebb638a204243ba2639820c97bebc60ec83a2c196bf75c6ffe38e364089b94720afe00a6a0b93eb38c29719489099bb155b905ed0dbe8b6aa0ff9d7501a4136c26e3f5858c05205ffd7bd7e1286e5359d498dc582aa37a7885dd6810bacc081c84c91cad5249e787bf770fa802be16726793665c007e17e26df0728253b17901dd61b627c315f04e26555a600ee22866946efbc032d06c74615bd50d55c0976337af098bdd8b5f0ba670cc60094b2b96c8d16b9365459a1a8e52616c04a92cf07409857596c92ed406f87331a1b5a6b7cb4237029615b030d065bda1af4ed989aa07d498f3d3e3763a9b697e706dbcaaa005d83ed9dcd4fc203a580c3ca39a817a2b748dd5c95887102aa428ca3a5bba74a75ad240ac4360098b329e9e1c951cb65546f905e99479d66c7665ceb0e90b5bd198d2fcc2d9570539e3a5dccb222df77cfde4cb5886b26458e8843df7fcf3322991a207e2749a57c4a39101f272a3a233b654e4dcd2268b7a463672b2927e76242e5e05a53c1fed856a32e56792a8e4b592712543ea978cfd12d0fc4f273a5d00ac32da3feb595eef3f2716feb520a9b3aefa8952fffa53ce3a30738896ceca3fffe7ff4c46aae18e90ce3b5a970e76f9100aac2ca30a336e2bc2961dbd4a80b299524d2d4a8019e7325228e0dedd32672e9420dda695fc86c7128c09045ce4ef9e6ce9005ddaea97043e7f8f4a1e5aff22569a9d4f1962e54983a89c746c12ca909023998847574b785494127b33502e39eb46156647938045369bba647607c92280ba665c7200e2b1f4a22324909462c718847007940caad76b9c0f00f352da58fc826849d9ad660281b9322ca45158dc19215250beba96469436506999f31a6c2e0749b859b5580a64d7a2ad40ac9239ddd581c9b744657e46aa185221b04c329e92ca284b179fc3c38b78c18eb75c339e6d9057079241e6dfc964a5684b676a88c38d878c51eae03da7338c4ea79ab5d4e7838c7b762a599e73e476c6a3b68e27e1784d25330a06e3adadb6ba81d0dd8e4a5369d94334565ce20059e146889fd5aea190b0892e35582c1db6b82f5d193b23c323c06afd9670647fc3421cee671f60b592e92e3ea1842da5ede4f5960c465f673dac6fd8344336f5c3f6e2875e6ae355c6d2c24827bb37bd42195d115651e695ef4065d11296849755341deda6722f57c9257972bf463f20e5effda09400dc0f58fd722efb2bd00a6359a6cab84b19ac4b3f2fcd31e3c77d0b2f48a52e251d378c8db2afc9fc1d479c4dc5f42239190989557ed33c1bfcb3ffe7ffbe16ce5152af944b7478a45154e32d5205a87628a7307f96ee925c7a02f89abcc9228802a7cb165c83c1078a5cc98dd503f285ca099a794230980a8ac2c296029047656131ef6857146f9444780529324236193ae05c5f45f63e20c96ba74dad07436684d7dc0826b1df63f1a01701ab0db85e9b54241dd7c61483c2ddb538ad040ce573c969a5170c09d2041d4e677e9e07e10302b0dee5e5eddbb7cdf845e70a92a81c666c492f48b867909a0c95f714c7a84e56d30d1c48f85c743135d45c018c6c4c723755fae833333a55cfd329ba9fad7d0fafdaa6f4d301e501da97dc08808e51f23b61ce434190e2ac02943975329fa813585311282f30ec8c190418d7ec5c8aa26acc54d94f203b3b9db6c170a9cd2e666d17999af1a86d6cedb4d1c6465b454a78e7a648bc1c3a6c70ee41c8cd3ef818d96180f04a8700a5bac7c7accfa6e03ea413376d67d3536791946b2b5e0b5c1f0aa7c15585a949ae7bac602c1ea232f87a2d59b32d5afe52cd600e1159a5d589c8acf0b1d63637da732fbea47273316fb70830ca7a6b6201e2ec023b62c8de655d7f5d25f074cf3c51a970cb3e4d618147318c9ea0e386890ef8c2cdf4b93c10e4035655d28a6757c950bb6aa4e0a49a7ce0ad33af9b3d92a064e6a389ccce46ddccf241e08335e379f92c290d75d0fe5fffe7ff513c2c5af09424040a734f7845b73a396501654955a3c5b46055277d73c968ec4191b64e76990a68560a5a83cb4c804eb96c311706008d9c07603951568280de0c1a46d590e94a3b9146b7817d078f8592844f12cf31417ee4849667e2fb26c3757a96cf1e9c1e01c49249b6c09ac1633f009e904f13f375fa1d9604adac0ba5be4a81ab858beed368686baa0a1e0e644d9cb40e4f60487a661a889a13c351dbddbda120af7b4060a33c40b9f51c6ca73cdcaeae24c76260dd6611e03f31af088ee0436145fa548bccb9dc8f2ad3e567b560d4457326eb6cda6e41fc3b2520d984e817973666d5eb950d9b150c7c322a4be17fc94a2f027d142e62761b8e1dcfeaf8e850f40dc0f58c0141d6556601deb53c5086c56c20a3515b376eb611b376eb5b9a412553bb449afba26ce2d58d71f648bc92ae5665d964203c0b5e9305cbfd0becc1da11c541cee69634f2f35b980d9f31942d65333795d4a45137b8ba78550ae930152dcff66768602d4fc68dc27de7e6adf6fc0b2fea79e760c89a62adf3be3eb817dae7bc9efc3babaa3127cb9f4599600c5cc4252ce91677956c0013f845fbd25ddd54348226ca4cd6875e0c4de16d31496078c51046ba83ceec1270f8f9aceb646c3934925d7b50c6a292fd3dd48def74dc4807fdbc1f7f161be17fffdffe29b7b474a0d86093eaec81032ca4586de9e5489bc085144cc0f85c98406dc981804ba024e0b2108c82497d1437e16281c7f075c87cdec46459f8b67938998748b03091b05c98eb46bb530ad913c0d337d0b539a744e96611b09c1f77757bb219a380f09f866d2efbaeca90fce5aeb3e66064f95cb2b6fe699140f59eecad74d27393793fe46638b18581e834b6fe7ca4825d4298d7a613f3eaaa6d6defb48df54d9b9732c4ccd808ad71ca969e74072cf22c56ba8730c937d8c49389169fd2e822e65e296099aa608cd0e450ee978c4331b49032a64b7f82281f7b3633ce4096a1539efb4dfbbdc658b836cf5252821b37d1e6a9cc2af72fa5423a9ace888d8fd1d92523938d7c611cfab7c2415cd2faa0b909b97465d46edebbd7866b6b6db2b629ac6a58644f0296ee7f0d787b6ed407a936ac5c672c6d2d238ce2126af3c8d5da72432359ba39eb10fb9f6eb018eb8c27796deaa0abe68a70d1c29d3860bb72b0681f0c5493618d37d6dbf41a7ac6dd76ff03cf754ed1cea61682947dbca85fae911d5a23debf92a52b98d5fdd71eac7d9aacd7567626294b90b103cc33118141a083440ee6bcaf827bb85485773ac8a7d47366c4b6728367a1cacbd7b347b49b74f02f8409fa41b05f2de575de8fb50dfed7ffe50fe404cac803f21764548c9ce01708be23c2eefbf01dfeae80238766eb56f5a9fc7d70928b55f74a8ebee8594db530f99fc0850334bf73a23077a50fab9bed193f2590ca724cc2c429399b82ecc5e5459c7abc01745d72ce311e61a26b81fb991b8c1e3bbbaf3a5649ab7db205b4aed7286c2cdfa30754274a1e4a1ffc4c0ace35ab2c218b1c9bcdcce2f57de1d45b94b5c1e8767676daad1b776462211c4b548e4b0d3adb45db5901540105becb4b051d0216bf8b115e81836b133b7dee4c31ef918c51f71da9de94fc556ea6530c3ca0ce674d08e8394b19c16d676502deed45a7f01661eba16dc5bff3f3d6b35a8c4725f84b71f3c26521061b400ddc63ada912ce9bcdc97a28dd5bdbded8145f8db1950946bceb9b6d884b363a523cf7327c106920ca9be2109e7b6d8fa17f049774f737d94508bfbe36323563a4a29e4ca7fa0cea2af73626593acf5d19a934eeed5cdce145aa56f0dc8445bc2ceed97cd0c4b3ba79ebb61205ca59059e0a0c26f12ec68216197f05d56a0c640de6f7c019043e025688a0394017d94e74eac85e17ac77a816c2aa7add434e6b9dd7955da992a843b3ffbd7c2de6187d603fc1af7bf69dba8b837a7f3f85bb16467e8272b22b7dff3ffd9f3f7b6dcb2216f948fc0f541b474300c61a57d00557ba5fe01f1795ae9409a1e6df68b3d4434c59c58360c34956449915f806c0aa9d4deca4e2f1928ce3a83e2e608f4518f053a74a07f879632e487ade2c2a3f254d6306781e4074ccb901fdc89fe0928528326b2fc0e5fbb986bc9ecb2b9792390d0193fb696cde230bc70b9e93dd8b24a5981783537ffe1d5c8380753133f0aeb2063df2cab0f2a0c94cfaaaa47dfc8df74e59a84cb546acb4b10a03e97011052bde7fa1bc90b290e64217680b1ccd82cc2948b6c533d6095a0b1aeccd999a33163efb1a7398f52b2d73d42bf00654d084ae51ddcfb3b3a902d66475cd530c64c4f0d4c8aad637e536740d84819206227e00e292e9b5b09e32a8a2a780a302de422721c30a08ac1243d89d4be1ee5956a64b169a928b729b5f8c10697d6563570a9380e3ec6a417fa024d41ae5b0a2b4845e0193fdfe83b6b1b5555a703eb4a490522520efd5c75ab3e1090afdee5ad66c7e577655e561825e025ad6af824b6559ec79f94756404a299aa915adb5dee7c9f7f5ab0d272e1c642edd736fb8161fcafe5cfa5961e5268c670fe5f04e90efefaddc8fbce6e09ffc83dfbcf6002f0f0f81b455d90c313745fb352f92b430b34cba480505f3a216659925351260d834b64aaff93f2d3e80605b7d597cce002da72b174b2949d7c6adfa0b01a0d4bc01df10010394cfcd7340004c1fab3bc446595e860c49abdce5a46ebc6808ce0c12e82291db0f62ddaeea496ff44f9d9c5879f08b938232d3f854aead5b4015dc68e183bdf5bb2c091c9cb47c3f9bfbf6ed7b3aad655e41e78bd120b04066e02a73d03c61597025901abc8ce242599a2ba82e3a2ff1297c4fd629eb35a7f374fa12681627ab5f439d9d0a42ca44dfe78fc7c99e528f1213e19c0000200049444154d73a3e3ed6e2dc407fbd36215961e8121c5c04de483f671d213d0ca1167a012584a083abebb626adab75a98d4eb62807696cd8a815a919b2f47c7ea004bc073d22e3313036151c2205ab6ac004270be9976b809396f9526da8aa24f273c6f816f891dfd4d9acd5739dcdd269a66c94ac331d36a08cb5f576ebdebd36595d97d984f122943416eba6bf7ef23e09123918bc07175cc8acc33e4c41299f433caf9900a135215ace62a636be87a91eb2c6734f933125802493677fca76ae3a9eb9967c7ff681e0a79e014ade4707798fac4a7ce8978b5dc0fadceffeb2b2d51112b312cc5fd386b111833710dd38e131c51b4a6d4b7d0f188f5d3adfc7e2e4d7ea9a9d679281f06f522c10b087681d7406bfa620f5a525b15831d03ca58d8d196689d58934083620cf3cb7dce9c6e546285a570b5f12c89297e1351113a49cb2ed7c368236b4d8b65eb4fc352756ff24d2fc7d950e5a8825d7920791a0d53fedae97de6bbe9113463e7abd0c244a0a0e3c2e31781dabafa26e3a6977ee3d50592a9d2df0a43200554695cf53c3e80990398d34ead30d2697d2e8fb88c159fc211af6831c9db6b33397de59dc5d9bba9e4b0e8ffed078167e3230be07d3540e2558ea7c5eee05bf3b10c3c88715efa085f65577f8b5413b9fce6bcd91fd68e6a5ad4d2803c9b2d6db788372d02351d0049627eb225b06b4e77afc19aac37c6db8007e153241e918669099fb88a22c580ef23ffd32c865a3f5e2c05a9177ce26cc21e1aeb4ffe7fb95f1aab5864cf2b00dc068b1f0dada6adbbb37649ec1e1e5e17173b152cee7d054f0a1ac1c99c7b7982a582842e830e5b9f49c99fb7b2f6bb69fbdf5d7b1ab251bb1e460e6f7042bfd5bf1cff2b545a05a744409eaf9beec9d5c47d6573fd8e66bf99eec293db70a6a09547c4df7e8f39ffd956b32186c94a4893d82d53b54b74ec27512327369e836f0a29d9a0f6ac54804f6ce95be8b815591969f412d910b305190168ab9431a87a8896c9c4e3801594c809c3aa1e67339a030ad9ff253c281e510add34eef15ce138b97c97cdca0097ab675f70c5c7c0e5dc641bd30105bd6d825c42616b952e41ad93177c37664f540b350fb2595ca09f1bdac3fa513b3467cd21573d6c9490f5fc7f3893265a841721623df8b4df9bd071fd0f3502622230b82af31ab8c4f717f625d1651456d783917957b4bb24bd430d47d85d3637224651ce3567447d9bca218c817d2b8648656b9579422a132041c7626ebfb92143fc12af2873a6414f0fd0b6f4267ce73651ff0a3e0d05dd4c1c2f7c884046df7ab26e550489e0ed8176d75bc264a002e394808434a944b1024e0adddb673e35697dd2c36a8e708b3097d90988a408927826865a17c0ee46bb2a6b3315d327b62206b1b42ae451d6a04acb0d660aadc1fca58322c82d612eb9f80b5b9d9d6377774f03a5819da20285b00d06593efab9f4bb4d7e83892a1f4b38f0419ee6bca29b940d594c9a2c1630c2c8122b24159c719384e75a4925f53155e2fefc9807a96670962ee00be77dc267fcfcfe675fa412a9fa51fc062ec920cac4b26fef11ffcfa350c7434b7196570c032a6c59439a7bd6f6698e71e47e1a1e806812f95e63a7fc7a64b2e312c54492763753414c3c16d7e3a2dd84d11b0ac78e0b93d4e08eb5b81d950134725e0d1c37775a2f12274da70dbd503e988716c463b418f47eb66cb5f525e7ae3713d2295aac3653df8645916c533d94ef388832b6517ee7998ece9eebf6722bbd3b4f700bb74b50748e6744f7013c65152b1caec3a96b09b06c1d1f83730ac173ff86165bd041000690c2b44d5f093eb027abf54ed839dddc22d75588f17f9d7fbb3abe04ee06594e3c91a83c5048bcaf5b7ea00e67e64f111fc9400a3095560b6b26a353e8c73328ec42f0544eebd249fadb3e5ac9a32f2a41d9f9d0bc3040f95433818531b28c35adb586f13e4aa3736649f053b9e673bdcd869b7efdcad464c0e1c27e51abc8d20a2bab2ce6af219087c67e7e7ca00d52080cbf79e4cb5d67b957aac3d111a6bac4d90826007cf56e63e6bda838e235de20933842b0a58526ed041e1bde10cce1cc0c01529d953ba7a4196bc0c7f8ea4b13dd01c905322caacc299119fa7bf4e7c6d91762eebaf54135924f5dc24ad54e44efd537f8c4783fe240dfeba9cb60b1b4b4593033441d102875ebfae70c2becf91e6fda999de9addf5a85c3101fef1e77e55a339d2a8a4b45ae16151eb6382099e6276ef10da4189dbfbf702d4d018925b2fd91064523838740d19c7a8593f9d82730172042ab22e0217e50443aa9496d26219c0f9994afae3f4d81c239ad04f9e3c6ec7c747c272042457f6a3c82e4769005bfbc4c96a1e42a9d4b3ddfed5e0b0b02ce91ad4b0f058c3af5c774a37cbddf8863a0b08b8ca6b2fa6f253def1da395d85570cddd9e4ba8371e8de952449c06ba81e8b7561ce59166dcaa60f7ef4631a94d510b4e6f2e6baafee44d56854617cfc4c48986c38320e4e653e833a7cb0f1ab71d1ef1ca5ace3b999c45763387552fb407023842c44e50a184d2de0c0040a2ad5ecc8668b9a873799dd7208bca8cdeae0805fc6ac2a0713530b256dc3351d1e1eb783e3a336e31015a1f74a83e274ae27a3557d0dbc75e7c64d39f3ec3ddbd77ddfd8bda5f5a44cb8b21097330c739f7783ee103f23c6a7030888623cd1da63ede0e82489e32ab1f2fc98474cb9193059995f81d8cac6387c8a5ad1955d644ad893adad6b4512b0085ce0476e1895ae1826b1d5e1ed1648353212bc44f2ae19d9945fc15ff30cb4f66a3283afa5f912fc8dafe9faf94319cd4004cdbace214bb0126c510138995770e1acf5c033d1604b399c3d90ebd3f50ec8522db79decd5eb6f51d64a524e7eb10b376ac7c4411b7cfe777f51f232fe02e926d8159d8ca1c627c85a085e1b1b9b62b70ad75a3621d2175adc8bb24ef7c0eaac5dcc50a52cc225d22ce2a8b89b90c84ae4674895a0c86bcdd075aaeed902a7b9680f1f3eec3a332a4300326bd3d3e141b941edd7cc0d16e18ebf8bb15f96d74e3d2da5e37a997f30aea16757ddc3642059b02a214b36398b371d1cbea703392f4d37f01e5d808679d0f93d373f8bd201b2b4d80bebfac8473fdeeede79a00c4b4d09d98979be50d4063a7b9cf2351e93139df74f8694052571c41567884af3eb144ec0d5e72dc71aa92d68035eab7bc4f7cb3883b2b4a11cbb22ef3cf17920f10e876d7d63a39b0185eee0a0e4d2c04e2fbed71c1064559aa0208bd63a7117d187983358322ce46ea61056958d5eb5e11287dd446d78407706c4399cbcf1076d3abfd0e0305d6e6d04d9e3a0a03ab38c50cd535a6d810ccfb003d05802be9ebfcc53d73a3a4f6819bc66e641d376e777cada503e94bd97f3797f6c4ce44c05adb1c6afd06a97ca2c9c3c3e374a1da40c70ba4a7239ea17923a2a9a60c66f42f60c4e99e7ccb526482478f9defadaf3bc8349bd1fbfecafdbfc5c82627fadf671a57e75d15ff3c9a8deffef694680f7652f2d66962d77e49f215e18824ac928d8e373bffdf30a587c113c45b653b228b2c6913620f8530d65da1812cbf149571ec1a331a3d97e6f8ac09477e2d4c07cc609d8b3896a7f564d66ab2f70332f54838afe9545707470d8f160cc191a351c86c984f2000837b21bd387746aec91030f21f70345f0a2944c6484b9d1f95a0258829816c8d522187143fbb8541f2ccca9d03f21134c9226f7b1b0fe227155e1931d25ce0f3cf7427913d6b80ad81e1943e1494c08301e92609a932ee93f7f570083195d03d959480284abfc208352794f0051464286b2c8126986442542810d4c83f582663a64c8c96a2944707ac1f6d614a9e813caae9097bebc68b3730c75e76d99d1ae29ae4135f757fa5adc8b646b5cc719b40da28b0ebcb9bacf043fba82eb9bdb7296c1e74f2c1766f556d76dab45492a3e94f5f8754fcb2d59f8dda009f4e72020e0bc27934288515409e34a6463090cc940b2e994a594596f30d23cdb04081d1e647b502da82ad636dae6ceae5453b9ef444faa0dcd3b4a8bde189fb5dc4ae964290c72afef68ba073bccfaea1a1655b60a532e75dd34c1128092b1650fe5bafb8769d6751730aa039d7516cc2c6b3dafdddf4769daf4e10a5d6f916c7d807a5df4d726b1c2894dd9e915bd62f0f9dffe8502dd3d9b277131b210e9f864c0d18a92f20facb92801b57c801a33d1070de056b387b8f9aa852d495f24756d83e5e0c405da51d717b61841d08951faed9451741f35d85a8cf6d132a0fa824dab45a13938c6635c924911b45ab6c99cb28173137583e5bee3b27011a0de6bf4a880d76b362460f55356e138eff357cbc9d70f687a988db195c5e0689a17fd86c6dd7b0fda873ff4d102cafd40b987cab008362508482035e86cba46161c5fe3fdc962915b2660e9fed4f7a45ce4e7722af3fc187f922687b2102f22f0330f629bf7352f691102086332606ecc2a32022429672d48f4d318c3b236161b1af720090f32948e72e9e9b13ecbfafa9aae1b805de60f64224554d5464261958683bc0e19b5e1105d16c00ed919e583091e7e288bcabecd523091c0d1f3462bad3868042c3a92e8ea2758715fd4cdc53310a58d15677c042c05d21edb3b90810261f908f42910fd034f6bb3cc79c9463dacbdadb2763a7769c4fa272353b0ee84f16ae243c616e9767a5c8c6793359d8c3e7f5fc019a63bf40fb3d036521124b0a404cce1194c329f396b266b2b077c32f92e49785fa592af676f07a7d5fda9f941fecc1c299976825a8218bfa78baecfc1defe83dffa05f1b074f1caa82cf1a294107c4ac699430fb98a105a753793ca9c2e6052a548a09f815755c39ae0163e6199e9b20516c07a0216f102138280b9224926e8f52429b870f492821568f1768a978c982c74c9dd05a15435372b8b2758525e233747426e1778e439cb231072cdfd00e628e0a09a879a20dbff9aacc47bde6e3e71dc195c94696499960ff6bffb358d81710d9e74dfdade6d9ffc8eef52f98b82016d7f8067696495e3321956829dd456abbbc967962a6865ad0401ca919c8c5cbb1783b38bae44bc6e029e6da4b0300281eccbfb9a76802fa45be8b0c691292660a939d3961ada5797d379bb447901691819c79eb6133029326ee175564985b2b1b98da09db3f9ed9d6d95999355ace2477e0fc9165b0fcca598cd7e28a7e05c6138bab1b32b03d5f1d6a65511c6ebcab0743acbb90699990466ab57a08bc535110c759f1438865253a0ac84f7b5ba3ad66190fb96c0950c8bfb280bb78b8bb6b9818e95034bc6603ae69b6cc3861a7c5edfdc502648e9a9a4a0272c49238992d001c4ff5b652443c1fefca11be5404c569e2654ffe04ac0caba4f36d4cfb0fa59573fab7a7fe694b5dd0f60fde0ec75d793467f8fa9c482ebc5678e2a86afcbcd24411d1da85ff2e0523c760241501bfc83dff92572f84a9b17a79237ad3b232c9a9caa6c34a92c16ef033b22168bb315dc4ea02ef824efe42f94ce79dc21ae2e5e044d5a46b4969542ab5498d928a1b00dba0a10194f4e8ef5bb54226a96ca0fcc0d0a3ef12282f33e1e444e00e4fab2519349c9a4a2ecd953cf67f30610f4c9858e9633c13e309993a92bc13a37e568ffb81de9ccd0d7eabe63cfeaa8a7d699b4dc0b72d43ef6f1ef105152c27adc0f4aa30aa89e11acf237b66bbd918994319295e5842ffcaabfe9fa272b9f9b676ca75de360da98177339d7c095424de10cda09c163366fab6babedd6cddb6d75c268cca05dceaedafe93a7edf8f0a85d9e9fb5a3c3037dbfa8009a899ce9fbc89e430f18afba514176b1b1b9d50690848b6829435a8685cfc9f04ac76b7928ae9e9a2de8a343b45dc53475b5ad2137b3b6deb6766e7872633451e9c5480c6b3472c36c16ace1f79f3d154cc18ca0ba5f80dfbc277c38756b01e21d28537e654371cd3ac867f3121c840fd8a3be0843f3469b2b4b82273692963bd72423deeae0cac24ba5eda00d471ead72a96685533790b46a3b23e07ee0797f904906c4ef0958fcd925a87ff13359e3592bfd0c2bff96b5dd5feb816e16c1a5270713167d1d78fd6bcb01aa43be12121fb833c945e7f075665f0d33cdbffa505140fb47bff7abaaf09d71781ecb9194c7570a872585ab082a7132e6b44a7759b6dcc1c0786095def6b4781491a54e4ae9e6933b56f5eb8c596c6d196ba9362c174c39296a44753452162a82eb947677c677df7caafec88489dd8b6e5c1e524e93a4bdc1b0f23e394dfb75bb5da2171dc03cbcfe89a38e9bd8bebee69c764987fbef1fe5c8c549682db0042c979aa3f6e28b1f6e5b9b9b6a56909d007e8bf02a6f469f4a595879ad64467ac05512508a6834a44ebc6487f9ac0e5664a9853f2d2d6913d219a41c04c3822272b47f2833d4d3534f24503addb973b74de8dcce2fa5faf9f61b6f36dc72e8f492ea4b5686c507f99180af39c42581ab5ab497a878d80462756d4da59b0e97d150b2c15cbbfc2d291966d645e2da30b12008e831439dc14d67386a9b9bdb6d17799ef158233c6bdb9b12fbc30e6c636b53192d627fc78707ede0e0a90221a03758dcf298f2d936f3abab23bd3ff728427ee9f2f6d71025a1d61d6344a86d48ede4d29af09591cfa84ec6e33618222bb3a9f79a31808e8d180b15ca8f546a6d26ec6767958480ee2ee7a3d0e90c7811d81623610956399c03a3241825d3eac330560931d13b9540ffe7b31792d165dd643df5837802621a13fcbd9f75699fc03dab4c8aefe340b69c956343d6a33f8b65a3b4bec162ffc167ff9eacea73115d10e0d4aef9aa5c84edd9ab251a3d9ed2fec9094439c3876774466b497c298fe6a8db559a3772cb595e52864549e10772253307fe4c6982a471709767cf9e9949cf07925c704e9d4898587f5e1f726931b290d3e0fde5107fcf024ca04c4a9b7439dd15bb5c2f0877790059040946f60ef4af7eaaec00147f453708b2e8f3b30a826502eb46c7b07de0c10bedc62eb48f593b87562023506b819925be90fcc8bdce03cf824ba93fae7b9cf9c5043aae2363380426e8217c0dc2ee1903ea1728721eb783674fdbd1e17e3b3e386e7b4f0e4c61595e6ab76edc5220a2ec9b9fcfdbd9e1b1caa4e9e0426518530d6455e85811005071d8dadab4122a27e9b9670ec99e2905b1108ba92e0191ff01e7f9fc643e740aa7a7c9b0863a60f98ff54419cae1026d802e1cc6a574e43677b6dbc6ceb6cc29080894f77c9eb3d32395b91beb6b1a4a06133be7ba501b591d2bf34fc9dcdfc0a107a483483026d322e8e4d0e94c555140b86cca0299af3a87303bb1fe9b9c7c04ae73005db7d12ab3bc13ed9f0e6c96c24266346df66ae9a14583298da51ca0392cfb9956d66c07b9f4fc16457d298e607ea69f3de57513b0f2f7feef2993fb412d8767fead7f780774f7fe468d64a15e9a7864031a0413f0dd34bc34f8fceffdaa9c4755faf4a45844dae26b552eeacd4aa84cbca9c84d94c3892e1e6c41aa9a809651dbf4cd469e561af0a4e03c2c9d8dd70a586458bcfeb9dc771de894f155e6c6c3d9dfdf1741f0f4fcb45d8b97446bdd195422b21d1babde9754b2f199049004553e6b527afead7f5ae5810670cccdb3519d0351c0e87ebacc67029b4a60ea2f96e05c094efeecbef60436959af51e3ef156dbed3bf7dbad1b37bb9230b2c6d264af4e61ffb4cfb5bee7352110529e1746d7cf209329c68d486c7336dfe5a5b20afe97cac6f9a974cf0ff79fb5bd277beddd779fb6bd67cf84f7410160a392fda02e41a6a5f295f53040157649e93ecb6932c6b0a1b5ad9d9db6b3b3dbf6d171a7f33b1ce980a283a7c58d4f2099992cd0d19f378543fa694b90994752821014517231641f74fe3402233ac35caf011f898c667b7747d9201dbacbe595f6e4f1bbb21f5b1a5cb67bf7efb5ed1b37dbed7b0f24637cc1125a1e345433ccd90a13fdbdc3ede95a0b7f2063926b9387c5cfa430b1dc96c7a31205f0f4c8c3a78f955931f84cb7936c83cebcd8eb43b2cc8d4e174db39bdc85ce51d93244311649161d91c81cee29f7b206fb594e02577e17e0df0bb4dde1db53b448a0c97acf9a4bc0ca9e4890cbba4eb04f569775a9eb9c2fdce5352d57a564aef5626e0d7b5bfe916141675a6a83cffdeeaf5c937273bebb74eb4b029b8723d0564ecf6174191b922c4b8f4fa11a543808122a08ff2351636c0b413405938145eaa5a1240da6918c05947e5f83282d64279469d41c18273a13f307fbcf34e7d575f6e866c15502b893059883d11cc67d316f833b198f5a747cf80c69ed07c3caa9909bde01d2154413ecfaa70e0f340f5dda4b3d55872cf62ef0f5f481fa3486040f468ba4eab032693b3b37dbbd3b77555a918d5012aa0c2c1b328df7f4e6bcfa6df704612d164af9cac672ad5c4f0269b00d59a617684ab0220090dd1c1eecb5d3e32361522727a7edf5b71eb567fbfba6925c5842996c6f7565229a008a0a6b2b130915c29f42ac917123c0fbc3e3d3f6e8f1e3369c4cc48da26903162600fbf454d7aa6642e7a46cf771f02ce61195614a27fe5c1b5feb7260835802025fa73463c13b03a25bec9fdfd9d96ec3f5f576383b6fc787cfa43176fbc64ebbf7e07edbb979b3ddbc7b5f4ed170a50874290973b8f15e5133607d70df44ca44acb0e492394c780eb3ea860f685441bde46b97f3f6cee3873aecc76bab6a58ac2ca13bd7d418188ee198c1691be820b00621e35ee9881b975d8ced2c648154465796d43f94fa8758b2efc5c1b9c0b2fa5f4b20ecafe3ac977e799700d93fc49300a4d2082e9540a47b59d32dd943c2e67a9236c24f9111bf861ac54ca7797a527df987645886954be08d5ad1ec64e54b55e5f824f309c7c230dddc8982c999bc4169624b97c88ecebc11270f33643669f07c94b39fd22c2f36ee08cb26d952951269a930d07521ca02f61e1eec97cd95897fa2e9c8a2bd6600cb0c62aacd57b56f4fbd20ad5d0518e9164511d49f3f014b2df92a95c578178fcc826fefcf8cf260198af51c5891554950cbe64cfadcd59154202d6a023fab074f767a4d36b0d1ee3e78d056271b2a7f7670403e3e6ed7d28c3a93017dd26837464c57884e96692417da14641b2878f26728082a153ac2add5310584965c0ab812e51f9ffbecfca49d9dd2fa3f930e9735d6cfdae9c959dbdf3f503b9ff73a3fb184337f47530d55506db662b6afafaf6a813e7ef4ae7137349724d37cdd9e1decb727a7c76d4a4713b96408ad224a7a8d116c3ad95e7c0cc793364278103fc19353bd2edf331e4ef499e93252f61d9f9eb6771f3e16ff6c3eb34a0841453e03c3413b3a83b5bfd46ededa6dcf3fff5cbb79fb86b0a5cddd9b6dfbc68db6bab1a9313532177025e46870e7111d428ed71e1ba1032af918aa8f5e49a8311981f89ec2006b43fae6f4f4a4bdfbf4911ac32660935121b888d1eb401d44e0110e7bc111a389451609d29076c9f498fbd5b22f1142b6611d98391c559695469c0fa51234ac19d34c21d8cecce5b4aa9992e6f1ba077289c268e1d6c59eb73e9d1b006a76c5ccb7c43413acfa013295d08239b000eaa154e6f0cc7e7080bbd03d7390f4be53c0ea670bc9423457c7d844d413cbe137691f0f40757db990c8c9835304a9dcc2b5228fcb871a2d7b4a9f7adc140277d0c48aaf2c01fe8c44f94498a3adecb120ae29e321c747c70270491173dae901c0b3e1bd9542d3b102f45d58dd2f3024370854b7cb0c95f2b4ffcbdc1546393cde627679c4e0fa3734a977821c7c22bb045997daa5b13139b09938088987552323342fb2a82f064b6d75634766aa9cbea4c900d4d393e336e3c1d5f0b3f4c7c04204d48eacf95ea30d32982513b8984bd204ae0fbfb298ed9f134a05b08a017c1605e0a7c9863381e69076a126d0a56b1aaa76a70f8a019914dd767c11296be66756e524681144d8806beb6b6d03679bf14a7bf2e8717be3f5d7c4d322286a52613068cfce4edaf9c5653b0403c3299af7207b6114a9f8461ae2e550a3bca4b45c596aebe3715b9baca9ccbb79e356dbdb3b10a9f6639ff80e55d6fb30e52fe7ed14bc0b855066140f0e95e14bb3a961a3356a37efde6c5bdbc6b896d1ec02a8dfa4dbb859eb7459a615264e170915f057adf90b6556da0755e278fda1418f30212533dcae8930b5a3a383767c7ad41ad24764a5cb43351a864366fd066d7d634d741602b646e5c0e144e0b53930d24572945eec754310dc17e6724b1b4ea59bc40c3c03ec526e71d0aa4a1056e7e992ace36469fa9c34444afed8fcdbf8845a12b9af1ada1de492c4b6dd8a32ada239c499490da99e41aa2a1c49932fe8478b6b8922ada5babb18f1fbbff58b9a254c844bea27c5815eb9015bf7bd9d27d7bea94b95b90c871a8588c6b3821b99944620c80460fca614316d2237d2d7e032326965d8c2bc070f5846aa0cc59681835bb65645f0862b29e5728fc1f289aff3da71b049c0d506d694bc03561e2a0f829b838b8bba64b4f9e942d508464ab77e8adb0f0839959cb69bbb65526791306be6d0e5e8d0dc37b204113c51a4dc6e1ffcf047656925f54d46962881198fe934ddb1b4b2e22b8b9e80a534bb868a85a7894ceb0c589ca6705c9415fbe4d4cf97b3b3bb846cf05305faa9caa623052c83cad66c5f19307a53e6b725a4c8fbcfa730d8ed26c4f7ac3337777961a9a276a592f0c9e387dae4b333385aa7ede8f8b03dde7b6a1482c6ccf25043cf9783ebb67f74a8c58f75fd6465d8362999349e336c6b9349bb73f7aeb291f5cd2d7505c994f79f1de8607bfe8517aca7c6bd9b5fb6e393637dae6ce8f9152342e8a3a3b73592743183d4cb7416276b6d7513c3d3757738b58699355c35174859a2d0100d73038968ed5c58f5956bcea1c03d958185665b07ed09d91543384b862d78eef625f064068616376edd6ceb6b7412d794712e7c0b16227b8b35555f53d5e204220d01e2460ea9acefacfd2425f93c7ca6bc66d6327fef63b509d659ffc1a5029168a9f502695280ecbf2ec3eae6747d4832a7b82c396aff0a449358936bcf350e7efbd77ff63a3a57f9477590f417bf481f7fc99f631433b876c662ad6cbf21923402c29582fa34bf982e4036d11b228fca8957292d5feb8fe9088bd246724790d35f370a9caac60fd29508d89e3454dae57532f97b3c4f15b99cfe83b5af43069e2f2491930dccfb02f25a3267b1d11de07c83c2596212209b228b4180b1b0052f639f62987bc26c9eb411d6551b1b0a5478dcb10935f35726a730a0a7585f61ac01215712d245f6bc067c5fcc5af1daeaa4702a1796c2f529a0d7503657a1b11a81fc65a4592718f790c6069fc7803b2a1170bf66ed728a53b4313f82ab2915b64c930d3c3c33144bcfe6eae232ac1c40170e1ecff8e4c8e526418bfb3b3d3d9127e01cb30d4e73ee2fd90533aba391b8778f1e3f6aab2bc336a9e0bfb1b1a6f7842dbe75e386cc54b76edcd260f170a9f189000020004944415460306c8f1e3d6a5bebebfa0c1a0d0343e3cfb3a9d8f03c83f3d959399333ec3d6fc3350c5096a4b1c5a407e44d0206cf41a51b994e95de7c2688ca3423c82ce19705c3414a8615012583dff13824e84df14c9ccf956131e42d31d4f0b8f8f9eaccb2cae926d294c09bf20259121de46579a7f1332b336443e775c8d2d1cc5a3408fc33e900f681ef0576e42c26148404a504be7e30ca01adc054b0425e27fbb31fb0fa7b253fa3605efbd6d8965ddcb387bd778c5966789d9f4d80d5ebfcce6ffc8ff2ef8913af824f89dc6126918b0b7fca40f6a5ba334a2be7eee6a5edeb60e7f9ae7eaa7931b34904bf6437551ae2329ea80c0f10b64fd8e4439159c90938e5261fa094089c2e3b73c96b2488902111b404dceb26172ef0be919d046040fb647bbe410bc70ede3b231879a8f9b92c1c674c76bd913ac0cc0c692d1a3951c3cb816f83f3ef9a5adb93cdddb67beb4ebb71fbb64a290661b9dafdbdbd76747020d5801bbb3bca2a616603baab542f1996fec2e33af8acfd933120bc5420eb0483e714830a657ee56d984d77727c223a834af51a07a23465fe8f6e9f4f308220124460182e3b500325585dcfe64c1a6b31026a0b271b2c4b9e9819509da2a547c668cee58ca0428778261c8b2e32f23e642b278cee406938396ee3a595b6bbbbabe04ea984fb0c99d078c3de849a6b9cac8bd0cae03d011403573ab71a8652846dc2f2bc69283cad6e4b26365ac5e81483d39229aaf94882f378b2a64cadcbaecbec44cb199f4d4ac0721ecae6d3f03519e1eaa49d4c67ede0e8c8b49e6ba83bf0a82eda68d9d7a24d49f388436579a826d4e6f67629fe5a8b0e235a1d92e24c96c26f1d98c98e9478689672c91e97454bea5705a9a40c6cd3645b0491049974c8b3bef299fa607ed67602900ec612e3aca5d6ddaf40263aaccaa28fc392bdebcc298e43866a14733ad99954619530fce6dffbef5512a6fc4ac0f0c2a25c2aca83e64b3da0ac342fc3a4b3f2e69321a81774e42f94c5880e011663167097355d9142dbb78f0b7496e72c27c3b8fc39fff3e1d2a591196b05b0742192eeeaba4bd2360394fe6c0e1a7431a33fa5e08cda43592a3958873b66725e323c05ad22b6a5e4d267adcc4c8b64007613f7106794fc7b3729bf02d6306e3776efb7072fbcd8ae072b6d8d85395ef55030cb713e6d074ff7543ee17ef3e10f7d580f194b2f0bf9916101263bf3cce07a3229a2a5c87975bff9badc7a2a131431b3a72526e0bee636f9ac70ddd47113904f67f25cd2366302140b9219b06b32860b050929401541b24daf1a9e840497f104ebf7a9c0e8983d13f82069ead042e38b677d76aceb2110716f74bd522d586e6fbffd561badace89a34fe8331edf250e0f4c5d5a05d2389bcb6ae7b48c94660325c60ac84200ab502c2e6f5ca523b855b363d33b0adac0fcbf599ee0d191e644f8f06ad3508cd3af187488593491afe30460bf682492c12cc9501d4011cdc860e26382cd9d6e1f1493b383e569052f00040877daf9d6a250be149d042c8b2d637da8d9b37a562a2e05c8ed334aeb426fbf86dcf723e9991a910ae28fa077902d1a2c38e01b107df139c12b412e41c0c6df49bbdd5df0719b0f6def6e74bf2d2cf8e92ad45cf8dbfd3fd16a5a68c52c8764763c30d60b3f979ae29908632ac7e869253d95d061b5e06d722f0597ae4b244f11c55e3aadc7d68da20307d9dda784163d059409e26d3e54958a278556aa54c53b9a0d9354f9b079b428994ac8e45acf4d2ed120f46979489498488027a46c91bc0443b47f84bbbc844e84ca59371265e2c013b9926ef93fa99d74a5b37c12a99a21e52a450954d997e1f5b34ba809b5b9b6d67e746bb75e7b976f7fe039de65c371be9f0e0a0adf07317f3767cb02f95d58db5b5f689eff8843e2b988f8c4b2991258667ad2e63d7e060b0a2df6ba924ed2a71e7a4f3ea6cb4cc30154c2b038c0e7bc6a29c2d58775df0348745dd5f30b5a5f9457bbab727a504e48a516b20431c2dafb4b3a353ad09ba83e048dc53ba9cf3738fe56044a1b9c433682a96d406705e5b5f6fdbbbbbede418ac69d028fde870b2a1345203805c5a53041408a0b2680328dfdaf28154524732a8a9cdcae037f81881484579d14ec8dcb80e3688ba65e998a182bbb4a41957680d740809a49489393c3958b97fdc175e3e04529e832822541fd7576d757d4dcff710a38d2992d3a5d65bcf6da930c06424740701c12987d7d63724db43c68ec986264864786c43d31ca469a0cc6a0e379004d23bfde0e37de02c8d35ec43f4baa99b5e8901f7a08f85d5c3e91291043c070f77152df8e819e0240d9909d49a2cea103f237cbbc8e0649a222c2b2998294bd5bd037345261cef03120fa99dfa90d55afedc6fffd275d2d2f79755ce4a38418a659a9678c900eb86147f2bf88c23adbb76fd5f646732452dbe4802827102024c3a0c0e0a09147c882835746598ba8b2ee10c68531246b993ac0c9c0b00de2a907e9831587057c46d59e64a6d21965944295716f337e5641e72de3fbc25be2fd99302594da02b18b0d5d5721eca67900c802075f7ee83b6be7953a9fbecc20f9baed9b3677bea385d4ecfda8cd2e9fa4a14818f7ef4a3da4c4a9f65aa6a3d2c6bd52fdabd2c0e613f9552cb38336de96283aba490b34939dcd4030230f658933308af070bee111801dc9714b02086cedbe5f1497bb2f7549be8c6ed5bc286c09eccafa94028ed330f3aa38ac067e2cf6ba3499bc3efba6e8df213ae17d70566446794a0c93d25fba67b747478a42c4581b6384856971d798c8786c51a016ca52d516a913941d844f88f0c3f5f2fd35382062515ef89de3cec7a9537c2ba4a1596aef668a24cccca103c4f67e8ce642d53ad67218fc774e2ae8d15ae30007da1f2138a05f0049ca26051363cf59a772563bc6fb03452c627423441737dbd88b96c5eeeafbbaffc54aa159e15cf5cc1b467ae42805d241bae0efa87acf67569acf1ccdfbfa695e5948e561ff608769bea2107786248fe9e60997d9e3dc49a8d0cb99e03a53b5243a55aac8e634db148aaaa24bdbd45071ecde96711dc38bd6961ee4ec7aebab66d9781c4e5787911603afcab2cdff38095dd14b0cd8505e44fb994bfb3e05912c9a882478534ca4d524aae8d5a03d695a549c308b1c13ae59054a6c315a09e4523ba824c317bf85a45fa5c6b4e22614d55d22573ec3a6df5f0fb8b26c3db3a79850b5c8b1c79ebde83f6c28b1f6a1b9b3b92c54545f46a5019e20529f1b16456c06938edce8e19c15956e94737ec139ff8a4a80974489556ab7b6b0a07a795dbcb9ea71397a63a46946201fc9301ebf354b6d57d5e4edc5999cf16f82e5c422339276eddcf672aaf64263e9fb5b3bdbd76787ca44d77ffc103954c00e6c8bc9091489e850ca731f633559063bef01aa0fa7a605e1927eec9693b3d3ad1bed5861c8dda640c8f6b5581079a08591e7c263e1ba33f7c8f4e738070e9472db7e5d549dbdcded20c0b1d46248f5c06baa41bad820f165ca1d2cbf822015999355c42d8faa59bc51e20c362dd4a349072b8806f651970c1d400f18c647e2963405194cc6aa9c94393090dfc0528329cc547b2e9bd1d7602249bc419b14b549e25340bf03ce83ec8434bfebb60069e61b23b0504654f0463b2144f9a88f754fe0a2a786a5fbbacbb924f40f04b5e4b4d15754bad77172884dff3e704be7e06978912c3140ee0d9c7f97e97990b655b120ad671bffae1df19f30287049a088ecd3e5650ffdc6ffd92cfdf44fbc286dc128f41e965142e3a4f316324a02ee5a8a1c85f595281f52c3411268b88960c251f3e29663a1b6270f79c3b8297256064d33afdf4499e7235627dd625f28d383f3b6947c7c7223cb248f91ab2bc3e658bc55fa7ad1e780d760b7c5726e83108c97c90d5c16c1e9a89ceb5a92c2d66b8ea6db857dc1354283636dbfd07cfb7e73ff8a176f7ee732affcc7365c07c6033d933ba6630b7a7ed627ada4e0e8fdafedebec06d0873740dfff25ffacb3a6d01a23905ddb5b3c12ad73c1a7a64882c12ac8aa3665c3891566ed117bab2a302961faf098574f5bce0caa442dc333bde101445690037943cf2accd91ab961c466b3bbb37142cd9b6b093e6709496876d8c79a8e486cc8983cb85828374b08ea1a79cb5e3fdfdd6ce2d5d4da7d0965d4c472cc9bc616d7d55f401c8aa94651abd11f7ef5a4c71022412c9e3f5b5b67d73572cf10b3e2f3c2b74da966c398742a9323281bcf0bbd0ed3f13b440b6a68d0775056f44a9610fe4241dfc06167a3fc392ea485101cc092ce0bc9a51da372b2bedd9fe338d1f5d5dc388b7f0a5a4bc0bf70bb60744221ed560a8acd184ec6b393c730d04cfb5d575cd36824d91bda34a91124cbfd7b34ea938b81a7433ba79d6c972f81e674fcb9de18bb31e37d458f331e4e5f77c7fdeaf1fbc04b1f41cabb367b51f7a76778b2067f2b54d7dd9a79e8da5f9e68acd530ba7a7477ade2ab9a5ad6667a5c13ffabddfb8f6e65b88bf49b2b45af0fd374ec9a8b4b8e6fc9c765a82c50432d7f74a1d4b5cdf1fc884b3b8a9e4b514b56bf3c0df09b72b115a296f89cff1be7a209d5df6b0544d196558ad36b4551fd4252acb30464aa4782970bd94303969d42d423ec4ff864c71b12a0bcf2a2c0a6d25382ecb2bed1206bc806f07671e28c14292b773670a77eedd6f2f7ef823fa9d1312bed5c121edfbb928126842716d4fe1205dcddb6434f4d8cafe7e7bf2eea3867638271f9fe9fb7fe007dbfc1a5a88addc65102b0074a94d15b4e6ea2e2a8897f696a82152865d5607ac0faa2e02bc338e7e5bdb365157ca803c0a74263964ca666466a4d021955073b828bde57c64e163972af5be8c5809c8a69cbd80926122f2320ffbe24a5d509a0b0395237424e958614e32d1cf2858906ac8b4c853fb29e5b5fe26ce9c9657c7a238a0ca3064fce7ea5226155c073e021b9b9bc247982b3c43654251a2e642af4cb28de823d8d13260b8f84c56b788c2aeb30997561a3aa7515165a6a5908a4c4af771a9b5c3a3e37674785c8a2374d2cd7ab7fb4d31bbf96c04fe72354702489e7b628930bde15295e04fc6b4b1b1de86abeb1ab382903b5a8146c3e8d142bc7169b824d180cb738f08f12b8d2d75e04abd54b82cd24db83181c515195478d2f28a48b9164044c9d5ddcc24353a88de63605c5cb42b573d01e55391f4031ab0385a6616dc84c25090931a19c5cabfbad4548782df1c9a91930368360a58a929f9a2d3be50dfbc4892e1244af67f0f55217e6c7db29a379629131ad855d85ad800f1bacab28a7ac00265e62befd74f3973b39422d6a9a6f2ab227c1f2cd4062d1956fe9dc15dd8d96a65574b5a411ac9e699817d8f1bd8c842e5d2c01897dc3a6a916b3c052ca6f862122e24d3d418c5a8adaf6eb75b77eeb68f7cec3bd49666f1a5f38600a14a60e4a82fedcbf7f0d13b2a9b36d66d2b75b8b7d7befdca2b1296bb7ff74ebb7def5efbdeeffb549bcee0ac800771ca9ceb67c8384ea7103df73d5b58ec640ddfae524250a655e6d595430b834f8221f7401dd55a10f84b72bf540ab2500824d333b7ab094ac5a8f7f891dd70a429d62b9d030b5c2e35719f742f6ba87ee9eab29d1fe38ae4995514186627c7edf8f0c41484ca703991cce93361371499e09cc29d5897a31581fe3b776ea8b387e228660f7c36322aa97f540999f25d246602d21201cd25a1ca79b0bd0c394b49c4ed759e2bff7bdcaa2a88c274c986a03d9c9cda159af7c8b0eed3a74fdbc9f1a15e7b38e440816b56046505dff225504c2a29f25e29c56b775dbf5a6fb2dd83d0bab6a151374413637accfd92f3932801088ef95af99fe64106a4d36dcfbf51469a3db6c090c5cbbabc923001f70147f3d087b2bf03e7641d2848d1b92d503f894eee8b5e07bcf9da196ebeaf9f252ac9a96008772fdf238842cef2176df007bf8dbc8c5f20df2c06ba12cf05c0675cc32f9208cae6f70737e3d6521969736300b1903e2638740f3c2a055d0731d212cb0a58bc7f3a8869912a8ba9efa73b94a096b22cc136a78a16b782e4b541fbea6ef239ccff9899e753df3353fb9dc15b8f3844f8dfc1dc5402bd17ad67cd20921932423494e3caddfb1f681ffbe82714a890d661e1ee1f302c7c2c25822849a4d3c7a98c4dfbb3674fda2a1c220677cf4edbc3b7df6aaf7ceb9576e7ce9df69dffdef7b4effff40f2104a0cd0ce39d11199d6e029dafdbe9c9814bdd0adce900897a717da5cecc44ca070b02b0680f1d3fcd9b857b72727224cc88eb50e7085963cd317a44a8cb7c4a375d6ebf7412d3c1a9b128655c83d64eb066f31b37ee2f5c2e98f01a50478c717a266ed9e1e1519bcdb086b3e203bf07f4553982253dd41bdaeb50239697db647d55c189ff3777b7dada26651fa32ddb7a4bee11d9eff4dc4616947c0431651fd7d8d683f1204c69dc49197f59d703f24b0e1c7c142a05656895cbd1ac173586aa448119750a1b26b0d60e0ff7dbe9f1615bd29a57ae69615981f71e79b9bef230af610d70608fca748d2f7534cb4740fc510e454409c70a584013e3610917ae11905655ca4292153da0544f885f0470e63b3d9bc90c68d44e3d8992313903e2a5467271a16028a67dc50797cecee6c5f9ab26845dc5a9ac9cd105cf72c031c6c7bf3960d99886b23363799ad9943972e4cac9604ba9b89a3d343154457cfe77ac87d5cfa2faddb17e8695a89cdf551b97705e3e842e4e4a9f8bd1005ec3e69de5805a73466ed1da865eafd59b57e4c1a5144cd04a5025134a8b969f8b8c6d17484b6e15709e85af720f80ba24846dc93e13bf87328bf7b522e8c09d98fa5cc9b0c071a86f958da04f3e07581eabb57ef7c173ede6cddbea04deba79a723c31d1e1e285321038592a0e1e5a971283e36444a4ab697bffeb5767cb8df984e20b33adc7bd61e3f7a247da6bff2039f6e3ffc991fa7216df9153020954725adc843bef0cc64f8303941a109b0f1b478ca45a8ff9cfb2069942ab8173c3806cc5119951d17d8c1f9d47ada853170dd79162a67464868bb3b9b4c98457e5a1996accab8e755fae97bd818184d9c1e6bfc06b5d399821838e3c2e483e726a0f9e2b2ad22892c007cd03637d7dbe6d6561b4e30c2402514c03e4a071ea371c96b05556341abe277cd2e790676225f2a8e93320d02d464a2aea7bd39dd8d74d958950122871ce89269c660e25aa6af6d65d4b6767615fc1e3f7ad89e3e7aa75d4e4f34deb68cbb758da8c93d5a41ac7c3e155cdde82201e84aaf2259cbf7af4a2569c8814f965b348d21468890a4e17f9e3785a9f61acd0fc118cb62cf838169285df018df8310a4a5a99d64b879e6fbcde7b3a48fca360593f20bacd9c4404279defd923d41ca9dc9f80dc667904eaa71af607facb3ac2957471a9c7267b33366356176f00f3ffb6bea122648e5a45e60543e24fb6dd1a0faca986aec22998d6eb8b0089feac14fe232d3654452747066961a3b7ca7948a492713b012d458dc09a4bc6ea7e7d4f3e9b371a7adb3750df5406c8d65791211d79063e694adae67b24c018b62a813abc0706c2546b68334efd6cecdf6c24b1f91e12984bf9053093a7b7b4f25adc2263f3d3ad07550ce91b9d0998224a9dafdf2b2bdfaf237db9baf7fbbcde7e76dae39c9b9a45cae9657da5ffda11f693ff4a33fa63939b295e9c9a1e7f964648b0e1d20ae334080ca9476feb785f16b70c0641edc9380b301468533f03ae7500dce3b0357804ecc2fe8248ad17de1a6853a41d57562b61090be3f75c0bf317cccfd54b7676e863e0124d2d57c9d5249cf8279c4397f9e4965142e13d78dae3aa506a3423423908c062c5e5f1dab1be79114324ec6aee86cad58caa6648dfd3c4d567589b7dce657356931201059ca852e20190dc03f0d1328051c8c22d9f22ca3357ee540e7ec61de2e907e4112687db3eddcbaab121546ffabdff8727bf3d597d54ca1dbc2e75400a5ac174ee48c83c0408790b542f0b37a70d11d8a06141845a57881ee0aa8caf4876d6d83eef3ba86ac45e7100ee6d7e07bc00537d637755f3a4f06a99ac0cb72b0caa1c55ad2b8550fd3c6abd4fbc33040a08434cd1cb4508d2dc593d2d6e459a7c190df1d18cd7d1461b6665c3b88219af04bd7c268e3c3e9e73868833ff89d5fd627d3f0654fea3827543ff34a34cde92aeca2248ffdb39ef24ec01140d9eb20e4cff2bb8b5c44cf2c31995b824632025d5fef21dadedd75755e939b4726151e91b0a7b264675888c09aa0ab408a6a80c898f3ce78545db8ba6179182ebf38796b43ac40eadb6cf71ebcd0eedcff40dbd8d852d6c54693e6f9d98902cea68c1996dadee3c7edf4e8d0444fb57c6d30c1f71e3e7bd69e3e7ed41ebdfbaeecda5915434a93c1a09d4ca7eda58f7cbcfde85fff7179ef8179cdcfcd6552d0bdb4ab9174160b7f60e39b42e2925a697bafebeaa3c7f79267a436fcf5b5300efe2e0c8b92f0fc4c4a9cc20d8aa303086a9ce2aa0dc7665ceb4061e1d70676c95ccd0daea1e791183b327e46dda1720d47fa19dc0d2096eae19c2c8c2c86993bd6c68acd7c29edc0eaf84ce3e14a5b5d33edc4c1d3c3ed68a58bd72756fac240d465d68a47c21a131621505ab74dea1270a1202ca209cff4019b1f15d3e0ba943c1891142d01291e81c24b8cf5ac6b2dac6eee0a10e73acf8ff7db1bafbedc1e3f7cb31d3f438e79bfcc5950ea98c950387b4640fcb5d7460e623d27dd600709055b71edfcdcfd35029e551de4d338a64474107775b260bb438be01eadad6e587ab9323bcae055c93a996ad3876da2748a465b86b05d8d58ca29e5abbf36b7f44da7048c19cdc26ddb2337047ea839c6b3832be6f3758911923585bf1917a41c2c730b88a3c17fe4985c5dbebc581677fe9e932aa7b5ac5c4a3e2bf855825d6cabf4bdd5caa58b93c59eef57eb5d53ef1e58cd26cb87ca4dcc43e3e685eb911b98eb4b9742a75f31705d82f86184e82960b13cf61ce8a60dee56dab2be49b6f91e97a42d3e78db3b371470c0acc00dcea626dd61fc49c9c3c97f7284eef951bb7d635752bc07cff63cf05b58138b83eb608e6e5aca058cde1c1f552b1726f3e565fbd0473edefeda0fff88467854d6327757a6a39448d23242e5329e9070d06a3e2b9f95a743294150eb07fe649e21bff24cb8f72c0c74b014a8cecfe5c02d0bf29a5f631bd1190c30abfbae512daf033ea7270facd32e91c1b2c2123da4807ab5aa6773b5aac5adb3d2973037f84b2241825bc1cd92cc90e596b96ef0348db6d47dd440719144a39840e74cb84eade7046f9e3358109b176769703e320d363d1d55c662766fdcd02c1e34117d4e8db6ad28182a8b85984c2093c0646b6b5bdb1a5e6f2b13cf58ea1aafdbd1fe9e3a5b8fde79bbbdf6cab7dae3876fb7a525ebf3336799b9b905f4b1504dc9dad7c142d653e373395053b958ba1b92e9864400290d2969979899ad9236d872fc0c4d8c06a71ba96bcd189282365676bd068dae0139a8a1c9b5b997d98ffd868d82578d9a066ee067a21fc67ae5205193ae8799bf7f8fe75065bd76e5a1440c4d385586f51e6ca3863c6de9d51b7eee49a62668a9b428ec276fbc38d57dcaf733a37edddbb53ccb69c40bd959cf22e0a595bda8ed4d48ecb993542d9c927611b90d3e263029ebabae64ca525e8b76ba34af90d82d1b2b974b59504b6d7b7ba7ad6fedb6f58dad76f3f69d8ef9cc67d30381a3257795734defefef3f6d2f7fed2bed03902a07ad1d9f1ce939c023a35b088d41340c74ef4b9ee4f1e3c78dff9f3ddd13e6b5b1b9defe83effddef6e91ffce176795d5d1a28151584d51aae0e1cd7c0f3123da432aa8e6857014b60735144a265cff5c74f4f81bae76307864597102e96926486738bac8a0596f00e1c95e460eccc0b705e0706e5788d457583c1a51c007ea34ee4d999ba6bcb32a220205eb7995e9392e3aa9dcff0b43460cc675ac524a232c6ac238912aab3e7ec03e50bebef5b86dbdfb798aee8d33b3c6161eb7909f4e16b381ab7c9863b6a94fd740005acbbe0f181571402371b0632b640e2860001c114891c02048d189428b8aef3a3a3f6eacb5f6f5ffbea97dad51c535a32d733056055213598ef72bba6102a9b54e550b852ff90562364255df2155d3bf377645870b486eb9b1a994a05d2c78cb27fb907dc5f5cddb7b77675fdb270ab3dadbd0b79556579c0f3521bae123bc1ab5fbd181a085471da8643a8467619921a43478b89a9860fb25c579a429abe50e73825f8451bfc3ebe84c54b31d8b67062e90bdc0420eb673fbab905c2f57127674e0be3cefc5b3f03d362aacd950b05c464e62a296230adbc67821cb2bca979b9e95c47825c82afe708dfeb932629e89867d46c9c088f358a024f2a940e8222a72ee4cdeddd9b6d73fbb6c73fb05e4202baa6e6018dd9cfd00d3069603098f20ee0f5e4f040f38c3ca8dd1b3795351ce3af08e37b65a5ad8fd70c96cfe6ed9db7df6d070787ea2c3e7cf8ae8c113ef399cfb44ffdc0a7a5c7c4b531d20216e64da4296d9348c1e834bf66e018f0559404753e2f058ad369eb07756543851fb0419561117419e81551d5f6f4b2f8aae17567af80a235aa25b9e6f25544e7eadc0c72d9785d594543f001ef532a0dc201af2c5f733e3d97163ae522018b72509d686d64fb623200aeeca29c9879066c00e9b90b92a044229b1a69d366cd644d906529e3a9090e7577111e64668fc1e252fe54f05f46a2784dd662e86271dfdc011ba823abb5a569006f224a69cf524e7c889550d6886986eb413b43a299f73d475b6caf7df36b5f6eefbcf99a88c2571c6e9aaf35879140c1cff76111eb8a9ae326b8806e32e45a82adca7e8f08a9fba6016a324f4ae3d536d9e180b57d9e4c6084439bacc9e7e0f3f38bcc8a11a4dddd9b122d249334f6648d325535cb0b88a14b343a1ea6bf35498071d4c5dcae8536c10c1d0895d16b90de73c9a21f15f1360aaf12e2d41896d54c2375ae7504d35d9bbfd4ff323aa08556122bb9a09c6c090efabd6e72e6fa22dea736b8ba11b6dd16e81ea944ddec9295a99bd267c473c35880fe407c2f278931297d68c9283bbb312f8416abd9e86177938acbc2ab1b862802b15ecf3c9b0e93535ae6a105f90f68260e16f875bb75fb76dbdcda6983e19a59d2d5ed14ee828a6571bcc83a786f680c8caf1cec3d6da7c8ff9e9dca64f3c68d1b5ac46051fb4f1fb7e3a3c3b62c0cc269f3ebafbfd14e4ecfb5c81f3e79d2d646a3f6937ff327da5ff9fe4f49c28540c5cc614a5b00ce018babca4c3d3f4abf0247b9672ab9d07b92438b71018d414915c55898712003e89447500ed2f1a35c236061f8c0cf4883ec0a414303c3fad93afdf85dca0eca42563459904da113b5300965e5905f91fe653102d6230973e16158e80f2a3d9832c01415458f89a92e74ed08c8f0cc4c52f5b34f705a1e99f69012a8a3a8f4a477c8a6d809a6aa5c2b13e2ef55f9fe7f0000200049444154f20e1c8e943111a8288304250b2b3209d6f399ce306834909d8cd1e72a209ceb23f0519a7938db65fbd5eca24d462bd2c67fede5afb7a78fdf694f1ebd2b401e9b33055319bb7018669d7b33a744e3010a879ae0aae30d5f8d50759c81103453cb5e58c6390815d51d01ed645da6f57826d5d22e56d3759c1e09db02ee80ca20c589643c9a47f581e1c659ba8a0bd0dc6003a523d085b13d7252bae2f3cb99143c34984e59072549cd0ccf21935d72bddc539e25fb5eb180a669f9a2f2b396249ab6c167fffe2f74256158e6cab48ac1de0f4efdec2ab5744eae740e14d47a1d85aedcaccc4de54889ca25b34269915f62c6d7bc20584418f4095889e27c6fded744cfd2262f2c47af258991859dfd22d53693d883dd280060c8b9a2535d77558ebc1e9fc0f987729053d72e5f68b1c3533ad6bc53d77d534904608c6ed55429f4f4f4588619b0c4c7d892970618191566a3e05acf9e3e762673396f6fbcfd6e3ba793b6b4d2cee6976d6773a3fda73ff193edfbbeeffb0c3846d7bac69c84cf6934a837cb297f3e03e26a694b2a19822c540c07820c7627500503e4d309cf217f2a163fd91be44e02111f900de1d3d26c6e36aa3873924ca980453b5df39c6091ce6c820b1220f933f7a07b1e97fe79ee0f810cbc2ba55b1a1f2b488e8cad3546a683690571c7e35880ec862f982184e408d78be7a77232bbba4a986e98565ca2a137a16cd5604bb9c4e3d05a1910fc5cb2d8d9c636720a600d838a353503e0814d053d5cb48dcd6da9864a631d3d763261f6d2850f68f422e067bdf9faabed9bdff84a3bc6177176ce65bb01c2bca288ef8c5e111c0d4c1b671c2b838ce471477fa8eff15e71e820d8501622484859881820d89cf685c8bf0e8a864b3c97cbfb881a3259d7bd96fa09f7186e65357038382479533237160d20569818ce41a68c0ae14cd8ea544b4a32d0287380a4fc27e130985ef4153d23f338455722985df1b96b5c472a24ac91b336f8bddffc4581eefc1f567002091131bfb2c0fb88be1e62af7b979b9839b2bcae1318d7e6bc8e4601aa8b94cd15d09c05d06fc367c1e57d55d295caa6462a4a5a99945adf1b17eba212181b5bd4ca7a004a37594466dff2bf9a01749620d9c169c15c73849bcb501887b8ff1aefc188018386136d6cc4d634fb778244cc9e460a60aeb37f3070a0fc03903f3a3ad44301c71ac22b9acddbebafbfd6de7aeb0d9799d7ad3ddadb6ffb4727720fdad9dc6c3ff577fe76fbd4a73e6579654aae99395c5a04949a2252baec5520989eeb04ee328e9883886c9e99ce1a7b29ac449f3dcec674ae283fcb27101227a7a3dc734071d4d6b65224413e0708d986c0ff1ab896f1e9059983311602544a78ef1a03aa7d3c128a83c1f7c50cdaa2ac63b38e64bdc586b24efd92d6ebc2e26aa9cdaf61673b4849d31e63d4eab0e53376b37645a7e180e0b9cb4078655941879d175e921a0a857d6a8ca65ca2d874044ebc0fe1913ddd7bd65e7cf1455de754d48d817030cde2cdacb24ada8002058d983ffac2bf6d7b7b0fdbf515c3fc343cce446695847834b628d9965754a29ac06925591d2ea54ba7c691fc021cd8729f71d0a632585fdf50e0621e91cc2fc98488d0c52f24b0e6f55c45b984943027592d6ed4a8b0d6503441cbfbdeb08ef713eb9283e2da6ab5cc9c2afb9f8b138690a28269d780316ca47d5fd9ba396fde93e08b49a03cd0edf9c3c16ffdeacfaa244cd6e2f5e4d6a92558d2055ccc08e67b0294f1a6efe14a558ee828ea1bacd9ab9ae40ea337dd91741fd449a89bde7fcd0efbe2a1d45c21a7820266b986a86b5303abba2eb1898d631958b5ac4cf75a24f745b9b0042e9a4b43390743da544940495b72bee6c2c0f6a72b782ec714021703b4601904ada3fda7ede4c4bc2b4dbe4ba2e54c64488699097cf088d659388341637ce32b5ff98a66de18dc7df7f1d3f6d6bb8f45a05c1b0ddb4fffd4df51860548eb876ddc8185464acf6b4c6739291d0478d89c84c107f50c6abc489973ef80e1cfce648b14c9fd45a34b5c1bca43075d0225a7a5d9ccc54d7b9f0dbaee6d7583d9d88325b0156332c2354a875f3f5f9d432f48afaf5052789d70f6582fca086900150b1d630b1a3de25f21ac57e34f049d9333eef145bb75eb96321a3a677d350332cd60868bb567b99d6bf1ad90a45956d6247c89c05ac6b5121e84b2938025907fb50dd7566579f6f6bbefb4e79f7b41a6120454785ddc5bc65b645b7841a64db6c984c351fbc6d7bfdaf69e3e290bb759dbdfdf6b0306f3bbe7e3729b2a808045d7b2bf1ecd234412c81929f74c1d6d39fd4007a93940f02c440ed731d5582d8e95337049b6513554e64cb66fe309cf373a0822d1c300f986f7269918fa60cab2ae7530f0bd748e051b4898cfb244e250d5a4e9a27befe093bdc815b88c5ff82e08b65017d3b08d1a13a147a1e9cec52bebe96945275005b74a705260e87532ba922f33406592a83abfdac0caaca461152daa45f033085a1f60c92744fe5717afd410f39e5da704a79032cd242a0bb82b691505406e8408a13eed9365f54143dd0c950e3cd00d0d30f360903821fa7b84a7f4c7e765cf0e396e7e2136b8dafe3812af2cb76ddc8ca704b10375d6f83a598707ae316798eaa466e21e9e16dd42ba32afbcf25a7bfaec4000e9b3fde3f6d6bb8fdad9d9aced6eaeb6fffaa77faa7dcff77c8fca5b5e83f24c5987164602953322f1cf0ae44ed6c167152997ae5e2d129fc8e6b4f4b95a2a0d091692ed05af71e9c3e727cb825fa601e86e08b9487fa22ed8919afb6250956c7a2129cc61a532b03797aac38b60d3e3e4e4ba926127fb95f40a818e216ff1912c05ac80555d3b07ef593bada171cf138e3b1226eb986e1b9b33a69dbe073ed1a797def4d2765f9d687c475c2070544ae9c1b21424842b8535cf9ce218edf913c9c8a084cafba281c5a606b8672d21336471003aa280fd94c6d046ce6490b1f7f469fbea5ffc453b3d7c221c8883d616663df77409083a00101098d2c8dad2e10e577064950571d244fbb03e3d5c33d6b654545750503516c6fb9069f11c38d0e1e17118b256b54f98ee105d84d299d724903bab22003b0326432ad99a2a4bd39957502cccd8fb904166b2ed45f7df87a5ef4d1806eae042252a9bbf742d69080c7eebd7fe878e879520a5ae431c736a605327bbd2b20589331a43809449452562576d6f39e102ba5be5bdeb1af15afdb2a5cbd4841514a9ab3087940812ff8b4a840c140c8ebbb403b8e384641421d7c2fb392b6271109ad2b54ad0d2354b1dd343cbe00e746aa03ab83bc46887395afc3c803ab38e922999cfda64c4a977d50e9fed098b5a8247767a24d54c193fc8fa69b99b3c9719e8fa44f8d56bdf7e5da0f96b6fbed91e3dd96b83e5513b3f9f6bb153e6ddd9d96cffcdcffc57edbbbff3bb3c614f6985dc866e8fe7375372071752e006c72313582690d9668ac5d975b98af8c7a20a9e95c005482c391d72433a7d6500a2d45e65a23bb89db654c907713fe586339d89e620035dd8d3352ba77fc76057736c6594410091c2e442d1366ceb7ea74fa5232d7b784595fd0094db16d3c15283d2a8751290d0a30294d7c890b1188ddd84d84cb64933a2fc028463a1e5ae531cf268e1a9ba7f536554e2b2353b58a71a90b81f41656d4dee3f72e9e180a0ab4930952d186d7c94333c4e24f91f1a0d95a98a04bcb22c52e99f7ce10b6defd11ba64d88de00883db4985d3aee952c70dfac2e422687b59a3963fc32de652c48815e338fec49072f07ab555131d4ace28da4a8813ac78981f2995db8b9b35150e07594e9b20fc12ecb15ca3ea34375789d51db4c59324ca86914cdc4a46cc6b138f85d1e72ad4e62cc9b49f6cffca6e82a528d05b2f1681015d4e077fffecfa924e481266d13f05513e909188990c9a88425f5fe4fb053765463153ab5c388555d1eed1c77fe94e655bd9ec0a3d2e77d521609345c744c1fd9112a0fc50c4782b9f4ab6af62bdd0c632ef3526970c9a4d7ab8074723e176675efc1733a81d8b444fcf04824f84fed8cb018e3210405b4c8cfcfb45094ed30e88cf6d1d3c712e1e31e5196a8cc61719d4f35584c3b1a9b2a4eb1975f79b5eded1fb66fbff1567be3ed873a052f34aae0cd75677ba3fddd9ff9e9f69d9ffca441583619a5861eb585da6c486a5e93b2c1a229281b45478aeb1d0edbc6e656bb163bde2734bfe7740e7154445629a6727fa4e9e2f6bdb2acb9b22336307f9672039b475c3daf1be9c017cd81f7e710e3fbcc4f4392c7e69e1aa09631855f03e9993cefa8cf2628a45495471f8b57ca1ebc369816cfc19400758a07cbed0cf585d1d03a5085e910c4c4a92378957987608a5a9b3ad905eed67ad61c2c98a54b2d2961f01eacb792f626400203a8a3b6b4dc0e8e9e09262023c3c8c21c2e83f2bc95541d6a542d7b4c9a5fa50ec19a7ae79db7dadbaf7db33d7af8ae028764842ee7cab8d4c92c2920aed5a5bf83039f097556553135842ed5b5ea84eb1fd4f926e0a33c3151d790a025fac32af397f619647d4fa7a7eac63168af929ce04bf7b9ca3282955e5bc0798c5dc6c2d6b216389c24a829950baf58ae5903fc3af416c6317a5d310dcce16311f1778418cd2470c0623d12fc079850f0827d8e8e168cecd0c3df78bfbceac278a003f9fa2336d5ad4839a9c085cac1b57918f9109a7dae1bcaf72673c84dce6b6b8b564a19404e3898d2537709f94554e7e47516e0d3201c0e8f57f941ba3e071b586de753d41796dbed3b77d54da1ad0e8d00ac8a3439eed15a6817066061823b60411120fb21bba043c8f8cc54d7028d815281ac88eceb184e160b6065497ae54f9e1db43fffd2d7dad75e7ea53d3b38567792c2390bfaf6e646fbbb3ffd53ede31fffb8a46e2cd102706bea86f4924a293407834ec51e552143e100c1682df59f47ee67c673544295098414409796e59a8cd6169b51074564756bfc8680d5b1bf53d61756a9c3a9661659ac02ac2565bda4ccc11c31904107cf1c842280d64217878c67ca2a09c158261f88ed79c3c86da824b699e9e41539d90928e88d530eb3d009e6a1c17814c85af79ce4c954b52e6bc8b70d1c0c0854dc6fcada096cf0e2bba1b985e63a8fe4d1e387ed6c7aaaee9af0c315646fb634b6c57c24d99ce6157b2e4f64b1f9a5cef9d565db7ff6b8bdfdf69b6defd1c3b6bff758990e1d660ee6641f6efb5b232e87af86b30afb72e6c53ca03125eeb70e1086fa97e81c335ab6ae320f5c6c7d7347c1545818a297042c0de9237a691b2e5c7e38689cd8f89002ce70271afdf592992e026cdfee4bf7b0eeb12720ec9e95e4857fe720d0a85329e8ea0086d55e462ab253d398d1b8c9973059504eb4b4c47392e6c4cb830de694a89b9bb200b1170f233f83696940f77e40cc8df67b53ced4cc503a335d3abf70ce7024af0151940332645d93e1dc5895a9717329d3002f10dbdab02976766fb5cded9b9ab68f3bcae929e032eb9636adf92a0427f4c779302c5a1605f8150f95c9243f6c708523718ad8746c18d9991f1fab04c458e2c9e3476237efececca34f54b5f7db97dfd9557dbe9cc5980dae0ca2297daedcdcdf633ffc5df56c0a270d522844b553ae9ee5892bd18df4a172cd9b2280a45ee43eae5aa2471fa87414e3e1612f7437cad9ea63dcd00e12e92a371f027689e1fe33e735e8c7097807a26d56d84b44a93218720815a191dc18043aa58f32e079dc998e0b828b9927509c7d0c164f0790545525b1b55f00378b7acafbbec9ebea0ac083f88a005082e0e521d7e6404310ae11a3a430ea00671fac070709b2ece53793246131fc55365a783717be5d597dbd1e951dbb9b12dcb7b34e6996b1c8e31a1009fa919c8b189add96fcc47b2a69401292b460ae954949837bffd6a7bfddbafa871839e1678a8c0f4fadcf92ce23b95b4713aa09adc50dfa97c302bd83313083582e0c935a20cbbb97da3adad4e4a7adc2a26e7e7a867786da9737b6501bd646d92a516a5c4d8964078822a107e17d8ca70a30229eb4801ab788c04ad0ee35617d16b2d99a4481ae64de8337b2d2db5c1affde27f2b1e96c0d9e2704cc62c4013bb528ee541672139238a31a8a32ebff47b8d1cf48391467838b92b45cccf73f26663595febbddc291660a2bb2fbfca0abd9f6f8a30921aa65649031768841375f1672ab3f2f55ada99687de3e62d8ddc5c5d59ae8592ecf8f844a9386342d7574ecba5867062eed0c6eaba36e811d2b7221f3a58f1800f8f60b65faa2431fe03c03bd7f0f3d1feb3b6f7e4b116eceddbf7c5b9f9977ff885f6da5bef085f8265ede07ea153fd85dbb7db7ff9b7fef3f6d24b2f292b13ce57843f6559d58a56a9d83991c4b4d5f2bad90800d5ca4a8aeddd6d90da282c24615f95fdd82cc4efd93545aa34e4dee2f01cadab71719df29c289359e4688d89875e19a178459af458b29862758fa5eb5d1cb18c0cf1bedca7043c95aa900a5727e239495205ddf79839c827c01b3f86b15890b15a34ce03a151530c7e2f513924e6e80ea121822b5ba3f9b41266c99f39fdcb56d803c50a7e4b6db436b187c0e5a07dfdeb5f69c767c7edfe07eeb755d44e3544bda18045b6eecfe2f93dd6abbaa6eaa6d98c15ac57995e755a472b4bed70ff69fbd637bfda9e3e7a57fc2db02d493317aca283a402894761fc6fac43c92749fdd37823b23c29fde52349a0dadc1295461d4419e3b23e980bc5cc8243043f505cc0adb5966724b5871a6416eb1ec91f8216b8a2608485a767d619afa57dca7ce0742689247e29c889df56ccfa68b6918da3ed55074c0e51a51bbff9cbff5d476b48896662a771a60e4c8fc09f865d5d222a20506f162b36e06d821b17931247a961cf2b2f91989f4949a048cac62d566ee71158b5398b4bc1a99bf32bd5cb92abe8c063e476e1b35486e1519a81f08d9595898059dabcb76edd919b8d5c766a6c6106910ffed0c5bc3d7bf6ac6a6f1b42e45417582822e865bb389faadc01a7da870878316f376fde6ca7474756b42408cf67f2193c3e3814103e5c438d74a5fd7f7ff86fdba3bd3dc421d5fa1e4f469297e1817ee4f90fb4bff5933fd1eedebd2b20db8e2b980658e65965d6b531818bf97b553fcdeff7b353c70d01bc327335ce65154f165e4e6a59cccb4acb1eda6cae1c382c6c052499164c350b997fd34629ec4cd883f86200b0e8d6174114750602c5c0dc29becef7a92ced290474ef57bcb27e5b5b740d6d10660a876d7363535d4d7f366b56ad0c6998808b5d9a6d0ef6a10906ba8b8bd35b41a3023a3fa34027954d5ba7fb2874a323b40fb033515da0bfa8b5ef91165437bef2953f6f27e7c7eda50fbfd41890b7cccbaa9cbd090e917b7140f69a7dcf7d2b830ab03a675098905cb577df79b3bdfacd6fb4cbd971bb9ec185a373c9a14bf730e4cfa9ca2c73e742dde1f32ec43495192d0d15f0d56851396dfe94c9b36391a409c67c1fbb857d0066093f8cee34bf94894bb072ac8347a5a6c8a613052c3eab702aacd92a81c94ca794a0259b0e06ba306f0dbd24941c75d4cb9436815d812a6e5bbff3eb3f2b1d3d8f5de0f9d7930e916d921fb409672e282c7d5cbf8aac995435f8148b3894846003c9c8527aaa74eb712d541294468effecae954863944a19ecadd2a3cbcc04327a8326e372270616b5832a016bf7d6ed365eddd042b6e019dae9e68548948d719f524400b7a1ae4ea9c08de75e4012d4c88f785f4b6d6b7d43dd40b9351f613870d1767776b4b1a5be70722cb2e0fedeb3f6f0dd77da11165907a7edf0f8549cab3941bd3a392a7fd455bd6adff9d10fb6ffec6ffc8d76e3c64d9d9279b0da589dd30f58960d55d50d2a2d32952d3d5999fe64814ebd525595740a9d2b40731c64322f57d4013cfd485c01d4d5c1abf19f71914d7308c99a6a6047a32e901529515822948cb2f6e29e01eef28b0d7c8e8d58658fa25054b6b0d87c96d02103c0f60cd13e1467c190c0dcc89e083e9ab39373d2447c37302f9df8382d43afe959c7a931c4065077db3c24c914e3e83243ad5356503ac400cee544249d29b22067e3191cbe989fb72ffed91fb7f9e5b4ddbc7d43828ec3c946bb1e4027e03d266ad44456da5e9fae449cbdc4ae0e5c88204307ce9237cca9befeeab7da3b6fbcda2ece8fdae51cfd3066f09cb98e468cc2d075e3bef9de87e601e82f27a58202e89e7340b18ea23f2748a7e4a0dbb5315d7d5e9e65cd3af2fa8c67653f131f14fb816c2428e800cee711c6545c3fc701db952591a02c1f6077564285296573b0f21e21afa7b24bac48ec187cf6377ffe9a8765954082020b98d18b98a1162faae80c4a0f89806c22f9bf853e9f6cc7c1cc5d81228db240ec34e19b5aa9387f1625a13697a800957ea6f4e3c324d2c6678f9bd42f49fda0163a4f2a9f06564c94781b99ddcab0ddbdff5cbb7df7bef01008979491cc0b2a0dbe60a4808d6757623a252a078adb25d70e36133bb8cc1558dc00effcce50b3fce7ae2eb571c8269817dc7ffa549880fcd7cecfdbd1d171fbfab75e6fef3c7cdace083eea74ae282b10154087c355fbdeeffe64fbeb3ffc436d6b73ab3be51df84d69f029c60c6858c096513601393afc3e54e26e1c2a0927210b434e3ba54a2a0f6cb00f75a7d0665aa9d9c37195087e9eca828b01ad450cabbbce2e652e956dd15dd29846e9a6cfce3cf76911bfca0434b48b2f9d87a6fbff078f71d66dc635a45b6d360e2182c67822be0ea5102515a44d30216558e358cc83e78091d86b516ba3e48ea922e02e59a0d19d50750521d45617d264490737b20f0216bfc832284b092a7ffcc7ffae5d2f5db43bf7eeb49b64ed934d49cd90997228426751364b301c59b32bc13db8a00e5b66748a04a483ba5db6c76fbfd5bef1d52fb5a70fdf6a97736ba61933f44c26ebde5e867668e6b3a9231999182d070eb061373b1a9e9e8282620a870a181ae2879bfa7986d7652b2f539223affd9aedd5f89614fdcc8627a06b6d69ed3aa08b624432a23fd70894060a592feff7087535c47b2460093bebc97a27c8cb9790d393535441a0d27794173508dc237e0933283763055069dd2f8252a221199818b312eab32c32a2f9bcbe3e3451373ae005ae13ccaeca7b45195ccd1eaa6dcfdfabbed7e9283135f8253e1db5603bd7dfb2ff92a3893c9b94c62f0dc76df7c69df6c24b1fd48d3c3b9b2a6029952efa019d374e71e9eec8a2caa720357d4e27635a8c3530177622bd2366ed18d511500b684df902a9f0f2a2ed3d7e62b389c152dbddddd5a9ffa77ffed5f6a5af7ea39d8365480db302cc15ce34e609fdc0f7fda5f6633ff2c36d7dcdb2bf09ecd2aa2f5ced7a6027117ef5d51b292d1cc4cdcdc94c5c864c399b4492acec58e5250ceec192822e1b9e67263d780ddb0ec5de1671918003df6ae4112a82300d064a3c0212e51ed78bc81ee318dc5f820d8780ba45c578d77324a85d358bf955469ef27211b0b89774a396d5f03077c77c27702a02874e717847f2ef1bb529eaa89834402b00cf8904b83020701d322b8fbaeb0c50f7b7f0d5ab4b4d2f4c94f9bb3456d909cfe9daf3866eeab86d0f81f8cb5ffeb3b63cc4e27edc6edf7bd04623ba7074145d8679b406e863aed2ab2b336b0fd0bce173f3bd1ad2bc76c6c2fd9a9d1fb77ff787ffaa7dfb956fca75686570ddd684df91549404129b9d802b9c0cde173c304b7dabd228ce54c67242d0648d80eda903b7822d1b740d9449d715c8340a86dd181d430e156629cb3856997ad167c87095a51685928a86e7c43352d94903a23274c40bad92eb0a2c3123494e1a7e39d416a55c25249fffdd5f5197d01d3f0fb3eae6490b68018e11b872c28af3536f064fc4b8d27b153d531ad45dd306481d2aeca28047d5c1652b2ed39aa2f7a7c4cc6b6b621e109be0a448be780d2df2a50501d12735cc778e000667cd37d9d8de6df7ee3fd0e9cbb54ce753051a58c3fafc58a9afae6a539235a944a13494130da9f2753b3e3c5270d74d271b4133bc8225af47cb1ede0ad7076647e43d39c46ce29916201dc9af7ce395f6ad57bedd9e1d1e6bf036e2fd3885b020d9d49ff9f4f7b7bffa1ffd872e3d48ef6536ca06e75ec7c91a7e9301d760223a144a512019959f85d52cf40cd031e7a29706d28a57c984a488c0e77237baba52f99bee8c785a953d11a05db23b6b0ccea9e7a84cdc6339043f0e1beeab3869b3595b25c014f501cc049f46eb2bfad4cdf3ee77d328a9438624c2b1c1781e64daf2f31bb139d02bb7fa02781c9b974e9d78c89240aac3b3d2417545a5a55e32bc0a644b0a562a9bd48a778925214278830306730d908b67341cb6838367edcd375f6fa76776a8c6a771757dbb4dd6c0b2ac9201cda123392f916d4c3ac0d943c89e862028ce66dc7f0e749b688c47cbedd597bfd1bef8c53f6a7b4f1fb5110db21567517cbf04f124b3c3523205249825582681c4b24a70d5ca7eaf02784a6339b55f72ef4cd824cbe27e0bd8671c0df3dce2d9f146c1a695f14be9a5c4fd24930c6d08750bf86dc8f730564507d8acfd1525a8c57a8f8866713515001308d3c0eb49d7081689e268f01f7e401f845cb33ea040bb0a585d1695f18e0a700e78119cf702e4e78cafb8559c322ec12edf9fd25044c43238a044c9860b99d2188d05e2acc3ee5629274130ac44649f40cc27adb5dd5b77db9dbbcfb5f5adad1a66363e81453698107ca970743668f7b2c1001bcfced40ddcdedd957e38418cc0c329217582921266f130bd4f1622dc8a6c8b81d436689bf081d0953a61266fde5e7ff3edf6675ffa5adb3b386853b4e9c178e8decd2fa4523926bd1e0cda8ffdd0a7dbbfffdddfb518f0e50990b5ab4476e946f785145bc74a6f109d464db0c4fc4ef7468700e53452bf04aca2432870a88a36d74681ba37a72659e4c21ad569bc7033c57e7c8b834359416126026cd1332fc2a3163fc1ab300d9eadb85173531074cf6b8c8903313afd5a8f98c38e0c0368d483d24c8a9fcc4d7a16724407912c5e980c37cae4468892744c3de651871a01478d0ced0665571a1baad355988bc670a2b7b5a42c8961781a24ce1c1c34d03d7be79d37dbc9e9615bdf586fdb3bbb6d805f20780e990e8d9ec9aa9a3b0ef2eed64ac75d589a331965c41ad9a9800cbb5f6039c289e7edeb5ffb4afbd6b7bed92ece8e1b561394a3ca11654a6299161b6718b4bf1a648e2fd9b78d70753f8befa1fd55f39e1926175d814c4db420ef63357784e7ca4eb6dbd3c29e6acdd809c88793e4900afbe6d0909271c114ec5d231ba149f40c4d147b2c79ddc1441553d43c2260fddeffb4909749c4f5a722682ddba2bcf743093edd422d45879cb2e9fee5440e7846b2d37f9d04b24c7aeb8169bcc6e060b788392d8bf71167da41d9012560397df453c88de2b4c5ab0e5da2dd5bf7da8b2f7e58353ae2711209bc6408f5b89b9b4a74a7a5cd863d3838e85aeb582a16ef4900002000494441546e9162232983fcb104c806d70a58b0c9f945c0a203c8d710f24306979c8679b2e9f9bcbdfbe8717bfc64af3d7cf2b4bdfced37eb641ab469e14564632b7821f260965afb4f7ee407dbf77cf293c264742f6bb3d17d4b4625d584ea187a56cd19aaacb0d4d6770b3d5af52c726560252762fd2c3f5fcac858b1c95dba06d5f3f31efc2e079a028ef36c238b6ceccb018331263a4c7c4d7c9d65f3a03860784d48975268b8bc122f28d2c60a6c11fe933dd8cca77d681a299f0bff0c800cc39c6744c92d3f428dc8b82453f64299472985df1fb89453798524672041e2dc6ec73d5b7387c95820c90e272a09799d540b6fbcfe5a7bf55bdf68d74b28776c4aed6165b42a0c89f1a8c9daa4ad6dee5829411b99c416e0db018ccdcbe1ab7b272f45e00d0f762bc0356098a683f08d375f6f8fc9e60ef73c6c2c1b30a48997daf9199866a99532de032da7a76727ed775eaf3afcdce73472ba8e3d8719e07c65995d0282ac3398522db0fc6cd7e0aabd0d5410d2f122103a8530460799d5a34e3a64b4466de6db7d4f1d68d9cb219a775dc4cffec6cf5deb21560bb80b5ac57fe20765db556587b82d523084bd3e2fa98fcacade6728912e80debcba59be399507c9e52b365f6a0575c0a14969b44b193b081f8ca027bab5cab43eb06febeb9aa3931f2a77117da4d576fbf607da079e7f49439a9004b1b33a3b413f1d999833e14d9ab29fa2eb6e99131e2e83ca946009006ce42984c825b7ecb90ede737631f5ec53b9153f7df2a81deeefb56de6b5565884d7edf537de6a7ff1e5afb4b71f3e694750139687026565444ac9c133e0922f2edaea68b9fdcdfff833ed931ffb983597d0942a22a8816303ed2ad1953a7b8cc6a33416a34b6695079f132a018b05a3f199a8b556f72bd8811c9be9c6325327135ab7ce05ac966a86d4433557690551ee5d326dc4063147b5d942cd812e33377760c0b952fd3a888583a9139b1190caf4b8fe30a0ddc17663614dbc1f0fe71280b88770ef087e72a416711342e4bc6ded6c8b6d8e1490d541edb80cdd04bd32773ba3676e8c952170801c89f99101564908e89e80c5b57de9cffea4fd9b7ff3afdaddfbb7db4b1f7c4943f4d00e0618656c600a01778cdfedf1a71253faf064950b2d33659eb0fad5943257b02bd9cad09772fdcd57bfd9de79f56539361b7fb3948d3039a964541645278e6a24dc453101162a09c63817554c8213bf6b444a4abec64009dbf0d6a493562aa194e26093e08f40397caf2a27b02cc11ce64b26f3e7fd5242b24fbac4a25719e47a925d05b7cd41a8a0f6d95fff3919a9aaf6ac0f6e8d1ba7c879a3be626408a51da8eeefd4875b64513167358b35627a7d6c2b0f440d07c597984b10248d4f28cbabf62ca3377c085aadb18a4a2752ba3b719526322d2fcb186067e7565bddd86d5b5b37ec927349b971dcce8e902a3eb75b9066a37055b1faa31ec670451b4e007c09cc81dd0ce07c2d35d9833100ed4ecda08dd726b275a794a43b88ed3c231502cda577b5d4bef0477fdabef0a77fda2e48d96549e22e996603914dd628486b3b9b6bed277ffcc7da475f7a510b5b1d3be14f3c684887ee284a9da17cf73293e9a86fbc2ff7a612e60ebc0f2359d950cd03f20c448e2843103221f1b296d1ee32d13304c53c43950455e6f16fa854c8d2abc0780e0048c809765c1a01446d78957f069605cc172e94522b65297f67b0984c503e79d5f522cb553029a964d61d96eafc2e913939c39856b0736357e32891dde1b5e0cdf12c4d147579a28da23b4db38972cc5895006c11a9296d8c2d89707a7dd1bef087ffba7df18b7faca1f68f7cec23edfe83e764594690dbdadd1610df86c82e63b1e54004c693b51f5c50197ee7f96732a983450df98b8c7dd90e9ebcd35efdda97a5172f50bc6cf668f4889c5b0ee00caaeb3915ce246699682966a82beb2c1c524b461d4aad9445a3a17027ca39120011cbcb557dc1afb282ab02251cb3d0a08c1e3a32d4a1b090955990ceb5de2aab4ea697c336c45261ea358b39f8fddff87931ddd30ad7dc54cf3e4924d1f2e6a36ba47f1719d8018a4cbd4b2d35e2100095e55f5c2c45d4f08516df1f60bd8bb60a1e268f7233295d948c55c0a293c1a9213def9e0c0d1b0b3c85c0c62616cbbc2db5975efa48bb7df78118ecf04cc09f44889be1ff376ded6a2ebb6f11222f2fdac9c9a9a466909545a91333546d84f158c03ce9ecc6eaaa41c893632d1ac9c820d4bf8668df527bfaf8b19446c1bf7638d1517400efba68ed0b7ff2c5f6c5bff82a3202ea10b221e88c8ab47a316bc3ebd636c6c376ffe6cdf6a37fed07da83fbf7b4c9c06c445a1526080b9f99c141cde799486b70dc6ec4f67b74166c8a87151be3dccdc47e47711020ec528559b32932b4f53a941bac3b5418e49a53d48080ae2c5ecc24846dd4f350967a722a305fe6af00aba577954dc2f7707fddbcc1ef90f20b6a82793dc90a594b0429069839f4f81ec421696ab0093ab142cc203636da648293f35c50000a9b376fde9296be807940f4dadc0c4d0b4f93822ccd06f3f878d6346fd2c55e415f2dc617a2f198d6c01897f6c0d5bcfdeb7ff9ffb66fbffe5abb7befb6680d88e691e1d214d8dede52490851783459177ec52febaa9b8398cfea58115765abab26bbd1b31c98b7f6ecc9c3f6f52f7d51f2db98f3a2ad45e64905a3e68526412c3dad3da27563755dbd5765c83c2f0e545d4f338d4534a0d2a1b2e1872758c000b5570b93b673939548795395869a34b1f351774012feb996d2654f19cdfa1191b8a60c7c4ffe7fbadec4d7d6f42af35b7b9ef73ef3b9f350935d76db8e0d18839b064cb001371d4813053581901e425a8186444d8bd04d90d204a1568b44fd0f44446a454994284d30d8cd6003edb9ca651755aeb96eddf9de33ee791ea2dfb3deb5cfb1931ca97cafcf3d67ef6f7fdffbae77ad673deb79d2f07328b224091a879acea46732ffc37fffdf28f208304d438a67c1c041730f28679e652a0db20ebc460b36dac4fcac16b4a808ee16ebb1ed0c9b881a392e34d253d2c960d0469495675b8ad47c0f395aba7edc58fdbc86309d32c14d632394ab159b4c97b67fe18a6d27d584b984ee92975cea683af9d3550df84c238c4c97ce73091c85d7ad923d316c2cded1c4cab49b2763eb9e1cabbc04af0270853ddfe976ecf4e848faeb707950c8e4543e3eedd9bd8707f6ca6b6fda71df098052422033c4c0339f5107a8552edb8d8b17ecbb3ffc5db6bb8bc676552584f8395a78ae8d2d41c2b43c44f448e5459c58bed89d9daeec291d30defc70950b69d78b5e00f3dd016d322ba922acb5a70aee8293baa6ea2226e22a9b3eba7f2179e2722c504956d6e976756f0752a0f4c1e49019e17a848b4875e35b85da28f7f5d9321999505076005b485b3c479733a34177ae9192753a9ba8a46fd69a1a8d615673efc2054d32f080039f54b9c92ba3a34fb6ac0e185949d218d7685852642d705d5e1671eb420f4ada524117998eedc5af3f67c727c7b67f9160d5b452ad627d116d4b56c7fe8b21e9c68665c1bf34b6e27bcd5508bc79e0d9ac73cbf8e2d02498c9c1591908ebc30f69eee5fd0777edf1fd3b76fce89e44ff56c8b5008c735029f32c5a590bc53334cf609c86100715490119aa74c652b6e5cd8a44084d6465eddc04d647708d98a0d231e15dae032f9752c58408463e300f5567926cda7c3286d7080ccc6937719d01679cb9e8c4f3535cfadddffab555643ae7a3bd473627806ae927e0890faf29eed49d88f45674f9733fe775a7e35301120b784bb37f4a47d3268ab458f21d293d3c7bb0e79441d33c12e09db09859ea90a4e97132314882fab74cc176f62e6a4c462d72398178640f0a86ca9214ede3c6bb8332df7709113a88d2d282315dc869a6ebe4f850670938154170319dbaa449ae282e16c4c393a3235976c972a9c4229ed9c383637be995d7ecd1495be9b39fd26c1894267256cde5ac592ada5357afd9777cf0fdd66c365c5b2a697cad310d365a6a7644e747789e5c7bcf48b5ba879a9b5b3831550e287e72fa42f4593aa45b08f6399a129af4278b7063030d25b369123f4f191e03e1685961379f8074324ae179482a4375807b35455667e0c03f06ad53463dc6ba16fe135698ba616471e289a583cdada05cc9d2b5c2ddfb50d489a46d861a26995563a325399fcd56cbb6b67775cf2bf5bacf1726d63fd931e5bb0e293aded874b1c993ba868b32f8e1ece32bce3a77a50097d326eb21e4796694d1a1f4e20b5fb3f17428bcb3daacaba34cb63e5bacacdea8cbbe9e0e216b636d8e918427793d57a325b3af781195dedfbbb22ef9cdfe510996717f493ec7833bb7eceb5ffdb2dcc0a916a41ac2c1ae11a6b23171e49f87f8e1b8161cb098295c3799821590f6a632ab946dc61e25609ddfff011345191da59bc6f4a4a2e2d49035fcc31ea3ac4ffcccc0d978fe8a07894ab35edf69a636821aafe5d79bb5ccfff8db677a58bc41e01ee7a55ea204f00b75c25d948191e67a87e9bcf46924a067d8568069f17a7113e23da3b6f694323599536742e4d00410abb5ae6e9aeb18118bc1bf60af83c96864235f913bf3c666731db0025b414960ddbd3a9755525aeadf921142a95cb05ea79bf03d27746e6eb4acd7ed488283b210f13e527016ec5cee36747932ca4ade7af34debc2b5ca156db6ccdadbefdcb537deb96d4b4a0d027e923281cb5641b7aa54b04a3663cf5cbb61ef7defbbb5e07db8d4d510745246621fedec7442060b9fc5703ebde69ee2f7274e5d4aade51814ce39da9c8964b80a3144caf10446877b7432606013e004a42c9b7251d66048f52ea55d0f878cef1d1e1f6b6345038300c5bfb3807c4817479fb94d535aa16ea0cab660a32716225956a9a46e1ef7009a08411cf91eca2efee45042ed93e04db926330831c513eb5b6316de8d1215034a085402326602573addbd96f1e0101d2c01faa934f2b289a0e5d6628c62bdf8f5e7753d8d66dd268b99bb466baeceb9625c0bd741960d9e19a44dcfafbda3190c6fc790a323e556f29e109e9365ca6615f40f1fdfb7af7ee1f33606b6109dc0cb672f01c99a81791c7e09ec4c940f18ef49ff2bc6ddd6fb5278990f83f31501494a6631cb97a830d120112e96f853ae514bd2ec5d4effafa0ec0fc55a9a37b0fdc3ee4b4ac0e706ab95e090d9ab4aa332f0e4232638d411fe57bff3cf441cf5b63813e43e3611e4aef5454bbbc8c995d2114a191240a47e3e69dc44548d6ee07933d62007a6cc775d769de7644466e5195eea549de3ee28654f44430f5cce74cf172aae360029349fb7cdad7dbb78f9bacfab25be1481d115449da8e7a7b52f643201c060b209b02e329e66b329dc0437116e2e9c9bd57c69b56a599b160a8373aee6ea1cf5c7536d9c02e33da3b1ddbe7ddb5e7ded75bbf7e0d0c68b950d277377c691e09c590e7db02cd3f4459d884d867b0958d76fd8cd276e5ab355d72267431064dc84d441775f18a91b9afc1785c16432724e76f2a6ab2e04fce9e5e2d97c192c70f1b292f03f2278bc68b10c5bdc4fbf3898d8d801b882032a6bc65547e6b3ae244a401a273721945343439d0c827501a6a552555ae973b1ac99a5e49eab044fcc6c95f8d27677dd70c8bc2409e081db5b5b325660c3202b5d6f362569ac4984e45e8cb09e0eadc435939f005d6ab24c0de04e6d3ce4c4470431a942c8d6ceada5a08ec4bd74471e7c10213fe6c5c55296be5cda9ddbb7354778f3e64ddbdaddd63c269c143034681bd8de8bd00a7561beb03ae6a61a8076713adf6bd1d54b567b69f3fb1e71e1427e3e9a12e0793c1bd43f5e78ee39eb9f1e0332da7c3292fb0e8e4ddc37b457953d27ef460e2ca70c715f52f9c9eb862c7a22734629a78e5d72ad09c03e825840389158049444d75bbfa7617437a295acb5c6f4d244c978b21e8a0f3a87f328cfcad5e07fa97b9b5c9762bf66fee57ff74f1c744f1bf77c0b51625b20126ae902489e653e2abb341ae317c906f1a0e5d1d9b10057015da78629e50dde45a496b13822d2476a18d712bf1fffee0a45de25535b9da022ce55d9eaad0d598d6fed5cb27cb2d8d6c4f9884de30c6cbe821221d132cdf8757523c3b8937104de8f6001980bc8d9eff5b5b99893a31c00c7e2a4e61a24aa97cbeb842553c01905f0f9e1e3237bf9b537edf6bd036960cd8427793790c056c2bcb3448695b31ad843366b4fdfb861d7ae5e563b1e13030f1a0e484bb82fd5ff80e27c7607d9bddb229c4fd8505af29296f153cfcbf19004f260a07f5319c0e80b4a16aece29467d68c433fb26e01dcc0716b99f82325a1df4d77366caf2949dce341f0826284bfa4444e57b7c0566a8f19e94d5eb804ab2222ac934dee4cd0102286b0b9ac8d6e6b65f2b060f3532d08a5c61c84ea4a2299d773fb8bc994080026f652404b99fb9b263d7a09f097f54169236ae4b003b55c4332acfe29595a0c925ae1407e9dc5e7ded9b76707060172f5eb0324e49288da0bc4077b8deb04abd21291c0e0574d6c8748019f8f2a1fe64a4929e1b257d641f51523122e7fcc354d5280b7517ee83870f6dd8ed58f7f4c8da878f2c9fa56c2600b3579d65aebda3808de618f40cd717630dea7ec88fd4bbd51c865a474ec3d421e0098463d9b12f83fb763e7089d2205a3f541074e5cb3ac4695a70b009f7a42a19b217dd1f8180e571d903b2f0ebf4cc98e515f72a754b79a6bc66e6b77efd1f49d33d16bc2e4c757f52eed4a0b1473f45cff32780462c3cd8b94e4f04afd4414cf65a11b5d7e07a4afb23cd8c12715df69c0b7abc7604acb861c524532336b65e6b257da952ad61376e3e251c032da2c5d259dba4a38eb13841cd59e2de0296c512b6e9839e7028daf0043008a2a957a09b4d9b984db2b9b1a9d9aa5ea7a3b19e41bfabd850c4f69c6ee064ac2e56b954b05eb76fe3e9c2fae3b9fde517be62771e1e26e5888515b31905a732fa4e85ac554b0599599456197bfa899b76e3fa35b5e3a5b12ef6af03e42ad593ba04188e1a0149d582e01087058187002ba63599c75ac02f5aeae89727fd7b90a34cc6ca858a633e613212e939f239a8778a65ee68c9594938119ec5bf2b939292877b1882cfe85e228088ca45e204b12883b3251b35a96fe414dc445fa0f50ecd41aec415cbe47ddc84b27b6b635b5987e45d6a75cb497206dda98c6cb724a3bbe617a5ec523ae3aebc01fe361771d82726c21c8435ba2ed75445a0b479e603284c29053557b018db8b7f45b76e20fc2ccfa153adc94907d6bdb2b16acd9a2d98ef3951642077ca612961601eb47ccfb29631be00ff51a3255169c8ec3456158747b9228a0cff9f11a4f160608f1f3fb0e383bb96370078788504094f32c8fee510cd619dece4c0d7141cd33e0b6a490425a76c9c99cd44f61390cc1adb3a57be9f1d383e7d40a0864a42c0d29a9ccda591369b3010efaaa894dffc5da3448a2fe198b4b209aabed09712cd42f412bab3bff54f7f7115198f36700a10fc721861528e9cd5d641d7e7e40a5500af39a536908c3cb9a10488084afe58ce5120d203880d169d877830e2c2a409eea89315f8525acfeb0a87028ce4d4b3acb5367714b020e989d53ef70e8c4e7471b7c29bcf4b2a9ff9439c6f68ed6e4778085f94847c36b01116128109c3cb4aa5a44d03dfa87d7ce47ae5d389163e0f09e75ce4720f1e3dd2a2614e8e80355d66ecf96fbc6c6fdd7920f0991310567b154ca65cb47291b2b02075c95226674f5fbf6e57ae5db38d6d0216f9a43b67077b382449b8d6680fbb840a24beb3521a671e163c1b492501739b69d64b7a58457795117915fb77f3e7ecae31c960560e448ec9b1b8e2d0a1c4829dcffd2533e5b454593d758d7657fff0719b00dea3c447839c32c09fb95f6fa4feb146b449f2799583c50a52be9e99341beeb527850005ad8615609ecbbc94394e940a929b759a6b94bd3c1d621a24e0261c74b0f90181cfcdc00620ad033c65d7eb75960c113808d82758b47de94b5fd41a47b3acb5b1612d0e1848c8752cb1a0527058945d9a265fb0e1f02c6b8f92d05dce5df4304b600ef9178dc221c4e7d8ad141418afd2f80d0795d9a38353bb73e79e1d1f1d592ebbb07ab560852c2361129257f307ea85e65301b6d5c54391d5d56d8589267c2c1a51eac6a6eac9a932742dcf0c692368c5b38c248275a8d295e9029a1e18b9566b3a40282d2169b356a2e11171c665939347e5faa011cf61cde953c6ac8e64d132bff18fff9e6cbea293171954740ecf28087e323b20e61fd4dd55bcc4483e1067adca3433145d427ee6db33b478cf35c897ca822028722ddf3e77a81b03f7abe07643042c00cdc52a67adad1d7bea99f78a2c18039d2c043775747ba1b0c7d27b92390d7b2279b2a159749c807482781f0883e00ca4b293614f9f158913807532040c25282be806f2c0c1bcc8408e8f0eedfefdfb76707068a3e9d2debe73df4e7a639b2e934965666e25a6ee0b056b96f256c2e52407a605cfab6c4f5ebb61bb17f66d6b7bcb67f83818349706fbda1b1f2eef9b512320eeada46f92a2a5ba78519a23b428e3b33461bf72013b0d078bbbe38ab3d94cc1079425f19b7840e960e17d2253e699e8409a3b1e48c6ea416ba2193c277d7a79c175a8d39aa831b13162dd50d2828d79a69c3a9989200c9c50c1e1a5d9d02ca74af452556a995057d0252740f0fc15acf80c3aa993fd7972b0d6f8920e17387813612a68ef13b0c8e4e2b08c80159b296458747826f7673e13cd84db77eed817bff805ab5600e80bb67761df2e5fbdea66190586a0775c8513563b6071216ffdde409f8100e0018bec7fa4cc9d6b28575dc9812f3706f6e7140d22ee99703d0e906cc90e8efaf6d5e75fb637debc659552d19a8db235eb256bd6cb56cb93418e6c262884c38538ee41103ccd0396ebe0055eecf236be46e23d2358f04c2319e17b11a054e5846e3b4a0eb826d5ea6a36541b751d28bc9ed359661e34a7fe9eac177e97f5e19d40c926faa84e72a60e7c3b647932bff1ab7f57b486c08b62c8553c97730aa11ea882f4e6410b5c4542ca0a463e8b16afa5f43f755f3c23f0dcf7ac4be2995a58b8ebfbc8d5241d2dcfd0ce2428e27715f5976e43ae52889247a31325dbbb78c5ae5c7bd26673ba9d7e7a3a8dc15d770956cc6461cba49474b5b072743d73059120690b375b5b0e02263c44e6a9433f21282934b292c9d8dedeae362819d9d1f181b08256a36eddf6a91d1e1cda1b6fbc65b7eedeb747875d5b648bb6c4f34ff481b995d176a78b54c90b70cf660140cd1ae58addbc7e5d381c4c69ca12d7ccf6ec477caae0b73167668c7af841a2e6491a48e5f385ee926cd74018127131a6e9d9e0d162165eb172b2a90e0259c3bb42839edd9ad670e6bc43c6e23826140534ee21e43ac626e864e95a4d31cb486922e09b409b464aa61243f403d0c9c869ca3f7195d8a0489ea030ca3367f387aa80ba71494113f35309138ab9ef540431e8c1a218f39902f62293327610184c6eeeda6592440e5884ca4232c29eeda831939a1751320d4743fbab975eb2cf7ef6cfac5e29dacedeb65dbd7ecd76f72fb8085eb5668dd646c2d44a962720adcc7abd81ab73221c992ce0b8df222a43f140bb3d250fda2c6a7ef9de8cc31e7d771ee36c51b4c9a2685ffaea37ed8b5f7e419671e2a7e5cd369b15db6e2ead8af20e9311b391f3fc34b84e168e1c4df2b53c27c6c95e72ecf94c1e9b27822a85f69facc4c01a5d5688af303a51998824335ddad6866dedec8ae241b9cebf3949d88d53f039d0b81f586e3e274fc768f0b0d608643807817571a0510a924828d3fbcd7ff2f757e297a4d4d0a31cd13874bd932b705a4c3efee2bc187dadc238c0bb4fbe18dd7b8d85481b5c3b39d97c81bbc8e22911075d46d70d08a4912ef0de6f8a82964e78efe8add342c5bea54d9733ab355b76e5fa13566fee58a5dab022c2ffd2587267dc61320045179d7f18a161853c0b9b6c32119b9df285928e4c0325524a51308766b32501bd7c3e63a341c77a9d9eb4cc4352e5f2c58be235757b3d3b7cf4c8eedfbb638d6ac937c7646c77ef3db47b8f8fecaddb8f6c99f5b2152baa4a396fd55cc6761a35ab4150941c754e011bfded1b5721bc6e8988c86c9ccac2047c726fd6be806960573ddd04b20797c707775310d373f27127ff1e0bc5b131f015368582137c1f89c3b97a03a7a516a264865c835ca77f48b2243c900511045207e69dda10aa12bcb797566ecaea8bd2c77166e036340452d7190e938bf4f969cfdfb956b4c458a7647ff9b2072774f07d568fb5c1d02e1d388725e2b367e419600a506c82059c25827bb24c0fdc94f5c01af00eb29797c40b0d2127b961d6231b08f3d32f7fe5cbf6e77ff1396bb52a76e9d265dbbf70d1f62e5cd221b3b3bb63e56ad506c389dc96a5f3ae2c230df2273140822b6b5b070b1861ea180a2c5ffa70f03a9b219027414915db85b20dc72bbb75fbd8fef0d37fa1bf6b28856c7239b6cd46d1f6b69bd6aa332931b7824dad985b5a29cf38170d08bab4d3c48cd750af7714d5e9739da7105f015b53e64e066c2edc899e9caa14edf195e002412cd99cb86717ae5cd1581cd40e3e031080b2b43cda684375948114c8aabb69be5487439aafa53982d2294470e2055d573d937ffeebff502561709b02a3f028ebbb202cc7bd84f34012f22eb92c5d8cb31320a6aad701cdc39a864b1dd34ad2246b8179d7f1f1d6a96f326917699cc69b01eed0e18b91d7e5b590d5c816bc257ff3a977dba5cb4fc82984cc4ae9f66c62331e4812f7e301a14dbd146130219d2b1376359a4ec48e969efc3922dd7cba4876f4591b0e3b5e06962b0245f952f696b09052a1606fbdf68a1d1e3cb046ade2d79e2fd983a3b67df56b2fdb697fe46a95e2da2cad96cbda85564ddd410078d7ce32718eae5fbb629b9bb0a4ebcab0a4b02af6b9373ea40d469383d338695cc5738b32da0f68c7f9422992f2361a28a234c88cc3415da737d0be77fb77e9e027b717c53b0d5b7b3794e0158d1a0e19de83933648b900ef0427fe83be00d6c7bae0be3b94e0ec672d7458da10341594cf66d1e8faaa5b98663b09dc3285ad79006716934c0b5765c118749152d3c0cbe818bc6534646e8b899bdf32c2228559f181ce3a5f0a5ca9fc151f90c7413001784f861c91b51d9f1edb673ffb59bb7df7963dfb9ea7ed9967de6d85524da562a3d5b48dcd0d6dd476b767f3d94a5417aed5475b38142b56ad3545ac857e1150cb70e04e44acafc06d75349f5363f5064c01d2954d6666fdd1c23ef5e97f67afbd71dfa6b3ac152a047b095c592eb3b48d66d576b61bb6d5285aa5b054e0cacc47c26ec165993ff0fbe0012bbebc5b9874d6281f1391575411d1523c6159ab15abdbe8cedc64987b17aed8c6d6b6d521d4565132010ba6f14585e2a2975eb1cc84310f07c3a4e4265d405a0000200049444154902ab698a6489093b26b2cd47efb377ec9850dd64aa27edafb62f70b8e287f863ff860ad00f59cbbe67a60f956b3cec0c34255808015ddc775ddabd7777d20ca9dc032343899a1fb46e6e5426a0ef0b94b6cf04cc6d3b96ded5eb277bdfb7d0a26ce517225451d00388b500f6b7e90c1e7b18c235402a7f92818dd9b9b5bca2cdbe8544d2632c9649c0740be562bd968d8b5478f1e8b2e70edda356b355b0a609dd353eb9cb475add3d1c03aa78756ab5694a14dd9f4f98a7de3a5d7ece5d7df523b5a9a47b3a9d58a39bbb8d1b01a2274a96c6191d6ab15bb7ee5b26d6c6d24acc3334b4a3405ab14d814b84bd00f5c174acd0a716d3cf011287ca429d11d1295c379583c5b2fbdbc04f1794d40785725f0d942b2ac686c880c9b84da28a543875dbcb054bac7c0b2cf8e25250bb9462727a4b41b3c9878f9cfe92db99b04b2bbd42f7a4e3ee1409323c4ef244353ad48b0cfd53c1d0b225361c2a198c306cc550434e3a6416e07d785614935d3152f295fa2dc0d0c30940574d2539f1b1e8acc0d3ae54281793ab13b77efd89ffce99f58a359b30f7dc707ecdaf59b56ab6f48f070341dbb3f61a524cf42941b509160dd5086116c68ee80b332d41daa9cbcf6a03fd2e6a6448cc3260ec6d887ec151dde395c9e32369caeec8517dfb43fffcbe7eda83dd4eb2be3cc67a5e8007fb458ccdad646cdb65b65db6a542d9f05239a5a76c1303f41c4c51b7916526d49f374a1241a2ee8caf09445f9207604550e247e87e68c264df245dbbf70491967bdd9b05ab5266800ee1b1a69bd4e5b87983767164a2428ff5847829ae456949ca2fce45def81cceffce6afc40893168a675a64506e5d155c91f31953e0250a20a48889ef115dc60065f939276bba5e368bd85ba49eb9ad4f777501caf29353f591cceb44ae4cf5afb7a49db13d556a4e4a4b7d5bb1edbd8bf6a10f7e58244239d92c1801c1ce9b939f120e65858995f2b935339b5a5a270b0bbf54d2c9c817d19e9a1abd22ace89bf586351a153b393a10903e9c0c25a34c1001ff10017234b65b6fbfa5616aba21bbdbdb3a45ef3c38b0de786e8f8e3af6c24bdf740505ba848ce114b27669ab65f5422e89f6f97032d9d9e58b17d415a36ee73ab8af2c1eb5bb4539f020c43530491fd9f1797e5b80da811d460606d0ab6047e757228d3e7622450c2d567f9e5e0a9ee9e93bf8094f26e613cf3aaee18013982438964307bec909185a3f4955547e79a10422bf877376f2d285077f4302d9032aa57164839480042a09c3413095a579b2995b7937c933c2341748460f5d82e008ae89412ef48f54ca9c6f24e979a683183c892da8567a02c139ec7afd9ebdf0f5afd9d75ef89a3df5cc93f6ae679fb14663436a208c08011970a602bec385aa569b5628fa414e1944ab9f59414d356a340a76775eeb0e4a037b22c07e8d31a54a8435a0408a72a87c0a5636e7e0b19cddba7d689ffacc9fdb4bafbe232cb7d1428a5b1b49739aba7ee62d4b39abd70ab6bfd3b2cd56d54a04ae61dba6938188b59c75e06028e90a73d234839b4b289bd272e1ffb3465c5ac61b598e156b22832c3d97b75a133e24a5b14f26703d1cf068d0497239758ff5c2e930d0b05ac26249e4023f8cc0c64190f997fffc1f0b74ff76b0db1768483f248b9ec47992614138fd26ca7ea4928e5d7817293a8aaef0e059586c06bf01619098ca171dbcc9f44265b4a7ec0a5432712008cd6dbc74054827d995ece9679eb5f77de043aabda7d3918dc63d3d54d256f855903cd1bfa28e4668af51affb356aa6cd9d630223a3253e1d39f172321c2b68150a74bb3819bad6ee9cba6c71a92c1097c5cf3cdac9c9898d0670b29c388bdb4d7730b52f7ded457b74786a87ed8eb201d1323259abe4577669ab690df857040282d062691bad860256a341b0f24d19234bcec971503c325a367564be714fd7e55a684bb181e152f16c04747ab6a6298139b8951b3b90e1f2a7e4773928a67ec03804e081d6bbbe67cfd71b1bce8ae767d535423d15526b120f24486b03a58085ba40748229bd48b8f4de69b651c3e0901ce5361d4a0cb0d91d542718c8aebe50b272cd39589e25b914b1bed2e40525079a576c0a9e95fe6343268a463481c8ca22b8abc22049d35002cd8895f8656cb8e3f6897de18b9fb7c3a3437bf6bdcfdaf6deb6e5b2d02b5a22fa3af1b6a032d03b84554d32708fb81f644f5c37dc340401594bbc1fc6b4ae46eacf9befa110c27bc6a890572c9e651314270b66312b7670d2b7dfffd49fdae73eff35b32ce3401bcebfcb1168c8122b5ec2a142ba44f207ca4ed3f65a75db28724030c0dfb7c562241e5716bdb5344f0b444126ceb513a484b5ea90f3c38efd288c0a5182829beaf29c68e8d4ea046b375995f22bea1edd8e4dc7437d36d68aa0804068420542cff25b49ea5aafc02c6458d1918b932936808c157dffe98bd22c4e777fb8a4edfec201a446f61501cb333a887f09d8851f72defa473d7a7f13b21e2d104a3ae80b4a4dbd7c017c8328379d676c99f74c838570e3e613f6c4cda754c2b1994672ad2535f6b18476fbd44f80898bcb055ec74de25a0142c95ed4ca4fa733d7479a0a5dc12561014497caac46e3a175db1ddbddd99226d6a3870fece8f8c8e69389b035384ced4edbc693a9551bdbf6e75f7cce1e1c1ecb9a896e8bba64b9acba93fbad8aed347d9447a9e572a58075697fcf9a2dba62e038c5b5c409655b3448bcd5ee0b28dac6f11ce2cfc01635fd29a6b113671938565626f58033099a0cef2580d989aa410af6b2f1cce016f38bc055b8c71c04f19ea2534828ce2b8bc0f922c3d22146e99a0e494a2f028d24915389ae834c8ec270ec22ebc00587193df036f722749b2f1f5d71a919779a895638782987096e401a72576bdd553b649caa0902fffc9189acef21ca1860af39822b1b980ca963efdcbd632fbef80d6b6d34ed5def799755b1ab5fa0ba9151f0241892ad530ae14bc8c8181c3b2625c22dd9c52219069fe9194387f1f2d8b3c258a3fc5d5cba749ddc17b230546c01ff87d3a1e54b159b89e7f78afd6fffe71fd9c3c39ed5eb5bea2c2b935b707f711672307d321dd8624eb0ccd8eed6a6b52a156bd44bd66a946d36e9d8a07d6099c5d8aa0597eb6674c7f2648c6455ae798fee9bbaec620ebafa82af43c74275fd05f72b2c51c6576a3a484663cac2be5cd0c3f486a6557446b9f77c7973cd0d60627debb9b0a6fedb5ffdcf359a1329749cd28163e9c424387f9b13f4f9f22fdadf91bec6433f7b2dba2e3e5e0276110f244a463d247afb734efcb94e5679af698480563ee927468ef8af2dacdd73279bbffe7ddf6d7fed3dcfa6c5e66d6cd2f64c966e062a922e3dc26680c8c94d76513ee7b390291258589980a291da2a25a7650b30381c58bb7d62fd7e471c2cba1c947d04276e0c627d8f1e3f52fa5c277b6b34747a7cf3b5b7ad3759d8adbb0fedb8c3620d0d716fbf14560bbbb4d9b0ed46d5ca7c5e294798edee6cda457599dc232ea472439749bcb374804467cddbe4e08367e6a92afb5269274269721f22abd27c618a286c4636a5d8cd74a2e486e31da9c4923897657967c8e7ea3cf3a27c387fe0e93012e9d1f93992190a43dd94793bbe14ec6d97445129268c2e79dc61d3954c1134482c4306bcfe4c1811a53c9b42da54c96350413895a1d2f84f0d9c15d90558c968e4300759b0e00ac73b759f24401758ae3b0f3b96e27afbdc4fb2e8d7df78d55e7bfd756b6e3625d807c1776b6bcf0ac58a3d460badd755d9bcb1b5651b5bbb562a220fb4927312644a3864948504ac76b7abe77be9e26561637a26e71c91d957d1c838ff7cc99c94e96af03f63e3f9c24e7b43fbc37ffbe7f6d9bf7cce0a791a1435ab9421d82253c3eb7ab62a02698661691fbb83ba532d156db355b3cd66d9ca3948a743b3e9c06c36b2722163f9329233192ba4cc47e20013ecbabc51034ce3c2073edf8a148e20930ae62fa8ad566db9f2bd369b8e84f5064f90529f521cc7f06818b9d2a9c7a4809b14cc7826bff6cb7f77453acc092c3c26993b28f54ba7a0a462539a1a9993b783e1df84446b4c99fbc91f254b6c1a461d428a46654de2c98846c1e2594c25cec60247135b62220570adac51a18d264b3b3e25381c2953f8ceeffc80fd8deffbb0d52a2ca8898bab0903e383ce95762ee69027fdd442aa975111124336697c26ba8d5c2303cece6a77da42684011a0781d4a4b322cc06702d6c9e181322c58f03c2431cdd3880999e89d8707f6c63bf7ecfe61dbfa2337ad70d75b5f688ca75eda68d84ea36a1558f132f334db6c356d6f0b4992921eb6eb309d292a906a47e9c2e65676a1d93fdf84c1838bec8acdcea92f5269ca92f5fb2c764f98756aab6182e6a82c9f280112f52189beb9d12eb236ce848e93cf3b801eb40237f3e1742f1b5375e6a35049a8cd2182f0b1445b8d933a78473ec3067f07de8fd68fba97c8ccb8c90238161916d88f1c8793489df4e9d574f0c5cef300645f4c91ee4d04d5a4d64a5913d0850e5018e481ab457a98544e65e3361ad9e38347f6f2cb2fd98347f795495fb976d5ae5ebf6e172e5cb6ed9d0b9a9f3ce9b48d0c94ee58bddeb24ab529c35364b379c00d34b26a75eb0f46e2fdf15971a9e1702280b12fc02e6382816be32b08d4de78622d11dc9d738618e4a39313fbd3cf7dd19e7fe1159b2d72365f42b2ada9d3ec18a1572a649870fe982080ba3449862274e1209c568a19ab16cd5ad5bc95725e4202d233a748a69ae5f0831694280d2ac1d55da4ca72ec92d715c4c21a264837dde97c2897749a303ec615d99470bbb4ce3d79720d378fdf9e8844d321f35ffdc2cffcbf869f036077ecc471a618625e2f4a051a3a6d056df00075f9d3d505ceecbb14bce8ba8898e820eb5916168229cef100e467d466baccd9ccf2d61bafacdd9ddac3c3b6c0eb617f64f552d67eee67feb6bdebdd5765e35d2db986b4a60fa4d13417e7468b358d07118cf87ebdde4c7c96a24ef0857953804d4826022f4c62749a27ec5b090ba9222328439db4d572499915e450ca4c0299caac42d67a9dbeba4a83d15819d62b6fddb6fe94f10ab211dafadc2f17cbcb2da6b6dfacda85ad96322c3614a0c946bd667b3bdb6276b388c07274ffc9ac00da09589161a58015a7d0795c31f845ca7294227b692ee3580517ca18c7ef08de1a7035578c2508807910b89899e3d9133cc84027d2cbf24da4f795a9abf3b3a2b315565f11c8888ccabc12cdc2bb777e1d6e59e64cfef882bc4bd9237b78e98b27bb2832743aaac91022b02c27bf721070f89c4d644899433a4c1eb042159554d6dbf10e1647b3297cfb22286893209ad7eb0b304738efd6adb72ca3e16f0fe810469917c4a49767952d90bdfa0034dd3298f9f8fc8d468818ce3567c8403b5248947bce2f222329db603452e611e4edc07c1590c3c753190cb40dd694535d08926fdfbe6bcf7dfd257be11bafda7451b0550e5cd23125ee137828e27f49a3400c7fd63f246b4a3534bbf81970eb5221633b9b556b350a562a98955713cb1b49c0c06c3eb202aaac2b5fcfac2b712539f8ce096d92b1f27a6457cd8d0dcb976a36410575c5f0b9cf96f29982481bcf80001ef73d86e4837ec23acafcc2cffee4caeb51c71bce2f7407fbfc84779a81ab1186cbb28217869b1397aff51be32a8ddc0c77a8f52c00eb6b29672606bb02a071b31237a8c0a9c0a6c1ac9268bcb28376df6e3f38b693cec4260bd369d03d3db59d6ac67ef63ff929fbc877bfcf4a053a6fc814e76c8239aa8c18e8b891d5786746d2bba203107c297f8a4a99d5b998b290dc18941b351a0cb4c815b444f22c4b6a8609ffd3d3139b61b4809c4cc9e7a378f03c64cc15d8648787479ad522bbfada8baf587f82bb72d50146aa0ef01b86916723dbaa94edc6e57da94332ffc56b6d369b56ab55847731dc1b9a42dccf099d98744f1524c340223530a2b40ff03b828a1f12104150820daa8a73970042bdfb44276bae204150e31962587afef012b6c8c697e44a1809acd6765fcae068c624a2a920817442fa5a49180d632e895b24f6bbde8f40ee214b16ef942aea9296d428d0f43f8134c9f502e28273495922d5ae48af5434784c43612ebc51c3d89cd8c91f51f40466d7d2488e32bfc4c122eb8bd118ae8367c6f3624d50e6bf7deb4d7bf9e597edea8dabb6b9b9a1cc9a6b4485949941544ed13003efe11f85dde47c809b40040b9e4046e797ec4a807ab9ac8e32b235908aa3f9150900eb96aa471930e33b655eaf664e89433d0202e9c8deb97bd78ad5863dfff557ecf35ffa9a0e77b86c64619ac9acd6d74ee7f96cc9313c7c10691c01f617f075f46790cbaeac5c0223ce5abd5eb2ed4ac1b6ea652be657361b766d366c9b2d86562ac2dd02071e49b4900a497669690ccfa5a921fbd67cbe17e148f85f73774e22ab526329d9cf85ecba3271a48b24a64963ccf98e0a5cffe9dffe84f4b06201c69f30d2dd4ac8899b6137751ed015937982bd90cbedb28842f69539225e43a501c506039788e62fe656d0cf834d994d96fcc9a22cda3c5bb1e3ced086a399dd7f746aa7fd891d9e0e2cabc099b35ef7c896939e6d96b3f6933ff1e3f6b11ff83e2b646910c35a1f499952251c644ef180126151adddc42d829752c2d3cd9d6686e3be0216baecd9d5522c5c3e934a4918f032565d49ff4a4e3043ba8e5dfd1dce142cddedcd1d0db612c84e3b3d1bcf56f6ca5befd8ab6fdd1617cb85799d70295132f084d5ca6ac582ddb8b86bad72de32d39186a061d7576a75ab962a8647a2f8491283f393321434159ce4a7e79949d03fe2efe771493f9dd38193ece1a3551c87950c3f08441930090df2e877843540a04c76594eec3de3dd81e69e6fb0acb97a32eb70e0dad9e34e8e55369b16b5af3bc78dc02e357b27b13b97288118ac711b75a7fc34d6e199088e9cde648acaf492bb8b303e61672cf05952b9a4f9ef25a0cac5447e5e1fcec948c303b77737395cd4559dcdaddf1d68d8f9f5375eb7376fbda98075e9f245bb76fdbad56b7571bf4eda6d95facc3e36eb7595d6dc33fe2d93650694e1fc2d7d76fe0dd05caa2809ac8e711df10813de482793ac0d6e13340682b074a6c0eed4bd846b05588f4bf752948677ee3cb0fffdfff837f6f69d7b962b9685ad89ba536e48de88f8cd7df3030a114532d0448128f8c8106b8a67c77b552a456b356b562a64ad5e29a9bb9d27e35a8d6c31ed598ebfe71c336666480d935496071c53295553532c6f9902aaa84e4a969c73a25d8069129c8935042a1a39543b546fe8a8057526f3f33ff523eb9230c0f0e0a204d358687f32bb0ca7da3879f970dc78f50c93638944e01288263b79c8813c204edeb4c1a8a9d1b29b59c1c6b39c1db747763a5ad8e169d78e8e4f6c3c5ed86499b56e6f68955ac5aaa5ac15b273b3c9c06a25b3effdc847ec6ffdcd1fd5243a9914e51fc18a074eba399b7b47489d06b9ed8602a27797fc245bda643a14504fc95029e51574981bf48e455636660cca520652164a16793ad203e2fd0e1e3d56902ecbcc6265fdc15081f685975eb50747c7021b39812529ad1125e627dca893bcf5cafeb6ed376b969f8f253103ed82d3481c30e45334beb112d0ccb807595280ecea9aa4fa907b1f03a9eb01dab56ef619d157996402c195f9aa54f6963443c49a3a88d7d4fdf4415c01faeb93d0332f7d2fe92d4503250216c13fd436a21900bd214ac708a894706778a98fc7a0cf25305d43db819f9e89095232f27c0870d28417e7e98cee218c4e189603ff8c79f03d1124f50cceb4dbddfd3948903e80ab937ce5e5222327a7c76d3b3c3cb4d7de78dddabdb65db9765999d4fe857dcd38c2bfaa351a76dceee8b579768c7831b40d86c35aa704f4260a6ab8898a424e9364551c600f9c2f2cbcdc1bc19f0b1931e460ff08240334b17c88d95541789fc707a7f6afff97ffd56edf7990c6628a5628d7e47c3e9e925595242049e62ee864ca3e80a3c6e1ec5e06dc5b02850c8225355d4cd3120bdbac95ad552b6a0f96b20b2b64d193a7133bb1a2aa04680f2ad0d55997cc761ef63e740e3f1034b89f3c34358b9c9806cab2572be15b7477b9ff64b6b166f4bb3ff71f7e5cb40680bec020f8ff60316c6c0c18b870be4746a5593fe115ae43c587f6215a2196a9a5e9a6093e44caa90d710dc03b2fad75e456e0520d674b6deed3cec41e1ff5ac3d9ada588bc405bec000b411b13c1f77ed3d4fdfb00f3cfb94c659ae5eb964cfbeeb99a45d0dc0eb375e25452a41e9e0216607e1b259877c9864471c6b56c9839dfab087fdfc502aa0008b5aa8690add17f3d2aa9aabcb58bb736293f140ed5d3a1bfcdefdbb0f1286e7d6608f4e3af6f5975eb3f16269a36f694a78d012b39b8c63b5b2fdcd965ddd695925bbb48ad409ca56ad37942ed798c34a582037918015bae7f170e3f306d81ea5c43a48a4928767151b53e769a2a2ac71239110c3fac987dc290fd9141e9c5888dec25e66bcf54ea320c659ce322bcfb808f0a1beb0bea6e41a1cd7a6efa7a68723acce4382c12852289c2b3500285b5d274ae56d6a2e10148293a6d6ff1a0773e507e9b5b34ec5b48f519d33313c95d4a9337816b4722a6bd05003b40766383838b2478f1ed9edbb776cb69cd9854b17946131822391807cde5a5bdb36e6709bcee4624319c49cebd6ceb60e2cf87e2eb9935510e3bd21a1fab895d7c29ae14456653cd0fae010647f39fd8112d81b28647d347f08ea6a5fe0beb46254676577ef3fb64ffdd1a7edf65befd8dede45655fe0543bbb17ece0e844cd8c994a76baee0443a748a062c1e188e30f252df795d1369a2ce55243873b586bb998b74615ee2083fe2581f465280f20ce8b9e813c0bd8a1f2c9a0de0045c5a561a894cab96a1a364f58aab89667445f8406d50c5938d13402e8ba79474918c4349d4c094c25b565b14a1f5a8e2cce6af574fe4c89416e2b62e1425d704d666e72260326e4dd0c2fbf96365be66cb22c5877bcb4f6706ac7dd813d3eea5a7f38b3d1c475a300340950948f600d2255661656584ded07bef7c3f6e39ff82175066be58a30a662097ccadbe86bde11d3e833570fe0dae46996366cdc849d2dcc295cf6973adef59cfa5226e5337e0b3bb73f70a1bd0a78c954a27d4a5153676e329e4a4a86d2a9dd1bd871b7672fbffa969df6075aac1154b425615ecb312763e40f9bd58a3d415958ca5a39474951963a411059d535aad79c959e88b694652a7dc29c32459dc85a02a4e5ff47091625a17e2665c34147889fa732382bd7dc323d88bca4eb04137593530790122fde436315893dae80857247c23222f8cb8e2ae48812ff891813259de61c53479475c5282b014bd914f231099015d8cedfb19fcc7bf6ccb38700eb140ac73b581f72ca9e71e89c1d663ab8120524d44644d7903a09e6b0d05f1817a10b3cb2c3c363bb73efaebdf1e61b523fbd7cf5b25d076cdf68aa241457ace4c27dfc7c2157b046aba592a7b5b9a1e70d6e453714bc17ec8dcf0c8e05c1f36c1a84929975e8e2908d7a539909141f82087a6ce05932ff4d6a1a64489a47cc16b58fbef0c5afd897bef29c9d3c3ed4d0f6e52bd784a9365acecd82df586b34edb4ddb66e1f22b68f357182d3959e70ef545cb8bd173f6f4b48a8d0479c4b085da856295a498db49935702a6a94ad921d5abd9cb312b4094ac50c52d2d08678fdacee53a550b3cc423d6257a2655c2aa9bc704f90bee1b091a06392e90e984307cc3ffcd99fd4f0b37334fce46431505b86d2217835747ce7de3877c59d3590ee704b6e140d08649c321c24447c59ffad7296c9976d34cb586f34b7d3fec21e1e77eda833b0fe642a1d6ccd5c292e3b06d5efb5c95ad706acb4fdf3cba97df43bff3dfbc40f7dbfedef6e28a091ad600fce358141493243da4a48c852123a9396cfc569cbc21078399fabadeb9cb8643765a6f493c08732009f8dffcf8cd3e9c9b14d47389b9404888381743a6d3feda1825036b4bb361c4d95bebff8f22b76fbfe23f163648ee937641de8f99cea162e17d62a97ecc9cbfbb65dce5b39c742702a0300b373c39656ad2384e6ed63d109d2a0706447e7cb2c5d531aea3d8f67718844400f7bfaf30d1665d792ec7537658fb23e364280e37755be248f3cc7c5cecc5a295dc848a2054da61ae5152f257c8876c83991488217014b0b91d72300419f0198ae5425c4276644f2559488a1866b5db2c4b38b34382dbbb26c72f7f1a1771f0973a3542968128c92ca08a520efcf67884c2b8298d35bfa821618ca3d3a3ab1b7dfb965ed5ed79acdba5dbc7c51c4d146b36155c8999c25c592edef5f70ec6cb6502b9f8d8f7c337900e03cd0c1788c42828f1091d1f86030fcc1897e8f40d9691febcfadcd2d8d97b96558d34a65d8efb8958f5dd513e13f263550bb9d2dedf1e1a9fd9bfffb8fecebdff82bcb6bfc2963bb7bfbcaaa4818b677f795315db97255446932474a48f851343a680a8c11bd8446c0985ea1a80e22e339e5624d0136c6865015c13c85b21bbd31a81b1b0dc67e9ad62866ac98995a350fff6d28b22a07872829229e422bf2b13d9f1f3cb33ec34374dd6d4e6b2c28553a4c7ff1e77f2a5160ceb856d13592f36d2978203e7e1143c9645e3a999dc8a38d8edc079b6a3a5dd9604ccb13ac88d26f6507bd99cabe4e6fa2cc0a2e5f369f957a27175d2e55349cacb16691085db94183bd9475e5acfdf8c73f66ef7fcf3376fdf2ae4e4c0216378d5349250e651ea937e5481ab40ed9933ac604858216069232d01604106610eeaf687112a028810958ee0ee39a3f08f2314b28022aa70427d1144070a4f115363399dbc9695f78c1375f7bc36eddbfa76b21539085381995c8882b9b613e51f06054cb67edd2ce865dde6ab8cd17c3bd662a0b5d42d7953f7d817b9b5af81ab8e1b96c85ef697c26059bd88c9e529f5792253024d1c544548ccc9a03ca477792c1669a4ad06748e57e648bc2d512cb9c8c4486a96911aabb26be8f2b8eae3934615270ce8a4c285552a390a361ca9e981564ec48d6560aa267260540108ec5717087e2842f7a74b994398251cea6227ec27e57c04d7655e70f68dd5f4a5d32e614c0a4f79e2ccac8443addbebdf4ea2bf29cdcdddfb12b572edbdede8e355b4da945f4876389d55dbd76dd051fc793a48905ff888397ee5e59d7ca793f4df7157230a33a5e9ec1fd5bda60d8b507f76e0bb302a6017fad561b7457d2c0b1d383506dd5a12139968c388a5ffcf2f3faefc1834722ca12d0100468365a3a8c08fe30f06529b65a89610fe54206ae96b1d3eec01e1d9dd868826cd3a6aa03264c267deea9fb13f22c680a695fce9830f0d125aea558295ab598b756b560bbcdb26d378a965f0d6dd83fb115d32259388360a24c1ab89207ec379a50727d974aabebf09df7418d35a783f957fefe4f6b96509d28e43ad282892183541b0000200049444154eff946f0ec0480344e659de2685f817588254daf0ed62de262391b8c287d0a76dcee894375345858b78f29813f40f781731505783b39615e3e9ceaafeb4e3e9405e562d1369b25fb073ff73376f3eabed52a9422b870906569ef265e8ceb796b781b95512471d34438a4cf285f1cff71eba429b2bef399f598b4571b756eb50a948ca2ecbc58c8e09d283cc449c886a0d5cac944a9e5c1ead4fa83a93d3e3ab53b0f1e587730d4d882b48d5286c5e7d45c1add5d8d35652dbb9cd9c5ad963d7171cf5aa5bc3598eb33f4c9214e3a86c7f5ba62830fa17ae736296a9c0b30414b89acf27c70719bfb3391bfc874ce6769be61932a294b464c4a979a09022787486050da68c3d13a3b8fac4ba26e1c184971747d1d92b439b369d73590891198923fa2869a25a5934fca0b9826b8fd54ccdd71282a585342268f4ade43e769a2cd480d2005a1b07397d450cada0257c3b528d6453492d848cb29261a23b1d71f1e1c08bfa2e3b7834e59a3ae0c0b2df772b52e67ea8ded2ddbded915f642778b7290d942324504fff45933196bd45be2198e47f8309e35a7b806eee5b0dfb5c1b0a3e60f04e966734300be0edef9541b9ac39d911e351444805d0a74ffca73dfb0e79eff86ddbe7b4f872dd2389458add686021f7fafd65c0d82528f4e77a99453d9898615c619bdc158a6bfe0667c865cc60f797909c8c19c8e254d112a173799612d82dd2ef205ab55ca56c030a45cb0dd56d5b6eb652be4a696cf10a0e8e413fce84c4e25e1cc1aa9622ee1759b1a52718006061ad59fd6fc3ffde5bfb736525d97834961f05b748f1218160b5de9365c16494ad0f1e3742ed87096b1fec4acdd9fd9d149df0e8f3bd6198e6d3c41f43e71f7d918500e66238d09685e4980af89a1ee0a9ab47c59c880f60b6b9473f6231ffb5efbd0fbde6dbb7bdb06d585749f1b09b93336230f364605bc2c746dad1698020f1729147854f099789fe94c027c6e0eeb992241948283d4bcd76deb7d3427584a416fbe900ccdad5bb73cc0351aea224de7397bed8db7edb4d7d5c3a51c74001a3551b0386ff32fb3744f7ce3db62667bcdba3d7575df362b65aba13c60a6b287d2305270e13c09138ad288d7d6b06d9849a461e735669632a8c0afd6e5620a1a91a145667196693991548f2b8d748403b23030ee07cf3e09f50586141c2c27abcedc453a05178d6d25b268042d9e0df36a947ec4727192440908e352a089a2ad2827922a853e6be224856eba072b3a96deedf34eb67377c8aea484c9612b7511a7d3c467e5b9e8004a06bbbc9606a339c47a5d3b3e3db577eedeb3dea06f97ae5eb14b972e0816d0465573c0e719a12c6c6e6f091ea064e3df6a8d9695aa651ba3c42ade1324e48a7c0bb9af64ba2107c466a48b7af8f8a1158adcff95754ebb56ab616306f114be943b41433182fe023b1fee16e36acb55de26b3a5bdf1e66dbbf7f0a17de58b5f4907099f352bbb38263d38dd655fb75cdad1d1910221991c7a70fc0cf003d93d5d432a0ef64604af31bc3ccb580f51003ad662cebb8fa3acf4684ee15a9d2f592907309fb146a568dbad8a6d6f302582dccdd032cba12db4c7160a6e3cfda042b056655c9130e7f5b34d9055e6b77eed17d7014b25d21acf02f8f21359181069be52bfe033b9f2e810a17cc32538679de1c21e1e0dec7830b7ce6021cc6a92862e4783b62d67b49869dc105999e9a29dea0a02949f96212da7a54cc00280a6ee871f35b7c5f8d49ebebe6f3ff51ffca8dd7cf229752ba8a3514ca0ccd22940d72a49d288659dc631387a79c05c3f6a91042d3942c3366e9f48e278677757e0367c2bb4af8e0f0e6c361988dfc59c9fbaa6792fe3bafd817e870ee43bb7ef2605d2acf587737be7de7d912bd98001629359adb32b65a44a19b4717868a88e3e75e5825dde6e49e79dd291133424550214e773448324c64ac005228005612f3a80118862603d024598952a989e63a8ab3c52f679a6611e4d839018516958f41937eeb782661acbd1df93f615dd219a1e7c45408881f338f414e068e624a912162a80b0e499cb152b72c2437c2c396d21a62708588e7bb9f12ad7a47b80b450c24528eb04da26ebb98c326ad698973f2aab5170882c2cc65fe8ec0ed95013c90c1d1c1fd9bd878f24f4b8bdb72b4999cb972e5aabd5d426c5d1990cb15a6fdafec50bea121e1e1ca92902f04ef6a526099db40292445569d1cb1e2f655891d911608f0e1ec950022846cf133dad7cd1babd8146a7e219c948b654b26ebf9f24c1c9880bc2a45e7dfd75fbcc1f7e4607377b880c19b2e9460b1e58d62e5dba64a7ed536b9ff66c8e98c072695bdb9b56afd5acdd3e5646bbbdbd69172e5c101bffc1c1912d3379615b241f9d5e5f16661afb828a21c9659283b1cc5fb2f9ba954b4dbd171e05b8426db52ad66a14ad515c5a15ded672aa8e623103b403dee932d51c30ea7e02cca7f1a9085a8a4dbff31bfff54ae9b84e356e1075eacca6e0129c58ea86b90125a72c83943364918d36aad97055b693ded07ac3a91d9e0cecf1495f43bfa48e60ce4b5e97289a7ce134b6a12e139bdaf5d6092c9245ce72b1595bcea96bb3561179b26c99e558b4861ffb91efb78f7fec07ad5af5e164ae497404e6fb927a61184f1268901609a90bf0248d344070cb981e0edad2edd3533191a9e545349d4eecf4f848c27c6c00322bd5eba261d3410203ebda3d0293b4a596767074ac147bbaccdbeb6fde12239da0c80694357aca323cbfe2f327196870200d959a5ddcdeb2272eedd956b564b9258616ad3569d4edc3614f63b3e5a5a43772cec650dc372fd981698b7cebfc19275770e9a484919c6162688bd7e39a23c8f96bcb6f79cd8a667c8475115981fbfda5193d0e36b21b058c244bcc1a4ab410ee5d8cc39c0f1222d2caaedc4d31e85411103123654652d48a6433a792500d073f58a3cc8a26022425f1ebc896e65056c65ad7c2e41284216d28111c49365443a6195334eff9dd850ec141df657cef3eb86f0f0f0f0c63d8eddd6d05acbddd3d052c89d641545e993536366c63735be5d6c9695bd9071c2659cd53b6a76009339d834cee3e12c0a43336d3f374758b890e510e5c0e6bba9070a67afdbeeeadf4e5a5544223a6209ea09ba4e2489db76fbef696fdfeef7fcade7cfd75d73d5367d5bbfffc0ed3181b325b6958abb9699629da44f40f3ab1251b0c07d6ebf5f52c351e861e5b1121c5a6b2af776edfb676bb6b0b0dd0e76c30465505bd36f4b4bcb39ccf55e4768e5c0e7393320b56573167ad4ad19ae5820c3310e6a59b58c832fa33b3cc82a403d22e0110d8c81b7bd174d12185557daa1e650944bb910f4ad683a01e96482c040db466582c159b58c17aa395f5c74b7bdc99d9e149df8eda1d1bcd969a359bc811187d1f16775619435623216008d4713e430676e4f35ddac5b6c82e04f21153f0f9c3928a0ca4552fdb93372ed9273efe83f6ec334f691c40869830a8c548473581993eef5ea2d92e3964d96f55ac526b7ac02173c1624a66092e8902994fb21be381b54f8f6d38e8e9b511e543ee8612847b01eec0893f9d4df4da4747c77672d2d6e9c5502784d1f6686e6fddba7d965144eb3e291b38199540eb1b256475b807ad6ad5de73e3baedd68bc6e8370bc40994b094dd4157e31db4f1e9b871df5269b32ed12809635c2781f25efa38cb5b1dc644ce3bc3097c685981f43ca095fe1e166f91bdb9aa90533522c87980f02e64645b04b300e2834b13990481268c290440a62c8f4e9a1c6612ab5d657b0ad652164dd72ff58644640e1a861c84d26c20259d48c30cc5a72e224c77ee394198ca8a0165617ee093912d8ae38456d644846570c987878fd5f4a04bb7b1d5923b0ed94d341cdabd8ec89b28336c6c6e0907c2ca0d0f42829748be6491123f6480bb28296fefb83b2c203c350d9f7318e23ba06c12babd6cb64aba5f605cb211c346abd21089742875125449e6365d987df5b9bfb24ffdd16714f4a021e830106196113a663e5da286e0d46a6d5aa3d152068786d6ceeebe757b7d3b383e9538a6e4859825ce99356b65bb7eed9ae2c3e969c7deb9774fef37a761914189c1e5cfe56c4de92fc10497b85110930cba59b3dab00addd17ad13637980ac85b2903e9746ab9d9c8324c9d40fd31a751a9c26282a5e4f48fccbffa17ff6c151221f26ae3699e4be301f498ef5b41f884aab08047b5b2a3d381dd7b7c62fd4946e4c8211b3c9dea2c149d106265f381b3863e3a1c1431be13eb1b063c693917c5031bc320e7f444d7088d225aabd9957df0fdefb14ffee80fd9958bbb56946983ef26b0263204cd1c493b274564ba96281af67b022cab8d0d57694c98d76c3c52298ad929209f4ed401e4d181660605d2d28acfe2d83bb46eaf6bdd6e4fd94d80f8606cb4bb1f3e7e2ce90ed8f9bdd9ca8e8e4fd76dd9080451a29d0f58dc0302967e864c2b9bb1f73ffd945ddd6e59a3805389137759a0eada8299a46e9feb17bb5fa032a1242bac21d41468c4824f98574cbc4739216a47c8d186557932fc380fa87b20390b72deed83719d1e40c27e82ebc5cf6b9c653a134618a56094af71ef22d5d7664da4416dd0945111a0a5df8e781c63590a4e9e598a5a91c8b441148ed7894ee9dac024d94a715d605564d76a162d99990b5142cc46dd38c39d75c652e1e8f547767c7a62f71f3fb4aded6dbb76f386359a7509f391a1f8f516ec107fcad94cb65eaded6d65f4640760407c066582cac2965616c45150c08a83c4efd1548da515b855a7e3da68c9a55c19e16266c707876ee4bbb3a352b85028ab5ca6e4048ce7fed099fff2575eb03ffcf41fcbe8176e64746a3db013ac9cae24ac97cf4d156519db686dda956bd7ad56c34ba021194a18fe9dde40418b6c179a0525f6f6d696022555c683c78f950133463519cfdd724d072a8c01d72de37a9dc3e7fe0da56ac99a0da639703bcf5a39bfb08d4ac1366b5417335b4dc796cf9161529db8a7a22622186cffdddffed555184bc82a1c3551e6df527d0fa03e59e66c38cf5a7bb8b0eed8ece0b86f27ed81645356d9ac757abda43fe7001ac4cf2280bf26ba5de768becaaaddab8ebc374c9219843390357728870c5f940ca792e95032fdd00f7e9f7df2133f6485c24ac1aa54f2520b6a020bac5c2a2a4069b32c673ad95808009588fd03221298c0175808706cba9d53abc3a952b070c29e26ea9579b90e125f94050fefddb1a3a303658d2cced170a29186f1786663b2cae9549d992923183357498dafc06ba22b25d09a8682b2415f9bfc4f6eb5b41b17f7eddd372edb56ad24954ccaa2287d246617a560bc7e3aa1c3dc9372297846e70381dc71ce794a9e615b7ed247774f6579c2a32238687c394c6b65fb15d21f8e31888b251997548e25cdab78bf088c8197715f782ef1bb4a7cd3d47e94beae05e68a1f900dc9823d9f733e173f27903a4d36a801904acb3097109d222975501df03364de64e5b98c0fe7a3922983d5847bc11d135914adfe4e4f871141ebc2e54bf6d4334f4be34a8ed0626ebb13b5283273c89818a96e3b60cce0b34c4493557cf2b9f471357c05fd9e4696c6ba832e03879103d2691650545c9b1ef1bf7ea76bdbdb5b3229f51219a101acee966a1801bc4f17191b4f96f6fb7ff069fbc2173eef86bd79fc0f99a9f5512a9c854808948de22b391b0a3396294926e706127bfbb6bdbdab0c8cb311e5dc05985236635b9b9b326ee5b0ddd9deb24ee754f7b0ddee587b80a51b592b954149645a9576391462e1d0e56d4a795c01cf6a8a7359c91744402570512e56f87b1953dfbead1600f373edf972999890b3cceffef35f59a9ab221303b8060c48524260179435e854edd1c20eba633bea8ead3b5cd869878dbdd2c520474caaed60bcb7fbd17d02fd070302176023905d428c13d934714a820dcdef4194c4d9a40269b25ab6dded1dc9126fb4ea76f3e615fb9e0f7fc82eedef48888fcea286234748c18c6da3d9d483edf6da4a9de908f20058386458d00106c3b1ba3f044b0256e7f4448aa5f0b00870042cd2714e5b1e34c189d76761635b7f72f858b8088b9b53e7e4d489a2962fdabd078fecf1e1915acbc22c429af85cf612d98d6f5c10ba24b193221b1d957a316fef7bfa865dd9d914c3dfc9bbbe49d7c07a524090555ab266135499f08ab5fd78f2988bc0e949591a9dcabbc2275f5e32789055ec4c407c00fde1f1b7ce0ed38ca5026f02dd358b968c28a2bb138128cac420942ab89c2b1d7dfcc737af303a3867c93946411a3a036b23b9ece87be7f4d6a21ad058894a41ff2c2a53197e665d4b969aa90bc7e8343206676be60750e8bd8bb602c37d3c56a6fce0d143cdc25dbd71dd6e3ef9846d27fb2ec64708326225a6ac767367cfeacd969b67208f836d3d1415684153d75f13e0afa645e2d2a9ba76fb33826a6f38b041b72783ded0ebea76dbfab75addc5218169c858c013c97ec7d3a98de98683276aefe6eccf3ef7efeccf3ef767cefe4f645b02095f64657e88f2be339bcc9044f26612d90fa3482e7059b2edad6dbb78f1b2355bdb3af887d0352c2fc14a680cf52a4d84bc4427e131debbff58741eb1e2d11783cdcf3a4b52d160937d2a987cd15af54de178cc5d82e3b1fe110b047cdf6c56ad515a2878e5654f3697416c6635b5cc6ffffa2fac68f38b86b9628340c32fdb7096b50e122f275d3bee8dec517b601d22e8d4a7165da1716583a147586e80cbf7c27866c2df05e966e3a1b227fe1ed3f21ad8cd2cad5c40540fbd25fe3d6bad6ad3ae5ebeac6167b4a4df7afb75cb679776f5cabe7dfce31fb3679e7e421b9d592b160cfae8bc2e4a9f6c14cc4c596c3c58d25c30030256a55693605a0c665202768e8fad7d7228b09d36af58ede3b11c6f38bd4f4fa13474c548674abdc7d0b384c456e293dd7ae78edac8808b6fdfb96b8f1e1da226a50579d66df3022db289b3d2d087a1f90a6a010d04dca0df75fdb23dfbe435ab225e97f026944ef95de617f5f3e29e79a0894c41d482b479f47e892fc57b7849e60132bac07c3f30a5c8fec8ce22a004552202d6b77ea6a4169a8208ff16e325ead402be274507fe2e4a43922f3a9f79296026495d651bacbec4008f2c860c8b0c316448b83e70bd789d75a733b1dc231093a188b59ff03b0927a611108287ba5a6a3ef8f5f13a64d3040f261b8e4f4e6c40f65eab5ab3b5619b3b5b76e3e64ddbd9db132d860d4a3091b5682ea759bd4215579faa8207014b9e89d9ac680ee4d4ea7ef1fc7205271f834bd169cc9a0e6afe3feb8ecf069999f2900c66777b4b8c7809ee412792461a86198c49b99dbd249327733b39eedbf35f7fc99e7be179b9f888afb5a08271555a49079105caa10a10c73d44c566170730abf218bc2bc8d58ce9c1e27ff2c977d92a5710be7778722c1885a6dcd666d39a0d27c0721fd1078382c3214e968a62093a747eb0b21f0a72192a956b8a37e0d604698c57b81ea65a9bd582b5ea55db6da1824a277d65c5eccc32bf8944b28033a7266473154d751f9c8eeca03315fb75345ba99dd995840a4ebf3328e572d8984c7a1a740d15caf59c5a72870d7e8c5a970491c4965f83ed4b6afdb25dd865f27d433c1968fe9dee89dd7ae74d19937ef2c73e6edff391ef522497c4cb6498f84d4be163ccdf4118ecf77b3289605193ce8a35ab318f8ae6b1f8596605395127a39eb5d162976f21b5bd0700ba8764819046198f90830e81633eb3a3a3434dbdc30ffbc64bdfb4c168aa46c3fd878fedb4dd4bd9553ac5d3084a6426013c0bbb50bb3a29472a785386cfac946518ba69dff5be67ad512e5a31d118284f299165eec04070b23c0bd916c9062723d424d3a86b098d2ff1a2248d7c361a13c1324ac0c870b83e368e88a2ca64ce30ac20ab52d22a4b92db4902db93f389c0fd54f3fbfb7a56aa922c5108b8ae70fc2633e2e7786df0aa905ce167a4b8ca7c603a0cf5334981348264501d28cb0896be29c3f17ba6725f9f3171b142995507ebd44b44ae918c01dc15de1187d7e1c9a16d6e6ddaeefe7e725a5eca8a1e4919be9034bef5f69b1a35c1a51b9718ca3534de35ce04584d872e79fe413286c049e000362060517a92d59365b5eaf0a428453b3a84803aa4bcb9c49dda47e574ff2411cdd4867b7992afc3c653f36732b3cf7fe139fbfc979e5329ab0380b19db557824b2a05d01fc44c0d9d9311f914b212129e2d39b7e821e3a186c8d99f4fbdfbbd76e1e2653b383cd6bde23f056179c28df59e74477777f7f53c315ced0cfab6b3b3abd7c7e085f0311aa3bd56121563309e58b182c76449381e149072118596a295722b09765edcae5ba39cb5ccaffef27fb1c29518d2676740872f2bb6ebc149cf0e3b53b97b508f921a8f26239fc25fa0833556b9077d206a658178e02a9000c108d4c5838a3fb352feac846070939939403c8207e92e5f9dd3816e68a54a8a4aa7e6c49e79eabafdf47ffc1fd9b52b17f5b300e3b4c0350728679789d5309e5ccc3d4b9a8cf57ab56a4365a102694cb5d3c2c6693abbb2e96864836edb4ebb1d39e0848406810bf2285aee447b0c26467d94478b767a72aa3298d9acdbf71ed8c3c770740ead376480d3bb501100a2dc3a1fb0d61915cd8164d525fd8654ae911297734bfbd0b3efb68bdbae44ca481199241927275fcc55f9a2f36c8e2e94f3921c1ce439100882f1cecffa40fa19ee743ed389922cf859e79b05dee1092c26615ea92922fc4a323d3e08ee5d3a0f58eb6e61cabee23ee8da52d754d927daebe9ba343ba9c1322f111d7487838502a983f07a9d540e6ba83d3237dc8ec6ce4e5746977458e8eccab95acc78271a0b7343182e7507353b280da6a99d7618c5e9aa01849a686b6b539bb0da68880dbebbb7bbbeaf77efded6381984d1ddbd8b029ca1d5d0c52340c9f0165141e14ed9c44e6734e7cc418a4c46ddf3cc4ade01dccb9632fe9ed6385508581301976bacb79a9a4f043cd7b88c6837dcc39c0d08589f7fdefee00f3f23bb310206c16832f66e37d9b23a6d5a235e2d089ea069231143cfde95a123554ee5238f4f5cd409e880e039dbdfbf643b3b17acb5b129e2ea69b7273641b77d242a094112222a5f1c2430f6798e54328d4acd6e5e7b5264737e9779db4787276ae420274419e9f6f454590859429380809ab756bd60995ffaa57fb41acd0ad69faeecb83d9661427730d1d023338abc2176efa48dce919ad87c3656e07247194e00f7e8638e8ba8cc89d0ed7445ee941c0a1802268d799fc3bbb0b76f9b1bd4b079fbe62b2fa9258e6169b65013d8379ef4242cb6b151b34ffee8c7edc3dff9410dfed06e467665382198d0496350ba671b88de954b4ae949d3199320b5ed74ba22cc556b3898b89c2fe520027cddd31329867273f6f72f7afb591d2e3a45232938d0ff467e06e71dd63f38008bf9e8a86da3d9ccee3d7c6cefdc7d28be1972b462c5a6322f4ac1ffaf9250227c49d3dc67b49c72818f737135b327ae5cb4f73e75c35ab58ac4da682bd1458a59b828e57c1166a538c922d318504acbf9bc1124bc2be824d10874112478adc0ab681ef0f79013723ce84cea7a5d1626050a59bea7d1a7c89e149032de853acfb7f24de2f727661ef5bd9533a5b9460046de1fe268647888f9013047a0d69852d25a8b1284d7235306730c25534d31689ed10f079deeb389c314c9e22bb4dab94ee000c8c0ac77869ca130dc78e209718fe03a51de6d6eefaee7f082487d727c205d2cbc31a548206fc7aca1e01119295957cc7ea240ba9e252c97758f782da83258d411e09801f42fb727a374e39ae99601ece72452e8165b4c23703f00e017999cf57a53fbd3cffea5fdf19ffeb14a2d46729c83575e8b19f03a6a4a48b9c30f36baa8fee50287de88418163614b4d1a646d361e0b96980e917f5ad9fede05dbddbf24463fbff7f8f163a9f2920d629ecaefd34488e6088d31f85f745df72f5c5426d66cb56cb1cc4a4bacdde92a336d777a56aa303eb490e8206536fea09572c6323ff3f3ffe5eab83bb3f6602e17d9ee7026bc474c71ba28323070875e320e3a5b1ae01d8f12fee26445c06b6a5e6807b572495d3b363f3c184ab6cdad8d146400d9502a582a6321634211812c69f7e2155d30a27a27278f24c1fad18f7ed87ee0fb3e2afbab4a92319e103093520244bb30c00cbe09191af356a77801220f5ba95b896ba22ba24e1fd736b26ea72dce0ca03bc1139e0b8eb36877f1efb4b7c13a489e3815d918b8f3bef1c6dbc237ee3f3a54d0426f08d96578671124225005461540bcb222e95f27cf4765e0681b51f24d5416a2daf0ddef7f8f5ddedbb652bee0633d49139dd4dd5d701c8b90c5bd86cf93e943a821a40c540b4f99982fc7e80a46f6c5efa91cd4e0b88fb49ccfccdcb8d3cbc208380a7da1672c638b33c55a36be7e5614192ff502673aff5ecabeb9b624a8b71e3d921ac5d9dc202c7200e0f01688c01ce34011b434fe22b8c2079d95d9a7712bee911a0322867ab6c2fd23237375cba98899a81174fb3d31dab7763755c24163a06b097d801119869cf93c1cc8ac0fe2eca5cb9725ba8892ad8685278c9d39e0add12ab9303b89932e9dd3127c78d95d9c96362160cd1c677502a94f96f019e898b23679bde6e686cd254eb8b401fb14e1490698a96bb2458dc3bdfdce5dfbccbffdb4ca360f54947c740659070e59b08608647416a99064189bb252de5bea2770d2e06122e009ec822e33dd44ca7c84ff0451946d6b7b5772de34d6981200f3a2caf1fb3e95e2854c2658afa592c6afc8d8687e8059f67b7d8d36d51b2d8df60c06637b74782849749a7ee8d3cb368c0cfb7b7ee41fac685b62f9ce6386e90a10ce8253174423719c8474147840595bcd27494c1e09576f175770bc91bc2a78fad2d9ada5b2daa010e0b2a58c3d7cf8c8c5f3e730601b0a5480ef8c9351f26c6e6f24e07c60c72707f273fbae0f7fc8fee68ffd885dbb7645374027ba1e564fa569b3d1500025bb029024ed54a74eeec6b47471a4c5238db2d3cb16715056b4b4a79e7a2b2d8105071767a640cbbe07103d3d3d4a8c6a6e46ceba9d81bdfcda9bb2557a707868c727a7c9cbcf0350fc1719ccb7675c518aa5e36ccd2c1706952483b9774f5fdab3f7dcbca63abe0a789ba81f810fe9f7258fe301215e37ca3901e9c2a07c2a3888a30408ef08b90204412a322ffee4de446610d481338a8383aa7a0f8910860a0465449cd08e0582ff4556a500966807c1f38afb0429d77d10dd025d995562ed47a9eaa4d184a925e55371f953f3670dfacf310f71c96ee96225491d65a6a1c4202a03dd65b20ce4886636180cb5ee61b38329ed5ddcb3cb37ae595943f0253571187ccec2c0afbade7ef7b423df4adc7170ce4154b054aa8a7849678c7db1d96ae91e33772a1fcd5a3595bf989b965c486fe5253781613ce8fbeca3ca5606c8bdbb09d4412c4145046a05303965163eb7c1be0000200049444154531a2c02646ee8ff2c56597bedcd3bf6b9bff8a2bdf9c69b4e7181625186be63ca1415ac5d88dae183343a2765105c91929bb30405d037e31020eb2e57d4d4010b56360705890035eabb7412a45cb2cbd5caea959ae4db032be3bdd5adcc66e5847de5ea0dcd4822274eb675e7ce3b76727c2cfc7873634336f7605ac7276d7bf0e848191822d72a1b9ffec8df59c1258229cb4d95d2a20c1c4256174953527f74ab260a3e53f09d15b81451d935ba9d00ea8b0a6abdea55e8fce5aa52c5dea0eb94ff395d840ddbddda563947fd0d939754920fdfeb6375b4b28b9776edfbffc65fb78f7ef47bad5e2b2bcd14285eaf2b28b2b18e8f0f658b15f2162c1aa5d753dc6d4b92af8db104ca0ae814747734c6235daf852d6753e15ac57c4e803e271d36466481bc2e03ce04d56abd6aab79ce3add81bdfae62d7bf3f65d3b3c85e5bc7442278bef1cbb3c025674e0221388ac2332af0868516e452656cfacec7d4fdfb4ebd7ae4ae40f3e1a20bc62ab27eec276c2e63bba7a7cfe28a778adf3efc77b050501ec685d7625791032806f0f5811a0e2f3b852ab4bc9506ef0a7772083ebe5740b4e69ae92f70b626704be08aedc3bc9e526f509957b743b9357a0a60cd4410263f48c44d66689e6e62edad0157cad0adf4c65a7c8a39a0d732a07808f4a47694f613232958b0b810bbc8719d34eb7add74702f9f28d2b9ec112682a15ab20632d7df6acd6f46232950a2925cddec54b6e8f562adbe9695bd80ceb1f89eb52d9f5deb9afccaf727ddc331a41989cd2c060b858d81f66b764590564685ce38d9f7ff0e0812462a0eb94aa68b453a19802964a78ace0c11a4b55eb0d66f6993ffe9cfdc5e7fe425001f82dd70cae04d6a90094a00bf1239140821b25ab356f4e7873c6e75f757f938e183c2abae26492dc6fa83732d805bfa42ad1f40ac3e6043ebf7e929d68c44d9151ce73ad342a766d77f7825dbb7a43c298ecffa3c323eb757bb6b7bb6f7bfb173c48aecc4e4e7bc2d5e13e6676ffda4fa8514e39e52d6840cb894a1401a270abc643952b68dd80eb2c70f7988dad02d620e99a951b26a296596f2a0d669e0a809a53a1dfc38cb4abb92e0077276c2eacdb3d111b9d0f4a8a18dd336edcd34f3f693ff3777edaae5ebda445a38da26e47de6ad5b2f857d4fd18b4723ab120e089f019b015dae0e1164b49711380da3326dec7338799e48e014dc768c0a3a3b4989a2d67564277aa54560b98ac908d50aa162dbb2ad883878776fff191bd7eeb8e9d74bbe2c5e884e1e1268fc5c89efcc19fd957f9e63eb3d23e9f850518cdcf885a301cd895dd1dfb8ef7bfd7361b35abe44d46969009191676a368e6343925dd3e4c2346895fa50a3079bb49dc3f7180c068f80ac552b1f711401423db3b769105c5f5070611995874d6e0db38d6e125a7ff3cfa643c4fa7ab44c6c76689df8fefbb992b49c099aebb824b0aa621891c0151bf9f9a0b3a236584ca9f4961140c559e8864d1695e32353422c3125e3ac41d7ca1836d38a2b9d3b3feb0af0ce42a6aa2376f58b9862ebb1b909085e64a8c93e0fc82985dc98ad9bcb54f4e2d5f2edae6ceae0b0e66f2c24da50eb2b9912815c810b9abb56353d01a728914cc10b9fb00f0efc5e45ccede20b04215e0dedfbb77cf7677f61438299109d8e8b0517e1118e12dd2795cac60bee7ecb5d76fd9effd4fbf67c7edd364ec4117d90d78dd5e8dc699cf7e7a798a0b3870804f8bc8610a3919e19119cb17716d9e883f26c7ed3cf39028bae29740e79ff29ba08bfc4d4ea46b0e0b07f6fd50611ba060cad90eaac83c67c6dc7f92d2fbe2febe6d3437741a8339d3ba23b364ec8d7291808d0d5aa6f1ae4f8ae9aea88891430ed6eb44a9a986a2494fc1251673ab574b9a62a796659a9c0fb741ba2c1bea7152281ccb3e9bfa99dfdfded9515d3a1a8c55824d27f8916114d1b1e1a8af2e9f464ce81451e3c364566990b3ffece77fce3ef4c10f38eb5d83ce2381f35b5b2ddd506150e391525e3227322c4e31403a7690462390e018f9dc203f4b09c0ef820bc8134f807fdf1e3fba67c361579e6b2b49bfe4ac0685219bb3c3a3433b387e64c4b3f164610f0f4fec1bdf7ccd062844a8dcf0a01decf2f301eb7c49181b76cd1d3ac7888f8d1d3f93c5a9c6ccdefbae27ecbd4f5eb7329aefa5bc4a6d8013088aeac7b208d2e072f0b6847d2472a63a3eb8ff24e63e65b370a044bee4608a6cefdb4d5223700526a481eec498f74e5c64555e120a302f9452b7d0ef791039cf86869c82a1cf9b324657aff5d762c12b83480a0cfe9c9c5dafa09afe2d323f3e5b780050190436c806949e5a2876c43da1db3d1ca81ce480437903dc6a61f81a54edeab52bb6bbb76315b27a0e64059ab275fa3d69cd838596c19f962bf7d62b17acb5b1658dd68633b9a5e19f9552831c77fa7dd77d92d96bce3abdb646ae5a1b1b227fca0d597857c9fa50692698a28c74f8ec6c6de900c2717a6b1349efb902969a36199ff6e05e52ba024e638ff7f051db9e7fe145fbe3cffc899a077011b5a754a1b83bb3cb48bbec12daf960cc8eef7298fb01eb49ec52a5f4baa388912d014e46c75ef2b1eed9d77974e025a5ee636d645732239ecffcf517543e6880799360868c0b6e87746b278cc995acd5dcb06663d3b6b676c4fbc2acf6f008431a4f44582f99ea539f5881d9709da351cf6a6504bbd0ef99ca401439e602a73e0b280749d327eaf7f676edb473223c89f2841baf4e4bbba7d38361486a7fb2adcdcd2d75bb180378fbcdd76c38eaaac454e644f46550325fb2d17cecedf86cceae5dbbea19d6e58b3ebac1879c7ac426bb239a13d5391dc01954a208c8746f3516375917dd05d25eae63d8eb2a9ba0eb07d78b1b391e0c9535f29a8f1fdfb5d1b0a701e3a198f188f9356d9159d869fbc806bdb1249f3b83b17df9f9afdb49afef1a553c5e4eae441c3d1fb0ce635ad18d8beed979803e089b7ccfcb28974b69550af6dd1f788f5ddfdfb54a0efb2b322918cd2b9bd0a14d7ca930e08cd7212045a78e855390738f2b80f2a5ae1cc127dd2b81e3897dcfbfab73941411a2ac8cce58648a74aa9cdac0291a599233a959e47cc59c61b8fd042ea5d22805a828190250271b0b8636ef15a339c2de9203798815b206303af552cb332ea7d29c756c398cf95d19734e19ad42b67762fd3112dd23ebf4bbca2236369a5ad7fb17f62c57c8b8869a318eb2adec80d28da7ac0c4265dccc723506875bd6686e1a16f25ead2c35544c29254db0d5caaae5b21d1c1cd849fb5472c99853908d92b98009f14c39387bfd8e4671c0c922c3d2f44673439c4074e3c9844902f89c1ce298f88a3d9f2fdba3c71dfbbf7eff53f68d175f766b3d89f6398915905ea07bc802b15eb1235342e0f39494e8921c57c6eed92bb0099511342170b22a9f6d95d53ca1d68db23527310ba89f50d6e65552f2ba50338693a1fe0dae15ceee19b03b601ae991cd5569c928656e562a96addeacd9e52b57ecca956bdaa7dcd7d75e7ddd32c5ebdfbf72ab2cea577c0379b8ccefacace87200562b966d73a329001800e9f0e8c05a9b9bf6e0f143454d486295725582f20fee3d54f457e78d963c36f1e5a20d07a7d6e99e5ab77b2adc4a96d68ccec8d0d455421719b0116f8b7fe4231fb19ffc89bf65cd7a555c243a707a38940b894f23fe8ab4d15dc84e37bf585aab507a02e3c4526d3244d9ba1d656680edf3f9445d38572c6581cf9c4792c5fdb6648fee3fb6d1706ab962ce46d3beb58f7bf27f83faf157afbc6e8f8e8fddcb0f0853e8e5d90ce17910dccba6332bf70868e703db79cc4ba709f6f152e41cdb13972fd8fb9f79c276379b7e7024d3051730750dab08508113398ee4c6b8ca00d329afd74e3885caa9a035a4802567e594c544803d8f75052ec6464484ce9b05bc979765dc6fa729785b9ccda6123cb5cae3fa3c40529ac2b3724e597c0e363af783f70d6c4e8b1d8c2d95b4ba76615013354af88c71dde28625099d3830b49150d91c8e4439504790d2505e922756aa94eccad5cb76717f4fd9427303022878ac8fc130744c868550231b11a914caabea6643eb0dd6366aa20409a0107e07cc4b8174b952171c0fcb9393a375b72f3247a00b3233be0643777072427449418a616b3a6a3ac838d099d32b94fc601df5e5fb891e3beecab345de3eff85afda1f7cead39a87242b46e2854c4a189e40f5a4a4211e5cca760505503c31f32249119575fcaca66a3524ed9232689581d971f88b3a91d61fcf589586e4c99d84cabee075fdd92c6d864f401e4cd699f7bc97c43851cd90c2067b1a31c291022572ccbbbb7b76fdea4dd15b32f5eb1f5de1774f2988e7fdd6c686302c3cf22e6c6fea8669e0f1f858e301e3c9c8ee3e78a0d418b07295cdbbe0fe6ca6aea052f1e5cab63736f4b04e8e8ead3fe8d86c8ed01896f0cec0e661c149a1b322ef3b02a5b9710472c69ffce427ed87fffd8fd946b3ee5e81708d5457bb961652acf0c3026425a393ad3bf84211ab2cdacf0efe35926e36548ce11011ffa1f5bb6d1fadc866145ce19831543d60d0b4db936ceba037b27b77eeda7c39b5c97c6cb33181316f07c76d7be58db7ede1d1919445855f294df8ff0f58b17122787d7bd0d21a39afb18e948f24646656c966ece9eb57ed7def7ada4a39d3b3914d987c031d63092a4264435112aaf4d37af30e29ff1ebc2705719e433270a0a49650eab900b206db13b933ca3cc9c3cc1d6f233b20c37212a963603438a27ba7d73867451f8150781006ade748b03e1defd85fc8754766c8f7b429d2e7115e95cc2fb40e5293213e6764789a11e47a13a39d4c897210dc4a8a9df3a94ac177bffb698d6621e2385d4ed41ca29b4726596d342dc75c2933849995d5352e6556aa558505e5b3784a82df26935e4a75a934200640e3a0a23945bad96ce0309f9053100a07d05596a60c0b8393adcd0d511ce086815349f99c67293d30976b517682cc38a530e28048ce64cbf6e65b77ecf7fee77f6d0f1f1f687d88b80a8995e71b8149530774161dbf8eefbb7e9bbb65716f95d512bce414e318654623461e60088832592e97a5ce1bf008d593f4cfd2fc66e09670c5f2651a67a8b93be76b361fbb00489a53a564a602c3b95b0a32742691892ad72db37df323ab7aa5681bcd86a23aecf3870f1fd878d897161522fc52e29cc13e857d5cd64dc7bd43da371913c74add394031f1fa9756cce5342643a00167217ba2750a9f429c1154dc25a877a66e399df66d73a361dff1c10fd90ffff00fdb85dd1d0552b784cfaa6c2333e2352383e07de50dc74988e0fec6966d6defad75b14426a42b23454a45461150d1be22db83b3258dae34fea101cd6ef7ff69ebdc7ee32aaf28be673c973357db711212073b891d01110dbd404b4ba5b6128ff0d252c443d5fe7ded431f6825dad25221f5a112226a08815044a1407088eff18ce76a7baadfdadf3e3e441d6185c4f65ccef9befdedbdf65a6bdb1e8af4d94c361de8b966656e5c5d2dd67b5f6fd9edbbff9661bf86baa480c5b52882ea814b1581f7470356f1e72350785d03d171a243a04480ae54ede927afd9b5cb8f4b245d2941d8c57113cffdc86e4ec7d7072e15ef21028f367db86224a22629bd1b0e3a76141858048dc0bba2148ccf43ec20085076b031546602a80a0f753f232121602d74d80a414fd81af73e0da088531a3c4be84672be0d0c4c9dc4c4dbe27b726548199644ed3c571e349d0316019352902f5e13d74c864610780693b10ee0eee2bc3d73e35b767975596b970cfe7074e8538aca350f446d8201563e250d2ad1900bf05c75864b562dfba05eb21959cce034a2f2071b63bf466aac94e8648f7428f21e9716cf2840f07d31e0cb33dbd8b8a7a611014b1e6858ec54a15864c28e48e635bf119172bd62d3e38906479061d91ca5dfc47efbbbdfdbaddbef6b5d83099295c56143b3caad98c8767ce418490afb82ccc835b70443972f31a95d469b316148581ec90b10895b749380d0d09219675a0b6aa0c83df8b483ce9e9fab7ad7176e19193296d01a082b5340e67db6acdea463ed8605c00b606978d4957efce2ab33b28cac066e83b6a967bb3b4804c6369c1cca4953d28806a6612dab9619253d1658dd6d756c3aa35dbba854978dcd93d38d03b8a7ecf3d6acdbc6889ca192a1e9bedaa8f4e57754150bf9f868644f5e5bb7577efe0bd9b3e2c4493b9f81a8e06978580d863d1b0dc0d8bc66864a215f696e68ab2d233204cf12ba427e9b40f674ae888a109586748a7aba208c2072cb1b5c02f02faa6aee1bb3074787bde493d557669855999e7b6c9f7cfab9ddfaf023dba6f3891097cf92ec992350280b7864065ff17bb1798ba5623160b1709c2f83d508bef7650d5dbdf1c49aad3cb6a4c1ab04604e48599a1418f691ad696327fd9e53cdbc1b98ff6c2ac3c069843b25c17294b3519645108bac300fb239e8ce264cec69f17adca030c07d95a685a937916171ff392022402a6825ffa83c28a6ac2970b5e073093364936b3c16fcbf8423268910ef31280494af1cb25c0b3a4dfd09a5ffc426c753052e4ac167e8c6ce77b4ae9b19338cf1a507b3ed184e0c582157b2ccc6c758a80cd5a482644cd5c0faab9460e393dd430c2d5ba992c6914108c64b8e5287f55cab686d3dd8d8d09eb870eebcaed3c1415f8383c128d1aca2166105701d741fa70c9398b71a139e0610a799c244e0a04c1e2b3bc3fdb39a75add71bd9eb7ff8937d70f723a7b1d0806ab6730e22e46949db3427c0a9489295491fea436709fe4039d2650e690214baddaa243cc8f06708eff95d595a27058caf33ef0273af659e387351baac71262983ab329d07a713fcfa11862f68bd1043784ec4d0c798fb4183f9fe0b2fcd7025e02427dda14d0f0d811a925f902c216b2892e21a40c7849ba5a91cf22587c9da538406c8a4a40bef4aad21396bfa4009c50b2b5bbbbba0d304709fd29260a03161c7537be1473fb4975f7a490a757cb5583ca4e870c0902e00ce3149a4ddeea84b83813e9819dd2fa23ee0a35b6f38faca4d778f23efd6b0c8095688a035f2bbe6f30c6127832544d782e08bb73b121d300d1669a5d29094e1ebed3dbb73f763fb72e36bd9f2286051bb1740ebb8c1390f2951cd955914a80391b54490390d6a5e9e911472ede48f552ed9f2f93392ed2c759ac2da346126652e118822ab8a31612a91d2c4eeb0588e9f55904c548b222616ef91c5587c5ec79a125d81d3530a7c1fa92e6261caf67c7ea51306750d5283c58764ba30580d8244b1f060e86457277ea4493dda4ca74323f439d2a4227186d2f056f16373b993f3b2c4383f467633b6c1c825220c52e8ab1c74fc8a72f0dafa9a32ac66c3bb82e04d7853710d9a8da65d7c7cc54a959a1d93f51e1dd9defe8eb5a5859d5785c0ec4095c3046d1d107899d19c72a2e86cae26cf77654c5acb53f7d11a4fe4ca4056470608b4025cb1bb0743bda68c12d34082154197358f0bc4acec9dbd293008fefa47531bd244188e3557e08baf1ed85b7f7bdbb6b6f664d047bd4563806a44c27618f6cadc7c924e64d2946774fc3cc1f07ba70c1a3a515253685b81234bea3653c64ae055505256ed3ccce27a968691cc8bfd57f6e6087b967f0f2da3bce0d56196858763e293b19426a21b1e4d8441972eac7c67c69b62f17470e76cb6151501ff26938132a6e83ca1ab132e44163546bfe6a3dd157093c815a8c237819fdae203a58e94fba2d09a3e1dce0970c851c64620d3facdaf7f65cf3efb5d398d6635ef200cfacc111caa1cc4b678e5f29ad26fdabdb82312bdb9f0b45b71626433b0782923f97da43e0099a3615fdd4608ab7bdb3bd234c2ade173705213b87777b6f53bfbbb3b363c3cd4a29d5f686bc1e05b5fa99096cfd9bbb7deb78ffff3a9328bb060896b552cf3f8ff622954dc7cde4d4b9dadc2e878fdbc84cc8959ceb5c4736c76a23160eb572ed9d54bcb72b2a82aa339f5772f6626604c9cf8ee53e63483d01f3af8eac07664501a599ec0ed48ffb95e7e02fb7b01f3a204521901b6a85992ded9e1e4967367d2c7c5ebf1f7473136657a6491e54a924d25dd5fa15b79da293cd52012a014f42128d2584844d9287778fd0097a1b370d022ab198e47d6c7a0f16466bd818f73e39005b3bc7265d59e7ffe07ea1022ca075fa2c1037ecb3dc50f0ba099ec1af2229c3ddefed299b3d6995f54a0d65092340ecb3308bf6e2a03ab0d49582a3485e6e6ac3feccb8582c30e612fb0c37830942616e2346691fc3e9fbfd5061373de953253fce298085d6fe7de561044c93cc1e5b6f7fbf6c69fdfb2f76f7fa8aea5bb3998f47e7c26ee35d79ef5ccf063e44a040f942080e57428c96ae4f0499231738793dccd57def809bb2ca549cde94009d94fde3c49bc43121b6fd6208b3db19364dd2c5f3260214d98772c54301ba2ef396fb0901dc21ce041434c01abdd6959133700a583387ad6d4d1c3408f0fc68ba99e84da4f3f2e9dd62c1275c812d59f4c0340529b66e620a170047842f273e70d02d87996a14e115dc44ad5ce2c2dd88d1b37ec673ffd899d3fbf647054c1af002ab737ef4b0d8eb3288feea2f3537a077d751110386bf0262935519a0b4366986443103f61b5435f081ed1838dfbeab240bae3a4a18d4cd0dadfdbb583de43d9c990cd51def27988f6b3524d6ddd87bd81bd73f33dfbf2fefd84c78544c5497211a4a2848a3fbf01aa3fe29315812ccab17c2a81c87ece5323f74020dd6d667665e5a2ad5c5c4e7896e30491b50bac46642b0a83ac5d7376b3ee41215046808bf7cdf3044f4a1ba4e0a195737792011e9b048d5c726c56e61d267a71c84569163858889895595282ea9e619febce1a41520d02a967a03e4f9087660ba449de00bb2e2571b02c4a40ee23d215daf0401a5409fda1e356941e13b9a3726d505d74ecfaf5a76c7dfdaa1c3d79aee0e86d7c754f4171f1ec9244c7035981bb0d0d621124530b0b8fc9bf4d868fe3b1beb8eeccb58cf59d35bb1ada22eb682604b10ec1e8d24837869ef0b9ce2c2cdadefeae6d6e3e10274ceb32799993b0724d6a0d3cb728efcc9a594b410d4e12cd03666b5aa56e1fdefdc4de7cf36d5918b328705081d84af6e3f8220713872fec76b22a1feccba1a87297e12b72d160a60241c9e71292214a233a73da09fb988ac43bcb94f65ee2292ea4460aaf05773082370188e044579ff211dcca47def95421aa020255ad5c4b9e87259154037b2d7dfb7b2f420d531244a46756994a20806d4037a5725eabc6900737b74f002dad4e22849c1cbdfda974904a369dccbcc99ca324c743ef6e853d087ca39595157bf597af887f9565556bd4e73cab3ad8b7877bdbe2899d3f7b56a934a4499c137afd819a0030611900c02941341e0e1daca32dcc0523f09256c2cc0728252507f083843a2bf96c3867d263ab7b24890e9c18e80f7e03bc8387a3231281eddd03bbf9de1ddbdcc1e8df81662fe5928b68a21014b3a928d31e0d621e684e2733177fc75fd803961f0e14a4f0e14ac25b569797ed6cb729f337f9dfcbec7ee683699397959f6c1c19a7c3268a5dc26fe266fe398ab81aa4dde2fb533676e2019280e5def13eee49610322a170139705e50138c98222c3e339b58893ce2670ac3cab4a80bd5e4f947d51fb7382299b3f3a9ec1b342bfc826f2ae20e261f4738e5b0dc6d801f33595860ff90bacf6d5cb2b3ed1a55ed3a129194ea3a5d31cfb18268bd32d6c310730e3dfc1eac656499ef059bd233f2c35a0d0f84dc6c2cbe2beaa835bcb5ccf4763e384f1f54dd936218a66cf6c3dd8549541c64f676c6b6bd3ce9d3babcf07ecc183204a0796ee777b7e5e19170ec1049d46d327f10c197e31c5176e2c9be40f3ef84870c790c654ddedc095a92435848f3de37e9dd8dccc712cb06b7710a643ed9a47e1cbc2a7bc23ce5e52660e0f8f8444c947e272a58aa1887bca072f08bf69a2935b457368e91852779ffd4bd042db491851a386a486042959e29416ceaccee072c88921d5a92c2682956a4d4547369477153cb2fa0757a43ef2ccc96d297c2e1d0f3f617d8a8b46542521b5280c6991f27c8dba83ae972e5eb0d75e7bcdd6d7d79459e1590586b5b3755f136de65b1dd5fbdb3b5bae2593f68909c95d95850ce104cf821f22cff09969c804ef112a0376b8042b04d3e004042419e389cdec644d54e35c07c984345bd04b0e8d9987887a64f6b037b42fee6dd8bbb7ee48bc29cfad94711018e2b48f1b9477b91e8d54e9ef8e099d965c716de379749dd3d0029f9483d50cdcaf1301b6572e9cb3f94e5bc1194c4bdc96244771ff28213bda189181e84049995360541ea492923fe9ff7c517a261c8147efb7ecb63664cd92dcc84dc2f57a414a44f612807f949d45898f96a9ba70d89f786093c54e728ec84be93458846f071ec8278ae78e9357a0bb9dd848645006f7ba0a01370eb222be84596953e39070646beb576c6dedb2f3842a25cdebeb2075c99a2a8d76f6b66d617e41ea8946bb6be56a43980dd7974e228e24c3a96b1da1c6c43d23c8b83cc83123a4263c8f82f268227ed62198aa2431c7f6390379c7135bbe7051ac75025eb7db11f992e7208900979572a34e932a73d07aec9dbb4addb1c072255397f0c1e68efde5af7fb79b37ffa5928a0617a53b63be2260f9400eefe4b246aa65d76d12b028531deea1bb8ee8d9131af7ee771d290fad5b0eab24d2866a117088cf89f0e425348971cf83ba92bc737dc2b4b2ab9a200c06da407b20f9900b6eadaab25b9dde4ad6f61817ba2e35885983a4757eb2d3768d8195aed00fb12b259e0f707020ada40b1fdd2119dbcb8fc6b91e6ed6e68186ffb819644dcf3df7ac3d7dfdba3df5e4134ad5b90e591dbb97bef5d0fb4d60fa76d5edabe142d8c8d41c00644798524d271825a10757f0afbaca05b19b113883bf2541ae0f1bc0ecdfcb599c1f78382d4369823cbcd0382af8c29191e712a9f7b17d71efbefde39fef2860098f4b0158a542e21045891537b0d865299630913e473c2be25f71832360852db512d993235bec76ede2d2825d90fca92afb1d05184d3876bd20802d192ca57abec8425691fce2036b0a0ff4082c01c8b330bd4c72833e26c2a87305482b101d4e0d16267339df4bfc23387969fd704f72767a940d0ac0a7f21dd12ad285c871bf42c0ca03eeff9920ad2601ae1d7def6c5322516a68bcfa8429ce7d6d5cb22cd622b32d572f5fb2b5abab56cb38844f6413030788f5042e04af083e14d6298b4be7ad9ab5f5fcec07007a5aedfb07077a3d702f2f7f1daf437dc1b562fd710dbc3954b6e96064d5ac264c8d239199805b4c5e821ddf6adbfc4257fb8272908045c0439f08e08ee66e8ac058ee073878a01d1df918bab98ad55b5dabd45a76fbce5d7bfd8f6fd8679ffd57c100dc8eb9067138f87de0bac054f789e4e8421130c3e922fb249be23e8c49342c0000004249444154532a02072938a9f6f7064364903008a4fb1745c6b9837ef8f997fe3d1da09a7b9a706db7f316f8ea073ed2b1345c83eb86309c648240cb3a06e4e75afe0f9bf8ac4419f053e60000000049454e44ae426082, '2015-07-28 02:56:33', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `staff_address`
--

CREATE TABLE `staff_address` (
  `staff_address_id` int(8) NOT NULL,
  `staff_id` int(8) NOT NULL,
  `staff_address1_primary` text NOT NULL,
  `staff_address2_primary` text,
  `staff_city_primary` varchar(255) NOT NULL,
  `staff_state_primary` varchar(255) NOT NULL,
  `staff_zip_primary` varchar(255) NOT NULL,
  `staff_address1_mail` text NOT NULL,
  `staff_address2_mail` text,
  `staff_city_mail` varchar(255) NOT NULL,
  `staff_state_mail` varchar(255) NOT NULL,
  `staff_zip_mail` varchar(255) NOT NULL,
  `last_update` datetime NOT NULL,
  `staff_pobox_mail` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Date time staff address record modified',
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `staff_certification`
--

CREATE TABLE `staff_certification` (
  `staff_certification_id` int(8) NOT NULL,
  `staff_id` int(8) NOT NULL,
  `staff_certification_date` date DEFAULT NULL,
  `staff_certification_expiry_date` date DEFAULT NULL,
  `staff_certification_code` varchar(127) DEFAULT NULL,
  `staff_certification_short_name` varchar(127) DEFAULT NULL,
  `staff_certification_name` varchar(255) DEFAULT NULL,
  `staff_primary_certification_indicator` char(1) DEFAULT NULL,
  `last_update` datetime DEFAULT NULL,
  `staff_certification_description` text,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `staff_contact`
--

CREATE TABLE `staff_contact` (
  `staff_phone_id` int(8) NOT NULL,
  `staff_id` int(8) NOT NULL,
  `last_update` datetime NOT NULL,
  `staff_home_phone` varchar(62) DEFAULT NULL,
  `staff_mobile_phone` varchar(62) DEFAULT NULL,
  `staff_work_phone` varchar(62) DEFAULT NULL,
  `staff_work_email` varchar(127) DEFAULT NULL,
  `staff_personal_email` varchar(127) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `staff_emergency_contact`
--

CREATE TABLE `staff_emergency_contact` (
  `staff_emergency_contact_id` int(8) NOT NULL,
  `staff_id` int(8) NOT NULL,
  `staff_emergency_first_name` varchar(255) NOT NULL,
  `staff_emergency_last_name` varchar(255) NOT NULL,
  `staff_emergency_relationship` varchar(255) NOT NULL,
  `staff_emergency_home_phone` varchar(64) DEFAULT NULL,
  `staff_emergency_mobile_phone` varchar(64) DEFAULT NULL,
  `staff_emergency_work_phone` varchar(64) DEFAULT NULL,
  `staff_emergency_email` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `staff_fields`
--

CREATE TABLE `staff_fields` (
  `id` int(8) NOT NULL,
  `type` varchar(10) DEFAULT NULL,
  `search` varchar(1) DEFAULT NULL,
  `title` varchar(30) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `select_options` varchar(10000) DEFAULT NULL,
  `category_id` decimal(10,0) DEFAULT NULL,
  `system_field` char(1) DEFAULT NULL,
  `required` varchar(1) DEFAULT NULL,
  `default_selection` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `staff_field_categories`
--

CREATE TABLE `staff_field_categories` (
  `id` int(8) NOT NULL DEFAULT '0',
  `title` varchar(100) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `include` varchar(100) DEFAULT NULL,
  `admin` char(1) DEFAULT NULL,
  `teacher` char(1) DEFAULT NULL,
  `parent` char(1) DEFAULT NULL,
  `none` char(1) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `staff_field_categories`
--

INSERT INTO `staff_field_categories` (`id`, `title`, `sort_order`, `include`, `admin`, `teacher`, `parent`, `none`, `last_updated`, `updated_by`) VALUES
(1, 'Demographic Info', '1', NULL, 'Y', 'Y', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
(2, 'Addresses & Contacts', '2', NULL, 'Y', 'Y', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
(3, 'School Information', '3', NULL, 'Y', 'Y', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
(4, 'Certification Information', '4', NULL, 'Y', 'Y', 'Y', 'Y', '2019-07-28 08:26:33', NULL),
(5, 'Schedule', '5', NULL, 'Y', 'Y', NULL, NULL, '2019-07-28 08:26:33', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `staff_school_info`
--

CREATE TABLE `staff_school_info` (
  `staff_school_info_id` int(8) NOT NULL,
  `staff_id` int(8) NOT NULL,
  `category` varchar(255) NOT NULL,
  `job_title` varchar(255) DEFAULT NULL,
  `joining_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `home_school` int(8) NOT NULL,
  `opensis_access` char(1) NOT NULL DEFAULT 'N',
  `opensis_profile` varchar(255) DEFAULT NULL,
  `school_access` varchar(255) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Date and time staff school info was modified',
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `staff_school_info`
--

INSERT INTO `staff_school_info` (`staff_school_info_id`, `staff_id`, `category`, `job_title`, `joining_date`, `end_date`, `home_school`, `opensis_access`, `opensis_profile`, `school_access`, `last_updated`, `updated_by`) VALUES
(1, 1, 'Super Administrator', 'Super Administrator', '2019-01-01', NULL, 1, 'Y', '0', '1', '2020-01-22 02:18:03', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `staff_school_relationship`
--

CREATE TABLE `staff_school_relationship` (
  `staff_id` int(11) NOT NULL,
  `school_id` int(11) NOT NULL,
  `syear` int(4) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `staff_school_relationship`
--

INSERT INTO `staff_school_relationship` (`staff_id`, `school_id`, `syear`, `last_updated`, `updated_by`, `start_date`, `end_date`) VALUES
(1, 1, 2021, '2021-07-22 11:38:34', NULL, '2021-07-01', '0000-00-00');

-- --------------------------------------------------------

--
-- Table structure for table `students`
--

CREATE TABLE `students` (
  `student_id` int(8) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `middle_name` varchar(50) DEFAULT NULL,
  `name_suffix` varchar(3) DEFAULT NULL,
  `gender` varchar(255) DEFAULT NULL,
  `ethnicity_id` int(11) DEFAULT NULL,
  `common_name` varchar(255) DEFAULT NULL,
  `social_security` varchar(255) DEFAULT NULL,
  `birthdate` varchar(255) DEFAULT NULL,
  `language_id` int(8) DEFAULT NULL,
  `estimated_grad_date` varchar(255) DEFAULT NULL,
  `alt_id` varchar(50) DEFAULT NULL,
  `email` varchar(50) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `is_disable` varchar(10) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `students_join_people`
--

CREATE TABLE `students_join_people` (
  `id` int(8) NOT NULL,
  `student_id` decimal(10,0) NOT NULL,
  `person_id` decimal(10,0) NOT NULL,
  `is_emergency` varchar(10) DEFAULT NULL,
  `emergency_type` varchar(100) DEFAULT NULL,
  `relationship` varchar(100) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_address`
--

CREATE TABLE `student_address` (
  `id` int(11) NOT NULL,
  `student_id` int(11) NOT NULL,
  `syear` int(11) NOT NULL,
  `school_id` int(11) NOT NULL,
  `street_address_1` varchar(5000) DEFAULT NULL,
  `street_address_2` varchar(5000) DEFAULT NULL,
  `city` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `zipcode` varchar(255) DEFAULT NULL,
  `bus_pickup` varchar(1) DEFAULT NULL,
  `bus_dropoff` varchar(1) DEFAULT NULL,
  `bus_no` varchar(255) DEFAULT NULL,
  `type` varchar(500) NOT NULL,
  `people_id` int(11) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_eligibility_activities`
--

CREATE TABLE `student_eligibility_activities` (
  `syear` decimal(4,0) DEFAULT NULL,
  `student_id` decimal(10,0) DEFAULT NULL,
  `activity_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_enrollment`
--

CREATE TABLE `student_enrollment` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `student_id` decimal(10,0) DEFAULT NULL,
  `grade_id` decimal(10,0) DEFAULT NULL,
  `section_id` varchar(255) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `enrollment_code` decimal(10,0) DEFAULT NULL,
  `drop_code` decimal(10,0) DEFAULT NULL,
  `next_school` decimal(10,0) DEFAULT NULL,
  `calendar_id` decimal(10,0) DEFAULT NULL,
  `last_school` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_enrollment_codes`
--

CREATE TABLE `student_enrollment_codes` (
  `id` int(8) NOT NULL,
  `syear` decimal(4,0) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `short_name` varchar(10) DEFAULT NULL,
  `type` varchar(4) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `student_enrollment_codes`
--

INSERT INTO `student_enrollment_codes` (`id`, `syear`, `title`, `short_name`, `type`, `last_updated`, `updated_by`) VALUES
(1, '2021', 'Transferred Out', 'TRAN', 'TrnD', '2019-07-27 22:56:33', NULL),
(2, '2021', 'Transferred In', 'TRAN', 'TrnE', '2019-07-27 22:56:33', NULL),
(3, '2021', 'Rolled Over', 'ROLL', 'Roll', '2019-07-27 22:56:33', NULL),
(4, '2021', 'Dropped Out', 'DROP', 'Drop', '2019-07-27 22:56:33', NULL),
(5, '2021', 'New', 'NEW', 'Add', '2019-07-27 22:56:33', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `student_field_categories`
--

CREATE TABLE `student_field_categories` (
  `id` int(8) NOT NULL,
  `title` varchar(100) DEFAULT NULL,
  `sort_order` decimal(10,0) DEFAULT NULL,
  `include` varchar(100) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `student_field_categories`
--

INSERT INTO `student_field_categories` (`id`, `title`, `sort_order`, `include`, `last_updated`, `updated_by`) VALUES
(1, 'General Info', '1', NULL, '2019-07-28 08:26:33', NULL),
(2, 'Medical', '3', NULL, '2019-07-28 08:26:33', NULL),
(3, 'Addresses & Contacts', '2', NULL, '2019-07-28 08:26:33', NULL),
(4, 'Comments', '4', NULL, '2019-07-28 08:26:33', NULL),
(5, 'Goals', '5', NULL, '2019-07-28 08:26:33', NULL),
(6, 'Enrollment Info', '6', NULL, '2019-07-28 08:26:33', NULL),
(7, 'Files', '7', NULL, '2019-07-28 08:26:33', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `student_goal`
--

CREATE TABLE `student_goal` (
  `goal_id` int(8) NOT NULL,
  `student_id` decimal(10,0) NOT NULL,
  `goal_title` varchar(100) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `goal_description` text,
  `school_id` decimal(10,0) DEFAULT NULL,
  `syear` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_goal_progress`
--

CREATE TABLE `student_goal_progress` (
  `progress_id` int(8) NOT NULL,
  `goal_id` decimal(10,0) NOT NULL,
  `student_id` decimal(10,0) NOT NULL,
  `start_date` date DEFAULT NULL,
  `progress_name` text NOT NULL,
  `proficiency` varchar(100) NOT NULL,
  `progress_description` text NOT NULL,
  `course_period_id` decimal(10,0) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_gpa_calculated`
--

CREATE TABLE `student_gpa_calculated` (
  `student_id` decimal(10,0) DEFAULT NULL,
  `marking_period_id` int(11) DEFAULT NULL,
  `mp` varchar(4) DEFAULT NULL,
  `gpa` decimal(10,2) DEFAULT NULL,
  `weighted_gpa` decimal(10,2) DEFAULT NULL,
  `unweighted_gpa` decimal(10,2) DEFAULT NULL,
  `class_rank` decimal(10,0) DEFAULT NULL,
  `grade_level_short` varchar(100) DEFAULT NULL,
  `cgpa` decimal(10,2) DEFAULT NULL,
  `cum_unweighted_factor` decimal(10,6) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_immunization`
--

CREATE TABLE `student_immunization` (
  `id` int(8) NOT NULL,
  `student_id` decimal(10,0) DEFAULT NULL,
  `type` varchar(25) DEFAULT NULL,
  `medical_date` date DEFAULT NULL,
  `comments` longtext,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_medical_alerts`
--

CREATE TABLE `student_medical_alerts` (
  `id` int(8) NOT NULL,
  `student_id` decimal(10,0) DEFAULT NULL,
  `title` text,
  `alert_date` date DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_medical_notes`
--

CREATE TABLE `student_medical_notes` (
  `id` int(8) NOT NULL,
  `student_id` decimal(10,0) NOT NULL,
  `doctors_note_date` date DEFAULT NULL,
  `doctors_note_comments` longtext,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_medical_visits`
--

CREATE TABLE `student_medical_visits` (
  `id` int(8) NOT NULL,
  `student_id` decimal(10,0) DEFAULT NULL,
  `school_date` date DEFAULT NULL,
  `time_in` varchar(20) DEFAULT NULL,
  `time_out` varchar(20) DEFAULT NULL,
  `reason` text,
  `result` text,
  `comments` longtext,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_mp_comments`
--

CREATE TABLE `student_mp_comments` (
  `id` int(8) NOT NULL,
  `student_id` decimal(10,0) NOT NULL,
  `syear` decimal(4,0) NOT NULL,
  `marking_period_id` int(11) NOT NULL,
  `staff_id` int(11) DEFAULT NULL,
  `comment` longtext,
  `comment_date` date DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_report_card_comments`
--

CREATE TABLE `student_report_card_comments` (
  `syear` decimal(4,0) NOT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `student_id` decimal(10,0) NOT NULL,
  `course_period_id` decimal(10,0) NOT NULL,
  `report_card_comment_id` decimal(10,0) NOT NULL,
  `comment` varchar(1) DEFAULT NULL,
  `marking_period_id` int(11) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `student_report_card_grades`
--

CREATE TABLE `student_report_card_grades` (
  `syear` decimal(4,0) DEFAULT NULL,
  `school_id` decimal(10,0) DEFAULT NULL,
  `student_id` decimal(10,0) NOT NULL,
  `course_period_id` decimal(10,0) DEFAULT NULL,
  `report_card_grade_id` decimal(10,0) DEFAULT NULL,
  `report_card_comment_id` decimal(10,0) DEFAULT NULL,
  `comment` longtext,
  `grade_percent` decimal(5,2) DEFAULT NULL,
  `marking_period_id` varchar(10) NOT NULL,
  `grade_letter` varchar(5) DEFAULT NULL,
  `weighted_gp` decimal(10,3) DEFAULT NULL,
  `unweighted_gp` decimal(10,3) DEFAULT NULL,
  `gp_scale` decimal(10,3) DEFAULT NULL,
  `gpa_cal` varchar(2) DEFAULT NULL,
  `credit_attempted` decimal(10,3) DEFAULT NULL,
  `credit_earned` decimal(10,3) DEFAULT NULL,
  `credit_category` varchar(10) DEFAULT NULL,
  `course_code` varchar(100) DEFAULT NULL,
  `course_title` text,
  `id` int(8) NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Triggers `student_report_card_grades`
--
DELIMITER $$
CREATE TRIGGER `td_student_report_card_grades` AFTER DELETE ON `student_report_card_grades` FOR EACH ROW SELECT CALC_GPA_MP(OLD.student_id, OLD.marking_period_id) INTO @return$$
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `ti_student_report_card_grades` AFTER INSERT ON `student_report_card_grades` FOR EACH ROW SELECT CALC_GPA_MP(NEW.student_id, NEW.marking_period_id) INTO @return$$
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `tu_student_report_card_grades` AFTER UPDATE ON `student_report_card_grades` FOR EACH ROW SELECT CALC_GPA_MP(NEW.student_id, NEW.marking_period_id) INTO @return$$
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `system_preference`
--

CREATE TABLE `system_preference` (
  `id` int(8) NOT NULL,
  `school_id` int(8) NOT NULL,
  `full_day_minute` int(8) DEFAULT NULL,
  `half_day_minute` int(8) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `system_preference`
--

INSERT INTO `system_preference` (`id`, `school_id`, `full_day_minute`, `half_day_minute`, `last_updated`, `updated_by`) VALUES
(1, 1, 5, 2, '2019-07-28 08:26:33', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `system_preference_misc`
--

CREATE TABLE `system_preference_misc` (
  `fail_count` decimal(5,0) NOT NULL DEFAULT '3',
  `activity_days` decimal(5,0) NOT NULL DEFAULT '30',
  `system_maintenance_switch` char(1) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `teacher_reassignment`
--

CREATE TABLE `teacher_reassignment` (
  `course_period_id` int(11) NOT NULL,
  `teacher_id` int(11) NOT NULL,
  `assign_date` date NOT NULL,
  `modified_date` date NOT NULL,
  `pre_teacher_id` int(11) NOT NULL,
  `modified_by` int(11) NOT NULL,
  `updated` enum('Y','N') NOT NULL DEFAULT 'N',
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `temp_message_filepath_ws`
--

CREATE TABLE `temp_message_filepath_ws` (
  `id` int(11) NOT NULL,
  `keyval` varchar(100) NOT NULL,
  `filepath` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Stand-in structure for view `transcript_grades`
-- (See below for the actual view)
--
CREATE TABLE `transcript_grades` (
`school_id` int(8)
,`school_name` varchar(100)
,`mp_source` varchar(7)
,`mp_id` int(11)
,`mp_name` varchar(50)
,`syear` decimal(10,0)
,`posted` date
,`student_id` decimal(10,0)
,`gradelevel` varchar(100)
,`grade_letter` varchar(5)
,`gp_value` decimal(10,3)
,`weighting` decimal(10,3)
,`gp_scale` decimal(10,3)
,`credit_attempted` decimal(10,3)
,`credit_earned` decimal(10,3)
,`credit_category` varchar(10)
,`course_period_id` decimal(10,0)
,`course_name` text
,`course_short_name` varchar(25)
,`gpa_cal` varchar(2)
,`weighted_gpa` decimal(10,2)
,`unweighted_gpa` decimal(10,2)
,`gpa` decimal(10,2)
,`class_rank` decimal(10,0)
,`sort_order` decimal(10,0)
);

-- --------------------------------------------------------

--
-- Table structure for table `user_file_upload`
--

CREATE TABLE `user_file_upload` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `profile_id` int(11) NOT NULL,
  `school_id` int(11) NOT NULL,
  `syear` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `size` int(11) NOT NULL,
  `type` varchar(255) NOT NULL,
  `content` longblob NOT NULL,
  `file_info` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `user_profiles`
--

CREATE TABLE `user_profiles` (
  `id` int(8) NOT NULL,
  `profile` varchar(30) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `user_profiles`
--

INSERT INTO `user_profiles` (`id`, `profile`, `title`, `last_updated`, `updated_by`) VALUES
(0, 'admin', 'Super Administrator', '2019-07-27 21:26:33', NULL),
(1, 'admin', 'Administrator', '2019-07-27 21:26:33', NULL),
(2, 'teacher', 'Teacher', '2019-07-27 21:26:33', NULL),
(3, 'student', 'Student', '2019-07-27 21:26:33', NULL),
(4, 'parent', 'Parent', '2019-07-27 21:26:33', NULL),
(5, 'admin', 'Admin Asst', '2019-07-27 21:26:33', NULL);

-- --------------------------------------------------------

--
-- Structure for view `course_details`
--
DROP TABLE IF EXISTS `course_details`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `course_details`  AS  select `cp`.`school_id` AS `school_id`,`cp`.`syear` AS `syear`,`cp`.`marking_period_id` AS `marking_period_id`,`c`.`subject_id` AS `subject_id`,`cp`.`course_id` AS `course_id`,`cp`.`course_period_id` AS `course_period_id`,`cp`.`teacher_id` AS `teacher_id`,`cp`.`secondary_teacher_id` AS `secondary_teacher_id`,`c`.`title` AS `course_title`,`cp`.`title` AS `cp_title`,`cp`.`grade_scale_id` AS `grade_scale_id`,`cp`.`mp` AS `mp`,`cp`.`credits` AS `credits`,`cp`.`begin_date` AS `begin_date`,`cp`.`end_date` AS `end_date` from (`course_periods` `cp` join `courses` `c`) where (`cp`.`course_id` = `c`.`course_id`) ;

-- --------------------------------------------------------

--
-- Structure for view `enroll_grade`
--
DROP TABLE IF EXISTS `enroll_grade`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `enroll_grade`  AS  select `e`.`id` AS `id`,`e`.`syear` AS `syear`,`e`.`school_id` AS `school_id`,`e`.`student_id` AS `student_id`,`e`.`start_date` AS `start_date`,`e`.`end_date` AS `end_date`,`sg`.`short_name` AS `short_name`,`sg`.`title` AS `title` from (`student_enrollment` `e` join `school_gradelevels` `sg`) where (`e`.`grade_id` = `sg`.`id`) ;

-- --------------------------------------------------------

--
-- Structure for view `marking_periods`
--
DROP TABLE IF EXISTS `marking_periods`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `marking_periods`  AS  select `q`.`marking_period_id` AS `marking_period_id`,'openSIS' AS `mp_source`,`q`.`syear` AS `syear`,`q`.`school_id` AS `school_id`,'quarter' AS `mp_type`,`q`.`title` AS `title`,`q`.`short_name` AS `short_name`,`q`.`sort_order` AS `sort_order`,`q`.`semester_id` AS `parent_id`,`s`.`year_id` AS `grandparent_id`,`q`.`start_date` AS `start_date`,`q`.`end_date` AS `end_date`,`q`.`post_start_date` AS `post_start_date`,`q`.`post_end_date` AS `post_end_date`,`q`.`does_grades` AS `does_grades`,`q`.`does_exam` AS `does_exam`,`q`.`does_comments` AS `does_comments` from (`school_quarters` `q` join `school_semesters` `s` on((`q`.`semester_id` = `s`.`marking_period_id`))) union select `school_semesters`.`marking_period_id` AS `marking_period_id`,'openSIS' AS `mp_source`,`school_semesters`.`syear` AS `syear`,`school_semesters`.`school_id` AS `school_id`,'semester' AS `mp_type`,`school_semesters`.`title` AS `title`,`school_semesters`.`short_name` AS `short_name`,`school_semesters`.`sort_order` AS `sort_order`,`school_semesters`.`year_id` AS `parent_id`,-(1) AS `grandparent_id`,`school_semesters`.`start_date` AS `start_date`,`school_semesters`.`end_date` AS `end_date`,`school_semesters`.`post_start_date` AS `post_start_date`,`school_semesters`.`post_end_date` AS `post_end_date`,`school_semesters`.`does_grades` AS `does_grades`,`school_semesters`.`does_exam` AS `does_exam`,`school_semesters`.`does_comments` AS `does_comments` from `school_semesters` union select `school_years`.`marking_period_id` AS `marking_period_id`,'openSIS' AS `mp_source`,`school_years`.`syear` AS `syear`,`school_years`.`school_id` AS `school_id`,'year' AS `mp_type`,`school_years`.`title` AS `title`,`school_years`.`short_name` AS `short_name`,`school_years`.`sort_order` AS `sort_order`,-(1) AS `parent_id`,-(1) AS `grandparent_id`,`school_years`.`start_date` AS `start_date`,`school_years`.`end_date` AS `end_date`,`school_years`.`post_start_date` AS `post_start_date`,`school_years`.`post_end_date` AS `post_end_date`,`school_years`.`does_grades` AS `does_grades`,`school_years`.`does_exam` AS `does_exam`,`school_years`.`does_comments` AS `does_comments` from `school_years` union select `history_marking_periods`.`marking_period_id` AS `marking_period_id`,'History' AS `mp_source`,`history_marking_periods`.`syear` AS `syear`,`history_marking_periods`.`school_id` AS `school_id`,`history_marking_periods`.`mp_type` AS `mp_type`,`history_marking_periods`.`name` AS `title`,NULL AS `short_name`,NULL AS `sort_order`,`history_marking_periods`.`parent_id` AS `parent_id`,-(1) AS `grandparent_id`,NULL AS `start_date`,`history_marking_periods`.`post_end_date` AS `end_date`,NULL AS `post_start_date`,`history_marking_periods`.`post_end_date` AS `post_end_date`,'Y' AS `does_grades`,NULL AS `does_exam`,NULL AS `does_comments` from `history_marking_periods` ;

-- --------------------------------------------------------

--
-- Structure for view `transcript_grades`
--
DROP TABLE IF EXISTS `transcript_grades`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `transcript_grades`  AS  select `s`.`id` AS `school_id`,if((`mp`.`mp_source` = 'history'),(select `history_school`.`school_name` from `history_school` where ((`history_school`.`student_id` = `rcg`.`student_id`) and (`history_school`.`marking_period_id` = `mp`.`marking_period_id`))),`s`.`title`) AS `school_name`,`mp`.`mp_source` AS `mp_source`,`mp`.`marking_period_id` AS `mp_id`,`mp`.`title` AS `mp_name`,`mp`.`syear` AS `syear`,`mp`.`end_date` AS `posted`,`rcg`.`student_id` AS `student_id`,`sgc`.`grade_level_short` AS `gradelevel`,`rcg`.`grade_letter` AS `grade_letter`,`rcg`.`unweighted_gp` AS `gp_value`,`rcg`.`weighted_gp` AS `weighting`,`rcg`.`gp_scale` AS `gp_scale`,`rcg`.`credit_attempted` AS `credit_attempted`,`rcg`.`credit_earned` AS `credit_earned`,`rcg`.`credit_category` AS `credit_category`,`rcg`.`course_period_id` AS `course_period_id`,`rcg`.`course_title` AS `course_name`,(select `courses`.`short_name` from (`course_periods` join `courses`) where ((`course_periods`.`course_id` = `courses`.`course_id`) and (`course_periods`.`course_period_id` = `rcg`.`course_period_id`))) AS `course_short_name`,`rcg`.`gpa_cal` AS `gpa_cal`,`sgc`.`weighted_gpa` AS `weighted_gpa`,`sgc`.`unweighted_gpa` AS `unweighted_gpa`,`sgc`.`gpa` AS `gpa`,`sgc`.`class_rank` AS `class_rank`,`mp`.`sort_order` AS `sort_order` from (((`student_report_card_grades` `rcg` join `marking_periods` `mp` on(((`mp`.`marking_period_id` = `rcg`.`marking_period_id`) and (`mp`.`mp_type` in ('year','semester','quarter'))))) join `student_gpa_calculated` `sgc` on(((`sgc`.`student_id` = `rcg`.`student_id`) and (`sgc`.`marking_period_id` = `rcg`.`marking_period_id`)))) join `schools` `s` on((`s`.`id` = `mp`.`school_id`))) ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `api_info`
--
ALTER TABLE `api_info`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `attendance_calendar`
--
ALTER TABLE `attendance_calendar`
  ADD PRIMARY KEY (`syear`,`school_id`,`school_date`,`calendar_id`);

--
-- Indexes for table `attendance_codes`
--
ALTER TABLE `attendance_codes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `attendance_codes_ind2` (`syear`,`school_id`) USING BTREE,
  ADD KEY `attendance_codes_ind3` (`short_name`) USING BTREE;

--
-- Indexes for table `attendance_code_categories`
--
ALTER TABLE `attendance_code_categories`
  ADD PRIMARY KEY (`id`),
  ADD KEY `attendance_code_categories_ind1` (`id`) USING BTREE,
  ADD KEY `attendance_code_categories_ind2` (`syear`,`school_id`) USING BTREE;

--
-- Indexes for table `attendance_day`
--
ALTER TABLE `attendance_day`
  ADD PRIMARY KEY (`student_id`,`school_date`);

--
-- Indexes for table `attendance_period`
--
ALTER TABLE `attendance_period`
  ADD PRIMARY KEY (`student_id`,`school_date`,`period_id`),
  ADD KEY `attendance_period_ind1` (`student_id`) USING BTREE,
  ADD KEY `attendance_period_ind2` (`period_id`) USING BTREE,
  ADD KEY `attendance_period_ind3` (`attendance_code`) USING BTREE,
  ADD KEY `attendance_period_ind4` (`school_date`) USING BTREE,
  ADD KEY `attendance_period_ind5` (`attendance_code`) USING BTREE;

--
-- Indexes for table `calendar_events`
--
ALTER TABLE `calendar_events`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `courses`
--
ALTER TABLE `courses`
  ADD PRIMARY KEY (`course_id`),
  ADD KEY `courses_ind1` (`course_id`,`syear`) USING BTREE,
  ADD KEY `courses_ind2` (`subject_id`) USING BTREE;

--
-- Indexes for table `course_periods`
--
ALTER TABLE `course_periods`
  ADD PRIMARY KEY (`course_period_id`),
  ADD KEY `course_periods_ind1` (`syear`) USING BTREE,
  ADD KEY `course_periods_ind2` (`course_id`,`course_weight`,`syear`,`school_id`) USING BTREE,
  ADD KEY `course_periods_ind3` (`course_period_id`) USING BTREE,
  ADD KEY `course_periods_ind5` (`parent_id`) USING BTREE;

--
-- Indexes for table `course_period_var`
--
ALTER TABLE `course_period_var`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `course_subjects`
--
ALTER TABLE `course_subjects`
  ADD PRIMARY KEY (`subject_id`),
  ADD KEY `course_subjects_ind1` (`syear`,`school_id`,`subject_id`) USING BTREE;

--
-- Indexes for table `custom_fields`
--
ALTER TABLE `custom_fields`
  ADD PRIMARY KEY (`id`),
  ADD KEY `address_desc_ind2` (`type`) USING BTREE,
  ADD KEY `address_fields_ind3` (`category_id`) USING BTREE,
  ADD KEY `custom_desc_ind` (`id`) USING BTREE,
  ADD KEY `custom_desc_ind2` (`type`) USING BTREE,
  ADD KEY `custom_fields_ind3` (`category_id`) USING BTREE,
  ADD KEY `people_desc_ind2` (`type`) USING BTREE,
  ADD KEY `people_fields_ind3` (`category_id`) USING BTREE;

--
-- Indexes for table `device_info`
--
ALTER TABLE `device_info`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `eligibility`
--
ALTER TABLE `eligibility`
  ADD KEY `eligibility_ind1` (`student_id`,`course_period_id`,`school_date`) USING BTREE;

--
-- Indexes for table `eligibility_activities`
--
ALTER TABLE `eligibility_activities`
  ADD PRIMARY KEY (`id`),
  ADD KEY `eligibility_activities_ind1` (`school_id`,`syear`) USING BTREE;

--
-- Indexes for table `eligibility_completed`
--
ALTER TABLE `eligibility_completed`
  ADD PRIMARY KEY (`staff_id`,`school_date`,`period_id`);

--
-- Indexes for table `ethnicity`
--
ALTER TABLE `ethnicity`
  ADD PRIMARY KEY (`ethnicity_id`);

--
-- Indexes for table `filters`
--
ALTER TABLE `filters`
  ADD PRIMARY KEY (`filter_id`);

--
-- Indexes for table `filter_fields`
--
ALTER TABLE `filter_fields`
  ADD PRIMARY KEY (`filter_field_id`);

--
-- Indexes for table `gradebook_assignments`
--
ALTER TABLE `gradebook_assignments`
  ADD PRIMARY KEY (`assignment_id`),
  ADD KEY `gradebook_assignment_types_ind1` (`staff_id`,`course_id`) USING BTREE,
  ADD KEY `gradebook_assignments_ind1` (`staff_id`,`marking_period_id`) USING BTREE,
  ADD KEY `gradebook_assignments_ind2` (`course_id`,`course_period_id`) USING BTREE,
  ADD KEY `gradebook_assignments_ind3` (`assignment_type_id`) USING BTREE;

--
-- Indexes for table `gradebook_assignment_types`
--
ALTER TABLE `gradebook_assignment_types`
  ADD PRIMARY KEY (`assignment_type_id`);

--
-- Indexes for table `gradebook_grades`
--
ALTER TABLE `gradebook_grades`
  ADD PRIMARY KEY (`student_id`,`assignment_id`,`course_period_id`),
  ADD KEY `gradebook_grades_ind1` (`assignment_id`) USING BTREE;

--
-- Indexes for table `grades_completed`
--
ALTER TABLE `grades_completed`
  ADD PRIMARY KEY (`staff_id`,`marking_period_id`,`period_id`);

--
-- Indexes for table `history_marking_periods`
--
ALTER TABLE `history_marking_periods`
  ADD PRIMARY KEY (`marking_period_id`),
  ADD KEY `history_marking_period_ind1` (`school_id`) USING BTREE,
  ADD KEY `history_marking_period_ind2` (`syear`) USING BTREE,
  ADD KEY `history_marking_period_ind3` (`mp_type`) USING BTREE;

--
-- Indexes for table `history_school`
--
ALTER TABLE `history_school`
  ADD PRIMARY KEY (`id`),
  ADD KEY `id` (`id`);

--
-- Indexes for table `honor_roll`
--
ALTER TABLE `honor_roll`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `language`
--
ALTER TABLE `language`
  ADD PRIMARY KEY (`language_id`);

--
-- Indexes for table `login_authentication`
--
ALTER TABLE `login_authentication`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `COMPOSITE` (`user_id`,`profile_id`),
  ADD KEY `idx_login_authentication_username_password` (`username`,`password`);

--
-- Indexes for table `login_message`
--
ALTER TABLE `login_message`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `login_records`
--
ALTER TABLE `login_records`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `log_maintain`
--
ALTER TABLE `log_maintain`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `mail_group`
--
ALTER TABLE `mail_group`
  ADD PRIMARY KEY (`group_id`);

--
-- Indexes for table `mail_groupmembers`
--
ALTER TABLE `mail_groupmembers`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `marking_period_id_generator`
--
ALTER TABLE `marking_period_id_generator`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `medical_info`
--
ALTER TABLE `medical_info`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `missing_attendance`
--
ALTER TABLE `missing_attendance`
  ADD KEY `idx_appstart_check` (`course_period_id`,`period_id`,`syear`,`school_id`,`school_date`),
  ADD KEY `idx_missing_attendance_syear` (`syear`);

--
-- Indexes for table `msg_inbox`
--
ALTER TABLE `msg_inbox`
  ADD PRIMARY KEY (`mail_id`);

--
-- Indexes for table `msg_outbox`
--
ALTER TABLE `msg_outbox`
  ADD PRIMARY KEY (`mail_id`);

--
-- Indexes for table `people`
--
ALTER TABLE `people`
  ADD PRIMARY KEY (`staff_id`);

--
-- Indexes for table `people_fields`
--
ALTER TABLE `people_fields`
  ADD PRIMARY KEY (`id`),
  ADD KEY `people_desc_ind` (`id`) USING BTREE;

--
-- Indexes for table `people_field_categories`
--
ALTER TABLE `people_field_categories`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `portal_notes`
--
ALTER TABLE `portal_notes`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `program_config`
--
ALTER TABLE `program_config`
  ADD KEY `program_config_ind1` (`program`,`school_id`,`syear`) USING BTREE;

--
-- Indexes for table `program_user_config`
--
ALTER TABLE `program_user_config`
  ADD KEY `program_user_config_ind1` (`user_id`,`program`) USING BTREE;

--
-- Indexes for table `report_card_comments`
--
ALTER TABLE `report_card_comments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `report_card_comments_ind1` (`syear`,`school_id`) USING BTREE;

--
-- Indexes for table `report_card_grades`
--
ALTER TABLE `report_card_grades`
  ADD PRIMARY KEY (`id`),
  ADD KEY `report_card_grades_ind1` (`syear`,`school_id`) USING BTREE;

--
-- Indexes for table `report_card_grade_scales`
--
ALTER TABLE `report_card_grade_scales`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `rooms`
--
ALTER TABLE `rooms`
  ADD PRIMARY KEY (`room_id`);

--
-- Indexes for table `schedule`
--
ALTER TABLE `schedule`
  ADD PRIMARY KEY (`id`),
  ADD KEY `schedule_ind1` (`course_id`,`course_weight`) USING BTREE,
  ADD KEY `schedule_ind2` (`course_period_id`) USING BTREE,
  ADD KEY `schedule_ind3` (`student_id`,`marking_period_id`,`start_date`,`end_date`) USING BTREE,
  ADD KEY `schedule_ind4` (`syear`,`school_id`) USING BTREE;

--
-- Indexes for table `schedule_requests`
--
ALTER TABLE `schedule_requests`
  ADD PRIMARY KEY (`request_id`),
  ADD KEY `schedule_requests_ind1` (`student_id`,`course_id`,`course_weight`,`syear`,`school_id`) USING BTREE,
  ADD KEY `schedule_requests_ind2` (`syear`,`school_id`) USING BTREE,
  ADD KEY `schedule_requests_ind3` (`course_id`,`course_weight`,`syear`,`school_id`) USING BTREE,
  ADD KEY `schedule_requests_ind4` (`with_teacher_id`) USING BTREE,
  ADD KEY `schedule_requests_ind5` (`not_teacher_id`) USING BTREE,
  ADD KEY `schedule_requests_ind6` (`with_period_id`) USING BTREE,
  ADD KEY `schedule_requests_ind7` (`not_period_id`) USING BTREE,
  ADD KEY `schedule_requests_ind8` (`request_id`) USING BTREE;

--
-- Indexes for table `schools`
--
ALTER TABLE `schools`
  ADD PRIMARY KEY (`id`),
  ADD KEY `schools_ind1` (`syear`) USING BTREE;

--
-- Indexes for table `school_calendars`
--
ALTER TABLE `school_calendars`
  ADD PRIMARY KEY (`calendar_id`);

--
-- Indexes for table `school_custom_fields`
--
ALTER TABLE `school_custom_fields`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `school_gradelevels`
--
ALTER TABLE `school_gradelevels`
  ADD PRIMARY KEY (`id`),
  ADD KEY `school_gradelevels_ind1` (`school_id`) USING BTREE;

--
-- Indexes for table `school_gradelevel_sections`
--
ALTER TABLE `school_gradelevel_sections`
  ADD PRIMARY KEY (`id`),
  ADD KEY `school_gradelevels_ind1` (`school_id`) USING BTREE;

--
-- Indexes for table `school_periods`
--
ALTER TABLE `school_periods`
  ADD PRIMARY KEY (`period_id`),
  ADD KEY `school_periods_ind1` (`period_id`,`syear`) USING BTREE;

--
-- Indexes for table `school_progress_periods`
--
ALTER TABLE `school_progress_periods`
  ADD PRIMARY KEY (`marking_period_id`),
  ADD KEY `school_progress_periods_ind1` (`quarter_id`) USING BTREE,
  ADD KEY `school_progress_periods_ind2` (`syear`,`school_id`,`start_date`,`end_date`) USING BTREE;

--
-- Indexes for table `school_quarters`
--
ALTER TABLE `school_quarters`
  ADD PRIMARY KEY (`marking_period_id`),
  ADD KEY `school_quarters_ind1` (`semester_id`) USING BTREE,
  ADD KEY `school_quarters_ind2` (`syear`,`school_id`,`start_date`,`end_date`) USING BTREE;

--
-- Indexes for table `school_semesters`
--
ALTER TABLE `school_semesters`
  ADD PRIMARY KEY (`marking_period_id`),
  ADD KEY `school_semesters_ind1` (`year_id`) USING BTREE,
  ADD KEY `school_semesters_ind2` (`syear`,`school_id`,`start_date`,`end_date`) USING BTREE;

--
-- Indexes for table `school_years`
--
ALTER TABLE `school_years`
  ADD PRIMARY KEY (`marking_period_id`),
  ADD KEY `school_years_ind2` (`syear`,`school_id`,`start_date`,`end_date`) USING BTREE;

--
-- Indexes for table `staff`
--
ALTER TABLE `staff`
  ADD PRIMARY KEY (`staff_id`),
  ADD KEY `staff_ind2` (`last_name`,`first_name`) USING BTREE;

--
-- Indexes for table `staff_address`
--
ALTER TABLE `staff_address`
  ADD PRIMARY KEY (`staff_address_id`),
  ADD UNIQUE KEY `staff_id` (`staff_id`);

--
-- Indexes for table `staff_certification`
--
ALTER TABLE `staff_certification`
  ADD PRIMARY KEY (`staff_certification_id`);

--
-- Indexes for table `staff_contact`
--
ALTER TABLE `staff_contact`
  ADD PRIMARY KEY (`staff_phone_id`),
  ADD UNIQUE KEY `staff_id` (`staff_id`);

--
-- Indexes for table `staff_emergency_contact`
--
ALTER TABLE `staff_emergency_contact`
  ADD PRIMARY KEY (`staff_emergency_contact_id`),
  ADD UNIQUE KEY `staff_id` (`staff_id`);

--
-- Indexes for table `staff_fields`
--
ALTER TABLE `staff_fields`
  ADD PRIMARY KEY (`id`),
  ADD KEY `staff_desc_ind1` (`id`) USING BTREE,
  ADD KEY `staff_desc_ind2` (`type`) USING BTREE,
  ADD KEY `staff_fields_ind3` (`category_id`) USING BTREE;

--
-- Indexes for table `staff_school_info`
--
ALTER TABLE `staff_school_info`
  ADD PRIMARY KEY (`staff_school_info_id`),
  ADD UNIQUE KEY `staff_id` (`staff_id`);

--
-- Indexes for table `staff_school_relationship`
--
ALTER TABLE `staff_school_relationship`
  ADD PRIMARY KEY (`staff_id`,`school_id`,`syear`);

--
-- Indexes for table `students`
--
ALTER TABLE `students`
  ADD PRIMARY KEY (`student_id`),
  ADD KEY `name` (`last_name`,`first_name`,`middle_name`) USING BTREE,
  ADD KEY `idx_students_search` (`is_disable`) COMMENT 'Student Info -> search all';

--
-- Indexes for table `students_join_people`
--
ALTER TABLE `students_join_people`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `student_address`
--
ALTER TABLE `student_address`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `student_eligibility_activities`
--
ALTER TABLE `student_eligibility_activities`
  ADD KEY `student_eligibility_activities_ind1` (`student_id`) USING BTREE;

--
-- Indexes for table `student_enrollment`
--
ALTER TABLE `student_enrollment`
  ADD PRIMARY KEY (`id`),
  ADD KEY `student_enrollment_1` (`student_id`,`enrollment_code`) USING BTREE,
  ADD KEY `student_enrollment_2` (`grade_id`) USING BTREE,
  ADD KEY `student_enrollment_3` (`syear`,`student_id`,`school_id`,`grade_id`) USING BTREE,
  ADD KEY `student_enrollment_6` (`syear`,`student_id`,`start_date`,`end_date`) USING BTREE,
  ADD KEY `student_enrollment_7` (`school_id`) USING BTREE,
  ADD KEY `idx_student_search` (`school_id`,`syear`,`start_date`,`end_date`,`drop_code`) COMMENT 'Student Info -> search all';

--
-- Indexes for table `student_enrollment_codes`
--
ALTER TABLE `student_enrollment_codes`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `student_field_categories`
--
ALTER TABLE `student_field_categories`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `student_goal`
--
ALTER TABLE `student_goal`
  ADD PRIMARY KEY (`goal_id`);

--
-- Indexes for table `student_goal_progress`
--
ALTER TABLE `student_goal_progress`
  ADD PRIMARY KEY (`progress_id`);

--
-- Indexes for table `student_gpa_calculated`
--
ALTER TABLE `student_gpa_calculated`
  ADD KEY `student_gpa_calculated_ind1` (`marking_period_id`,`student_id`) USING BTREE;

--
-- Indexes for table `student_immunization`
--
ALTER TABLE `student_immunization`
  ADD PRIMARY KEY (`id`),
  ADD KEY `student_medical_ind1` (`student_id`) USING BTREE;

--
-- Indexes for table `student_medical_alerts`
--
ALTER TABLE `student_medical_alerts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `student_medical_alerts_ind1` (`student_id`) USING BTREE;

--
-- Indexes for table `student_medical_notes`
--
ALTER TABLE `student_medical_notes`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `student_medical_visits`
--
ALTER TABLE `student_medical_visits`
  ADD PRIMARY KEY (`id`),
  ADD KEY `student_medical_visits_ind1` (`student_id`) USING BTREE;

--
-- Indexes for table `student_mp_comments`
--
ALTER TABLE `student_mp_comments`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `student_report_card_comments`
--
ALTER TABLE `student_report_card_comments`
  ADD PRIMARY KEY (`syear`,`student_id`,`course_period_id`,`marking_period_id`,`report_card_comment_id`),
  ADD KEY `student_report_card_comments_ind1` (`school_id`) USING BTREE;

--
-- Indexes for table `student_report_card_grades`
--
ALTER TABLE `student_report_card_grades`
  ADD PRIMARY KEY (`id`),
  ADD KEY `student_report_card_grades_ind1` (`school_id`) USING BTREE,
  ADD KEY `student_report_card_grades_ind2` (`student_id`) USING BTREE,
  ADD KEY `student_report_card_grades_ind3` (`course_period_id`) USING BTREE,
  ADD KEY `student_report_card_grades_ind4` (`marking_period_id`) USING BTREE;

--
-- Indexes for table `system_preference`
--
ALTER TABLE `system_preference`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `temp_message_filepath_ws`
--
ALTER TABLE `temp_message_filepath_ws`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `user_file_upload`
--
ALTER TABLE `user_file_upload`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `user_profiles`
--
ALTER TABLE `user_profiles`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `api_info`
--
ALTER TABLE `api_info`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attendance_codes`
--
ALTER TABLE `attendance_codes`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attendance_code_categories`
--
ALTER TABLE `attendance_code_categories`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `calendar_events`
--
ALTER TABLE `calendar_events`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `courses`
--
ALTER TABLE `courses`
  MODIFY `course_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `course_periods`
--
ALTER TABLE `course_periods`
  MODIFY `course_period_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `course_period_var`
--
ALTER TABLE `course_period_var`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `course_subjects`
--
ALTER TABLE `course_subjects`
  MODIFY `subject_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `custom_fields`
--
ALTER TABLE `custom_fields`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `device_info`
--
ALTER TABLE `device_info`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `eligibility_activities`
--
ALTER TABLE `eligibility_activities`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ethnicity`
--
ALTER TABLE `ethnicity`
  MODIFY `ethnicity_id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT for table `filters`
--
ALTER TABLE `filters`
  MODIFY `filter_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `filter_fields`
--
ALTER TABLE `filter_fields`
  MODIFY `filter_field_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `gradebook_assignments`
--
ALTER TABLE `gradebook_assignments`
  MODIFY `assignment_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `gradebook_assignment_types`
--
ALTER TABLE `gradebook_assignment_types`
  MODIFY `assignment_type_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `history_school`
--
ALTER TABLE `history_school`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `honor_roll`
--
ALTER TABLE `honor_roll`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `language`
--
ALTER TABLE `language`
  MODIFY `language_id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `login_authentication`
--
ALTER TABLE `login_authentication`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `login_message`
--
ALTER TABLE `login_message`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `login_records`
--
ALTER TABLE `login_records`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `log_maintain`
--
ALTER TABLE `log_maintain`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `mail_group`
--
ALTER TABLE `mail_group`
  MODIFY `group_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `mail_groupmembers`
--
ALTER TABLE `mail_groupmembers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `marking_period_id_generator`
--
ALTER TABLE `marking_period_id_generator`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `medical_info`
--
ALTER TABLE `medical_info`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `msg_inbox`
--
ALTER TABLE `msg_inbox`
  MODIFY `mail_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `msg_outbox`
--
ALTER TABLE `msg_outbox`
  MODIFY `mail_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `people`
--
ALTER TABLE `people`
  MODIFY `staff_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `people_fields`
--
ALTER TABLE `people_fields`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `people_field_categories`
--
ALTER TABLE `people_field_categories`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `portal_notes`
--
ALTER TABLE `portal_notes`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `report_card_comments`
--
ALTER TABLE `report_card_comments`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `report_card_grades`
--
ALTER TABLE `report_card_grades`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `report_card_grade_scales`
--
ALTER TABLE `report_card_grade_scales`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `rooms`
--
ALTER TABLE `rooms`
  MODIFY `room_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `schedule`
--
ALTER TABLE `schedule`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `schedule_requests`
--
ALTER TABLE `schedule_requests`
  MODIFY `request_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `schools`
--
ALTER TABLE `schools`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `school_calendars`
--
ALTER TABLE `school_calendars`
  MODIFY `calendar_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `school_custom_fields`
--
ALTER TABLE `school_custom_fields`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `school_gradelevels`
--
ALTER TABLE `school_gradelevels`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `school_gradelevel_sections`
--
ALTER TABLE `school_gradelevel_sections`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `school_periods`
--
ALTER TABLE `school_periods`
  MODIFY `period_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `staff`
--
ALTER TABLE `staff`
  MODIFY `staff_id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `staff_address`
--
ALTER TABLE `staff_address`
  MODIFY `staff_address_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `staff_certification`
--
ALTER TABLE `staff_certification`
  MODIFY `staff_certification_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `staff_contact`
--
ALTER TABLE `staff_contact`
  MODIFY `staff_phone_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `staff_emergency_contact`
--
ALTER TABLE `staff_emergency_contact`
  MODIFY `staff_emergency_contact_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `staff_fields`
--
ALTER TABLE `staff_fields`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `staff_school_info`
--
ALTER TABLE `staff_school_info`
  MODIFY `staff_school_info_id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `students`
--
ALTER TABLE `students`
  MODIFY `student_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `students_join_people`
--
ALTER TABLE `students_join_people`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_address`
--
ALTER TABLE `student_address`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_enrollment`
--
ALTER TABLE `student_enrollment`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_enrollment_codes`
--
ALTER TABLE `student_enrollment_codes`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `student_field_categories`
--
ALTER TABLE `student_field_categories`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `student_goal`
--
ALTER TABLE `student_goal`
  MODIFY `goal_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_goal_progress`
--
ALTER TABLE `student_goal_progress`
  MODIFY `progress_id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_immunization`
--
ALTER TABLE `student_immunization`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_medical_alerts`
--
ALTER TABLE `student_medical_alerts`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_medical_notes`
--
ALTER TABLE `student_medical_notes`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_medical_visits`
--
ALTER TABLE `student_medical_visits`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_mp_comments`
--
ALTER TABLE `student_mp_comments`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `student_report_card_grades`
--
ALTER TABLE `student_report_card_grades`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `system_preference`
--
ALTER TABLE `system_preference`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `temp_message_filepath_ws`
--
ALTER TABLE `temp_message_filepath_ws`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_file_upload`
--
ALTER TABLE `user_file_upload`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_profiles`
--
ALTER TABLE `user_profiles`
  MODIFY `id` int(8) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
