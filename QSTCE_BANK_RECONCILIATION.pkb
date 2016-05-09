CREATE OR REPLACE PACKAGE BODY APPS.QSTCE_BANK_RECONCILIATION AS
/******************************************************************************
   NAME:       QSTCE_BANK_RECONCILIATION.pkb
   PURPOSE:    Quest Custom Program to process Cash Management Statements

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        7/24/2012      pgreen       1. Created this package body.
  1.1        03/06/13     pgreen        change code to clear lines trx_text if has
                                         foreign characters
  1.2	     04/29/13     pgreen	Add logic for JPMorgan Implementation
  1.3 	     06/11/13     pgreen 	Add Logic to create Statement Lines for 
					Credit Cards.
					Proccessing for EMEA Month End Receipts
  1.4   07/09/13    pgreen      fix restart to included statements loaded but
                                not transfered
                                fix receipts duplicating with credit card logic
                                change GL date to be statement date
 1.5  09/04/13     pgreen       Improved Month End process for Deutsche setting
                                Receipt Number. 
 1.6  11/19/13     pgreen	Added logic for TC 455 to check if payment exists    
				if flagged l.attribute10 = Y. if payment doesn't exist
				change TC to 455-1.                     
1.7  12/18/13   pgreen      Add logic to Create and Apply Receipts when flagged
                            attribute10
1.8  06/16/14  PGREEN     Changed to Create and Apply Receipts first if errors
                          then just Create Receipts   
1.9  11/11/14  PGREEN     Changed to process CyberSource Credit Card Receipts                                                    
******************************************************************************/

/*
  l_request_id NUMBER := 0 ; 

  mode_boolean BOOLEAN; 
 
  L_ERRBUF VARCHAR2(32767);
  L_RETCODE NUMBER;
  l_option                     VARCHAR2(100);
  l_bank_branch_id          NUMBER;
  l_bank_account_id            NUMBER;
  l_statement_number_from      VARCHAR2(100);
  l_statement_number_to        VARCHAR2(100);
  l_statement_date_from        VARCHAR2(100);
  l_statement_date_to          VARCHAR2(100);
  l_gl_date                    VARCHAR2(100);
  l_org_id             VARCHAR2(100);
  l_legal_entity_id         VARCHAR2(100);
  l_receivables_trx_id         NUMBER;
  l_payment_method_id         NUMBER;
  l_nsf_handling               VARCHAR2(100);
  l_display_debug             VARCHAR2(100);
  l_debug_path             VARCHAR2(100);
  l_debug_file             VARCHAR2(100);
  l_intra_day_flag         VARCHAR2(100);

l_process_option      VARCHAR2(100);
l_loading_id        NUMBER;
l_input_file        VARCHAR2(1000);
l_directory_path      VARCHAR2(1000);

l_phase_code varchar2(30);
l_status_code  varchar2(30);
l_loop_count number := 0;
l_loop_flag boolean := true;
l_creation_date date := trunc(sysdate);
l_bank_branch_name varchar2(360);
l_bank_name varchar2(360); 
l_bank_org_id number;
l_bank_account_num varchar2(30);
l_statement_date date;
l_currency_code varchar2(15);
l_record_status_flag varchar2(1);
l_record_status_cnt number;
l_message_name varchar2(30);
*/





  PROCEDURE submit_reconciliation_files(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_code in varchar2) is

l_errbuf varchar2(1000);
l_retcode number;
l_directory_name varchar2(100);
l_file_name varchar2(100);

cursor files_cur is
SELECT qb.directory_name, qb.file_name 
FROM qstce_bai2_files qb
where qb.processed_date is null
and qb.bank_code = nvl(p_bank_code, qb.bank_code)
and qb.file_name NOT like 'BAI_ME_%'
order by qb.bank_code, creation_date;

begin
null;
  fnd_global.apps_initialize('1433','52653','260'); -- user_id, responsibility_id, application_id
  mo_global.init('CE'); -- application_short_name
null;
--  mo_global.set_policy_context('S',84); -- (s)ingle org, org_id  

/*
--obtain request_id so can query when finished
select max(r.request_id) max_request_id
into l_submit_req_id
FROM   fnd_responsibility_tl rt,
       fnd_user u,
       fnd_concurrent_requests r,
       fnd_concurrent_programs_tl pt
WHERE  u.user_id = r.requested_by
AND       rt.responsibility_id = r.responsibility_id
AND       rt.application_id = r.responsibility_application_id
AND       rt.LANGUAGE = 'US'
AND       r.concurrent_program_id = pt.concurrent_program_id
AND       r.program_application_id = pt.APPLICATION_ID 
AND       pt.LANGUAGE = rt.LANGUAGE
and       pt.user_concurrent_program_name = 'Quest CE Submit Bank Reconciliation Files' 
AND       NVL(r.actual_completion_date,SYSDATE) > SYSDATE-90
and       r.argument_text like '%'||p_bank_code||'%';
*/
null;

    for files_rec in files_cur loop
        NULL;

        l_directory_name := files_rec.directory_name;
        l_file_name := files_rec.file_name;
        
        
       update qstce_bai2_files qb
        set processed_date = sysdate
        where qb.processed_date is null
        and qb.bank_code = nvl(p_bank_code, qb.bank_code)
        and qb.directory_name = l_directory_name 
        and qb.file_name = l_file_name;
      
       
        commit;

        
        submit_reconciliation(l_errbuf, l_retcode, p_bank_code, l_file_name, l_directory_name); 
        
         
    end loop; --for files_rec in files_cur loop

null;

end submit_reconciliation_files; 

  PROCEDURE submit_reconciliation(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_code in varchar2,
                                   p_input_file in varchar2,
                                   p_directory_path in varchar2) is

  l_request_id NUMBER := 0 ; 


  mode_boolean BOOLEAN; 
 
  L_ERRBUF VARCHAR2(32767);
  L_RETCODE NUMBER;
  l_option                     VARCHAR2(100);
  l_bank_branch_id          NUMBER;
  l_bank_account_id            NUMBER;
  l_statement_number_from      VARCHAR2(100);
  l_statement_number_to        VARCHAR2(100);
  l_statement_date_from        VARCHAR2(100);
  l_statement_date_to          VARCHAR2(100);
  l_gl_date                    VARCHAR2(100);
  l_org_id             VARCHAR2(100);
  l_legal_entity_id         VARCHAR2(100);
  l_receivables_trx_id         NUMBER;
  l_payment_method_id         NUMBER;
  l_nsf_handling               VARCHAR2(100);
  l_display_debug             VARCHAR2(100);
  l_debug_path             VARCHAR2(100);
  l_debug_file             VARCHAR2(100);
  l_intra_day_flag         VARCHAR2(100);

l_process_option      VARCHAR2(100);
l_loading_id        NUMBER;
l_input_file        VARCHAR2(1000);
l_directory_path      VARCHAR2(1000);

l_phase_code varchar2(30);
l_status_code  varchar2(30);
l_loop_count number := 0;
l_loop_flag boolean := true;
l_creation_date date := trunc(sysdate);
l_bank_branch_name varchar2(360);
l_bank_name varchar2(360); 
l_bank_org_id number;
l_bank_account_num varchar2(30);
l_statement_date date;
l_currency_code varchar2(15);
l_record_status_flag varchar2(1);
l_line_cnt number;
l_unreconciled_line_cnt number;
l_message_name varchar2(30);
l_control_line_count number;

l_submit_req_id number; 

l_error_cnt number;

l_message_text varchar2(2000);

l_clear_trx_text varchar2(1);  --pgreen 03/06/13

l_remove_flag number := 0;  -- pgreen 04/29/13

--Retrieve all Interface headers created today and weren't already Transfered yet.
cursor stmt_head_cur is
select shi.control_cr_line_count, trunc(shi.statement_date) statement_date , shi.currency_code, shi.control_line_count,
bau.org_id, bau.BANK_ACCT_USE_ID, ba.bank_branch_id, 
ba.bank_account_id, shi.statement_number,
ba.bank_account_num, bb.bank_branch_name, bb.bank_name, ba.attribute1 loading_id
,nvl(ba.attribute2,'N') clear_trx_text  --pgreen 03/06/13
from CE_STATEMENT_HEADERS_INT shi,
CE_BANK_ACCOUNTS BA,
CE_BANK_ACCT_USES_ALL BAU,
CE_BANK_BRANCHES_V BB
where 1=1 
--and shi.bank_account_num = '4681939101' --'939329637'  --********  temporary **********
and ba.bank_account_num = shi.bank_account_num
AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID
and BB.BANK_PARTY_ID = BA.BANK_ID
AND BB.BRANCH_PARTY_ID = BA.BANK_BRANCH_ID
and trunc(shi.creation_date) = l_creation_date
and shi.record_status_flag != 'T'
and ba.attribute1 = p_bank_code
--AND ba.bank_account_num = '939329637'   -- ****** TEMPORARY ************
order by shi.statement_date;

cursor stmt_load_errors_cur is
select statement_number, bank_account_num, message_text
FROM CE_SQLLDR_ERRORS SE
where trunc(se.creation_date) = l_creation_date
and status = 'E';

BEGIN

--------------------------------------------------------
-- R12 US Org Setup

--  fnd_global.apps_initialize('1152','52653','260'); -- user_id, responsibility_id, application_id
--  mo_global.init('CE'); -- application_short_name
--  mo_global.set_policy_context('S',84); -- (s)ingle org, org_id  

/* 
    mode_boolean := Fnd_Request.set_mode(TRUE); 


    IF (NOT mode_boolean) THEN 
      RAISE_APPLICATION_ERROR(-20995,Fnd_Message.get); 
    END IF; -- not mode_boolean
*/

--obtain request_id so can query when finished
begin
    select max(r.request_id) max_request_id
    into l_submit_req_id
    FROM   fnd_responsibility_tl rt,
           fnd_user u,
           fnd_concurrent_requests r,
           fnd_concurrent_programs_tl pt
    WHERE  u.user_id = r.requested_by
    AND       rt.responsibility_id = r.responsibility_id
    AND       rt.application_id = r.responsibility_application_id
    AND       rt.LANGUAGE = 'US'
    AND       r.concurrent_program_id = pt.concurrent_program_id
    AND       r.program_application_id = pt.APPLICATION_ID 
    AND       pt.LANGUAGE = rt.LANGUAGE
    and       pt.user_concurrent_program_name = 'Quest CE Submit Bank Reconciliation Files' 
    AND       NVL(r.actual_completion_date,SYSDATE) > SYSDATE-90
    and       r.argument_text like '%'||p_bank_code||'%';
exception
  when others then
    l_submit_req_id := null;
end;

--create log header record with file info ************
insert into qstce_statement_log (file_name, directory_path, creation_date, submit_req_id, bank_code, statement_log_id) values
                                (p_input_file, p_directory_path, sysdate, l_submit_req_id, p_bank_code, qstce_statement_log_id.nextval);
  commit;                           
                                
  select to_char(sysdate,'YYYY/MM/DD') ||' 00:00:00' DTE 
  INTO l_gl_date
  from dual;


  l_statement_date_from  := null;  --   VARCHAR2(100);
  l_statement_date_to   := null;  --        VARCHAR2(100);
  l_org_id  := null;  --           VARCHAR2(100);
  l_legal_entity_id   := null;  --       VARCHAR2(100);
  l_receivables_trx_id  := null;  --        NUMBER;
  l_payment_method_id  := null;  --        NUMBER;
  l_nsf_handling := NULL; --              VARCHAR2(100);
  l_display_debug   := 'N'; --          VARCHAR2(100);
  l_debug_path    := null;  --         VARCHAR2(100);
  l_debug_file    := null;  --         VARCHAR2(100);
  l_intra_day_flag := null;  --        VARCHAR2(100);
  l_bank_account_id := null; 


--p_input_file


--Submit 'Bank Statement Loader'--------------------------------------------------------------------------------------
   select  v.attribute1 
   into l_loading_id 
   from  FND_FLEX_VALUE_SETS VS,
    fnd_flex_values_vl  v
   where  VS.FLEX_VALUE_SET_NAME = 'QSTCE_BAI2_MAPPING'
    AND V.FLEX_VALUE_SET_ID = VS.FLEX_VALUE_SET_ID
    and v.flex_value = p_bank_code;



      l_process_option  := 'LOAD'; --    IN    VARCHAR2,
--      l_loading_id    := 2020; -- 1020; --    IN    NUMBER,      Mapping Name
      l_input_file    := p_input_file; --'QUESTSOFT.IRIS.PBAIUS.20120425050311.txt'; --    IN    VARCHAR2,
      l_directory_path  := p_directory_path; --'/apps/R12DEV/jpmc/BAI/'; --    IN    VARCHAR2,

      l_request_id := Fnd_Request.submit_request('CE','CESQLLDR',
                        NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_process_option, l_loading_id, l_input_file, l_directory_path, l_bank_branch_id, l_bank_account_id, l_gl_date, l_org_id , l_receivables_trx_id, l_payment_method_id, l_nsf_handling, l_display_debug,l_debug_path ,l_debug_file); --PGREEN 09/26/11

        IF (l_request_id = 0) THEN 
          RAISE_APPLICATION_ERROR(-20996,Fnd_Message.get); 
        else
            update qstce_statement_log
            set statement_loader_req_id = l_request_id
            where file_name = p_input_file
            and directory_path = p_directory_path;
            commit;
        END IF; -- l_request_id = 0


    l_loop_count := 0;
    l_loop_flag := true;

    while l_loop_flag loop
            l_loop_count := l_loop_count + 1;
            begin

            select r.phase_code,   r.status_code
            into l_phase_code,   l_status_code
            from fnd_concurrent_requests r
            where r.request_id = l_request_id;
            exception
              when others then
                    null;
            end;
            
            
            if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                 l_loop_flag := false;
            ELSE
                dbms_lock.sleep( 60 );  --seconds        
            end if;  

    end loop;

    l_loop_count := 0;
    l_loop_flag := true;

    while l_loop_flag loop
            l_loop_count := l_loop_count + 1;
            begin

            select r.phase_code,   r.status_code
            into l_phase_code,   l_status_code
            FROM   fnd_responsibility_tl rt,
                   fnd_user u,
                   fnd_concurrent_requests r,
                   fnd_concurrent_programs_tl pt
            WHERE  u.user_id = r.requested_by
            AND       rt.responsibility_id = r.responsibility_id
            AND       rt.application_id = r.responsibility_application_id
            AND       rt.LANGUAGE = 'US'
            AND       r.concurrent_program_id = pt.concurrent_program_id
            AND       r.program_application_id = pt.APPLICATION_ID 
            AND       pt.LANGUAGE = rt.LANGUAGE
            and       pt.user_concurrent_program_name = 'Load Bank Statement Data' 
            AND       NVL(r.actual_completion_date,SYSDATE) > SYSDATE-1
            and       r.argument_text like '%'||l_input_file||'%'
            and       r.request_id = --3860129
                (select max(r.request_id) max_request_id
                FROM   fnd_responsibility_tl rt,
                       fnd_user u,
                       fnd_concurrent_requests r,
                       fnd_concurrent_programs_tl pt
                WHERE  u.user_id = r.requested_by
                AND       rt.responsibility_id = r.responsibility_id
                AND       rt.application_id = r.responsibility_application_id
                AND       rt.LANGUAGE = 'US'
                AND       r.concurrent_program_id = pt.concurrent_program_id
                AND       r.program_application_id = pt.APPLICATION_ID 
                AND       pt.LANGUAGE = rt.LANGUAGE
                and       pt.user_concurrent_program_name = 'Load Bank Statement Data' 
                AND       NVL(r.actual_completion_date,SYSDATE) > SYSDATE-1
                and       r.argument_text like '%'||l_input_file||'%'
                and       r.request_id > l_request_id);


            exception
              when others then
                    null;
            end;
            
            
            if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                 l_loop_flag := false;
            ELSE
                dbms_lock.sleep( 60 );  --seconds        
            end if;  

    end loop;


-- ERROR CHECKING DURING SQL LOAD -- SEND AND EMAIL
for stmt_load_errors_rec in stmt_load_errors_cur loop
    l_statement_number_from := stmt_load_errors_rec.statement_number;
    l_bank_account_num := stmt_load_errors_rec.bank_account_num;
    l_message_text := stmt_load_errors_rec.message_text;

    insert into qstce_statement_log (file_name, directory_path, creation_date, submit_req_id, bank_code, 
    bank_account_num,  statement_number, statement_loader_message, statement_log_id) 
    values
    (p_input_file, p_directory_path, sysdate, l_submit_req_id, p_bank_code,
    l_bank_account_num, l_statement_number_from, l_message_text, qstce_statement_log_id.nextval);
    
    commit;

 
end loop; --for stmt_load_errors_rec in stmt_load_errors_cur loop


-----------------------------------------------------------------------------
--Retrieve all Interface headers created today and weren't already Transfered yet.
 for stmt_head_rec in stmt_head_cur loop
--      l_option      := 'ZALL'; --               VARCHAR2(100);
      l_bank_branch_id := stmt_head_rec.bank_branch_id;     --    NUMBER;
      l_bank_account_id := stmt_head_rec.bank_account_id; --           NUMBER;
      l_statement_number_from   := stmt_head_rec.statement_number; --   VARCHAR2(100);
      l_statement_number_to    := stmt_head_rec.statement_number; --    VARCHAR2(100);
      l_bank_name  := stmt_head_rec.bank_name;
      l_bank_branch_name  := stmt_head_rec.bank_branch_name;
      l_bank_account_num  := stmt_head_rec.bank_account_num;
      l_bank_org_id  := stmt_head_rec.org_id;
      l_statement_date := stmt_head_rec.statement_date;
      l_currency_code := stmt_head_rec.currency_code;
      l_control_line_count := stmt_head_rec.control_line_count;
      l_clear_trx_text := stmt_head_rec.clear_trx_text; --pgreen 03/06/13
 
/* --pgreen 08/05/13 
--begin pgreen 07/09/13    
      select to_char(l_statement_date,'YYYY/MM/DD') ||' 00:00:00' DTE 
      INTO l_gl_date
      from dual;

--     l_gl_date := l_statement_date; --pgreen 07/09/13
--end pgreen 07/09/13      
*/ --end pgreen 08/05/13
 
     l_message_name := null;
     
 --??????????????????????  pgreen 03/29/13    
--BEGIN PGREEN 04/29/13
--Remove statements for accounts that should not be reconciled (Ex. JPMC payroll) 
   l_remove_flag := 0;
         
     SELECT count(*)
     into l_remove_flag
     FROM fnd_lookup_values_vl  L
     WHERE L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
        and nvl(l.attribute6, p_bank_code) = p_bank_code    
        and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num
        AND l_statement_date  BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)     
     AND L.ATTRIBUTE2 = 'REMOVE';


    if l_remove_flag = 1 then  
        delete FROM CE_STATEMENT_LINES_INTERFACE sli
        where sli.bank_account_num = l_bank_account_num
        and sli.statement_number = l_statement_number_from;

        delete FROM CE_STATEMENT_HEADERS_INT shi
        where shi.bank_account_num = l_bank_account_num
        and shi.statement_number = l_statement_number_from;
            
        commit;

    else --if l_remove_flag = 1 then  

--END PGREEN 04/29/13
     

     if l_control_line_count != 0 then
 --begin pgreen 03/06/13
        if l_clear_trx_text = 'Y' then
            update CE_STATEMENT_LINES_INTERFACE
            set trx_text = null
            where bank_account_num = l_bank_account_num
            and statement_number = l_statement_number_from
            and trx_text is not null;
            commit;
            
        end if; --if l_clear_trx_text = 'Y' then
--end pgreen 03/06/13
    
     
     
     
     
     
--Submit CUSTOM 'Quest CE Create Statement Lines'------------------------------------------------------------
       l_request_id := Fnd_Request.submit_request('CE','QSTCE_CREATE_STMT_LINES',
                        NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_bank_account_id, l_statement_number_from); --PGREEN 09/26/11

        IF (l_request_id = 0) THEN 
          RAISE_APPLICATION_ERROR(-20996,Fnd_Message.get); 
        else
        --insert detail log record************

            insert into  qstce_statement_log 
            (bank_name, bank_branch_name, bank_account_num, org_id, file_name, directory_path, bank_account_id, statement_number, 
            create_stmt_lines_req_id, creation_date, statement_date, currency_code, bank_branch_id, submit_req_id, bank_code,
            statement_log_id)
            values 
            (l_bank_name,l_bank_branch_name, l_bank_account_num, l_bank_org_id, p_input_file, p_directory_path,l_bank_account_id,  
            l_statement_number_from, l_request_id, sysdate,l_statement_date, l_currency_code, l_bank_branch_id, l_submit_req_id, p_bank_code,
            qstce_statement_log_id.nextval );
    
/*            update qstce_statement_log
            set bank_branch_id = l_bank_branch_id,
          --  bank_account_num
            bank_account_id = l_bank_account_id,
            statement_number = l_statement_number_from,
            create_stmt_lines_req_id = l_request_id
            where file_name = p_input_file
            and directory_path = p_directory_path;*/
            commit;
        END IF; -- l_request_id = 0

    l_loop_count := 0;
    l_loop_flag := true;

        while l_loop_flag loop
                l_loop_count := l_loop_count + 1;
                begin

                select r.phase_code,   r.status_code
                into l_phase_code,   l_status_code
                from fnd_concurrent_requests r
                where r.request_id = l_request_id;
                exception
                  when others then
                        null;
                end;
                    
                if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                     l_loop_flag := false;
                ELSE
                    dbms_lock.sleep( 60 );  --seconds        
                end if;  
                             

        end loop;

     end if; --if l_control_line_count != 0 then


-----------------------------------------------------------------------------

 --******Restart point     
 --Submit 'Bank Statement Import and AutoReconciliation'
       submit_import_autorec(l_errbuf, --              OUT NOCOPY    VARCHAR2,
                                   l_retcode , --             OUT NOCOPY    NUMBER,
--                                   l_option in varchar2, 
                                   l_bank_branch_id, -- in number, 
                                   l_bank_account_id, -- in number, 
                                   l_bank_account_num, -- in varchar2,
                                   l_statement_number_from, -- in varchar2, 
                                   l_statement_number_to, -- in varchar2, 
                                   l_statement_date, -- in varchar2, 
                                   l_statement_date, -- in varchar2, 
                                   l_gl_date, -- in varchar2, 
                                   l_org_id, -- in varchar2 ,
                                   l_control_line_count,
/*
                                   l_legal_entity_id, -- in varchar2, 
                                   l_receivables_trx_id, -- in number, 
                                   l_payment_method_id, -- in number, 
                                   l_nsf_handling, -- in varchar2, 
                                   l_display_debug, -- in varchar2,
                                   l_debug_path, -- in varchar2,
                                   l_debug_file,
*/
                                   l_record_status_flag); -- in varchar2); 

    if l_record_status_flag != 'E' and l_control_line_count != 0 then
        --MAY NEED LOCIG FOR INVALID TRAN CODES.
        null;

-----------------------------------------------------------------------------

--Restart point ---------------------------

--Submit CUSTOM 'Quest CE Create Receipts and Misc Receipts'
       submit_create_receipts_autorec(l_errbuf, --              OUT NOCOPY    VARCHAR2,
                                   l_retcode , --             OUT NOCOPY    NUMBER,
--                                   l_option in varchar2, 
                                   l_bank_branch_id, -- in number, 
                                   l_bank_account_id, -- in number, 
                                   l_bank_account_num, -- in varchar2,
                                   l_statement_number_from, -- in varchar2, 
                                   l_statement_number_to, -- in varchar2, 
                                   l_statement_date, --l_statement_date_from, -- in varchar2, 
                                   l_statement_date, --l_statement_date_to, -- in varchar2, 
                                   l_gl_date, -- in varchar2, 
                                   l_org_id--, -- in varchar2 ,
/*
                                   l_legal_entity_id, -- in varchar2, 
                                   l_receivables_trx_id, -- in number, 
                                   l_payment_method_id, -- in number, 
                                   l_nsf_handling, -- in varchar2, 
                                   l_display_debug, -- in varchar2,
                                   l_debug_path, -- in varchar2,
                                   l_debug_file
*/
                                   ); -- in varchar2); 

    end if; --if l_record_status_flag != 'E' and l_control_line_count != 0 then

   end if; --if l_remove_flag = 1 then  
    
    update qstce_statement_log
    set end_process_date = sysdate
    where bank_account_id = l_bank_account_id
    and statement_number = l_statement_number_from;
    commit;

 
  end loop; --for stmt_head_rec in stmt_head_cur loop


END submit_reconciliation;


------------------------------------------------------------------

PROCEDURE create_statement_lines(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_account_id in number, 
                                   p_statement_number in varchar2) is

l_sqlcode                        NUMBER;
l_sqlerrm                        VARCHAR2 (2000);

v_control_cr_line_count  CE_STATEMENT_HEADERS_INT.control_cr_line_count%type := 0;
v_tot_sli_cnt number := 0;
v_tot_sli_amount number := 0;
v_insert_sli_cnt number := 0;
v_tot_r_cnt number := 0;
v_tot_r_amount number := 0;
v_r_cnt number := 0;
v_line_seq number := 0;
v_max_sli_line number := 0;

v_error_flag number := 0;

l_bank_account_num  CE_STATEMENT_HEADERS_INT.bank_account_num%type;
--p_statement_number  CE_STATEMENT_HEADERS_INT.statement_number%type := '120417';

v_statement_date CE_STATEMENT_HEADERS_INT.statement_date%type;
v_org_id number;
v_BANK_ACCT_USE_ID CE_BANK_ACCT_USES_ALL.BANK_ACCT_USE_ID%type;

v_header_currency_code     CE_STATEMENT_HEADERS_INT.currency_code%type;     

v_bank_account_num  CE_STATEMENT_LINES_INTERFACE.bank_account_num%type;
v_statement_number  CE_STATEMENT_LINES_INTERFACE.statement_number%type;
v_line_number       CE_STATEMENT_LINES_INTERFACE.line_number%type;
v_trx_date          CE_STATEMENT_LINES_INTERFACE.trx_date%type;
v_trx_code          CE_STATEMENT_LINES_INTERFACE.trx_code%type;
v_trx_text          CE_STATEMENT_LINES_INTERFACE.trx_text%type;
v_invoice_text      CE_STATEMENT_LINES_INTERFACE.invoice_text%type;
v_amount            CE_STATEMENT_LINES_INTERFACE.amount%type;
v_currency_code     CE_STATEMENT_LINES_INTERFACE.currency_code%type;     
v_bank_trx_number   CE_STATEMENT_LINES_INTERFACE.bank_trx_number%type;
v_customer_text     CE_STATEMENT_LINES_INTERFACE.customer_text%type;
v_created_by        CE_STATEMENT_LINES_INTERFACE.created_by%type;
v_creation_date     CE_STATEMENT_LINES_INTERFACE.creation_date%type;
v_last_updated_by   CE_STATEMENT_LINES_INTERFACE.last_updated_by%type;
v_last_update_date  CE_STATEMENT_LINES_INTERFACE.last_update_date%type;
v_record_status_flag    CE_STATEMENT_HEADERS_INT.record_status_flag%type;


l_line_cnt number;

L_BANK_ACCT_USE_ID NUMBER;
L_ORG_ID NUMBER;

l_bank_code varchar2(20);

CURSOR RECEIPT_CUR IS
SELECT 
R.RECEIPT_NUMBER, R.AMOUNT--, r.*
FROM AR_BATCHES_ALL B
,ar_interim_cash_receipts_all R
,AR_LOCKBOXES_ALL L
WHERE B.GL_DATE = v_statement_date
AND B.LOCKBOX_BATCH_NAME not like  L.LOCKBOX_NUMBER||'99_'--'73138199_'
AND R.BATCH_ID = B.BATCH_ID
--and nvl(R.attribute4,'X') = 'C'
AND R.STATUS = 'UNAPP'
AND L.LOCKBOX_ID = B.LOCKBOX_ID 
and b.org_id = V_ORG_ID
and B.remit_bank_acct_use_id = v_BANK_ACCT_USE_ID
union
SELECT R.RECEIPT_NUMBER, R.AMOUNT --, r.*
FROM AR_BATCHES_ALL B
,AR_CASH_RECEIPT_HISTORY_ALL rh
,ar_cash_receipts_all R
,AR_LOCKBOXES_ALL L
WHERE B.GL_DATE = v_statement_date
AND B.LOCKBOX_BATCH_NAME not like  L.LOCKBOX_NUMBER||'99_'--'73138199_'
AND RH.BATCH_ID = B.BATCH_ID
and r.cash_receipt_id = rh.cash_receipt_id
--and nvl(R.attribute4,'X') = 'C'
AND R.STATUS != 'REV'
AND RH.STATUS != 'REVERSED'
AND L.LOCKBOX_ID = B.LOCKBOX_ID 
and b.org_id = V_ORG_ID
and B.remit_bank_acct_use_id = v_BANK_ACCT_USE_ID
order by 1 --r.receipt_number
;


BEGIN

--obtain bank account number
    begin
        select ba.bank_account_num, bau.BANK_ACCT_USE_ID, BAU.ORG_ID, ba.attribute1
        INTO l_bank_account_num, L_BANK_ACCT_USE_ID, L_ORG_ID, l_bank_code
        from CE_BANK_ACCOUNTS BA,
        CE_BANK_ACCT_USES_ALL BAU
        where ba.bank_account_id = p_bank_account_id
        AND SYSDATE BETWEEN NVL(BA.START_DATE, SYSDATE-1) AND NVL(BA.END_DATE, SYSDATE+1)
        AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID;
    exception
        when others then
            v_error_flag := 1;
    end;


--obtain Statement header info
    if v_error_flag = 0 then
        begin
            select shi.control_cr_line_count, trunc(shi.statement_date) statement_date , bau.org_id, bau.BANK_ACCT_USE_ID,
            nvl(shi.record_status_flag,'N') record_status_flag, shi.currency_code
            into v_control_cr_line_count, v_statement_date, v_org_id, v_BANK_ACCT_USE_ID, v_record_status_flag, v_header_currency_code
            from CE_STATEMENT_HEADERS_INT shi,
            CE_BANK_ACCOUNTS BA,
            CE_BANK_ACCT_USES_ALL BAU
            where shi.bank_account_num = l_bank_account_num
            and shi.statement_number = p_statement_number
            and ba.bank_account_num = shi.bank_account_num
            AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID;
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then

  if v_record_status_flag != 'T' then--if not already transfered

--statement line amount total for lockbox checks
    if v_error_flag = 0 then
        begin
            select nvl(sum(sli.amount),0) amount , count(*) cnt --, sli.*  -- 525608.84   07/5/2012
            into v_tot_sli_amount, v_tot_sli_cnt
            from CE_STATEMENT_LINES_INTERFACE sli
            where sli.bank_account_num = l_bank_account_num
            and sli.statement_number = p_statement_number
            and sli.trx_code = '115' --lockbox checks          
            AND NOT EXISTS
                (    
                SELECT 'X'
                 FROM fnd_lookup_values_vl  L2
                 WHERE L2.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
                 AND L2.ATTRIBUTE2 = 'CASH' --for regular receipt 
                 AND L2.ATTRIBUTE1 = SLI.TRX_CODE
                 and nvl(l2.attribute6, l_bank_code) = l_bank_code    
                 and nvl(l2.attribute9, l_bank_account_num) = l_bank_account_num    
                 and sli.trx_date BETWEEN L2.START_DATE_ACTIVE AND NVL(L2.END_DATE_ACTIVE, SYSDATE+1)    
                 );
                 
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then

--get max line number from the statement lines
    if v_error_flag = 0  then
        begin
            select  max(line_number) line_number
            into v_max_sli_line
            from CE_STATEMENT_LINES_INTERFACE sli
            where sli.bank_account_num = l_bank_account_num
            and sli.statement_number = p_statement_number
            ;
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then


    if v_error_flag = 0 then
        begin
            select sum(x.amount) amount, sum(x.cnt) cnt
            INTO v_tot_r_amount, v_tot_r_cnt
            from (
            select nvl(sum(r.amount),0) amount, COUNT(*) CNT
            FROM AR_BATCHES_ALL B
            ,ar_interim_cash_receipts_all R
            ,AR_LOCKBOXES_ALL L
            WHERE B.GL_DATE = v_statement_date
            AND B.LOCKBOX_BATCH_NAME not like  L.LOCKBOX_NUMBER||'99_'--'73138199_'
            AND R.BATCH_ID = B.BATCH_ID
            --and nvl(R.attribute4,'X') = 'C'
            AND R.STATUS = 'UNAPP'
            AND L.LOCKBOX_ID = B.LOCKBOX_ID 
            and b.org_id = V_ORG_ID
            and B.remit_bank_acct_use_id = v_BANK_ACCT_USE_ID
            union
            select nvl(sum(r.amount),0) amount, COUNT(*) CNT
            FROM AR_BATCHES_ALL B
            ,AR_CASH_RECEIPT_HISTORY_ALL rh
            ,ar_cash_receipts_all R
            ,AR_LOCKBOXES_ALL L
            WHERE B.GL_DATE = v_statement_date
            AND B.LOCKBOX_BATCH_NAME not like  L.LOCKBOX_NUMBER||'99_'--'73138199_'
            AND RH.BATCH_ID = B.BATCH_ID
            and r.cash_receipt_id = rh.cash_receipt_id
            --and nvl(R.attribute4,'X') = 'C'
            AND R.STATUS != 'REV'
            AND RH.STATUS != 'REVERSED'
            AND L.LOCKBOX_ID = B.LOCKBOX_ID 
            and b.org_id = V_ORG_ID
            and B.remit_bank_acct_use_id = v_BANK_ACCT_USE_ID) x
            ;
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then


    if v_error_flag = 0 then
        begin
            select 
            sli.bank_account_num, 
            sli.statement_number,
            sli.line_number,
            sli.trx_date,
            sli.trx_code ,
            sli.trx_text ,
            sli.invoice_text ,
            sli.amount,
            sli.currency_code,  
            sli.bank_trx_number ,
            sli.customer_text ,
            sli.created_by ,
            sli.creation_date ,
            sli.last_updated_by  ,
            sli.last_update_date 
            INTO 
            v_bank_account_num, 
            v_statement_number,
            v_line_number,
            v_trx_date,
            v_trx_code ,
            v_trx_text ,
            v_invoice_text ,
            v_amount,
            v_currency_code,  
            v_bank_trx_number ,
            v_customer_text ,
            v_created_by ,
            v_creation_date ,
            v_last_updated_by  ,
            v_last_update_date 
            from CE_STATEMENT_LINES_INTERFACE sli
            where bank_account_num = l_bank_account_num
            and statement_number = p_statement_number
            and trx_code = '115' --lockbox checks
            AND ROWNUM < 2
            ;
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then

if v_error_flag = 0 then
    IF v_tot_sli_amount = v_tot_r_amount THEN

        v_line_seq := v_max_sli_line;

        FOR RECEIPT_REC IN RECEIPT_CUR LOOP
            v_r_cnt := v_r_cnt + 1;
            IF v_r_cnt <= v_tot_sli_cnt then
            
              begin
                update CE_STATEMENT_LINES_INTERFACE sli
                set sli.amount = receipt_rec.amount,
                    sli.bank_trx_number = receipt_rec.receipt_number
                where sli.bank_account_num = l_bank_account_num
                and sli.statement_number = p_statement_number
                and sli.trx_code = '115' --lockbox checks
                and sli.bank_trx_number = sli.invoice_text
                and rownum < 2;
              exception
                when others then
                   null;
              end;
               
            else
                v_line_seq := v_line_seq +  1;
                
                insert into CE_STATEMENT_LINES_INTERFACE sli 
                (        
                sli.bank_account_num, 
                sli.statement_number,
                sli.line_number,
                sli.trx_date,
                sli.trx_code ,
                sli.trx_text ,
                sli.invoice_text ,
                sli.amount,
                sli.currency_code,  
                sli.bank_trx_number ,
                sli.customer_text ,
                sli.created_by ,
                sli.creation_date ,
                sli.last_updated_by  ,
                sli.last_update_date 
                )
                values
                (
                v_bank_account_num, 
                v_statement_number,
                v_line_seq,
                v_trx_date,
                v_trx_code ,
                v_trx_text ,
                v_invoice_text ,
                receipt_rec.amount, --v_amount,
                v_currency_code,  
                receipt_rec.receipt_number, --v_bank_trx_number ,
                v_customer_text ,
                v_created_by ,
                v_creation_date ,
                v_last_updated_by  ,
                v_last_update_date 
                );
                
                v_insert_sli_cnt := v_insert_sli_cnt +1; 
                
            end if; --IF v_r_cnt < v_tot_sli_cnt then

        END LOOP;  --FOR RECEIPT_REC IN RECEIPT_CUR LOOP

        update CE_STATEMENT_HEADERS_INT shi
        set control_cr_line_count = control_cr_line_count + v_insert_sli_cnt,
        control_line_count = control_line_count + v_insert_sli_cnt
        where shi.bank_account_num = l_bank_account_num
        and shi.statement_number = p_statement_number;

    ELSE --IF v_tot_sli_amount = v_tot_r_amount THEN
    
        begin
            update qstce_statement_log
            set create_stmt_lines_message = 'v_tot_sli_amount: '||v_tot_sli_amount||' v_tot_r_amount: '|| v_tot_r_amount
            where bank_account_id = p_bank_account_id
            and statement_number = p_statement_number;
              
        exception
          when others then
            insert into qstce_statement_log (bank_account_id, statement_number, create_stmt_lines_message, statement_log_id)
                values (p_bank_account_id, p_statement_number, 'v_tot_sli_amount: '||v_tot_sli_amount||' v_tot_r_amount: '|| v_tot_r_amount,
                qstce_statement_log_id.nextval);
                         
        end;

    END IF; --IF v_tot_sli_amount = v_tot_r_amount THEN

    commit;
    
    
end if; --if v_error_flag = 0 then

--populate blank BANK_TRX_NUMBER
    update CE_STATEMENT_LINES_INTERFACE sli
    set sli.BANK_TRX_NUMBER = nvl(sli.INVOICE_TEXT, sli.customer_text)
    where sli.bank_account_num = l_bank_account_num
    and sli.statement_number = p_statement_number
    and sli.BANK_TRX_NUMBER is null;

    commit;

-- remove temporarily for Deutsche ****************************************

--populate for Receipt Number
    update CE_STATEMENT_LINES_INTERFACE sli
    set sli.BANK_TRX_NUMBER = sli.CUSTOMER_TEXT
    where sli.bank_account_num = l_bank_account_num
    and sli.statement_number = p_statement_number
    AND SLI.TRX_CODE in 
            (select l.attribute1 
            from fnd_lookup_values_vl l  
            where  l.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)    
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            and l.attribute3 is not null) --??????????????????????????????????????????????????????????????????? PAULA CHECK !!!!!!!!!!!!!!!!!!!!!
    and exists
        (SELECT 'x' 
        FROM FND_FLEX_VALUE_SETS VS,
        fnd_flex_values_vl  v,
        qstce_statement_log qsl
        WHERE qsl.bank_account_num = l_bank_account_num
        and qsl.statement_number = p_statement_number
        and VS.FLEX_VALUE_SET_NAME = 'QSTCE_BAI2_MAPPING'
        AND V.FLEX_VALUE_SET_ID = VS.FLEX_VALUE_SET_ID
        and v.flex_value = qsl.bank_code
        and nvl(v.attribute2, 'N') = 'Y');
    commit;




--remove leading 0 from all trx code types -- 'Check Paid'
    update CE_STATEMENT_LINES_INTERFACE sli
    set sli.BANK_TRX_NUMBER = ltrim(sli.BANK_TRX_NUMBER,'0')
    where sli.bank_account_num = l_bank_account_num
    and sli.statement_number = p_statement_number
   -- AND SLI.TRX_CODE = '475'--Check Paid
    ;
    
    commit;

-- Change Transaction Codes
--begin pgreen 11/19/13
--new 1
    update CE_STATEMENT_LINES_INTERFACE sli
    set trx_code = 
            (select l.attribute4 
            from fnd_lookup_values_vl l  
            where  l.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and L.ATTRIBUTE1 = sli.trx_code
            and l.attribute2 = 'CHANGE_TC'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            AND SLI.TRX_TEXT LIKE L.ATTRIBUTE5
            )
    where sli.bank_account_num = l_bank_account_num
    and sli.statement_number = p_statement_number
    and trx_code in
            (select l.attribute1 
            from fnd_lookup_values_vl l  
            where  l.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and L.ATTRIBUTE1 = sli.trx_code
            and l.attribute2 = 'CHANGE_TC'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            AND SLI.TRX_TEXT LIKE L.ATTRIBUTE5
            and nvl(l.attribute10,'N') = 'N' -- do not check AP Invoices  --pgreen 11/19/13
            );

--new 2
    update CE_STATEMENT_LINES_INTERFACE sli
    set trx_code = 
            (select l.attribute4 
            from fnd_lookup_values_vl l  
            where  l.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and L.ATTRIBUTE1 = sli.trx_code
            and l.attribute2 = 'CHANGE_TC'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            AND SLI.TRX_TEXT LIKE L.ATTRIBUTE5
            )
    where sli.bank_account_num = l_bank_account_num
    and sli.statement_number = p_statement_number
    and trx_code in
            (select l.attribute1 
            from fnd_lookup_values_vl l  
            where  l.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and L.ATTRIBUTE1 = sli.trx_code
            and l.attribute2 = 'CHANGE_TC'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            AND SLI.TRX_TEXT LIKE L.ATTRIBUTE5
            and nvl(l.attribute10,'N') = 'Y'-- check AP Checks.  (don't change if exists)
            )
    and not exists  -- check AP Checks. ( don't change if exists)
        (select 'x'
         from ap_checks_all chk
         where  chk.check_number = sli.BANK_TRX_NUMBER
         and chk.amount = sli.amount
         and org_id = v_org_id)  ;


/*    update CE_STATEMENT_LINES_INTERFACE sli
    set trx_code = 
            (select l.attribute4 
            from fnd_lookup_values_vl l  
            where  l.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and L.ATTRIBUTE1 = sli.trx_code
            and l.attribute2 = 'CHANGE_TC'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            AND SLI.TRX_TEXT LIKE L.ATTRIBUTE5)
    where sli.bank_account_num = l_bank_account_num
    and sli.statement_number = p_statement_number
    and trx_code in
            (select l.attribute1 
            from fnd_lookup_values_vl l  
            where  l.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and L.ATTRIBUTE1 = sli.trx_code
            and l.attribute2 = 'CHANGE_TC'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            AND SLI.TRX_TEXT LIKE L.ATTRIBUTE5)
   -- AND SLI.TRX_CODE = '475'--Check Paid
    ;
*/ 
--end pgreen 11/19/13   

    commit;



--update currency fields    
    update CE_STATEMENT_LINES_INTERFACE sli
    set sli.CURRENCY_CODE = v_header_currency_code,
    USER_EXCHANGE_RATE_TYPE = 'Corporate',
    EXCHANGE_RATE_DATE = sli.trx_date
    where sli.bank_account_num = l_bank_account_num
    and sli.statement_number = p_statement_number;
     
 
--remove trx_code 397 records
   SELECT COUNT(*)
    INTO L_line_cnt
    FROM CE_STATEMENT_LINES_INTERFACE sli
    where sli.bank_account_num = l_bank_account_num
    and sli.statement_number = p_statement_number
    AND sli.amount = 0
    AND SLI.TRX_CODE IN
        (SELECT L.ATTRIBUTE1 
         FROM fnd_lookup_values_vl  L
         WHERE L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
          and nvl(l.attribute6, l_bank_code) = l_bank_code    
          and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num 
          AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)    
         AND L.ATTRIBUTE2 = 'DELETE');

    DELETE FROM CE_STATEMENT_LINES_INTERFACE sli
    where sli.bank_account_num = l_bank_account_num
    and sli.statement_number = p_statement_number
    AND sli.amount = 0
    AND SLI.TRX_CODE IN
        (SELECT L.ATTRIBUTE1 
         FROM fnd_lookup_values_vl  L
         WHERE L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num
            AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)     
         AND L.ATTRIBUTE2 = 'DELETE');
    
     
    update CE_STATEMENT_HEADERS_INT shi
    set control_cr_line_count = control_cr_line_count - L_line_cnt,
    control_line_count = control_line_count - L_line_cnt
    where shi.bank_account_num = l_bank_account_num
    and shi.statement_number = p_statement_number;
    
    commit;
--end remove trx_code 397 records


--MAKE BANK_TRX_NUMBER UNIQUE
   UPDATE CE_STATEMENT_LINES_INTERFACE sli
   set sli.BANK_TRX_NUMBER = nvl(sli.BANK_TRX_NUMBER,sli.statement_number)||'-'||TO_CHAR(QSTCE_RECEIPT_SEQUENCE.NEXTVAL)
    where sli.bank_account_num = l_bank_account_num
   and sli.statement_number = p_statement_number
   AND SLI.TRX_CODE in 
            (select l.attribute1 
            from fnd_lookup_values_vl l  
            where  l.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            AND sli.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            and l.attribute2 in ('MISC','CASH')   --PGREEN 03/27/13
  --PGREEN 03/27/13          and l.attribute2 is not null
            ) --************************************?????????????????????
    and (exists
            (select 'DUPLICATE IN INTERFACE TABLE'
            from CE_STATEMENT_LINES_INTERFACE  SL
            where sl.bank_account_num = sli.bank_account_num
            and sl.bank_trx_number = sli.bank_trx_number
            and (sl.statement_number != sli.statement_number
            or sl.line_number != sli.line_number))
    or exists
            (SELECT  'DUPLICATE RECEIPT ALREADY CREATED'
            from AR_CASH_RECEIPTS_V 
            where org_id = l_org_id
            and receipt_number = sli.bank_trx_number --'999721212509610'
            and type = 'CASH'
            and remit_bank_acct_use_id = l_bank_acct_use_id
            and remit_bank_account = sli.bank_account_num
            AND TRUNC(RECEIPT_DATE) != TRUNC(SLI.TRX_DATE))
     or sli.bank_trx_number is null        
            );  --PGREEN 03/27/13
   COMMIT;
  

  end if; --if v_record_status_flag != 'T' --if not already transfered


exception
  when others then
      l_sqlcode := SQLCODE;
      l_sqlerrm := SQLERRM;
      null;
  
END create_statement_lines;



------------------------------------------------------------------
PROCEDURE create_receipts (errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_account_id in number, 
                                   p_statement_number in varchar2) is
l_return_status VARCHAR2(1);
l_msg_count NUMBER;
l_msg_data VARCHAR2(240);
l_misc_receipt_id number;
l_user_id NUMBER := Fnd_Profile.VALUE('USER_ID');
--l_org_id NUMBER := Fnd_Profile.VALUE('ORG_ID');
--l_resp_id NUMBER := 51439; --Fnd_Profile.VALUE('RESP_ID');
l_org_id number;
l_cr_id number;
l_currency_code varchar2(15);
l_amount number;
l_bank_trx_number varchar2(240);
l_trx_date date;
L_TRX_TYPE VARCHAR2(30);
L_STATUS VARCHAR2(30);
L_TRX_CODE VARCHAR2(30);
L_BANK_ACCOUNT_ID NUMBER;
L_RECEIPT_METHOD_ID NUMBER;
l_remit_bank_acct_use_id number;
l_BANK_NAME varchar2(360);
l_BANK_ACCOUNT_NUM varchar2(30);
l_statement_line_id number;
l_bank_branch_name varchar2(360);
l_statement_number varchar2(50);
l_exist_cnt number := 0;
l_exist_cnt2 number := 0;
l_activity varchar2(1000);
l_process_type varchar2(30);
l_activity_type varchar2(1000);
l_payment_type varchar2(1000);
l_bank_reference varchar2(1000);
l_activity_flag number;
L_MULTIPLY NUMBER;
L_EXCHANGE_RATE_DATE DATE;
L_EXCHANGE_RATE_TYPE VARCHAR2(30);
l_comment varchar2(2000);

l_bank_code varchar2(20); 

l_attribute_rec  ar_receipt_api_pub.attribute_rec_type;
l_global_attribute_rec  ar_receipt_api_pub.global_attribute_rec_type;

l_sqlcode                     NUMBER;
l_sqlerrm                     VARCHAR2 (2000);
v_error_message               VARCHAR2 (8000);

v_error_flag number := 0;

l_r_type varchar2(2); --pgreen 06/04/13

l_bank_account_text CE_STATEMENT_LINES.bank_account_text%type; --pgreen 07/09/13

l_invoice_number varchar2(20);  --pgreen 12/18/13
l_customer_id number; --pgreen 12/18/13
l_location varchar2(40); --pgreen 12/18/13
l_bill_to_site_use_id  number; --pgreen 12/18/13

CURSOR MAIN_CUR (v_statement_number in varchar2, v_bank_account_num in varchar2, v_bank_code in varchar2)  IS
select 
sl.trx_date, sl.trx_type, sl.amount, sl.status, sl.bank_trx_number, sl.trx_code, 
sl.currency_code, sl.EXCHANGE_RATE_DATE, sl.EXCHANGE_RATE_TYPE,--sh.currency_code, 
SH.BANK_ACCOUNT_ID, rma.ORG_ID, 
rma.receipt_method_id
, RMA.remit_bank_acct_use_id, BB.BANK_NAME, bb.bank_branch_name, BA.BANK_ACCOUNT_NUM, sl.statement_line_id ,sh.statement_number
,L.ATTRIBUTE2 PROCESS_TYPE,l.attribute3 payment_type, 
l.attribute4 activity_type, decode( sl.trx_type,'MISC_DEBIT',-1,1) multiply
,'QSTCE: '||case when nvl(ba.attribute2,'N') = 'N' THEN sl.trx_text else 'Text removed (has foreign characters).' end trx_text, --pgreen 03/06/13
sh.statement_number||'-'||sl.currency_code bank_reference
,nvl(sl.bank_account_text, 'X') bank_account_text --pgreen 07/09/13
--begin pgreen 12/18/13
,l.attribute10 check_invoice_flag  
 ,case when l.attribute10 is not null and sl.trx_text like '%'||L.ATTRIBUTE10||'%' then  --pgreen 02/25/14
             rtrim(SUBSTR(sl.trx_text, instr(sl.trx_text,l.attribute10), 10))   --pgreen 02/25/14
      else null end invoice_number  --pgreen 02/25/14
 --pgreen 02/25/14,case when l.attribute10 is not null and sl.trx_text like '%'||L.ATTRIBUTE10||'%' then
 --pgreen 02/25/14          rtrim(SUBSTR(sl.trx_text, instr(sl.trx_text,l.attribute10) + length(l.attribute10)-3 , 10)) 
--pgreen 02/25/14      else null end invoice_number
--end pgreen 12/18/13
from CE_STATEMENT_LINES SL , CE_STATEMENT_HEADERS SH ,
ce_bank_acct_uses_all bau,
CE_BANK_BRANCHES_V BB,
CE_BANK_ACCOUNTS BA,
ar_receipt_method_accounts_all rma,
fnd_lookup_values_vl  L,
ar_receipt_methods rm,
ar_receipt_classes rc
where 1=1
and sh.statement_number = v_statement_number
and sl.statement_header_id = sh.statement_header_id
and SL.status = 'UNRECONCILED'
and ba.bank_account_num = v_bank_account_num
--and SH.org_id = bau.org_id --l_org_id
--AND rma.org_id = SH.org_id
AND BAU.BANK_ACCOUNT_ID = SH.BANK_ACCOUNT_ID
AND BAU.BANK_ACCT_USE_ID = RMA.remit_bank_acct_use_id
and ba.bank_account_id = bau.bank_account_id
AND BB.BANK_PARTY_ID = BA.BANK_ID  --5041
AND BB.BRANCH_PARTY_ID = BA.BANK_BRANCH_ID --5045
AND L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
and nvl(l.attribute6, v_bank_code) = v_bank_code    
and nvl(l.attribute9, v_bank_account_num) = v_bank_account_num    
AND sl.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
AND L.ATTRIBUTE1 = SL.trx_code
AND L.ATTRIBUTE2 = 'CASH' --for regular receipt   
and sl.trx_type = 'CREDIT'
and rm.receipt_method_id = rma.receipt_method_id
and rc.receipt_class_id = rm.receipt_class_id
and sl.trx_date between rma.start_date and nvl(rma.end_date, sysdate+1)
and sl.trx_date between rm.start_date and nvl(rm.end_date, sysdate+1)
--and SL.trx_code in (165) -- (195) --,698,699)
--and sl.bank_trx_number = '1157452'
and nvl(sl.bank_account_text, 'X') != 'CREDIT CARD'--pgreen 07/09/13
AND NOT EXISTS
    (SELECT 'X'
     FROM fnd_lookup_values_vl  L2
     WHERE L2.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
     AND L2.ATTRIBUTE2 = 'MISC' --for regular receipt 
     AND L2.ATTRIBUTE1 = SL.TRX_CODE
     and sl.trx_date BETWEEN L2.START_DATE_ACTIVE AND NVL(L2.END_DATE_ACTIVE, SYSDATE+1)
     and nvl(l.attribute6, v_bank_code) = v_bank_code    
     and nvl(l.attribute9, v_bank_account_num) = v_bank_account_num    
     AND SL.TRX_TEXT LIKE L2.ATTRIBUTE5) 
AND NOT EXISTS
    (SELECT 'X'
     FROM fnd_lookup_values_vl  L2
     WHERE L2.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
     AND L2.ATTRIBUTE2 = 'EXCEPTION' --for regular receipt 
     AND L2.ATTRIBUTE1 = SL.TRX_CODE
     and nvl(l.attribute6, v_bank_code) = v_bank_code    
     and nvl(l.attribute9, v_bank_account_num) = v_bank_account_num    
     and sl.trx_date BETWEEN L2.START_DATE_ACTIVE AND NVL(L2.END_DATE_ACTIVE, SYSDATE+1)
     AND SL.TRX_TEXT LIKE L2.ATTRIBUTE5) 
UNION ALL
select 
sl.trx_date, sl.trx_type, sl.amount, sl.status, sl.bank_trx_number, sl.trx_code, 
sl.currency_code, sl.EXCHANGE_RATE_DATE, sl.EXCHANGE_RATE_TYPE,--sh.currency_code, 
SH.BANK_ACCOUNT_ID, rma.ORG_ID, 
rma.receipt_method_id
, RMA.remit_bank_acct_use_id, BB.BANK_NAME, bb.bank_branch_name, BA.BANK_ACCOUNT_NUM, sl.statement_line_id ,sh.statement_number
,L.ATTRIBUTE2 PROCESS_TYPE,l.attribute3 payment_type, 
l.attribute4 activity_type, decode( sl.trx_type,'MISC_DEBIT',-1,1) multiply
,'QSTCE: '||case when nvl(ba.attribute2,'N') = 'N' THEN sl.trx_text else 'Text removed (has foreign characters).' end trx_text, --pgreen 03/06/13
sh.statement_number||'-'||sl.currency_code bank_reference
,nvl(sl.bank_account_text, 'X') bank_account_text --pgreen 07/09/13
--begin pgreen 12/18/13
,l.attribute10 check_invoice_flag  
,null invoice_number
--end pgreen 12/18/13
from CE_STATEMENT_LINES SL , CE_STATEMENT_HEADERS SH ,
ce_bank_acct_uses_all bau,
CE_BANK_BRANCHES_V BB,
CE_BANK_ACCOUNTS BA,
ar_receipt_method_accounts_all rma,
fnd_lookup_values_vl  L,
ar_receipt_methods rm,
ar_receipt_classes rc
where 1=1
and sh.statement_number = v_statement_number
and sl.statement_header_id = sh.statement_header_id
and SL.status = 'UNRECONCILED'
and ba.bank_account_num = v_bank_account_num
--and SH.org_id = bau.org_id --l_org_id
--AND rma.org_id = SH.org_id
AND BAU.BANK_ACCOUNT_ID = SH.BANK_ACCOUNT_ID
AND BAU.BANK_ACCT_USE_ID = RMA.remit_bank_acct_use_id
and ba.bank_account_id = bau.bank_account_id
AND BB.BANK_PARTY_ID = BA.BANK_ID  --5041
AND BB.BRANCH_PARTY_ID = BA.BANK_BRANCH_ID --5045
AND L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
and nvl(l.attribute6, v_bank_code) = v_bank_code    
and nvl(l.attribute9, v_bank_account_num) = v_bank_account_num    
AND sl.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
AND L.ATTRIBUTE1 = SL.trx_code
AND L.ATTRIBUTE2 = 'MISC' --for miscellaneous receipt  
and rm.receipt_method_id = rma.receipt_method_id
and rc.receipt_class_id = rm.receipt_class_id
and sl.trx_date between rma.start_date and nvl(rma.end_date, sysdate+1)
and sl.trx_date between rm.start_date and nvl(rm.end_date, sysdate+1)
AND SL.TRX_TEXT LIKE L.ATTRIBUTE5
AND NOT EXISTS
    (SELECT 'X'
     FROM fnd_lookup_values_vl  L2
     WHERE L2.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
     AND L2.ATTRIBUTE2 = 'EXCEPTION' --for regular receipt 
     AND L2.ATTRIBUTE1 = SL.TRX_CODE
     and nvl(l2.attribute6, v_bank_code) = v_bank_code    
     and nvl(l2.attribute9, v_bank_account_num) = v_bank_account_num    
     and sl.trx_date BETWEEN L2.START_DATE_ACTIVE AND NVL(L2.END_DATE_ACTIVE, SYSDATE+1)
     AND SL.TRX_TEXT LIKE L2.ATTRIBUTE5) 
--AND SL.TRX_CODE = 999
--and SL.trx_code in (195,698,699)
--and sl.bank_trx_number = '041000126368038'
;

BEGIN

null;
/*------------------------------+
| Setting global initialization | 
+-------------------------------*/ 
--FND_GLOBAL.apps_initialize(l_user_id, l_resp_id, 222);

FND_GLOBAL.apps_initialize(1433, 51306, 222);
MO_GLOBAL.init('AR');

null;
--l_user_id  := Fnd_Profile.VALUE('USER_ID');
--l_org_id := Fnd_Profile.VALUE('ORG_ID');
--l_resp_id  := Fnd_Profile.VALUE('RESP_ID');

--obtain bank account number
    begin
        select ba.bank_account_num, ba.attribute1
        INTO l_bank_account_num, l_bank_code
        from CE_BANK_ACCOUNTS BA
        where ba.bank_account_id = p_bank_account_id
        AND SYSDATE BETWEEN NVL(BA.START_DATE, SYSDATE-1) AND NVL(BA.END_DATE, SYSDATE+1);
    exception
        when others then
            v_error_flag := 1;
    end;


if v_error_flag = 0 then


    --l_BANK_ACCOUNT_NUM := P_BANK_ACCOUNT_NUM;
    l_statement_number := p_statement_number;


    FOR MAIN_REC IN MAIN_CUR (l_statement_number, l_bank_account_num, l_bank_code ) LOOP
    l_org_id := MAIN_REC.org_id;
    l_currency_code := MAIN_REC.currency_code;
    l_amount := MAIN_REC.amount;
    l_bank_trx_number := MAIN_REC.bank_trx_number; --*********??????
    l_trx_date := MAIN_REC.trx_date;

    L_TRX_TYPE := MAIN_REC.TRX_TYPE;
    L_STATUS := MAIN_REC.STATUS;
    L_TRX_CODE := MAIN_REC.TRX_CODE;
    L_BANK_ACCOUNT_ID := MAIN_REC.BANK_ACCOUNT_ID;
    L_RECEIPT_METHOD_ID := MAIN_REC.RECEIPT_METHOD_ID;
    l_remit_bank_acct_use_id := main_rec.remit_bank_acct_use_id;
    l_BANK_NAME := main_rec.BANK_NAME;
    l_bank_branch_name := main_rec.bank_branch_name;
    l_statement_line_id := main_rec.statement_line_id;
    l_process_type := main_rec.process_type;
    l_activity_type := main_rec.activity_type;
    l_payment_type := main_rec.payment_type;
    l_bank_reference := main_rec.bank_reference;
    l_multiply := main_rec.multiply;
    L_EXCHANGE_RATE_DATE := main_rec.EXCHANGE_RATE_DATE;
    L_EXCHANGE_RATE_TYPE := main_rec.EXCHANGE_RATE_TYPE;
    l_comment := main_rec.trx_text;
    l_attribute_rec := null;
    l_bank_account_text := main_rec.bank_account_text; --pgreen 07/09/13
    l_invoice_number := main_rec.invoice_number;  --pgreen 12/18/13



 --   IF L_TRX_CODE IN (195) THEN--MANUAL RECEIPT
    if l_process_type = 'CASH' then --MANUAL RECEIPT


       begin
            l_r_type := null;
            
            select l.attribute4 r_type
            into l_r_type
            from fnd_lookup_values_vl  L
            where  L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            and l.attribute2 = 'CREDIT_CARD'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            and l_trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and l.attribute1 = l_trx_code
            and l_comment like l.attribute5 
            and l_bank_trx_number not like l.attribute4||'%'
            ;
                
            if l_r_type is not null then
                l_bank_trx_number := l_bank_trx_number||'-'||l_r_type;
            end if; --if l_r_type is not null then
       exception
        when others then
            null;
            
       end;
                 

    --check if already exists
        l_exist_cnt := 0;

        select count(*)
        into l_exist_cnt 
        from AR_CASH_RECEIPTS_V 
        where org_id = l_org_id
        and receipt_number = l_bank_trx_number --'999721212509610'
        and receipt_date = l_trx_date
--BEGIN PGREEN 07/09/13
        AND (TYPE = 'CASH'
        OR
            (l_bank_account_text = 'CREDIT CARD'
             AND TYPE = 'MISC')
            )
--END PGREEN 07/09/13
        and currency_code = l_currency_code                   
        and amount = l_amount
        and remit_bank_acct_use_id = l_remit_bank_acct_use_id
        and remit_bank_account = l_BANK_ACCOUNT_NUM
        and receipt_status in ('UNAPP','APP','UNID')  --pgreen 07/08/14
        ;
        


        if l_exist_cnt = 0 then
        
        

/*
 --new 11/5/12 not sure going to use           
          l_exist_cnt2 := 0;
          select count(*) 
            into l_exist_cnt2 
            from AR_CASH_RECEIPTS_V 
            where org_id = l_org_id
            and receipt_number = l_bank_trx_number --'999721212509610'
            and type = 'CASH'
            and remit_bank_acct_use_id = l_remit_bank_acct_use_id
            and remit_bank_account = l_BANK_ACCOUNT_NUM;
           
            if l_exist_cnt2 = 0 then
                select count(*) 
                into l_exist_cnt2 
                from CE_STATEMENT_LINES SL , CE_STATEMENT_HEADERS SH
                where 1=1 --sl.statement_header_id = :statement_header_id -- 1000
                and sl.status= 'UNRECONCILED'
                and sl.statement_line_id != l_statement_line_id
                and sl.bank_trx_number = l_bank_trx_number
                and sl.statement_header_id = sh.statement_header_id
                and sh.bank_account_id =l_bank_account_id;
            end if; --if l_exist_cnt2 = 0 then
 
             if l_exist_cnt2 != 0 then
                select count(*) 
                into l_exist_cnt2 
                from CE_STATEMENT_LINES SL , CE_STATEMENT_HEADERS SH
                where 1=1 --sl.statement_header_id = :statement_header_id -- 1000
                and sl.status= 'UNRECONCILED'
                and sl.statement_line_id != l_statement_line_id
                and sl.bank_trx_number = l_bank_trx_number
                and sl.statement_header_id = sh.statement_header_id
                and sh.bank_account_id =l_bank_account_id;
            end if; --if l_exist_cnt2 != 0 then
*/            
 
/*
--*******?????????????
          begin
                select l.attribute4 r_type
                into l_r_type
                from fnd_lookup_values_vl  L
                where  L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
                and l.attribute2 = 'CREDIT_CARD'
                and nvl(l.attribute6, l_bank_code) = l_bank_code    
                and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
                and l_trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
                and l.attribute1 = l_trx_code
                and l_comment like l.attribute5 ;
                
                if l_r_type is not null then
                    l_bank_trx_number := l_bank_trx_number||'-'||l_r_type;
                end if; --if l_r_type is not null then
           exception
            when others then
                null;
            
           end;
 */                
          l_attribute_rec.attribute4 := l_payment_type;
          l_attribute_rec.attribute5 := l_bank_reference;
          
--begin pgreen 12/18/13
           if l_invoice_number is not null then
            begin
                l_customer_id := null;
                
                select t.bill_to_customer_id, t.bill_to_site_use_id
                into l_customer_id, l_bill_to_site_use_id
                from ra_customer_trx_all t
                where t.trx_number = l_invoice_number;
            
            exception
                when others then
                    l_customer_id := null;
            end;
           
           end if; --if l_invoice_number is not null then

        if not (l_customer_id is null or l_invoice_number is null) then  --pgreen 06/16/14
        -- create and apply cash to invoice

--begin pgreen 12/18/13        
            begin
                select ltrim(rtrim(s.location))
                into l_location
                from hz_cust_site_uses_all s
                where s.site_use_id = l_bill_to_site_use_id;
            exception
              when others then
                l_location := null;
            end;
--end pgreen 12/18/13

              APPS.AR_RECEIPT_API_PUB.Create_and_apply(
                       -- Standard API parameters.
                  p_api_version      => 1.0, --IN  NUMBER,
                  p_init_msg_list    => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                  p_commit           => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                  p_validation_level => FND_API.G_VALID_LEVEL_FULL, --IN  NUMBER   := FND_API.G_VALID_LEVEL_FULL,
                  x_return_status    => l_return_status, --OUT NOCOPY VARCHAR2 ,
                  x_msg_count        => l_msg_count, --OUT NOCOPY NUMBER ,
                  x_msg_data         => l_msg_data, --OUT NOCOPY VARCHAR2 ,
                             -- Receipt info. parameters
                  p_usr_currency_code            => null, --IN  VARCHAR2 DEFAULT NULL, --the translated currency code
                  p_currency_code                => l_currency_code, --'GBP', --IN  VARCHAR2 DEFAULT NULL,
                  p_usr_exchange_rate_type       => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_exchange_rate_type           => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_exchange_rate                => null, --IN  NUMBER   DEFAULT NULL,
                  p_exchange_rate_date           => null, --IN  DATE     DEFAULT NULL,
                  p_amount                       => l_amount, -- -183.40, --IN  NUMBER,
                  p_factor_discount_amount       => null, --IN  NUMBER   DEFAULT NULL,                  ????
                  p_receipt_number               => l_bank_trx_number, --IN  OUT NOCOPY VARCHAR2 ,
                  p_receipt_date                 => l_trx_date, --IN  DATE     DEFAULT NULL,
                  p_gl_date                      => l_trx_date, --IN  DATE     DEFAULT NULL,
                             p_maturity_date           => l_trx_date, --IN  DATE     DEFAULT NULL,
                             p_postmark_date           => null, --IN  DATE     DEFAULT NULL,
                             p_customer_id             => l_customer_id, --null, --IN  NUMBER   DEFAULT NULL,    bill_to_customer_id
                             p_customer_name           => null, --IN  VARCHAR2 DEFAULT NULL,
                             p_customer_number         => null, --IN VARCHAR2  DEFAULT NULL,
                             p_customer_bank_account_id => null, --IN NUMBER   DEFAULT NULL,
                             p_customer_bank_account_num   => null, --IN  VARCHAR2  DEFAULT NULL,
                             p_customer_bank_account_name  => null, --IN  VARCHAR2  DEFAULT NULL,
                             p_payment_trxn_extension_id  => null, --IN NUMBER DEFAULT NULL,
--???                             p_location                 => l_location, --IN  VARCHAR2 DEFAULT NULL,
                             p_customer_site_use_id     => l_bill_to_site_use_id, -- null, --IN  NUMBER  DEFAULT NULL,
                             p_default_site_use         => null, --IN VARCHAR2  DEFAULT 'Y', --bug4448307-4509459
                             p_customer_receipt_reference => null, --IN  VARCHAR2  DEFAULT NULL,                            ????
    --*                         p_override_remit_account_flag => 'Y', --IN  VARCHAR2 DEFAULT NULL,
                  p_remittance_bank_account_id   => l_remit_bank_acct_use_id, --L_BANK_ACCOUNT_ID, --10043, --IN  NUMBER   DEFAULT NULL,
                  p_remittance_bank_account_num  => null, --'019057300006', --IN  VARCHAR2 DEFAULT NULL,
                  p_remittance_bank_account_name => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_deposit_date                 => l_trx_date,  --IN  DATE     DEFAULT NULL,
                  p_receipt_method_id            => L_RECEIPT_METHOD_ID, --IN  NUMBER   DEFAULT NULL,
                  p_receipt_method_name          => null, --IN  VARCHAR2 DEFAULT NULL,                                  
                  p_doc_sequence_value           => null, --IN  NUMBER   DEFAULT NULL,
                  p_ussgl_transaction_code       => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_anticipated_clearing_date    => l_trx_date, --IN  DATE     DEFAULT NULL,
                  p_called_from                  => null, --IN VARCHAR2 DEFAULT NULL,
                             p_attribute_rec         => null, --=> attribute_rec_const, --IN  attribute_rec_type        DEFAULT attribute_rec_const,                ???????
                   -- ******* Global Flexfield parameters *******
                             p_global_attribute_rec  => null, --=> global_attribute_rec_const, --IN  global_attribute_rec_type DEFAULT global_attribute_rec_const,          ?????????
                  p_receipt_comments                     => null, --'01-MAY-2012', --IN  VARCHAR2 DEFAULT NULL,                                                                    ????
                  --   ***  Notes Receivable Additional Information  ***
                             p_issuer_name                  => null, --IN VARCHAR2  DEFAULT NULL,
                             p_issue_date                   => null, --IN DATE   DEFAULT NULL,
                             p_issuer_bank_branch_id        => null, --IN NUMBER  DEFAULT NULL,
    --PG              p_org_id                       => l_org_id, --IN NUMBER  DEFAULT NULL,
    --PG                         p_installment                  => null,
                  --   ** OUT NOCOPY variables
                             p_cr_id          => l_cr_id, --OUT NOCOPY NUMBER
    --BEGIN PG
       -- Receipt application parameters
    --**************************** NEW PARAMETERS FOR APPLY *******************************
          p_customer_trx_id         => null, --3780703, --IN ra_customer_trx.customer_trx_id%TYPE DEFAULT NULL,
          p_trx_number              => l_invoice_number, --IN ra_customer_trx.trx_number%TYPE DEFAULT NULL,
    --*      p_installment             => 1, --null, --IN ar_payment_schedules.terms_sequence_number%TYPE DEFAULT NULL,
          p_applied_payment_schedule_id => null, --    IN ar_payment_schedules.payment_schedule_id%TYPE DEFAULT NULL,  --?????????
    --*      p_amount_applied          =>  3675.00, --IN ar_receivable_applications.amount_applied%TYPE DEFAULT NULL,
          -- this is the allocated receipt amount
    --*      p_amount_applied_from     => l_amount, -- IN ar_receivable_applications.amount_applied_from%TYPE DEFAULT NULL,
          p_trans_to_receipt_rate   => null, -- IN ar_receivable_applications.trans_to_receipt_rate%TYPE DEFAULT NULL,
    --*      p_discount                => 0, -- IN ar_receivable_applications.earned_discount_taken%TYPE DEFAULT NULL,
          p_apply_date              =>  l_trx_date,  --IN ar_receivable_applications.apply_date%TYPE DEFAULT NULL,
          p_apply_gl_date           =>  l_trx_date,  --IN ar_receivable_applications.gl_date%TYPE DEFAULT NULL,
          app_ussgl_transaction_code  => null, --  IN ar_receivable_applications.ussgl_transaction_code%TYPE DEFAULT NULL,
          p_customer_trx_line_id      => null, --  IN ar_receivable_applications.applied_customer_trx_line_id%TYPE DEFAULT NULL,
          p_line_number             => null, --  IN ra_customer_trx_lines.line_number%TYPE DEFAULT NULL,
    --*      p_show_closed_invoices    => 'N', --  IN VARCHAR2 DEFAULT 'N', /* Bug fix 2462013 */
          p_move_deferred_tax       => null, --  IN VARCHAR2 DEFAULT 'Y',
          p_link_to_trx_hist_id     => null, --  IN ar_receivable_applications.link_to_trx_hist_id%TYPE DEFAULT NULL,
          app_attribute_rec           => null, --  IN attribute_rec_type DEFAULT attribute_rec_const,
      -- ******* Global Flexfield parameters *******
          app_global_attribute_rec    => null, --  IN global_attribute_rec_type DEFAULT global_attribute_rec_const,
          app_comments                => null, --  IN ar_receivable_applications.comments%TYPE DEFAULT NULL,
          p_call_payment_processor    => null, --  IN VARCHAR2 DEFAULT FND_API.G_FALSE,
          p_org_id                    => l_org_id --IN NUMBER  DEFAULT NULL,  --******** DONE PG
    --END PG
                              );

            if l_return_status != 'S' then
                v_error_message := 'Error: Create_and_apply - RStatus: '||l_return_status||' Msg_data: ' ||l_msg_data||' Statement_line_id: '|| l_statement_line_id ;
                dbms_output.put_line(v_error_message);
            end if; --if l_return_status != 'S' then

	end if; --if l_customer_id is null or l_invoice_number is null then  --pgreen 06/16/14



        if (l_customer_id is null or l_invoice_number is null) or l_return_status != 'S' then
--end pgreen 12/18/13          
          
	      l_return_status := null;
          APPS.AR_RECEIPT_API_PUB.Create_cash(
                   -- Standard API parameters.
              p_api_version      => 1.0, --IN  NUMBER,
              p_init_msg_list    => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
              p_commit           => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
              p_validation_level => FND_API.G_VALID_LEVEL_FULL, --IN  NUMBER   := FND_API.G_VALID_LEVEL_FULL,
              x_return_status    => l_return_status, --OUT NOCOPY VARCHAR2 ,
              x_msg_count        => l_msg_count, --OUT NOCOPY NUMBER ,
              x_msg_data         => l_msg_data, --OUT NOCOPY VARCHAR2 ,
                         -- Receipt info. parameters
              p_usr_currency_code            => null, --IN  VARCHAR2 DEFAULT NULL, --the translated currency code
              p_currency_code                => l_currency_code, --'GBP', --IN  VARCHAR2 DEFAULT NULL,
              p_usr_exchange_rate_type       => null, --IN  VARCHAR2 DEFAULT NULL,
              p_exchange_rate_type           => null, --L_EXCHANGE_RATE_TYPE, --IN  VARCHAR2 DEFAULT NULL,
              p_exchange_rate                => null, --IN  NUMBER   DEFAULT NULL,
              p_exchange_rate_date           => null, --L_EXCHANGE_RATE_DATE, --IN  DATE     DEFAULT NULL,
              p_amount                       => l_amount, -- -183.40, --IN  NUMBER,
              p_factor_discount_amount       => null, --IN  NUMBER   DEFAULT NULL,                  ????
       p_receipt_number               => l_bank_trx_number, --IN  OUT NOCOPY VARCHAR2 ,
              p_receipt_date                 => l_trx_date, --IN  DATE     DEFAULT NULL,
              p_gl_date                      => l_trx_date, --IN  DATE     DEFAULT NULL,
                         p_maturity_date           => null, --IN  DATE     DEFAULT NULL,
                         p_postmark_date           => null, --IN  DATE     DEFAULT NULL,
                         p_customer_id             => null, --IN  NUMBER   DEFAULT NULL,
                         p_customer_name           => null, --IN  VARCHAR2 DEFAULT NULL,
                         p_customer_number         => null, --IN VARCHAR2  DEFAULT NULL,
                         p_customer_bank_account_id => null, --IN NUMBER   DEFAULT NULL,
                         p_customer_bank_account_num   => null, --IN  VARCHAR2  DEFAULT NULL,
                         p_customer_bank_account_name  => null, --IN  VARCHAR2  DEFAULT NULL,
                         p_payment_trxn_extension_id  => null, --IN NUMBER DEFAULT NULL,
                         p_location                 => null, --IN  VARCHAR2 DEFAULT NULL,
                         p_customer_site_use_id     => null, --IN  NUMBER  DEFAULT NULL,
                         p_default_site_use         => null, --IN VARCHAR2  DEFAULT 'Y', --bug4448307-4509459
                         p_customer_receipt_reference => null, --IN  VARCHAR2  DEFAULT NULL,                            ????
                         p_override_remit_account_flag => null, --IN  VARCHAR2 DEFAULT NULL,
              p_remittance_bank_account_id   => l_remit_bank_acct_use_id, --L_BANK_ACCOUNT_ID, --10043, --IN  NUMBER   DEFAULT NULL,
              p_remittance_bank_account_num  => null, --'019057300006', --IN  VARCHAR2 DEFAULT NULL,
              p_remittance_bank_account_name => null, --IN  VARCHAR2 DEFAULT NULL,
              p_deposit_date                 => null, --IN  DATE     DEFAULT NULL,
              p_receipt_method_id            => L_RECEIPT_METHOD_ID, --IN  NUMBER   DEFAULT NULL,
              p_receipt_method_name          => null, --IN  VARCHAR2 DEFAULT NULL,                                  
              p_doc_sequence_value           => null, --IN  NUMBER   DEFAULT NULL,
              p_ussgl_transaction_code       => null, --IN  VARCHAR2 DEFAULT NULL,
              p_anticipated_clearing_date    => l_trx_date, --IN  DATE     DEFAULT NULL,
              p_called_from                  => null, --IN VARCHAR2 DEFAULT NULL,
              p_attribute_rec                => l_attribute_rec, --null, --=>
 --                         attribute_rec_const, --IN   attribute_rec_type        DEFAULT attribute_rec_const,                ???????
               -- ******* Global Flexfield parameters *******
--              p_global_attribute_rec  => l_global_attribute_rec, --DEFAULT global_attribute_rec_const,          ?????????
              p_comments                     => l_comment, --'01-MAY-2012', --IN  VARCHAR2 DEFAULT NULL,                                                                    ????
              --   ***  Notes Receivable Additional Information  ***
                         p_issuer_name                  => null, --IN VARCHAR2  DEFAULT NULL,
                         p_issue_date                   => null, --IN DATE   DEFAULT NULL,
                         p_issuer_bank_branch_id        => null, --IN NUMBER  DEFAULT NULL,
              p_org_id                       => l_org_id, --IN NUMBER  DEFAULT NULL,
                         p_installment                  => null,
              --   ** OUT NOCOPY variables
                         p_cr_id          => l_cr_id --OUT NOCOPY NUMBER
                          );
            if l_return_status != 'S' then
                v_error_message := 'Error: Create_cash - RStatus: '||l_return_status||' Msg_data: ' ||l_msg_data||' Statement_line_id: '|| l_statement_line_id ;
                dbms_output.put_line(v_error_message);
            end if; --if l_return_status != 'S' then


        end if; --if l_customer_id is null or l_invoice_number is null then


        end if; --if l_exist_cnt = 0 then


--    elsif L_TRX_CODE IN (698, 699) THEN 
    elsif l_process_type = 'MISC'  THEN 

    --check if already exists
        l_exist_cnt := 0;

        select count(*)
        into l_exist_cnt 
        from AR_CASH_RECEIPTS_V 
        where org_id = l_org_id
        and receipt_number = l_bank_trx_number --'999721212509610'
        and receipt_date = l_trx_date
        and type = 'MISC'
        and currency_code = l_currency_code                   --????????????????  temporary
        and amount = l_amount * L_MULTIPLY
        and remit_bank_acct_use_id = l_remit_bank_acct_use_id
        and remit_bank_account = l_BANK_ACCOUNT_NUM
        and receipt_status in ('UNAPP','APP','UNID')  --pgreen 07/08/14
        ;


        if l_exist_cnt = 0 then
            select count(*)
            into l_activity_flag
            from AR_RECEIVABLES_TRX_ALL  rt
            where rt.org_id = l_org_id
            and rt.name = l_activity_type;

          if l_activity_flag = 1 then
        
              l_activity := l_activity_type;
--              l_activity := 'Miscellaneous cash';
              l_attribute_rec.attribute5 := l_bank_reference;
                
              APPS.AR_RECEIPT_API_PUB.create_misc(
                -- Standard API parameters.
                  p_api_version                  => 1.0, --IN  NUMBER,
                  p_init_msg_list                => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                  p_commit                       => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                  p_validation_level             => FND_API.G_VALID_LEVEL_FULL, --IN  NUMBER   := FND_API.G_VALID_LEVEL_FULL,
                  x_return_status                => l_return_status, --OUT NOCOPY VARCHAR2 ,
                  x_msg_count                    => l_msg_count, --OUT NOCOPY NUMBER ,
                  x_msg_data                     => l_msg_data, --OUT NOCOPY VARCHAR2 ,
                -- Misc Receipt info. parameters

                  p_usr_currency_code            => null, --IN  VARCHAR2 DEFAULT NULL, --the translated currency code
                  p_currency_code                => l_currency_code, --IN  VARCHAR2 DEFAULT NULL,
                  p_usr_exchange_rate_type       => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_exchange_rate_type           => null, --L_EXCHANGE_RATE_TYPE, --IN  VARCHAR2 DEFAULT NULL,
                  p_exchange_rate                => null, --IN  NUMBER   DEFAULT NULL,
                  p_exchange_rate_date           => null, --L_EXCHANGE_RATE_DATE, --IN  DATE     DEFAULT NULL,

                  p_amount                       =>  L_AMOUNT * L_MULTIPLY, --IN  NUMBER,
                  p_receipt_number               => l_bank_trx_number, --IN  OUT NOCOPY VARCHAR2 ,
                  p_receipt_date                 => l_trx_date, --IN  DATE     DEFAULT NULL,
                  p_gl_date                      => l_trx_date, --IN  DATE     DEFAULT NULL,
                  p_receivables_trx_id           => null, --IN  NUMBER   DEFAULT NULL,
                  p_activity                     => l_activity, --'Miscellaneous Non A/R Receipt', --IN  VARCHAR2 DEFAULT NULL,
                  p_misc_payment_source          => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_tax_code                     => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_vat_tax_id                   => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_tax_rate                     => null, --IN  NUMBER   DEFAULT NULL,
                  p_tax_amount                   => null, --IN  NUMBER   DEFAULT NULL,
                  p_deposit_date                 => null, --IN  DATE     DEFAULT NULL,
                  p_reference_type               => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_reference_num                => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_reference_id                 => null, --IN  NUMBER   DEFAULT NULL,
                  p_remittance_bank_account_id   => l_remit_bank_acct_use_id, --IN  NUMBER   DEFAULT NULL,
                  p_remittance_bank_account_num  => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_remittance_bank_account_name => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_receipt_method_id            => L_RECEIPT_METHOD_ID, --IN  NUMBER   DEFAULT NULL,
                  p_receipt_method_name          => null, --IN  VARCHAR2 DEFAULT NULL,
                  p_doc_sequence_value           => null, --IN  NUMBER   DEFAULT NULL,
                  p_ussgl_transaction_code       => null, --IN  VARCHAR2 DEFAULT NULL,                      --??????????????????????????????????
                  p_anticipated_clearing_date    => l_trx_date, --IN  DATE     DEFAULT NULL,
                  p_attribute_record             => l_attribute_rec, --null, --=> attribute_rec_const, --IN  attribute_rec_type        DEFAULT attribute_rec_const,
                  p_global_attribute_record      => null, --=> global_attribute_rec_const, --    IN  global_attribute_rec_type DEFAULT global_attribute_rec_const,
                  p_comments                     => l_comment, --IN  VARCHAR2 DEFAULT NULL,
                  p_org_id                       => l_org_id, --IN NUMBER  DEFAULT NULL,
                  p_misc_receipt_id              => l_misc_receipt_id, --OUT NOCOPY NUMBER,
                  p_called_from                  => null, --IN VARCHAR2 DEFAULT NULL,
                  p_payment_trxn_extension_id    => null --IN ar_cash_receipts.payment_trxn_extension_id%TYPE DEFAULT NULL ) /* Bug fix 3619780*/
              );

                if l_return_status != 'S' then
                    v_error_message := 'Error: create_misc - RStatus: '||l_return_status||' Msg_data: ' ||l_msg_data||' Statement_line_id: '|| l_statement_line_id ;
                    dbms_output.put_line(v_error_message);
                end if; --if l_return_status != 'S' then


          else --  if l_activity_flag = 1 then
            null; 
            --error no activity!!!!!!!!!!
          end if; --  if l_activity_flag = 1 then


        end if; --if l_exist_cnt = 0 then

    END IF; --IF L_TRX_CODE IN (195) THEN--MANUAL RECEIPT



    END LOOP;
end if; --if v_error_flag = 0 then

null;
END create_receipts;

------------------------------------------------------------
--begin pgreen 03/27/13
PROCEDURE create_month_end_receipts (p_bank_account_id in number, 
                                   p_statement_number in varchar2) is
l_return_status VARCHAR2(1);
l_msg_count NUMBER;
l_msg_data VARCHAR2(240);
l_misc_receipt_id number;
l_user_id NUMBER := Fnd_Profile.VALUE('USER_ID');
--l_org_id NUMBER := Fnd_Profile.VALUE('ORG_ID');
--l_resp_id NUMBER := 51439; --Fnd_Profile.VALUE('RESP_ID');
l_org_id number;
l_cr_id number;
l_currency_code varchar2(15);
l_amount number;
l_bank_trx_number varchar2(240);
l_trx_date date;
L_TRX_TYPE VARCHAR2(30);
L_STATUS VARCHAR2(30);
L_TRX_CODE VARCHAR2(30);
L_BANK_ACCOUNT_ID NUMBER;
L_RECEIPT_METHOD_ID NUMBER;
l_remit_bank_acct_use_id number;
l_BANK_NAME varchar2(360);
l_BANK_ACCOUNT_NUM varchar2(30);
l_line_number number;
l_bank_branch_name varchar2(360);
l_statement_number varchar2(50);
l_exist_cnt number := 0;
l_exist_cnt2 number := 0;
l_activity varchar2(1000);
l_process_type varchar2(30);
l_activity_type varchar2(1000);
l_payment_type varchar2(1000);
l_bank_reference varchar2(1000);
l_activity_flag number;
L_MULTIPLY NUMBER;
L_EXCHANGE_RATE_DATE DATE;
L_EXCHANGE_RATE_TYPE VARCHAR2(30);
l_comment varchar2(2000);

l_bank_code varchar2(20); 

l_attribute_rec  ar_receipt_api_pub.attribute_rec_type;
l_global_attribute_rec  ar_receipt_api_pub.global_attribute_rec_type;


l_r_type varchar2(2); --pgreen 07/09/13

l_sqlcode                     NUMBER;
l_sqlerrm                     VARCHAR2 (2000);
v_error_message               VARCHAR2 (8000);

v_error_flag number := 0;


CURSOR MAIN_CUR (v_statement_number in varchar2, v_bank_account_num in varchar2, v_bank_code in varchar2)  IS
select 
sl.trx_date, tc.trx_type, sl.amount,
 'UNRECONCILED' status,
--pgreen 07/09/13  ltrim(sl.customer_text,'0') bank_trx_number, sl.trx_code, 
--pgreen 09/04/13  ltrim(nvl(sl.customer_text,BA.BANK_ACCOUNT_NUM||'-'||sl.statement_number||'-'||sl.line_number),'0') bank_trx_number,  --pgreen 07/09/13
  ltrim(nvl(ltrim(sl.customer_text,'0'),BA.BANK_ACCOUNT_NUM||'-'||sl.statement_number||'-'||sl.line_number),'0') bank_trx_number,  --pgreen 09/04/13
sl.trx_code, sh.currency_code, sl.trx_date EXCHANGE_RATE_DATE , 'Corporate' EXCHANGE_RATE_TYPE, --sh.currency_code, 
BA.BANK_ACCOUNT_ID,
 rma.ORG_ID, 
rma.receipt_method_id
, RMA.remit_bank_acct_use_id, BB.BANK_NAME, bb.bank_branch_name, BA.BANK_ACCOUNT_NUM , sl.line_number line_number
,sl.statement_number
,L.ATTRIBUTE2 PROCESS_TYPE,l.attribute3 payment_type, 
l.attribute4 activity_type, decode( tc.trx_type,'MISC_DEBIT',-1,1) multiply
,'QSTCE: '||case when nvl(ba.attribute2,'N') = 'N' THEN sl.trx_text else 'Text removed (has foreign characters).' end trx_text, --pgreen 03/06/13
sl.statement_number||'-'||sh.currency_code bank_reference
from 
CE_STATEMENT_LINES_INTERFACE sl, CE_STATEMENT_HEADERS_INT sh,
--CE_STATEMENT_LINES SL , CE_STATEMENT_HEADERS SH ,
ce_bank_acct_uses_all bau,
CE_BANK_BRANCHES_V BB,
CE_BANK_ACCOUNTS BA,
ar_receipt_method_accounts_all rma,
fnd_lookup_values_vl  L,
ar_receipt_methods rm,
ar_receipt_classes rc,
CE_TRANSACTION_CODES tc
where 1=1
and sh.statement_number = v_statement_number
and sh.bank_account_num =v_bank_account_num
and sl.statement_number = sh.statement_number
and sl.bank_account_num = sh.bank_account_num
and ba.bank_account_num = sl.bank_account_num
AND BAU.BANK_ACCT_USE_ID = RMA.remit_bank_acct_use_id
and ba.bank_account_id = bau.bank_account_id
AND BB.BANK_PARTY_ID = BA.BANK_ID  --5041
AND BB.BRANCH_PARTY_ID = BA.BANK_BRANCH_ID --5045
AND L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
and nvl(l.attribute6, v_bank_code) = v_bank_code    
and nvl(l.attribute9, v_bank_account_num) = v_bank_account_num    
AND sl.trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
AND L.ATTRIBUTE1 = SL.trx_code
AND L.ATTRIBUTE2 = 'CASH' --for regular receipt   
and tc.trx_code = SL.trx_code
and tc.bank_account_id = ba.bank_account_id
and tc.trx_type = 'CREDIT'
and rm.receipt_method_id = rma.receipt_method_id
and rc.receipt_class_id = rm.receipt_class_id
and sl.trx_date between rma.start_date and nvl(rma.end_date, sysdate+1)
and sl.trx_date between rm.start_date and nvl(rm.end_date, sysdate+1)
--and SL.trx_code in (165) -- (195) --,698,699)
--and sl.bank_trx_number = '1157452'
AND NOT EXISTS
    (SELECT 'X'
     FROM fnd_lookup_values_vl  L2
     WHERE L2.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
     AND L2.ATTRIBUTE2 = 'MISC' --for regular receipt 
     AND L2.ATTRIBUTE1 = SL.TRX_CODE
     and sl.trx_date BETWEEN L2.START_DATE_ACTIVE AND NVL(L2.END_DATE_ACTIVE, SYSDATE+1)
     and nvl(l.attribute6, v_bank_code) = v_bank_code    
     and nvl(l.attribute9, v_bank_account_num) = v_bank_account_num    
     AND SL.TRX_TEXT LIKE L2.ATTRIBUTE5) 
AND NOT EXISTS
    (SELECT 'X'
     FROM fnd_lookup_values_vl  L2
     WHERE L2.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
     AND L2.ATTRIBUTE2 = 'EXCEPTION' --for regular receipt 
     AND L2.ATTRIBUTE1 = SL.TRX_CODE
     and nvl(l.attribute6, v_bank_code) = v_bank_code    
     and nvl(l.attribute9, v_bank_account_num) = v_bank_account_num    
     and sl.trx_date BETWEEN L2.START_DATE_ACTIVE AND NVL(L2.END_DATE_ACTIVE, SYSDATE+1)
     AND SL.TRX_TEXT LIKE L2.ATTRIBUTE5) 
;


BEGIN

null;
/*------------------------------+
| Setting global initialization | 
+-------------------------------*/ 
--FND_GLOBAL.apps_initialize(l_user_id, l_resp_id, 222);

FND_GLOBAL.apps_initialize(1433, 51306, 222);
MO_GLOBAL.init('AR');

null;
--l_user_id  := Fnd_Profile.VALUE('USER_ID');
--l_org_id := Fnd_Profile.VALUE('ORG_ID');
--l_resp_id  := Fnd_Profile.VALUE('RESP_ID');

--obtain bank account number
    begin
        select ba.bank_account_num, ba.attribute1
        INTO l_bank_account_num, l_bank_code
        from CE_BANK_ACCOUNTS BA
        where ba.bank_account_id = p_bank_account_id
        AND SYSDATE BETWEEN NVL(BA.START_DATE, SYSDATE-1) AND NVL(BA.END_DATE, SYSDATE+1);
    exception
        when others then
            v_error_flag := 1;
    end;


if v_error_flag = 0 then


    --l_BANK_ACCOUNT_NUM := P_BANK_ACCOUNT_NUM;
    l_statement_number := p_statement_number;


    FOR MAIN_REC IN MAIN_CUR (l_statement_number, l_bank_account_num, l_bank_code ) LOOP
    l_org_id := MAIN_REC.org_id;
    l_currency_code := MAIN_REC.currency_code;
    l_amount := MAIN_REC.amount;
    l_bank_trx_number := MAIN_REC.bank_trx_number;
    l_trx_date := MAIN_REC.trx_date;

    L_TRX_TYPE := MAIN_REC.TRX_TYPE;
    L_STATUS := MAIN_REC.STATUS;
    L_TRX_CODE := MAIN_REC.TRX_CODE;
    L_BANK_ACCOUNT_ID := MAIN_REC.BANK_ACCOUNT_ID;
    L_RECEIPT_METHOD_ID := MAIN_REC.RECEIPT_METHOD_ID;
    l_remit_bank_acct_use_id := main_rec.remit_bank_acct_use_id;
    l_BANK_NAME := main_rec.BANK_NAME;
    l_bank_branch_name := main_rec.bank_branch_name;
    l_line_number := main_rec.line_number;
    l_process_type := main_rec.process_type;
    l_activity_type := main_rec.activity_type;
    l_payment_type := main_rec.payment_type;
    l_bank_reference := main_rec.bank_reference;
    l_multiply := main_rec.multiply;
    L_EXCHANGE_RATE_DATE := main_rec.EXCHANGE_RATE_DATE;
    L_EXCHANGE_RATE_TYPE := main_rec.EXCHANGE_RATE_TYPE;
    l_comment := main_rec.trx_text;
    l_attribute_rec := null;



 --   IF L_TRX_CODE IN (195) THEN--MANUAL RECEIPT
    if l_process_type = 'CASH' then --MANUAL RECEIPT

--begin pgreen 07/09/13
       begin
            l_r_type := null;
            
            select l.attribute4 r_type
            into l_r_type
            from fnd_lookup_values_vl  L
            where  L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            and l.attribute2 = 'CREDIT_CARD'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
            and l_trx_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and l.attribute1 = l_trx_code
            and l_comment like l.attribute5 
            and l_bank_trx_number not like l.attribute4||'%'
            ;
                
            if l_r_type is not null then
                l_bank_trx_number := l_bank_trx_number||'-'||l_r_type;
            end if; --if l_r_type is not null then
       exception
        when others then
            null;
            
       end;
--end pgreen 07/09/13

    --check if already exists
        l_exist_cnt := 0;

        select count(*)
        into l_exist_cnt 
        from AR_CASH_RECEIPTS_V 
        where org_id = l_org_id
        and receipt_number = l_bank_trx_number --'999721212509610'
        and receipt_date = l_trx_date
        and type = 'CASH'
        and currency_code = l_currency_code                   --????????????????  temporary
        and amount = l_amount
        and remit_bank_acct_use_id = l_remit_bank_acct_use_id
        and remit_bank_account = l_BANK_ACCOUNT_NUM
        and receipt_status in ('UNAPP','APP','UNID')  --pgreen 07/08/14
        ;


        if l_exist_cnt = 0 then

          l_attribute_rec.attribute4 := l_payment_type;
          l_attribute_rec.attribute5 := l_bank_reference;

          APPS.AR_RECEIPT_API_PUB.Create_cash(
                   -- Standard API parameters.
              p_api_version      => 1.0, --IN  NUMBER,
              p_init_msg_list    => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
              p_commit           => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
              p_validation_level => FND_API.G_VALID_LEVEL_FULL, --IN  NUMBER   := FND_API.G_VALID_LEVEL_FULL,
              x_return_status    => l_return_status, --OUT NOCOPY VARCHAR2 ,
              x_msg_count        => l_msg_count, --OUT NOCOPY NUMBER ,
              x_msg_data         => l_msg_data, --OUT NOCOPY VARCHAR2 ,
                         -- Receipt info. parameters
              p_usr_currency_code            => null, --IN  VARCHAR2 DEFAULT NULL, --the translated currency code
              p_currency_code                => l_currency_code, --'GBP', --IN  VARCHAR2 DEFAULT NULL,
              p_usr_exchange_rate_type       => null, --IN  VARCHAR2 DEFAULT NULL,
              p_exchange_rate_type           => null, --L_EXCHANGE_RATE_TYPE, --IN  VARCHAR2 DEFAULT NULL,
              p_exchange_rate                => null, --IN  NUMBER   DEFAULT NULL,
              p_exchange_rate_date           => null, --L_EXCHANGE_RATE_DATE, --IN  DATE     DEFAULT NULL,
              p_amount                       => l_amount, -- -183.40, --IN  NUMBER,
              p_factor_discount_amount       => null, --IN  NUMBER   DEFAULT NULL,                  ????
              p_receipt_number               => l_bank_trx_number, --IN  OUT NOCOPY VARCHAR2 ,
              p_receipt_date                 => l_trx_date, --IN  DATE     DEFAULT NULL,
              p_gl_date                      => l_trx_date, --IN  DATE     DEFAULT NULL,
                         p_maturity_date           => null, --IN  DATE     DEFAULT NULL,
                         p_postmark_date           => null, --IN  DATE     DEFAULT NULL,
                         p_customer_id             => null, --IN  NUMBER   DEFAULT NULL,
                         p_customer_name           => null, --IN  VARCHAR2 DEFAULT NULL,
                         p_customer_number         => null, --IN VARCHAR2  DEFAULT NULL,
                         p_customer_bank_account_id => null, --IN NUMBER   DEFAULT NULL,
                         p_customer_bank_account_num   => null, --IN  VARCHAR2  DEFAULT NULL,
                         p_customer_bank_account_name  => null, --IN  VARCHAR2  DEFAULT NULL,
                         p_payment_trxn_extension_id  => null, --IN NUMBER DEFAULT NULL,
                         p_location                 => null, --IN  VARCHAR2 DEFAULT NULL,
                         p_customer_site_use_id     => null, --IN  NUMBER  DEFAULT NULL,
                         p_default_site_use         => null, --IN VARCHAR2  DEFAULT 'Y', --bug4448307-4509459
                         p_customer_receipt_reference => null, --IN  VARCHAR2  DEFAULT NULL,                            ????
                         p_override_remit_account_flag => null, --IN  VARCHAR2 DEFAULT NULL,
              p_remittance_bank_account_id   => l_remit_bank_acct_use_id, --L_BANK_ACCOUNT_ID, --10043, --IN  NUMBER   DEFAULT NULL,
              p_remittance_bank_account_num  => null, --'019057300006', --IN  VARCHAR2 DEFAULT NULL,
              p_remittance_bank_account_name => null, --IN  VARCHAR2 DEFAULT NULL,
              p_deposit_date                 => null, --IN  DATE     DEFAULT NULL,
              p_receipt_method_id            => L_RECEIPT_METHOD_ID, --IN  NUMBER   DEFAULT NULL,
              p_receipt_method_name          => null, --IN  VARCHAR2 DEFAULT NULL,                                  
              p_doc_sequence_value           => null, --IN  NUMBER   DEFAULT NULL,
              p_ussgl_transaction_code       => null, --IN  VARCHAR2 DEFAULT NULL,
              p_anticipated_clearing_date    => l_trx_date, --IN  DATE     DEFAULT NULL,
              p_called_from                  => null, --IN VARCHAR2 DEFAULT NULL,
              p_attribute_rec                => l_attribute_rec, --null, --=>
 --                         attribute_rec_const, --IN   attribute_rec_type        DEFAULT attribute_rec_const,                ???????
               -- ******* Global Flexfield parameters *******
--              p_global_attribute_rec  => l_global_attribute_rec, --DEFAULT global_attribute_rec_const,          ?????????
              p_comments                     => l_comment, --'01-MAY-2012', --IN  VARCHAR2 DEFAULT NULL,                                                                    ????
              --   ***  Notes Receivable Additional Information  ***
                         p_issuer_name                  => null, --IN VARCHAR2  DEFAULT NULL,
                         p_issue_date                   => null, --IN DATE   DEFAULT NULL,
                         p_issuer_bank_branch_id        => null, --IN NUMBER  DEFAULT NULL,
              p_org_id                       => l_org_id, --IN NUMBER  DEFAULT NULL,
                         p_installment                  => null,
              --   ** OUT NOCOPY variables
                         p_cr_id          => l_cr_id --OUT NOCOPY NUMBER
                          );
            if l_return_status != 'S' then
                v_error_message := 'Error: Create_cash - RStatus: '||l_return_status||' Msg_data: ' ||l_msg_data||' Line_number: '|| l_line_number ;
                dbms_output.put_line(v_error_message);
            end if; --if l_return_status != 'S' then
        end if; --if l_exist_cnt = 0 then


    END IF; --IF L_TRX_CODE IN (195) THEN--MANUAL RECEIPT



    END LOOP;
end if; --if v_error_flag = 0 then

null;
END create_month_end_receipts;


--end pgreen 03/27/13
------------------------------------------------------------


PROCEDURE submit_import_autorec(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
--                                   l_option in varchar2, 
                                   l_bank_branch_id in number, 
                                   l_bank_account_id in number, 
                                   l_bank_account_num in varchar2,
                                   l_statement_number_from in varchar2, 
                                   l_statement_number_to in varchar2, 
                                   l_statement_date_from in varchar2, 
                                   l_statement_date_to in varchar2, 
                                   l_gl_date in varchar2, 
                                   l_org_id in varchar2 ,
                                   l_control_line_count in number,                                 
/*
                                   l_legal_entity_id in varchar2, 
                                   l_receivables_trx_id in number, 
                                   l_payment_method_id in number, 
                                   l_nsf_handling in varchar2, 
                                   l_display_debug in varchar2,
                                   l_debug_path in varchar2,
                                   l_debug_file in varchar2,
*/ 
                                  l_record_status_flag out varchar2) is 

--  l_bank_account_id            NUMBER := p_bank_account_id;
--  l_statement_number_from      VARCHAR2(100) := p_statement_number;
  l_legal_entity_id         VARCHAR2(100) := null;
  l_receivables_trx_id         NUMBER := null;
  l_payment_method_id         NUMBER := null;
  l_nsf_handling               VARCHAR2(100) := 'NO_ACTION';
  l_display_debug             VARCHAR2(100) := 'N';
  l_debug_path             VARCHAR2(100) := null;
  l_debug_file             VARCHAR2(100) := null;


    l_request_id NUMBER := 0 ; 
    l_loop_count number := 0;
    l_loop_flag boolean := true;
    l_phase_code varchar2(30);
    l_status_code varchar2(30);
--    l_bank_account_num varchar2(30);
    l_message_name varchar2(30);
    l_option                     VARCHAR2(100);


begin
--Submit 'Bank Statement Import and AutoReconciliation'
       if l_control_line_count = 0 then
           l_option      := 'IMPORT'; --               VARCHAR2(100);
           l_request_id := Fnd_Request.submit_request('CE','ARPLABIM',
                            NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_option, l_bank_branch_id, l_bank_account_id, NULL, NULL, NULL , NULL, l_gl_date, l_org_id ,l_legal_entity_id , l_receivables_trx_id, l_payment_method_id, NULL, l_display_debug,l_debug_path ,l_debug_file); --PGREEN 09/26/11
       else
           l_option      := 'ZALL'; --               VARCHAR2(100);
           l_request_id := Fnd_Request.submit_request('CE','ARPLABIR',
--                            NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_option, l_bank_branch_id, l_bank_account_id, l_statement_number_from, l_statement_number_to, l_statement_date_from , l_statement_date_to, l_gl_date, l_org_id ,l_legal_entity_id , l_receivables_trx_id, l_payment_method_id, l_nsf_handling, l_display_debug,l_debug_path ,l_debug_file); --PGREEN 09/26/11
                            NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_option, l_bank_branch_id, l_bank_account_id, l_statement_number_from, l_statement_number_to, null , null, l_gl_date, l_org_id ,l_legal_entity_id , l_receivables_trx_id, l_payment_method_id, l_nsf_handling, l_display_debug,l_debug_path ,l_debug_file); --PGREEN 09/26/11

       end if; --       if l_control_line_count = 0 then

        IF (l_request_id = 0) THEN 
          RAISE_APPLICATION_ERROR(-20996,Fnd_Message.get); 
        else

            update qstce_statement_log
            set import_reconcile_req_id = l_request_id,
            import_reconcile_message = null
            where bank_account_id = l_bank_account_id
            and statement_number = l_statement_number_from;
            commit;
 
       END IF; -- l_request_id = 0

    l_loop_count := 0;
    l_loop_flag := true;

    while l_loop_flag loop
            l_loop_count := l_loop_count + 1;
            begin

            select r.phase_code,   r.status_code
            into l_phase_code,   l_status_code
            from fnd_concurrent_requests r
            where r.request_id = l_request_id;
            exception
              when others then
                    null;
            end;
            
            if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                 l_loop_flag := false;
            ELSE
                dbms_lock.sleep( 60 );  --seconds        
            end if;  
                     

    end loop;

--******************Error check
    if l_control_line_count != 0 then

    select shi.record_status_flag
    into l_record_status_flag
    from CE_STATEMENT_HEADERS_INT shi
    where shi.bank_account_num = l_bank_account_num
    and shi.statement_number = l_statement_number_from;
    
        if l_record_status_flag = 'E' then
        
            SELECT he.message_name
            into l_message_name
            FROM CE_HEADER_INTERFACE_ERRORS he
            where he.bank_account_num = l_bank_account_num
            and he.statement_number = l_statement_number_from
            AND ROWNUM < 2;
     
            update qstce_statement_log
            set IMPORT_RECONCILE_MESSAGE = l_message_name
            where bank_account_id = l_bank_account_id
            and statement_number = l_statement_number_from;
            commit;
        end if; --if l_record_status_flag = 'E' then
    END IF; --if l_control_line_count != 0 then

end submit_import_autorec;




PROCEDURE submit_create_receipts_autorec(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
--                                   l_option in varchar2, 
                                   l_bank_branch_id in number, 
                                   l_bank_account_id in number, 
                                   l_bank_account_num in varchar2,
                                   l_statement_number_from in varchar2, 
                                   l_statement_number_to in varchar2, 
                                   l_statement_date_from in varchar2, 
                                   l_statement_date_to in varchar2, 
                                   l_gl_date in varchar2, 
                                   l_org_id in varchar2 --,
/*
                                   l_legal_entity_id in varchar2, 
                                   l_receivables_trx_id in number, 
                                   l_payment_method_id in number, 
                                   l_nsf_handling in varchar2, 
                                   l_display_debug in varchar2,
                                   l_debug_path in varchar2,
                                   l_debug_file in varchar2
*/
                                   ) is

  l_legal_entity_id         VARCHAR2(100) := null;
  l_receivables_trx_id         NUMBER := null;
  l_payment_method_id         NUMBER := null;
  l_nsf_handling               VARCHAR2(100) := 'NO_ACTION';
  l_display_debug             VARCHAR2(100) := 'N';
  l_debug_path             VARCHAR2(100) := null;
  l_debug_file             VARCHAR2(100) := null;

    l_request_id NUMBER := 0 ; 
    l_loop_count number := 0;
    l_loop_flag boolean := true;
    l_phase_code varchar2(30);
    l_status_code  varchar2(30);
    l_line_cnt number;
    l_unreconciled_line_cnt number;
    l_message_name varchar2(30);
    l_option  VARCHAR2(100);
    
    v_credit_card_cnt number := 0;

begin


    select count(*)
    into v_credit_card_cnt
    from fnd_lookup_values_vl  L,
    CE_BANK_ACCOUNTS BA
    where  L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
    and l.attribute2 = 'CREDIT_CARD'
    and nvl(l.attribute6, ba.attribute1) = ba.attribute1  -- bank_code    
    and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num   
    and ba.bank_account_id = l_bank_account_id
    and l_statement_date_from  BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1);

  if v_credit_card_cnt > 0 then

--paula louise

--Submit CUSTOM 'Quest CE Create Credit Card Receipts'
       l_request_id := Fnd_Request.submit_request('CE','QSTCE_CREATE_CC_RECEIPTS',
                        NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_bank_account_id, l_statement_number_from); --PGREEN 09/26/11

        IF (l_request_id = 0) THEN 
          RAISE_APPLICATION_ERROR(-20996,Fnd_Message.get); 
        else
            update qstce_statement_log
            set create_cc_receipts_req_id = l_request_id
            where bank_account_id = l_bank_account_id
            and statement_number = l_statement_number_from;
            commit;
        END IF; -- l_request_id = 0

    l_loop_count := 0;
    l_loop_flag := true;

    while l_loop_flag loop
            l_loop_count := l_loop_count + 1;
            begin

            select r.phase_code,   r.status_code
            into l_phase_code,   l_status_code
            from fnd_concurrent_requests r
            where r.request_id = l_request_id;
            exception
              when others then
                    null;
            end;
            
            if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                 l_loop_flag := false;
            ELSE
                dbms_lock.sleep( 60 );  --seconds        
            end if;  
                     

    end loop;



-----------------------------------------------------------------------------

--Submit CUSTOM 'Quest CE Create Credit Card Statement Lines'
       l_request_id := Fnd_Request.submit_request('CE','QSTCE_CREATE_CC_STMT_LINES',
                        NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_bank_account_id, l_statement_number_from); --PGREEN 09/26/11

        IF (l_request_id = 0) THEN 
          RAISE_APPLICATION_ERROR(-20996,Fnd_Message.get); 
        else
            update qstce_statement_log
            set create_stmt_lines_cc_req_id = l_request_id
            where bank_account_id = l_bank_account_id
            and statement_number = l_statement_number_from;
            commit;
        END IF; -- l_request_id = 0

    l_loop_count := 0;
    l_loop_flag := true;

    while l_loop_flag loop
            l_loop_count := l_loop_count + 1;
            begin

            select r.phase_code,   r.status_code
            into l_phase_code,   l_status_code
            from fnd_concurrent_requests r
            where r.request_id = l_request_id;
            exception
              when others then
                    null;
            end;
            
            if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                 l_loop_flag := false;
            ELSE
                dbms_lock.sleep( 60 );  --seconds        
            end if;  
                     

    end loop;

  end if; --if v_credit_card_cnt > 0 then

-----------------------------------------------------------------------------




--Submit CUSTOM 'Quest CE Create Receipts and Misc Receipts'
       l_request_id := Fnd_Request.submit_request('CE','QSTCE_CREATE_RECEIPTS',
                        NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_bank_account_id, l_statement_number_from); --PGREEN 09/26/11

        IF (l_request_id = 0) THEN 
          RAISE_APPLICATION_ERROR(-20996,Fnd_Message.get); 
        else
            update qstce_statement_log
            set create_receipts_req_id = l_request_id
            where bank_account_id = l_bank_account_id
            and statement_number = l_statement_number_from;
            commit;
        END IF; -- l_request_id = 0

    l_loop_count := 0;
    l_loop_flag := true;

    while l_loop_flag loop
            l_loop_count := l_loop_count + 1;
            begin

            select r.phase_code,   r.status_code
            into l_phase_code,   l_status_code
            from fnd_concurrent_requests r
            where r.request_id = l_request_id;
            exception
              when others then
                    null;
            end;
            
            if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                 l_loop_flag := false;
            ELSE
                dbms_lock.sleep( 60 );  --seconds        
            end if;  
                     

    end loop;



-----------------------------------------------------------------------------



    --Submit 'AutoReconciliation'

      l_option      := 'RECONCILE'; --               VARCHAR2(100);

       l_request_id := Fnd_Request.submit_request('CE','ARPLABRC',
--                        NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_option, l_bank_branch_id, l_bank_account_id, l_statement_number_from, l_statement_number_to, l_statement_date_from , l_statement_date_to, l_gl_date, l_org_id ,l_legal_entity_id , l_receivables_trx_id, l_payment_method_id, l_nsf_handling, l_display_debug,l_debug_path ,l_debug_file); --PGREEN 09/26/11
                        NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_option, l_bank_branch_id, l_bank_account_id, l_statement_number_from, l_statement_number_to, NULL , NULL, l_gl_date, l_org_id ,l_legal_entity_id , l_receivables_trx_id, l_payment_method_id, l_nsf_handling, l_display_debug,l_debug_path ,l_debug_file); --PGREEN 09/26/11

        IF (l_request_id = 0) THEN 
          RAISE_APPLICATION_ERROR(-20996,Fnd_Message.get); 
        else
            update qstce_statement_log
            set reconciliation_req_id = l_request_id
            where bank_account_id = l_bank_account_id
            and statement_number = l_statement_number_from;
            commit;
        END IF; -- l_request_id = 0

    l_loop_count := 0;
    l_loop_flag := true;

    while l_loop_flag loop
            l_loop_count := l_loop_count + 1;
            begin

            select r.phase_code,   r.status_code
            into l_phase_code,   l_status_code
            from fnd_concurrent_requests r
            where r.request_id = l_request_id;
            exception
              when others then
                    null;
            end;
            
            
            if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                 l_loop_flag := false;
            ELSE
                dbms_lock.sleep( 60 );  --seconds        
            end if;  

    end loop;

--******************Error check
        select count(*) line_cnt, nvl(sum(decode(SL.status, 'UNRECONCILED', 1, 0)),0) unreconciled_line_cnt
        into l_line_cnt , l_unreconciled_line_cnt
        from CE_STATEMENT_HEADERS SH  , CE_STATEMENT_LINES SL
        where 1=1
        and sh.statement_number = l_statement_number_from
        and sh.bank_account_id = l_bank_account_id
        and sl.statement_header_id = sh.statement_header_id;

        
        if l_unreconciled_line_cnt = 0 then
            l_message_name := null;
        else

            l_message_name :='QST_UNRECONCILED_LINES';
        end if; --if l_record_status_flag = 'E' then
           
        update qstce_statement_log
        set RECONCILE_MESSAGE = l_message_name,
        line_cnt = l_line_cnt,
        unreconciled_line_cnt = l_unreconciled_line_cnt
        where bank_account_id = l_bank_account_id
        and statement_number = l_statement_number_from;
        commit;
            
 

end submit_create_receipts_autorec;

PROCEDURE restart_import_autorec(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_account_id in number, 
                                   p_statement_number in varchar2,
                                    p_creation_date in varchar2,
                                   p_bank_code in varchar2) is

    l_creation_date date := trunc(to_date(p_creation_date,'YYYY/MM/DD HH24:MI:SS')) ; -- FND_DATE_STANDARD    2013/05/14 00:00:00

l_bank_name varchar2(360); 
l_bank_org_id number;
l_bank_account_num varchar2(30);
l_statement_date date;
l_currency_code varchar2(15);
l_record_status_flag varchar2(1);
l_record_status_cnt number;
l_message_name varchar2(30);

  L_ERRBUF VARCHAR2(32767);
  L_RETCODE NUMBER;
  
  l_option                     VARCHAR2(100);
  l_bank_branch_id          NUMBER;
  l_bank_account_id            NUMBER;
  l_statement_number_from      VARCHAR2(100);
  l_statement_number_to        VARCHAR2(100);
  l_statement_date_from        VARCHAR2(100);
  l_statement_date_to          VARCHAR2(100);
  l_gl_date                    VARCHAR2(100);
  l_org_id             VARCHAR2(100);
  l_type number;
  l_control_line_count number;
  
  l_check_log   number := 0; --pgreen 07/09/13




cursor stmt_log_cur is
--begin pgreen 07/09/13
select '1' xtype, shi.creation_date, ba.bank_branch_id, ba.bank_account_id, shi.statement_number,  
bb.bank_name, bb.bank_branch_name, ba.bank_account_num, 
bau.org_id, shi.statement_date, shi.currency_code--, '****' x, qsl.*
,shi.control_line_count, ba.attribute1 bank_code
from CE_STATEMENT_HEADERS_INT shi,
CE_BANK_ACCT_USES_ALL BAU,
CE_BANK_BRANCHES_V BB,
CE_BANK_ACCOUNTS BA
where 1 = 1
and ba.bank_account_id = nvl(p_bank_account_id, ba.bank_account_id)
and shi.bank_account_num = ba.bank_account_num
and shi.statement_number = nvl(p_statement_number, shi.statement_number)
and shi.record_status_flag != 'T'
AND BB.BANK_PARTY_ID = BA.BANK_ID  --5041
AND BB.BRANCH_PARTY_ID = BA.BANK_BRANCH_ID --5045
AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID
/*
select '1' xtype, qsl.creation_date, qsl.bank_branch_id, qsl.bank_account_id, qsl.statement_number,  
qsl.bank_name, qsl.bank_branch_name, qsl.bank_account_num, 
qsl.org_id, qsl.statement_date, qsl.currency_code--, '****' x, qsl.*
,shi.control_line_count, qsl.bank_code
from qstce_statement_log qsl,
CE_STATEMENT_HEADERS_INT shi
where qsl.statement_loader_req_id is null
and (qsl.create_receipts_req_id is null
--or qsl.reconciliation_req_id is null
) 
and qsl.bank_account_id = nvl(p_bank_account_id, qsl.bank_account_id)
and qsl.statement_number = nvl(p_statement_number, qsl.statement_number)
and trunc(qsl.creation_date) = nvl(l_creation_date, trunc(qsl.creation_date))
and qsl.bank_code = nvl(p_bank_code, qsl.bank_code)
and shi.bank_account_num = qsl.bank_account_num
and shi.statement_number = qsl.statement_number
and shi.record_status_flag != 'T'
and qsl.creation_date =
    (select max(qsl2.creation_date)
     from qstce_statement_log qsl2
     where qsl2.bank_account_id = qsl.bank_account_id 
     and qsl2.statement_number = qsl.statement_number 
     and qsl2.bank_code = qsl.bank_code 
     )
*/
--end pgreen 07/09/13
union
select '2' xtype, qsl.creation_date, qsl.bank_branch_id, qsl.bank_account_id, qsl.statement_number,  
qsl.bank_name, qsl.bank_branch_name, qsl.bank_account_num, 
qsl.org_id, qsl.statement_date, qsl.currency_code --,'****' x, qsl.*
,nvl(qsl.line_cnt,1) control_line_count, qsl.bank_code
from qstce_statement_log qsl
where qsl.statement_loader_req_id is null
and qsl.create_receipts_req_id is not null
and (qsl.reconciliation_req_id is null
or nvl(qsl.unreconciled_line_cnt,1) != 0)
and qsl.bank_account_id = nvl(p_bank_account_id, qsl.bank_account_id)
and qsl.statement_number = nvl(p_statement_number, qsl.statement_number)
and trunc(qsl.creation_date) = nvl(l_creation_date, trunc(qsl.creation_date))
and qsl.bank_code = nvl(p_bank_code, qsl.bank_code)
and qsl.creation_date =
    (select max(qsl2.creation_date)
     from qstce_statement_log qsl2
     where qsl2.statement_loader_req_id is null
     and qsl2.create_receipts_req_id is not null
     and (qsl2.reconciliation_req_id is null
     or nvl(qsl2.unreconciled_line_cnt,1) != 0)
     and qsl2.bank_account_id = qsl.bank_account_id 
     and qsl2.statement_number = qsl.statement_number 
     and qsl2.bank_code = qsl.bank_code) 
order by 1, 2,3,4,5;


begin
 fnd_global.apps_initialize('1433','52653','260'); -- user_id, responsibility_id, application_id
 mo_global.init('CE'); -- application_short_name

  select to_char(sysdate,'YYYY/MM/DD') ||' 00:00:00' DTE 
  INTO l_gl_date
  from dual;


for stmt_log_rec in stmt_log_cur loop
      l_bank_branch_id := stmt_log_rec.bank_branch_id;     --    NUMBER;
      l_bank_account_id := stmt_log_rec.bank_account_id; --           NUMBER;
      l_statement_number_from   := stmt_log_rec.statement_number; --   VARCHAR2(100);
      l_statement_number_to    := stmt_log_rec.statement_number; --    VARCHAR2(100);
      l_bank_name  := stmt_log_rec.bank_name;
--      l_bank_branch_name  := stmt_log_rec.bank_branch_name;
      l_bank_account_num  := stmt_log_rec.bank_account_num;
      l_bank_org_id  := stmt_log_rec.org_id;
      l_statement_date := stmt_log_rec.statement_date;
      l_currency_code := stmt_log_rec.currency_code;
      l_bank_account_num := stmt_log_rec.bank_account_num;
      l_type := stmt_log_rec.xtype;
      l_record_status_flag := 'S';
      l_control_line_count := stmt_log_rec.control_line_count;
      l_check_log := 0;
      
/* --pgreen 08/05/13
--begin pgreen 07/09/13    
      select to_char(l_statement_date,'YYYY/MM/DD') ||' 00:00:00' DTE 
      INTO l_gl_date
      from dual;

--     l_gl_date := l_statement_date; --pgreen 07/09/13
--end pgreen 07/09/13      
*/--pgreen 08/05/13
      

    If l_type = 1 then 

--BEGIN pgreen 07/09/13
--check if log record exists.  If not create it
        select count(*)
        into l_check_log
        from qstce_statement_log qsl
        where bank_account_id = l_bank_account_id
        and statement_number = l_statement_number_from;
    
        if l_check_log = 0 then --log doesn't exist so create it
            insert into qstce_statement_log qsl (
            statement_log_id,
            file_name,
            directory_path,
            bank_name,
            bank_branch_id,
            bank_branch_name,
            BANK_ACCOUNT_NUM,    
            BANK_ACCOUNT_ID,    
            STATEMENT_NUMBER,    
            STATEMENT_DATE,    
            BANK_CODE,    
            CURRENCY_CODE,    
            ORG_ID,
            SUBMIT_REQ_ID,
            CREATE_STMT_LINES_REQ_ID,    
            IMPORT_RECONCILE_REQ_ID,
            IMPORT_RECONCILE_MESSAGE,
            CREATION_DATE,    
            END_PROCESS_DATE
            ) 
            select 
            qstce_statement_log_id.nextval statement_log_id,  --nextval
            qsl.file_name,
            qsl.directory_path,
            bb.bank_name,
            ba.bank_branch_id,
            bb.bank_branch_name,
            ba.BANK_ACCOUNT_NUM,    
            ba.BANK_ACCOUNT_ID,    
            shi.STATEMENT_NUMBER,    
            shi.STATEMENT_DATE,    
            qsl.BANK_CODE,    
            shi.CURRENCY_CODE,    
            bau.ORG_ID,
            qsl.SUBMIT_REQ_ID,
            null CREATE_STMT_LINES_REQ_ID,    
            null IMPORT_RECONCILE_REQ_ID,
            null IMPORT_RECONCILE_MESSAGE,
            sysdate CREATION_DATE,    
            sysdate END_PROCESS_DATE
            from qstce_statement_log qsl,
            CE_STATEMENT_HEADERS_INT shi,
            CE_BANK_ACCT_USES_ALL BAU,
            CE_BANK_BRANCHES_V BB,
            CE_BANK_ACCOUNTS BA 
            where 1=1
            and qsl.bank_name is null
            --and qsl.statement_log_id in (4521,4524)
            and ba.bank_account_id = l_bank_account_id
            and shi.bank_account_num = ba.bank_account_num
            and shi.statement_number = l_statement_number_from
            and shi.record_status_flag != 'T'
            AND BB.BANK_PARTY_ID = BA.BANK_ID  --5041
            AND BB.BRANCH_PARTY_ID = BA.BANK_BRANCH_ID --5045
            AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID
            and qsl.file_name = 
                (select max(qsl2.file_name)
                 from qstce_statement_log qsl2
                 where qsl2.statement_number = shi.statement_number)
            and not exists
                (select 'x'
                 from qstce_statement_log qsl2
                 where qsl2.bank_account_id = ba.bank_account_id
                 and qsl2.statement_number = shi.statement_number);
            commit;
          
        end if; --if l_check_log = 0 then

--end pgreen 07/09/13

      submit_import_autorec(l_errbuf, --              OUT NOCOPY    VARCHAR2,
                                   l_retcode , --             OUT NOCOPY    NUMBER,
--                                   l_option in varchar2, 
                                   l_bank_branch_id, -- in number, 
                                   l_bank_account_id, -- in number, 
                                   l_bank_account_num, -- in varchar2,
                                   l_statement_number_from, -- in varchar2, 
                                   l_statement_number_to, -- in varchar2, 
                                   l_statement_date, -- in varchar2, 
                                   l_statement_date, -- in varchar2, 
                                   l_gl_date, -- in varchar2, 
                                   l_org_id, -- in varchar2 ,
                                   l_control_line_count,
/*
                                   l_legal_entity_id, -- in varchar2, 
                                   l_receivables_trx_id, -- in number, 
                                   l_payment_method_id, -- in number, 
                                   l_nsf_handling, -- in varchar2, 
                                   l_display_debug, -- in varchar2,
                                   l_debug_path, -- in varchar2,
                                   l_debug_file,
*/                                  
                                   l_record_status_flag); -- in varchar2); 
    end if; --If l_type = 1 then 


    if l_record_status_flag != 'E' AND l_control_line_count != 0 then
        --MAY NEED LOCIG FOR INVALID TRAN CODES.

--Submit CUSTOM 'Quest CE Create Receipts and Misc Receipts'
       submit_create_receipts_autorec(l_errbuf, --              OUT NOCOPY    VARCHAR2,
                                   l_retcode , --             OUT NOCOPY    NUMBER,
--                                   l_option in varchar2, 
                                   l_bank_branch_id, -- in number, 
                                   l_bank_account_id, -- in number, 
                                   l_bank_account_num, -- in varchar2,
                                   l_statement_number_from, -- in varchar2, 
                                   l_statement_number_to, -- in varchar2, 
                                   l_statement_date, -- in varchar2, 
                                   l_statement_date, -- in varchar2, 
                                   l_gl_date, -- in varchar2, 
                                   l_org_id--, -- in varchar2 ,
/*
                                   l_legal_entity_id, -- in varchar2, 
                                   l_receivables_trx_id, -- in number, 
                                   l_payment_method_id, -- in number, 
                                   l_nsf_handling, -- in varchar2, 
                                   l_display_debug, -- in varchar2,
                                   l_debug_path, -- in varchar2,
                                   l_debug_file
*/
                                   ); -- in varchar2); 

    end if; --if l_record_status_flag != 'E' AND l_control_line_count != 0 
    
    update qstce_statement_log
    set end_process_date = sysdate
    where bank_account_id = l_bank_account_id
    and statement_number = l_statement_number_from;
    commit;


end loop; --for stmt_log_rec in stmt_log_cur loop


end restart_import_autorec;

 PROCEDURE restart_create_receipts(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_account_id in number, 
                                   p_statement_number in varchar2,
                                   p_creation_date in varchar2) is

/*
select qsl.* 
from qstce_statement_log qsl
where qsl.statement_loader_req_id is null
and ( qsl.reconciliation_req_id is null
) 
and qsl.bank_account_id = nvl(:px_bank_account_id, qsl.bank_account_id)
and qsl.statement_number = nvl(:px_statement_number, qsl.statement_number)
order by creation_date 
*/

begin
 fnd_global.apps_initialize('1433','52653','260'); -- user_id, responsibility_id, application_id
 mo_global.init('CE'); -- application_short_name

/*
  select to_char(sysdate,'YYYY/MM/DD') ||' 00:00:00' DTE 
  INTO l_gl_date
  from dual;

cur loop
      l_bank_branch_id := stmt_head_rec.bank_branch_id;     --    NUMBER;
      l_bank_account_id := stmt_head_rec.bank_account_id; --           NUMBER;
      l_statement_number_from   := stmt_head_rec.statement_number; --   VARCHAR2(100);
      l_statement_number_to    := stmt_head_rec.statement_number; --    VARCHAR2(100);
      l_bank_name  := stmt_head_rec.bank_name;
      l_bank_branch_name  := stmt_head_rec.bank_branch_name;
      l_bank_account_num  := stmt_head_rec.bank_account_num;
      l_bank_org_id  := stmt_head_rec.org_id;
      l_statement_date := stmt_head_rec.statement_date;
      l_currency_code := stmt_head_rec.currency_code;
      l_bank_account_num := stmt_head_rec.bank_account_num;


       submit_create_receipts_autorec(l_errbuf, --              OUT NOCOPY    VARCHAR2,
                                   l_retcode , --             OUT NOCOPY    NUMBER,
--                                   l_option in varchar2, 
                                   l_bank_branch_id, -- in number, 
                                   l_bank_account_id, -- in number, 
                                   l_bank_account_num in varchar2,
                                   l_statement_number_from, -- in varchar2, 
                                   l_statement_number_to, -- in varchar2, 
                                   l_statement_date_from, -- in varchar2, 
                                   l_statement_date_to, -- in varchar2, 
                                   l_gl_date, -- in varchar2, 
                                   l_org_id, -- in varchar2 ,
                                   l_legal_entity_id, -- in varchar2, 
                                   l_receivables_trx_id, -- in number, 
                                   l_payment_method_id, -- in number, 
                                   l_nsf_handling, -- in varchar2, 
                                   l_display_debug, -- in varchar2,
                                   l_debug_path, -- in varchar2,
                                   l_debug_file); -- in varchar2); 

end loop
*/


end restart_create_receipts;

--------------------------------------------------------
--begin pgreen 03/27/13
  PROCEDURE submit_month_end_receipts(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_code in varchar2,
                                   p_input_file in varchar2,
                                   p_directory_path in varchar2) is

  l_request_id NUMBER := 0 ; 


  mode_boolean BOOLEAN; 
 
  L_ERRBUF VARCHAR2(32767);
  L_RETCODE NUMBER;
  l_option                     VARCHAR2(100);
  l_bank_branch_id          NUMBER;
  l_bank_account_id            NUMBER;
  l_statement_number_from      VARCHAR2(100);
  l_statement_number_to        VARCHAR2(100);
  l_statement_date_from        VARCHAR2(100);
  l_statement_date_to          VARCHAR2(100);
  l_gl_date                    VARCHAR2(100);
  l_org_id             VARCHAR2(100);
  l_legal_entity_id         VARCHAR2(100);
  l_receivables_trx_id         NUMBER;
  l_payment_method_id         NUMBER;
  l_nsf_handling               VARCHAR2(100);
  l_display_debug             VARCHAR2(100);
  l_debug_path             VARCHAR2(100);
  l_debug_file             VARCHAR2(100);
  l_intra_day_flag         VARCHAR2(100);

l_process_option      VARCHAR2(100);
l_loading_id        NUMBER;
l_input_file        VARCHAR2(1000);
l_directory_path      VARCHAR2(1000);

l_phase_code varchar2(30);
l_status_code  varchar2(30);
l_loop_count number := 0;
l_loop_flag boolean := true;
l_creation_date date := trunc(sysdate);
l_bank_branch_name varchar2(360);
l_bank_name varchar2(360); 
l_bank_org_id number;
l_bank_account_num varchar2(30);
l_statement_date date;
l_currency_code varchar2(15);
l_record_status_flag varchar2(1);
l_line_cnt number;
l_unreconciled_line_cnt number;
l_message_name varchar2(30);
l_control_line_count number;

l_submit_req_id number; 

l_error_cnt number;

l_message_text varchar2(2000);

l_clear_trx_text varchar2(1);  --pgreen 03/06/13

--Retrieve all Interface headers created today and weren't already Transfered yet.
cursor stmt_head_cur is
select shi.control_cr_line_count, trunc(shi.statement_date) statement_date , shi.currency_code, shi.control_line_count,
bau.org_id, bau.BANK_ACCT_USE_ID, ba.bank_branch_id, 
ba.bank_account_id, shi.statement_number,
ba.bank_account_num, bb.bank_branch_name, bb.bank_name, ba.attribute1 loading_id
,nvl(ba.attribute2,'N') clear_trx_text  --pgreen 03/06/13
from CE_STATEMENT_HEADERS_INT shi,
CE_BANK_ACCOUNTS BA,
CE_BANK_ACCT_USES_ALL BAU,
CE_BANK_BRANCHES_V BB
where 1=1 
--and shi.bank_account_num = '4681939101' --'939329637'  --********  temporary **********
and ba.bank_account_num = shi.bank_account_num
AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID
and BB.BANK_PARTY_ID = BA.BANK_ID
AND BB.BRANCH_PARTY_ID = BA.BANK_BRANCH_ID
and trunc(shi.creation_date) = l_creation_date
and shi.record_status_flag != 'T'
and ba.attribute1 = p_bank_code
order by shi.statement_date;

cursor stmt_load_errors_cur is
select statement_number, bank_account_num, message_text
FROM CE_SQLLDR_ERRORS SE
where trunc(se.creation_date) = l_creation_date
and status = 'E';

BEGIN

--------------------------------------------------------
-- R12 US Org Setup

--  fnd_global.apps_initialize('1152','52653','260'); -- user_id, responsibility_id, application_id
--  mo_global.init('CE'); -- application_short_name
--  mo_global.set_policy_context('S',84); -- (s)ingle org, org_id  

/* 
    mode_boolean := Fnd_Request.set_mode(TRUE); 


    IF (NOT mode_boolean) THEN 
      RAISE_APPLICATION_ERROR(-20995,Fnd_Message.get); 
    END IF; -- not mode_boolean
*/

/*
--obtain request_id so can query when finished
begin
    select max(r.request_id) max_request_id
    into l_submit_req_id
    FROM   fnd_responsibility_tl rt,
           fnd_user u,
           fnd_concurrent_requests r,
           fnd_concurrent_programs_tl pt
    WHERE  u.user_id = r.requested_by
    AND       rt.responsibility_id = r.responsibility_id
    AND       rt.application_id = r.responsibility_application_id
    AND       rt.LANGUAGE = 'US'
    AND       r.concurrent_program_id = pt.concurrent_program_id
    AND       r.program_application_id = pt.APPLICATION_ID 
    AND       pt.LANGUAGE = rt.LANGUAGE
    and       pt.user_concurrent_program_name = 'Quest CE Submit Bank Reconciliation Files' --???????????????????? change to month and name
    AND       NVL(r.actual_completion_date,SYSDATE) > SYSDATE-90
    and       r.argument_text like '%'||p_bank_code||'%';
exception
  when others then
    l_submit_req_id := null;
end;
*/
/*
--create log header record with file info ************
insert into qstce_statement_log (file_name, directory_path, creation_date, submit_req_id, bank_code, statement_log_id) values
                                (p_input_file, p_directory_path, sysdate, l_submit_req_id, p_bank_code, qstce_statement_log_id.nextval);
  commit;                           
*/                                

null;
  fnd_global.apps_initialize('1433','52653','260'); -- user_id, responsibility_id, application_id
  mo_global.init('CE'); -- application_short_name
null;


  select to_char(sysdate,'YYYY/MM/DD') ||' 00:00:00' DTE 
  INTO l_gl_date
  from dual;


  l_statement_date_from  := null;  --   VARCHAR2(100);
  l_statement_date_to   := null;  --        VARCHAR2(100);
  l_org_id  := null;  --           VARCHAR2(100);
  l_legal_entity_id   := null;  --       VARCHAR2(100);
  l_receivables_trx_id  := null;  --        NUMBER;
  l_payment_method_id  := null;  --        NUMBER;
  l_nsf_handling := NULL; --              VARCHAR2(100);
  l_display_debug   := 'N'; --          VARCHAR2(100);
  l_debug_path    := null;  --         VARCHAR2(100);
  l_debug_file    := null;  --         VARCHAR2(100);
  l_intra_day_flag := null;  --        VARCHAR2(100);
  l_bank_account_id := null; 


--p_input_file


--Submit 'Bank Statement Loader'--------------------------------------------------------------------------------------
   select  v.attribute1 
   into l_loading_id 
   from  FND_FLEX_VALUE_SETS VS,
    fnd_flex_values_vl  v
   where  VS.FLEX_VALUE_SET_NAME = 'QSTCE_BAI2_MAPPING'
    AND V.FLEX_VALUE_SET_ID = VS.FLEX_VALUE_SET_ID
    and v.flex_value = p_bank_code;



      l_process_option  := 'LOAD'; --    IN    VARCHAR2,
--      l_loading_id    := 2020; -- 1020; --    IN    NUMBER,      Mapping Name
      l_input_file    := p_input_file; --'QUESTSOFT.IRIS.PBAIUS.20120425050311.txt'; --    IN    VARCHAR2,
      l_directory_path  := p_directory_path; --'/apps/R12DEV/jpmc/BAI/'; --    IN    VARCHAR2,

      l_request_id := Fnd_Request.submit_request('CE','CESQLLDR',
                        NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_process_option, l_loading_id, l_input_file, l_directory_path, l_bank_branch_id, l_bank_account_id, l_gl_date, l_org_id , l_receivables_trx_id, l_payment_method_id, l_nsf_handling, l_display_debug,l_debug_path ,l_debug_file); --PGREEN 09/26/11

        IF (l_request_id = 0) THEN 
          RAISE_APPLICATION_ERROR(-20996,Fnd_Message.get); 
        else
            l_submit_req_id := l_request_id;
            insert into qstce_statement_log (file_name, directory_path, creation_date, submit_req_id, statement_loader_req_id, bank_code, 
                                            statement_log_id) 
                                            values
                                            (p_input_file, p_directory_path, sysdate, l_submit_req_id, l_request_id, p_bank_code, 
                                            qstce_statement_log_id.nextval);

      /*      update qstce_statement_log
            set statement_loader_req_id = l_request_id
            where file_name = p_input_file
            and directory_path = p_directory_path;*/
            commit;
        END IF; -- l_request_id = 0


    l_loop_count := 0;
    l_loop_flag := true;

    while l_loop_flag loop
            l_loop_count := l_loop_count + 1;
            begin

            select r.phase_code,   r.status_code
            into l_phase_code,   l_status_code
            from fnd_concurrent_requests r
            where r.request_id = l_request_id;
            exception
              when others then
                    null;
            end;
            
            
            if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                 l_loop_flag := false;
            ELSE
                dbms_lock.sleep( 60 );  --seconds        
            end if;  

    end loop;

    l_loop_count := 0;
    l_loop_flag := true;

    while l_loop_flag loop
            l_loop_count := l_loop_count + 1;
            begin

            select r.phase_code,   r.status_code
            into l_phase_code,   l_status_code
            FROM   fnd_responsibility_tl rt,
                   fnd_user u,
                   fnd_concurrent_requests r,
                   fnd_concurrent_programs_tl pt
            WHERE  u.user_id = r.requested_by
            AND       rt.responsibility_id = r.responsibility_id
            AND       rt.application_id = r.responsibility_application_id
            AND       rt.LANGUAGE = 'US'
            AND       r.concurrent_program_id = pt.concurrent_program_id
            AND       r.program_application_id = pt.APPLICATION_ID 
            AND       pt.LANGUAGE = rt.LANGUAGE
            and       pt.user_concurrent_program_name = 'Load Bank Statement Data' 
            AND       NVL(r.actual_completion_date,SYSDATE) > SYSDATE-1
            and       r.argument_text like '%'||l_input_file||'%'
            and       r.request_id = --3860129
                (select max(r.request_id) max_request_id
                FROM   fnd_responsibility_tl rt,
                       fnd_user u,
                       fnd_concurrent_requests r,
                       fnd_concurrent_programs_tl pt
                WHERE  u.user_id = r.requested_by
                AND       rt.responsibility_id = r.responsibility_id
                AND       rt.application_id = r.responsibility_application_id
                AND       rt.LANGUAGE = 'US'
                AND       r.concurrent_program_id = pt.concurrent_program_id
                AND       r.program_application_id = pt.APPLICATION_ID 
                AND       pt.LANGUAGE = rt.LANGUAGE
                and       pt.user_concurrent_program_name = 'Load Bank Statement Data' 
                AND       NVL(r.actual_completion_date,SYSDATE) > SYSDATE-1
                and       r.argument_text like '%'||l_input_file||'%'
                and       r.request_id > l_request_id);


            exception
              when others then
                    null;
            end;
            
            
            if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                 l_loop_flag := false;
            ELSE
                dbms_lock.sleep( 60 );  --seconds        
            end if;  

    end loop;


-- ERROR CHECKING DURING SQL LOAD -- SEND AND EMAIL  --------------temporary remove **************************** 03/27/13
/*
for stmt_load_errors_rec in stmt_load_errors_cur loop
    l_statement_number_from := stmt_load_errors_rec.statement_number;
    l_bank_account_num := stmt_load_errors_rec.bank_account_num;
    l_message_text := stmt_load_errors_rec.message_text;

    insert into qstce_statement_log (file_name, directory_path, creation_date, submit_req_id, bank_code, 
    bank_account_num,  statement_number, statement_loader_message, statement_log_id) 
    values
    (p_input_file, p_directory_path, sysdate, l_submit_req_id, p_bank_code,
    l_bank_account_num, l_statement_number_from, l_message_text, qstce_statement_log_id.nextval);
    
    commit;

 
end loop; --for stmt_load_errors_rec in stmt_load_errors_cur loop
*/

-----------------------------------------------------------------------------
--Retrieve all Interface headers created today and weren't already Transfered yet.
 for stmt_head_rec in stmt_head_cur loop
--      l_option      := 'ZALL'; --               VARCHAR2(100);
      l_bank_branch_id := stmt_head_rec.bank_branch_id;     --    NUMBER;
      l_bank_account_id := stmt_head_rec.bank_account_id; --           NUMBER;
      l_statement_number_from   := stmt_head_rec.statement_number; --   VARCHAR2(100);
      l_statement_number_to    := stmt_head_rec.statement_number; --    VARCHAR2(100);
      l_bank_name  := stmt_head_rec.bank_name;
      l_bank_branch_name  := stmt_head_rec.bank_branch_name;
      l_bank_account_num  := stmt_head_rec.bank_account_num;
      l_bank_org_id  := stmt_head_rec.org_id;
      l_statement_date := stmt_head_rec.statement_date;
      l_currency_code := stmt_head_rec.currency_code;
      l_control_line_count := stmt_head_rec.control_line_count;
      l_clear_trx_text := stmt_head_rec.clear_trx_text; --pgreen 03/06/13

 
     l_message_name := null;

     if l_control_line_count != 0 then
 --begin pgreen 03/06/13
        if l_clear_trx_text = 'Y' then
            update CE_STATEMENT_LINES_INTERFACE
            set trx_text = null
            where bank_account_num = l_bank_account_num
            and statement_number = l_statement_number_from
            and trx_text is not null;
            commit;
            
        end if; --if l_clear_trx_text = 'Y' then  --pgreen 06/25/14 moved so header would still be deleted if no lines
--end pgreen 03/06/13
    
     
--Execute create Receipts
      qstce_bank_reconciliation.create_month_end_receipts(  l_bank_account_id, l_statement_number_from);
 
     end if; -- l_control_line_count != 0 then

 --Delete interface records so they can be re-loaded with standard process

        delete from CE_STATEMENT_LINES_INTERFACE sl
        where sl.statement_number = l_statement_number_from
        and sl.bank_account_num = l_bank_account_num;

        delete from CE_STATEMENT_HEADERS_INT sh
        where sh.statement_number = l_statement_number_from
        and sh.bank_account_num = l_bank_account_num;
       
        commit;

    
     
     
/*     
--Submit CUSTOM 'Quest CE Create Statement Lines'------------------------------------------------------------
       l_request_id := Fnd_Request.submit_request('CE','QSTCE_CREATE_STMT_LINES',
                        NULL, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'),FALSE, l_bank_account_id, l_statement_number_from); --PGREEN 09/26/11

        IF (l_request_id = 0) THEN 
          RAISE_APPLICATION_ERROR(-20996,Fnd_Message.get); 
        else
        --insert detail log record************

            insert into  qstce_statement_log 
            (bank_name, bank_branch_name, bank_account_num, org_id, file_name, directory_path, bank_account_id, statement_number, 
            create_stmt_lines_req_id, creation_date, statement_date, currency_code, bank_branch_id, submit_req_id, bank_code,
            statement_log_id)
            values 
            (l_bank_name,l_bank_branch_name, l_bank_account_num, l_bank_org_id, p_input_file, p_directory_path,l_bank_account_id,  
            l_statement_number_from, l_request_id, sysdate,l_statement_date, l_currency_code, l_bank_branch_id, l_submit_req_id, p_bank_code,
            qstce_statement_log_id.nextval );
    
            commit;
        END IF; -- l_request_id = 0

    l_loop_count := 0;
    l_loop_flag := true;

        while l_loop_flag loop
                l_loop_count := l_loop_count + 1;
                begin

                select r.phase_code,   r.status_code
                into l_phase_code,   l_status_code
                from fnd_concurrent_requests r
                where r.request_id = l_request_id;
                exception
                  when others then
                        null;
                end;
                    
                if l_loop_count > 30 or ( l_phase_code = 'C' and   l_status_code = 'C') then
                     l_loop_flag := false;
                ELSE
                    dbms_lock.sleep( 60 );  --seconds        
                end if;  
                             

        end loop;

     end if; --if l_control_line_count != 0 then

*/
-----------------------------------------------------------------------------
/*
 --******Restart point     
 --Submit 'Bank Statement Import and AutoReconciliation'
       submit_import_autorec(l_errbuf, --              OUT NOCOPY    VARCHAR2,
                                   l_retcode , --             OUT NOCOPY    NUMBER,
--                                   l_option in varchar2, 
                                   l_bank_branch_id, -- in number, 
                                   l_bank_account_id, -- in number, 
                                   l_bank_account_num, -- in varchar2,
                                   l_statement_number_from, -- in varchar2, 
                                   l_statement_number_to, -- in varchar2, 
                                   l_statement_date_from, -- in varchar2, 
                                   l_statement_date_to, -- in varchar2, 
                                   l_gl_date, -- in varchar2, 
                                   l_org_id, -- in varchar2 ,
                                   l_control_line_count,
                                   l_record_status_flag); -- in varchar2); 

    if l_record_status_flag != 'E' and l_control_line_count != 0 then
        --MAY NEED LOCIG FOR INVALID TRAN CODES.
        null;
*/
-----------------------------------------------------------------------------

--Restart point ---------------------------
/*
--Submit CUSTOM 'Quest CE Create Receipts and Misc Receipts'
       submit_create_receipts_autorec(l_errbuf, --              OUT NOCOPY    VARCHAR2,
                                   l_retcode , --             OUT NOCOPY    NUMBER,
--                                   l_option in varchar2, 
                                   l_bank_branch_id, -- in number, 
                                   l_bank_account_id, -- in number, 
                                   l_bank_account_num, -- in varchar2,
                                   l_statement_number_from, -- in varchar2, 
                                   l_statement_number_to, -- in varchar2, 
                                   l_statement_date_from, -- in varchar2, 
                                   l_statement_date_to, -- in varchar2, 
                                   l_gl_date, -- in varchar2, 
                                   l_org_id--, -- in varchar2 ,
                                   ); -- in varchar2); 

    end if; --if l_record_status_flag != 'E' and l_control_line_count != 0 then
    
    update qstce_statement_log
    set end_process_date = sysdate
    where bank_account_id = l_bank_account_id
    and statement_number = l_statement_number_from;
    commit;
*/
 
  end loop; --for stmt_head_rec in stmt_head_cur loop


END submit_month_end_receipts;




PROCEDURE submit_month_end_receipt_files(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_code in varchar2) is

l_errbuf varchar2(1000);
l_retcode number;
l_directory_name varchar2(100);
l_file_name varchar2(100);

cursor files_cur is
SELECT qb.directory_name, qb.file_name 
FROM qstce_bai2_files qb
where qb.processed_date is null
and qb.bank_code = nvl(p_bank_code, qb.bank_code)
and qb.file_name like 'BAI_ME_%'
and qb.creation_date =
        (select max(qb.creation_date)
        FROM qstce_bai2_files qb
        where qb.processed_date is null
        and qb.bank_code = nvl(p_bank_code, qb.bank_code)
        and qb.file_name like 'BAI_ME_%')
order by qb.bank_code, creation_date;

begin
null;
  fnd_global.apps_initialize('1433','52653','260'); -- user_id, responsibility_id, application_id
  mo_global.init('CE'); -- application_short_name
null;
--  mo_global.set_policy_context('S',84); -- (s)ingle org, org_id  

/*
--obtain request_id so can query when finished
select max(r.request_id) max_request_id
into l_submit_req_id
FROM   fnd_responsibility_tl rt,
       fnd_user u,
       fnd_concurrent_requests r,
       fnd_concurrent_programs_tl pt
WHERE  u.user_id = r.requested_by
AND       rt.responsibility_id = r.responsibility_id
AND       rt.application_id = r.responsibility_application_id
AND       rt.LANGUAGE = 'US'
AND       r.concurrent_program_id = pt.concurrent_program_id
AND       r.program_application_id = pt.APPLICATION_ID 
AND       pt.LANGUAGE = rt.LANGUAGE
and       pt.user_concurrent_program_name = 'Quest CE Submit Bank Reconciliation Files' 
AND       NVL(r.actual_completion_date,SYSDATE) > SYSDATE-90
and       r.argument_text like '%'||p_bank_code||'%';
*/
null;

    for files_rec in files_cur loop
        NULL;

        l_directory_name := files_rec.directory_name;
        l_file_name := files_rec.file_name;
        
        
       update qstce_bai2_files qb
        set processed_date = sysdate
        where qb.processed_date is null
        and qb.bank_code = nvl(p_bank_code, qb.bank_code)
        and qb.directory_name = l_directory_name 
        and qb.file_name = l_file_name;
      
       
        commit;

        
       -- submit_reconciliation(l_errbuf, l_retcode, p_bank_code, l_file_name, l_directory_name); 
        submit_month_end_receipts(l_errbuf, l_retcode, p_bank_code, l_file_name, l_directory_name); 
        
         
    end loop; --for files_rec in files_cur loop


end submit_month_end_receipt_files; 


------------------------------------------------------------------

--end pgreen 03/27/13
--------------------------------------------------------
--begin pgreen 05/16/13
procedure submit_restart_autorec_current(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_code in varchar2) is

  L_ERRBUF VARCHAR2(32767);
  L_RETCODE NUMBER;
  
  l_creation_date varchar2(19) := to_char(sysdate,'YYYY/MM/DD HH24:MI:SS') ; -- FND_DATE_STANDARD    2013/05/14 00:00:00

begin
        restart_import_autorec(l_errbuf, l_retcode, null, null, l_creation_date, p_bank_code); 

end submit_restart_autorec_current;
--end pgreen 05/16/13

--begin pgreen 06/11/13
PROCEDURE create_statement_lines_cc(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_account_id in number, 
                                   p_statement_number in varchar2) is

l_sqlcode                        NUMBER;
l_sqlerrm                        VARCHAR2 (2000);

--CE_STATEMENT_HEADERS_INT =
-- CE_STATEMENT_HEADERS
--CE_STATEMENT_LINES_INTERFACE =
-- CE_STATEMENT_LINES

v_control_cr_line_count  CE_STATEMENT_HEADERS.control_cr_line_count%type := 0;
v_tot_sli_cnt number := 0;
v_tot_sli_amount number := 0;
v_insert_sli_cnt number := 0;
v_tot_r_cnt number := 0;
v_tot_r_amount number := 0;
v_r_cnt number := 0;
v_line_seq number := 0;
v_max_sli_line number := 0;

v_error_flag number := 0;

l_bank_account_num  CE_STATEMENT_HEADERS_INT.bank_account_num%type; --????
--p_statement_number  CE_STATEMENT_HEADERS_INT.statement_number%type := '120417';

v_statement_date CE_STATEMENT_HEADERS.statement_date%type;
v_org_id number;
v_BANK_ACCT_USE_ID CE_BANK_ACCT_USES_ALL.BANK_ACCT_USE_ID%type;

v_header_currency_code     CE_STATEMENT_HEADERS.currency_code%type;     

v_bank_account_num  CE_STATEMENT_LINES_INTERFACE.bank_account_num%type; --????
v_statement_number  CE_STATEMENT_LINES_INTERFACE.statement_number%type; --????
v_line_number       CE_STATEMENT_LINES.line_number%type;
v_trx_date          CE_STATEMENT_LINES.trx_date%type;
v_trx_code          CE_STATEMENT_LINES.trx_code%type;
v_trx_text          CE_STATEMENT_LINES.trx_text%type;
v_invoice_text      CE_STATEMENT_LINES.invoice_text%type;
v_amount            CE_STATEMENT_LINES.amount%type;
v_currency_code     CE_STATEMENT_LINES.currency_code%type;     
v_bank_trx_number   CE_STATEMENT_LINES.bank_trx_number%type;
v_customer_text     CE_STATEMENT_LINES.customer_text%type;
v_created_by        CE_STATEMENT_LINES.created_by%type;
v_creation_date     CE_STATEMENT_LINES.creation_date%type;
v_last_updated_by   CE_STATEMENT_LINES.last_updated_by%type;
v_last_update_date  CE_STATEMENT_LINES.last_update_date%type;
v_trx_type          CE_STATEMENT_LINES.trx_type%type;
v_status            CE_STATEMENT_LINES.status%type;
v_effective_date    CE_STATEMENT_LINES.effective_date%type;
v_exchange_rate_type    CE_STATEMENT_LINES.exchange_rate_type%type;
v_exchange_rate     CE_STATEMENT_LINES.exchange_rate%type;
v_exchange_rate_date    CE_STATEMENT_LINES.exchange_rate_date%type;
v_statement_header_id   CE_STATEMENT_LINES.statement_header_id%type;
v_statement_line_id     CE_STATEMENT_LINES.statement_line_id%type;

v_r_type varchar2(2);
v_cc_trx_text CE_STATEMENT_LINES.trx_text%type;

l_line_cnt number;

L_BANK_ACCT_USE_ID NUMBER;
L_ORG_ID NUMBER;

l_bank_code varchar2(20);

CURSOR CC_CUR IS
select l.attribute1 trx_code, l.attribute4 r_type, l.attribute5 cc_trx_text
from fnd_lookup_values_vl  L
where  L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
and l.attribute2 = 'CREDIT_CARD'
and nvl(l.attribute6, l_bank_code) = l_bank_code    
and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
and v_statement_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
;


CURSOR RECEIPT_CUR IS
SELECT substr(R.RECEIPT_NUMBER, 1,2) r_type, R.RECEIPT_NUMBER, R.AMOUNT --, r.*
FROM AR_CASH_RECEIPT_HISTORY_ALL rh
,ar_cash_receipts_all R
WHERE r.receipt_date = v_statement_date
and r.cash_receipt_id = rh.cash_receipt_id
AND R.STATUS != 'REV'
AND RH.STATUS != 'REVERSED'
and r.org_id = V_ORG_ID
and r.remit_bank_acct_use_id = v_BANK_ACCT_USE_ID
and R.RECEIPT_NUMBER LIKE v_r_type||'%' --= '732683793TC'
order by 1, 2 --type, r.receipt_number
;

/*--PGREEN 07/25/13  new code but didn't use
SELECT R.ROWID, substr(R.RECEIPT_NUMBER, 1,2) r_type, 
DECODE(NVL(R.ATTRIBUTE5,'X') ,'REFUND',R.RECEIPT_NUMBER||'-REFUND', R.RECEIPT_NUMBER) RECEIPT_NUMBER, --PGREEN 07/25/13
R.AMOUNT --, r.*
FROM AR_CASH_RECEIPT_HISTORY_ALL rh
,ar_cash_receipts_all R
WHERE r.receipt_date = v_statement_date
and r.cash_receipt_id = rh.cash_receipt_id
AND (R.STATUS != 'REV' OR (R.STATUS = 'REV' AND NVL(R.ATTRIBUTE5,'X') = 'REFUND')) --PGREEN 07/25/13
AND RH.STATUS != 'REVERSED'
and r.org_id = V_ORG_ID
and r.remit_bank_acct_use_id = v_BANK_ACCT_USE_ID
and R.RECEIPT_NUMBER LIKE v_r_type||'%' --= '732683793TC'
order by 1, 2 --type, r.receipt_number
;
*/--PGREEN 07/25/13


BEGIN

--obtain bank account number
    begin
        select ba.bank_account_num, bau.BANK_ACCT_USE_ID, BAU.ORG_ID, ba.attribute1
        INTO l_bank_account_num, L_BANK_ACCT_USE_ID, L_ORG_ID, l_bank_code
        from CE_BANK_ACCOUNTS BA,
        CE_BANK_ACCT_USES_ALL BAU
        where ba.bank_account_id = p_bank_account_id
        AND SYSDATE BETWEEN NVL(BA.START_DATE, SYSDATE-1) AND NVL(BA.END_DATE, SYSDATE+1)
        AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID;
    exception
        when others then
            v_error_flag := 1;
    end;


--obtain Statement header info
    if v_error_flag = 0 then
        begin
            select shi.control_cr_line_count, trunc(shi.statement_date) statement_date , bau.org_id, bau.BANK_ACCT_USE_ID,
            shi.currency_code
            into v_control_cr_line_count, v_statement_date, v_org_id, v_BANK_ACCT_USE_ID, 
            v_header_currency_code
            from CE_STATEMENT_HEADERS shi,
            CE_BANK_ACCOUNTS BA,
            CE_BANK_ACCT_USES_ALL BAU
            where shi.bank_account_id = p_bank_account_id --31001
            and shi.statement_number = p_statement_number --130314
            and ba.bank_account_id = shi.bank_account_id
            AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID;
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then


--statement line amount total for Credit Card
if v_error_flag = 0 then
  for cc_rec in cc_cur loop
    v_trx_code :=  cc_rec.trx_code;
    v_cc_trx_text := cc_rec.cc_trx_text;
    v_r_type := cc_rec.r_type;
    v_error_flag := 0;
    v_tot_sli_amount := 0;
    v_tot_sli_cnt := 0;
    v_max_sli_line := 0;
    v_tot_r_amount := 0; 
    v_tot_r_cnt := 0;
    v_r_cnt := 0;
    v_insert_sli_cnt := 0;

    if v_error_flag = 0 then
        begin
            select sum(sli.amount) amount , count(*) cnt --, sli.*  -- 525608.84   07/5/2012
            into v_tot_sli_amount, v_tot_sli_cnt
            from CE_STATEMENT_LINES sli,
            CE_STATEMENT_HEADERS shi
            where shi.bank_account_id = p_bank_account_id --31001
            and shi.statement_number = p_statement_number
            and sli.statement_header_id = shi.statement_header_id
            and sli.trx_code = v_trx_code
            and sli.trx_text like v_cc_trx_text
            and SLI.BANK_ACCOUNT_TEXT is null
           ;
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then

    if v_tot_sli_cnt = 0 then
        v_error_flag := 1;
    end if; --if v_tot_sli_cnt = 0 then
--get max line number from the statement lines
    if v_error_flag = 0  then
        begin
            select  max(line_number) line_number
            into v_max_sli_line
            from CE_STATEMENT_LINES sli,
            CE_STATEMENT_HEADERS shi
            where shi.bank_account_id = p_bank_account_id --31001
            and shi.statement_number = p_statement_number
            and sli.statement_header_id = shi.statement_header_id
            ;
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then


    if v_error_flag = 0 then
        begin
            select sum(r.amount) amount, count(*) cnt
            INTO v_tot_r_amount, v_tot_r_cnt
            FROM AR_CASH_RECEIPT_HISTORY_ALL rh
            ,ar_cash_receipts_all R
            WHERE r.receipt_date = v_statement_date
            and r.cash_receipt_id = rh.cash_receipt_id
            AND R.STATUS != 'REV'
            AND RH.STATUS != 'REVERSED'
            and r.org_id = V_ORG_ID
            and r.remit_bank_acct_use_id = v_BANK_ACCT_USE_ID
            and R.RECEIPT_NUMBER LIKE v_r_type||'%'--= '732683793TC'
            ;
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then


    if v_error_flag = 0 then
        begin
            select 
            shi.statement_header_id,
            sli.line_number,
            sli.trx_date,
            sli.trx_type, 
            sli.amount,
            sli.status,            
            sli.created_by ,
            sli.creation_date ,
            sli.last_updated_by  ,
            sli.last_update_date ,
            sli.effective_date,
            sli.bank_trx_number,
            sli.trx_text ,
            sli.customer_text ,
            sli.invoice_text ,
            sli.currency_code,
            sli.exchange_rate_type,
            sli.exchange_rate,
            sli.exchange_rate_date--, 
--            sli.trx_code 
            INTO 
            v_statement_header_id,
            v_line_number,
            v_trx_date,
            v_trx_type,
            v_amount,
            v_status,
            v_created_by ,
            v_creation_date ,
            v_last_updated_by  ,
            v_last_update_date,
            v_effective_date,
            v_bank_trx_number ,
            v_trx_text ,
            v_customer_text ,
            v_invoice_text ,           
            v_currency_code,  
            v_exchange_rate_type,
            v_exchange_rate,
            v_exchange_rate_date--, 
--            v_trx_code
            from CE_STATEMENT_LINES sli,
            CE_STATEMENT_HEADERS shi
            where shi.bank_account_id = p_bank_account_id --31001
            and shi.statement_number = p_statement_number
            and sli.statement_header_id = shi.statement_header_id
            and sli.trx_code = v_trx_code
            and sli.trx_text like v_cc_trx_text
            and SLI.BANK_ACCOUNT_TEXT is null
            AND ROWNUM < 2
            ;
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then

   if v_error_flag = 0 then
--pgreen 07/25/13      IF v_tot_sli_amount = v_tot_r_amount THEN --$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
    IF v_tot_r_amount <=  v_tot_sli_amount THEN --$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

        v_line_seq := v_max_sli_line;

        FOR RECEIPT_REC IN RECEIPT_CUR LOOP
            v_r_cnt := v_r_cnt + 1;
            IF v_r_cnt <= v_tot_sli_cnt then
            
              begin
                update CE_STATEMENT_LINES sli
                set sli.amount = receipt_rec.amount,
                    sli.bank_trx_number = receipt_rec.receipt_number,
                    SLI.BANK_ACCOUNT_TEXT = 'CREDIT CARD'
                where sli.statement_header_id = v_statement_header_id
                and sli.trx_code = v_trx_code
                and sli.trx_text like v_cc_trx_text
--PGREEN 07/02/2013                and sli.bank_trx_number = v_bank_trx_number
                and SLI.BANK_ACCOUNT_TEXT is null
                and rownum < 2;
              exception
                when others then
                   null;
              end;
               
            else
                v_line_seq := v_line_seq +  1;
                
                insert into CE_STATEMENT_LINES sli
                (
                sli.statement_header_id,
                sli.statement_line_id,
                sli.line_number,
                sli.trx_date,
                sli.trx_type, 
                sli.amount,
                sli.status,            
                sli.created_by ,
                sli.creation_date ,
                sli.last_updated_by  ,
                sli.last_update_date ,
                sli.effective_date,
                sli.bank_trx_number,
                sli.trx_text ,
                sli.customer_text ,
                sli.invoice_text ,
                sli.bank_account_text,
                sli.currency_code,
                sli.exchange_rate_type,
                sli.exchange_rate,
                sli.exchange_rate_date, 
                sli.trx_code 
                )
                VALUES
                (
                v_statement_header_id,
                CE_STATEMENT_LINES_S.NEXTVAL, --v_statement_line_id,
                v_line_seq,
                v_trx_date,
                v_trx_type,
                receipt_rec.amount, --v_amount,
                v_status,
                v_created_by ,
                v_creation_date ,
                v_last_updated_by , 
                v_last_update_date,
                v_effective_date,
                receipt_rec.receipt_number, --v_bank_trx_number ,
                v_trx_text ,
                v_customer_text ,
                v_invoice_text ,
                'CREDIT CARD', --   SLI.BANK_ACCOUNT_TEXT           
                v_currency_code,  
                v_exchange_rate_type,
                v_exchange_rate,
                v_exchange_rate_date, 
                v_trx_code
                );

                                
                v_insert_sli_cnt := v_insert_sli_cnt +1; 
                
            end if; --IF v_r_cnt < v_tot_sli_cnt then

        END LOOP;  --FOR RECEIPT_REC IN RECEIPT_CUR LOOP

        update CE_STATEMENT_HEADERS shi
        set control_cr_line_count = control_cr_line_count + v_insert_sli_cnt
        where shi.bank_account_id = p_bank_account_id
        and shi.statement_number = p_statement_number;

--begin pgreen 07/25/13
        IF v_tot_r_amount <  v_tot_sli_amount THEN 
                 v_line_seq := v_line_seq +  1;
                
                insert into CE_STATEMENT_LINES sli
                (
                sli.statement_header_id,
                sli.statement_line_id,
                sli.line_number,
                sli.trx_date,
                sli.trx_type, 
                sli.amount,
                sli.status,            
                sli.created_by ,
                sli.creation_date ,
                sli.last_updated_by  ,
                sli.last_update_date ,
                sli.effective_date,
                sli.bank_trx_number,
                sli.trx_text ,
                sli.customer_text ,
                sli.invoice_text ,
                sli.bank_account_text,
                sli.currency_code,
                sli.exchange_rate_type,
                sli.exchange_rate,
                sli.exchange_rate_date, 
                sli.trx_code 
                )
                VALUES
                (
                v_statement_header_id,
                CE_STATEMENT_LINES_S.NEXTVAL, --v_statement_line_id,
                v_line_seq,
                v_trx_date,
                v_trx_type,
                v_tot_sli_amount - v_tot_r_amount, --v_amount,
                v_status,
                v_created_by ,
                v_creation_date ,
                v_last_updated_by , 
                v_last_update_date,
                v_effective_date,
                v_r_type||p_statement_number||'-UNIDENTIFIED', --receipt_rec.receipt_number, --v_bank_trx_number ,
                v_trx_text ,
                v_customer_text ,
                v_invoice_text ,
                'CREDIT CARD', --   SLI.BANK_ACCOUNT_TEXT           
                v_currency_code,  
                v_exchange_rate_type,
                v_exchange_rate,
                v_exchange_rate_date, 
                v_trx_code
                );

                                
                v_insert_sli_cnt := v_insert_sli_cnt +1; 
        end if; --IF v_tot_r_amount < v_tot_sli_amount THEN 
--end pgreen 07/25/13


    ELSE --IF v_tot_r_amount <=  v_tot_sli_amount THEN 
    
        begin
            update qstce_statement_log
            set create_stmt_lines_message = v_r_type||'-Credit Card v_tot_sli_amount: '||v_tot_sli_amount||' v_tot_r_amount: '|| v_tot_r_amount
            where bank_account_id = p_bank_account_id
            and statement_number = p_statement_number;
              
        exception
          when others then
            insert into qstce_statement_log (bank_account_id, statement_number, create_stmt_lines_message, statement_log_id)
                values (p_bank_account_id, p_statement_number, 'v_tot_sli_amount: '||v_tot_sli_amount||' v_tot_r_amount: '|| v_tot_r_amount,
                qstce_statement_log_id.nextval);
                         
        end;

    END IF; --IF v_tot_sli_amount = v_tot_r_amount THEN

    commit;
    
    
   end if; --if v_error_flag = 0 then

  end loop; --for cc_rec in cc_cur loop
end if; --if v_error_flag = 0 then

exception
  when others then
      l_sqlcode := SQLCODE;
      l_sqlerrm := SQLERRM;
      null;
  
END create_statement_lines_cc;



procedure submit_create_stmt_line_cc_cur (errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_code in varchar2) is

  L_ERRBUF VARCHAR2(32767);
  L_RETCODE NUMBER;
  
--  l_creation_date varchar2(19) := to_char(sysdate,'YYYY/MM/DD HH24:MI:SS') ; -- FND_DATE_STANDARD    2013/05/14 00:00:00


  l_creation_date date := trunc(sysdate) ; -- FND_DATE_STANDARD    2013/05/14 00:00:00


  l_bank_account_id number; 
  l_statement_number CE_STATEMENT_LINES_INTERFACE.statement_number%type;

cursor stmt_log_cur is
select qsl.creation_date, qsl.bank_branch_id, qsl.bank_account_id, qsl.statement_number,  
qsl.bank_name, qsl.bank_branch_name, qsl.bank_account_num, 
qsl.org_id, qsl.statement_date, qsl.currency_code --,'****' x, qsl.*
,nvl(qsl.line_cnt,1) control_line_count, qsl.bank_code
from qstce_statement_log qsl
where qsl.statement_loader_req_id is null
and qsl.create_receipts_req_id is not null
and (qsl.reconciliation_req_id is null
or nvl(qsl.unreconciled_line_cnt,1) != 0)
--and qsl.bank_account_id = nvl(p_bank_account_id, qsl.bank_account_id)
--and qsl.statement_number = nvl(p_statement_number, qsl.statement_number)
and trunc(qsl.creation_date) = nvl(l_creation_date, trunc(qsl.creation_date))
and qsl.bank_code = nvl(p_bank_code, qsl.bank_code)
and qsl.creation_date =
    (select max(qsl2.creation_date)
     from qstce_statement_log qsl2
     where qsl2.statement_loader_req_id is null
     and qsl2.create_receipts_req_id is not null
     and (qsl2.reconciliation_req_id is null
     or nvl(qsl2.unreconciled_line_cnt,1) != 0)
     and qsl2.bank_account_id = qsl.bank_account_id 
     and qsl2.statement_number = qsl.statement_number 
     and qsl2.bank_code = qsl.bank_code) 
order by 1, 2,3,4;


begin
 fnd_global.apps_initialize('1433','52653','260'); -- user_id, responsibility_id, application_id
 mo_global.init('CE'); -- application_short_name

for stmt_log_rec in stmt_log_cur loop
--        restart_import_autorec(l_errbuf, l_retcode, null, null, l_creation_date, p_bank_code); 
    l_bank_account_id := stmt_log_rec.bank_account_id;
    l_statement_number := stmt_log_rec.statement_number;

    create_statement_lines_cc(l_errbuf, l_retcode, l_bank_account_id, l_statement_number);

end loop; --for stmt_log_rec in stmt_log_cur loop
end submit_create_stmt_line_cc_cur;
--end pgreen 06/11/13

----------------------------------------------
PROCEDURE create_cc_receipts(errbuf              OUT NOCOPY    VARCHAR2,
                                   retcode              OUT NOCOPY    NUMBER,
                                   p_bank_account_id in number, 
                                   p_statement_number in varchar2)IS
                                   

l_sqlcode                        NUMBER;
l_sqlerrm                        VARCHAR2 (2000);
v_error_message               VARCHAR2 (8000);

l_attribute_rec  ar_receipt_api_pub.attribute_rec_type;
l_global_attribute_rec  ar_receipt_api_pub.global_attribute_rec_type;

l_comment varchar2(2000);

v_zuora_invoice_number varchar2(50);

--CE_STATEMENT_HEADERS_INT =
-- CE_STATEMENT_HEADERS
--CE_STATEMENT_LINES_INTERFACE =
-- CE_STATEMENT_LINES

v_control_cr_line_count  CE_STATEMENT_HEADERS.control_cr_line_count%type := 0;
v_tot_sli_cnt number := 0;
v_tot_sli_amount number := 0;
v_insert_sli_cnt number := 0;
v_tot_r_cnt number := 0;
v_tot_r_amount number := 0;
v_r_cnt number := 0;
v_line_seq number := 0;
v_max_sli_line number := 0;

v_continue boolean := true;

v_error_flag number := 0;

l_bank_account_num  CE_STATEMENT_HEADERS_INT.bank_account_num%type; --????
--p_statement_number  CE_STATEMENT_HEADERS_INT.statement_number%type := '120417';

v_statement_date CE_STATEMENT_HEADERS.statement_date%type;
v_org_id number;
v_BANK_ACCT_USE_ID CE_BANK_ACCT_USES_ALL.BANK_ACCT_USE_ID%type;

v_header_currency_code     CE_STATEMENT_HEADERS.currency_code%type;     

v_bank_account_num  CE_STATEMENT_LINES_INTERFACE.bank_account_num%type; --????
v_statement_number  CE_STATEMENT_LINES_INTERFACE.statement_number%type; --????
v_line_number       CE_STATEMENT_LINES.line_number%type;
v_trx_date          CE_STATEMENT_LINES.trx_date%type;
v_trx_code          CE_STATEMENT_LINES.trx_code%type;
v_trx_text          CE_STATEMENT_LINES.trx_text%type;
v_invoice_text      CE_STATEMENT_LINES.invoice_text%type;
--v_amount            CE_STATEMENT_LINES.amount%type;
v_currency_code     CE_STATEMENT_LINES.currency_code%type;     
v_bank_trx_number   CE_STATEMENT_LINES.bank_trx_number%type;
v_customer_text     CE_STATEMENT_LINES.customer_text%type;
v_created_by        CE_STATEMENT_LINES.created_by%type;
v_creation_date     CE_STATEMENT_LINES.creation_date%type;
v_last_updated_by   CE_STATEMENT_LINES.last_updated_by%type;
v_last_update_date  CE_STATEMENT_LINES.last_update_date%type;
v_trx_type          CE_STATEMENT_LINES.trx_type%type;
v_status            CE_STATEMENT_LINES.status%type;
v_effective_date    CE_STATEMENT_LINES.effective_date%type;
v_exchange_rate_type    CE_STATEMENT_LINES.exchange_rate_type%type;
v_exchange_rate     CE_STATEMENT_LINES.exchange_rate%type;
v_exchange_rate_date    CE_STATEMENT_LINES.exchange_rate_date%type;
v_statement_header_id   CE_STATEMENT_LINES.statement_header_id%type;
v_statement_line_id     CE_STATEMENT_LINES.statement_line_id%type;

v_r_type varchar2(2);
v_cc_trx_text CE_STATEMENT_LINES.trx_text%type;

v_attribute7 fnd_lookup_values_vl.attribute7%TYPE;
v_attribute8 fnd_lookup_values_vl.attribute8%TYPE;
v_receipt_type varchar2(30);

l_line_cnt number;

L_BANK_ACCT_USE_ID NUMBER;

l_bank_code varchar2(20);

v_cybersource_amount number := 0;
v_cybersource_total_amount number := 0;
v_merchant_ref_number QSTAR_CYBERSOURCE_DETAIL.merchant_ref_number%TYPE;
l_amount QSTAR_CYBERSOURCE_DETAIL.amount%TYPE;
v_currency QSTAR_CYBERSOURCE_DETAIL.currency%TYPE;
v_transaction_type QSTAR_CYBERSOURCE_DETAIL.transaction_type%TYPE;
v_payment_type varchar2(30);

l_bank_trx_number varchar2(240);
l_invoice_number varchar2(20);  --pgreen 12/18/13
l_trx_date date;
l_remit_bank_acct_use_id number;
L_RECEIPT_METHOD_ID NUMBER;
l_cr_id number;
l_currency_code varchar2(15);
l_bill_to_site_use_id  number; --pgreen 12/18/13
l_customer_id number; --pgreen 12/18/13
l_location varchar2(40); --pgreen 12/18/13
l_apply_flag varchar2(1) := 'Y';
l_exist_cnt number := 0;

l_return_status VARCHAR2(1);
l_msg_count NUMBER;
l_msg_data VARCHAR2(240);
l_misc_receipt_id number;


l_activity_flag number;
l_activity_type  varchar2(1000);
l_bank_reference varchar2(1000);
l_activity varchar2(1000);
l_statement_number varchar2(50);

CURSOR CC_CUR IS
select l.attribute1 trx_code, l.attribute4 r_type, l.attribute5 cc_trx_text, l.attribute7, l.attribute8
from fnd_lookup_values_vl  L
where  L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
and l.attribute2 = 'CREDIT_CARD'
and nvl(l.attribute6, l_bank_code) = l_bank_code    
and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
and v_statement_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
--and l.attribute4 = 'CC'                                                     -- ************TEMPORARY
;

cursor CYBERSOURCE_CUR IS
select c.cybersource_id, 
substr(c.merchant_ref_number,1,instr(replace(c.merchant_ref_number,',',';')||';',';')-1)  merchant_ref_number,
--substr(c.merchant_ref_number,1,instr(c.merchant_ref_number||',',',')-1)  merchant_ref_number,
 c.amount, c.currency, c.transaction_type, c.payment_method--, c.*
from QSTAR_CYBERSOURCE_DETAIL c
where c.posted_date is null
and ((v_attribute7 = 'EQUAL'
and c.payment_method = v_attribute8)
OR (v_attribute7 = 'NOTEQUAL'
and c.payment_method != v_attribute8))
and C.CURRENCY = 'USD'
--and c.payment_processor != 'Global Payment Service'
order by c.cybersource_id;


begin


FND_GLOBAL.apps_initialize(1433, 51306, 222);
MO_GLOBAL.init('AR');
/*
--obtain bank account number
    begin
        select ba.bank_account_num, bau.BANK_ACCT_USE_ID, BAU.ORG_ID, ba.attribute1
        INTO l_bank_account_num, L_BANK_ACCT_USE_ID, L_ORG_ID, l_bank_code
        from CE_BANK_ACCOUNTS BA,
        CE_BANK_ACCT_USES_ALL BAU
        where ba.bank_account_id = p_bank_account_id
        AND SYSDATE BETWEEN NVL(BA.START_DATE, SYSDATE-1) AND NVL(BA.END_DATE, SYSDATE+1)
        AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID;
    exception
        when others then
            v_error_flag := 1;
    end;
*/
--obtain Statement header info

l_session_id := null;
l_zuora_password := null;  --pgreen 04/3/15

    if v_error_flag = 0 then
        begin


            select shi.control_cr_line_count, trunc(shi.statement_date) statement_date , bau.org_id, bau.BANK_ACCT_USE_ID,
            shi.currency_code
            ,ba.bank_account_num, ba.attribute1, rma.receipt_method_id, shi.statement_number
            into v_control_cr_line_count, v_statement_date, v_org_id, v_BANK_ACCT_USE_ID, 
            v_header_currency_code, l_bank_account_num, l_bank_code, L_RECEIPT_METHOD_ID, l_statement_number
            from CE_STATEMENT_HEADERS shi,
            CE_BANK_ACCOUNTS BA,
            CE_BANK_ACCT_USES_ALL BAU
            ,ar_receipt_method_accounts_all rma,
            ar_receipt_methods rm,
            ar_receipt_classes rc
            where shi.bank_account_id = p_bank_account_id --31001
            and shi.statement_number = p_statement_number --130314
            and ba.bank_account_id = shi.bank_account_id
            AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID
            AND BAU.BANK_ACCT_USE_ID = RMA.remit_bank_acct_use_id
            and rm.receipt_method_id = rma.receipt_method_id
            and rc.receipt_class_id = rm.receipt_class_id
            and trunc(shi.statement_date) between rma.start_date and nvl(rma.end_date, sysdate+1)
            and trunc(shi.statement_date) between rm.start_date and nvl(rm.end_date, sysdate+1);
            
        exception
            when others then
                v_error_flag := 1;
        end;
    end if; --if v_error_flag = 0 then

if v_error_flag = 0 then
  for cc_rec in cc_cur loop
    v_trx_code :=  cc_rec.trx_code;
    v_cc_trx_text := cc_rec.cc_trx_text;
    v_r_type := cc_rec.r_type;
    v_attribute7 := cc_rec.attribute7;
    v_attribute8 := cc_rec.attribute8;


    begin 
           select sum(sli.amount) amount , count(*) cnt --, sli.*  -- 525608.84   07/5/2012
            into v_tot_sli_amount, v_tot_sli_cnt
            from CE_STATEMENT_LINES sli,
            CE_STATEMENT_HEADERS shi
            where shi.bank_account_id = p_bank_account_id --31001
            and shi.statement_number = p_statement_number
            and sli.statement_header_id = shi.statement_header_id
            and sli.trx_code = v_trx_code
            and sli.trx_text like v_cc_trx_text           
            and SLI.BANK_ACCOUNT_TEXT is null;
    exception
        when others then
            v_tot_sli_amount := 0;
            v_tot_sli_cnt := 0;
    end;

    v_cybersource_amount :=  0;
    v_cybersource_total_amount :=  0;
    v_continue := true;
    v_num_entries := 0;
    
    FOR CYBERSOURCE_REC IN CYBERSOURCE_CUR LOOP
        --?????????11/5/2014  might need to skip if - if v_transaction_type != 'ics_credit' then
        v_cybersource_total_amount := v_cybersource_total_amount + cybersource_rec.amount;
        if v_cybersource_total_amount <= v_tot_sli_amount and v_continue then
            v_cybersource_amount := v_cybersource_amount + cybersource_rec.amount;
            v_num_entries := v_num_entries + 1;
            v_cybersource_id(v_num_entries) := cybersource_rec.cybersource_id; 
            if v_cybersource_amount = v_tot_sli_amount then
                v_continue := false;              
            end if; --   if v_cybersource_amount = v_tot_sli_amount then        
        end if; -- if v_cybersource_amount <= v_tot_sli_amount then
    
    END LOOP; --FOR CYBERSOURCE_REC IN RECEIPT_CUR LOOP

 --pgreen 10/30/14
  if nvl(v_cybersource_amount,0) = nvl(v_tot_sli_amount,-1) then --??????????????????????????????????????????

    for v_loop_index in 1..v_num_entries loop

        l_invoice_number := null;
        l_customer_id := null; 
        l_bill_to_site_use_id := null;
        v_payment_type := null;  
        v_receipt_type := null;
        l_attribute_rec := null;
        v_error_flag := 0;
       
       begin
       select substr(c.merchant_ref_number,1,instr(replace(c.merchant_ref_number,',',';')||';',';')-1),
--       substr(c.merchant_ref_number,1,instr(c.merchant_ref_number||',',',')-1) ,
              c.amount, c.currency, c.transaction_type--, c.*
            , l.attribute3, l.attribute4 activity_type,  l.attribute7 receipt_type
        into  v_merchant_ref_number, l_amount, l_currency_code, v_transaction_type
            , v_payment_type, l_activity_type, v_receipt_type
        from QSTAR_CYBERSOURCE_DETAIL c,
        fnd_lookup_values_vl  L
        where c.cybersource_id = v_cybersource_id(v_loop_index )
        and L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
        and l.attribute2 = 'CC_RECEIPT'
        and nvl(l.attribute6, l_bank_code) = l_bank_code    
        and v_statement_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
--        and substr(c.merchant_ref_number,1,instr(c.merchant_ref_number||',',',')-1)  like l.attribute5
        and substr(c.merchant_ref_number,1,instr(replace(c.merchant_ref_number,',',';')||';',';')-1) like l.attribute5
        and C.CURRENCY = 'USD'
       UNION ALL
       select substr(c.merchant_ref_number,1,instr(replace(c.merchant_ref_number,',',';')||';',';')-1),
 --      substr(c.merchant_ref_number,1,instr(c.merchant_ref_number||',',',')-1) , 
              c.amount, c.currency, c.transaction_type--, c.*
            ,'R' payment_type, 'CE_OTHER' r_type, 'CASH' receipt_type
      --  into  v_merchant_ref_number, v_amount, v_currency, v_transaction_type
        from QSTAR_CYBERSOURCE_DETAIL c
        where c.cybersource_id = v_cybersource_id(v_loop_index )     
        and C.CURRENCY = 'USD' 
        and not exists
            (   select 'x'
            from fnd_lookup_values_vl  L
            where L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
            and l.attribute2 = 'CC_RECEIPT'
            and nvl(l.attribute6, l_bank_code) = l_bank_code    
            and v_statement_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
            and substr(c.merchant_ref_number,1,instr(replace(c.merchant_ref_number,',',';')||';',';')-1)  like l.attribute5  )
 --           and substr(c.merchant_ref_number,1,instr(c.merchant_ref_number||',',',')-1)  like l.attribute5  )
        ;
       exception
          when others then
                v_error_flag := 1;
                
                update QSTAR_CYBERSOURCE_DETAIL c
                set c.status = sysdate||' error getting QSTAR_CYBERSOURCE_DETAIL record'
                where c.cybersource_id = v_cybersource_id(v_loop_index )
                and C.CURRENCY = 'USD' 
                ; 
                begin
                    update qstce_statement_log
                    set create_cc_receipts_message = v_r_type||' error getting QSTAR_CYBERSOURCE_DETAIL record cybersource_id = '||v_cybersource_id(v_loop_index )
                    where bank_account_id = p_bank_account_id
                    and statement_number = p_statement_number;
                      
                exception
                  when others then
                    insert into qstce_statement_log (bank_account_id, statement_number, create_cc_receipts_message, statement_log_id)
                        values (p_bank_account_id, p_statement_number, v_r_type||' error getting QSTAR_CYBERSOURCE_DETAIL record cybersource_id = '||v_cybersource_id(v_loop_index ),
                        qstce_statement_log_id.nextval);
                                 
                end;
--            commit;
       end;
         
/* 
        l_invoice_number := null;
        l_customer_id := null; 
        l_bill_to_site_use_id := null;
        v_payment_type := null;  
        v_receipt_type := null;
*/
      if v_error_flag = 0 then
       
        if v_transaction_type != 'ics_credit' then
                l_bank_trx_number := v_r_type||v_merchant_ref_number;
                l_trx_date := v_statement_date;
                l_remit_bank_acct_use_id := v_BANK_ACCT_USE_ID;
                l_customer_id := null;
                l_bill_to_site_use_id := null;
                l_apply_flag := 'Y';

            if l_activity_type = 'CE_ZUORA_INVOICE' then
                zuora_invoice_main(l_bank_code, l_bank_account_num, 
                p_bank_account_id, p_statement_number, 
                v_merchant_ref_number, v_zuora_invoice_number);
--                zuora_invoice_main('P-00000040', v_zuora_invoice_number);
                
                
                begin
                    select t.trx_number, t.bill_to_customer_id, t.bill_to_site_use_id
                    --,l.attribute3 payment_type ,  l.attribute7 receipt_type
                    into l_invoice_number, l_customer_id, l_bill_to_site_use_id
                        --, v_payment_type,  v_receipt_type                    
                    from ra_customer_trx_all t,
                    ra_batch_sources_all bs
                    where t.org_id = v_org_id
                    and bs.org_id = t.org_id
                    and bs.name = 'Zuora'
                    and t.batch_source_id = bs.batch_source_id
                    and t.INTERFACE_HEADER_ATTRIBUTE1 = REPLACE(v_zuora_invoice_number, 'INV','') ;             
                
                exception
                  when others then
                    l_apply_flag := 'N';
                end;
            elsif l_activity_type = 'CE_SIEBEL_QUOTE' then
                begin
/*                    select t.trx_number, t.bill_to_customer_id, t.bill_to_site_use_id
                    into l_invoice_number, l_customer_id, l_bill_to_site_use_id
                    from ra_customer_trx_all t
                    where ATTRIBUTE2 = v_merchant_ref_number; --SIEBEL QUOTE 
*/
                    select t.trx_number, t.bill_to_customer_id, t.bill_to_site_use_id
                    ,l.attribute3 payment_type,  l.attribute7 receipt_type
                    into l_invoice_number, l_customer_id, l_bill_to_site_use_id
                        , v_payment_type,  v_receipt_type
                    from ra_customer_trx_all t
                        ,fnd_lookup_values_vl  L
                    where t.ATTRIBUTE2 = v_merchant_ref_number --SIEBEL QUOTE 
                    and t.org_id = v_org_id
                    and L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
                    and l.attribute2 = 'CC_RECEIPT'
                    and nvl(l.attribute6, l_bank_code) = l_bank_code    
                    and nvl(l.attribute9, l_bank_account_num) = l_bank_account_num    
                    and v_statement_date BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)
                    and t.trx_number like l.attribute5;
                    
                exception
                    when others then
                        l_apply_flag := 'N';
                        v_payment_type := 'R';
                        v_receipt_type := 'CASH';
               end;
            elsif l_activity_type like '%ORDER' then
                begin
                    select t.trx_number, t.bill_to_customer_id, t.bill_to_site_use_id
                    into l_invoice_number, l_customer_id, l_bill_to_site_use_id
                    from ra_customer_trx_all t
                    where t.INTERFACE_HEADER_ATTRIBUTE1 = v_merchant_ref_number
--                    where t.ct_reference = v_merchant_ref_number
                    and t.org_id = v_org_id; --SIEBEL QUOTE 
                exception
                    when others then
                        l_apply_flag := 'N';
                end;
            elsif l_activity_type like '%INVOICE' then
                l_invoice_number := v_merchant_ref_number;

                begin
                   select t.bill_to_customer_id, t.bill_to_site_use_id
                    into l_customer_id, l_bill_to_site_use_id
                    from ra_customer_trx_all t
                    where t.trx_number = l_invoice_number
                    and t.org_id = v_org_id;
                exception
                    when others then
                        l_apply_flag := 'N';
                end;

               
            elsif l_activity_type = 'CE_OTHER' then
                l_apply_flag := 'N';
            END IF;
/*        
        else --ics_credit
            
            l_bank_trx_number := v_r_type||v_merchant_ref_number;
            l_trx_date := v_statement_date;
            l_remit_bank_acct_use_id := v_BANK_ACCT_USE_ID;
            l_customer_id := null;
            l_bill_to_site_use_id := null;
            l_apply_flag := 'Y';
        
            update QSTAR_CYBERSOURCE_DETAIL c
            set c.posted_date = sysdate
            where c.cybersource_id = v_cybersource_id(v_loop_index );           

        
        end if; --if v_transaction_type != 'ics_credit' then
*/
        l_comment := rtrim('Created from Cash Management Statement Number: '||l_statement_number ||' Date: '||v_statement_date||
                        ' Type: '||v_r_type ||
                        case when l_activity_type = 'CE_ZUORA_INVOICE' then
                            ' Zuora  Invoice: ' || ltrim(rtrim(v_zuora_invoice_number))
                        else null end ||
                        ' Apply Invoice: '||ltrim(rtrim(l_invoice_number)));

    /*

       update ap_invoice_lines
       set type_1099 = null,
       income_tax_region = null
       where invoice_id = qst_ap_invoices_pkg.v_invoice_id(v_loop_index );

       update ap_invoice_distributions
       set type_1099 = null,
       income_tax_region = null
       where invoice_id = qst_ap_invoices_pkg.v_invoice_id(v_loop_index );
    */
        if v_receipt_type = 'CASH' then

    --check if already exists
            l_exist_cnt := 0;

            select count(*)
            into l_exist_cnt 
            from AR_CASH_RECEIPTS_V 
            where org_id = v_org_id
            and receipt_number = l_bank_trx_number --'999721212509610'
            and receipt_date = l_trx_date
    --BEGIN PGREEN 07/09/13
            AND TYPE = v_receipt_type
    --END PGREEN 07/09/13
            and currency_code = l_currency_code                   
            and amount = l_amount
            and remit_bank_acct_use_id = l_remit_bank_acct_use_id
            and remit_bank_account = l_BANK_ACCOUNT_NUM
            and receipt_status in ('UNAPP','APP','UNID');
            
            if l_exist_cnt = 0 then
 --*****************************************************
              l_attribute_rec.attribute4 := v_payment_type;


                if not (l_customer_id is null or l_invoice_number is null) and l_apply_flag = 'Y' then  --pgreen 06/16/14
                -- create and apply cash to invoice

        --begin pgreen 12/18/13        
                    begin
                        select ltrim(rtrim(s.location))
                        into l_location
                        from hz_cust_site_uses_all s
                        where s.site_use_id = l_bill_to_site_use_id;
                    exception
                      when others then
                        l_location := null;
                    end;
        --end pgreen 12/18/13

                      APPS.AR_RECEIPT_API_PUB.Create_and_apply(
                               -- Standard API parameters.
                          p_api_version      => 1.0, --IN  NUMBER,
                          p_init_msg_list    => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                          p_commit           => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                          p_validation_level => FND_API.G_VALID_LEVEL_FULL, --IN  NUMBER   := FND_API.G_VALID_LEVEL_FULL,
                          x_return_status    => l_return_status, --OUT NOCOPY VARCHAR2 ,
                          x_msg_count        => l_msg_count, --OUT NOCOPY NUMBER ,
                          x_msg_data         => l_msg_data, --OUT NOCOPY VARCHAR2 ,
                                     -- Receipt info. parameters
                          p_usr_currency_code            => null, --IN  VARCHAR2 DEFAULT NULL, --the translated currency code
                          p_currency_code                => l_currency_code, --'GBP', --IN  VARCHAR2 DEFAULT NULL,
                          p_usr_exchange_rate_type       => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_exchange_rate_type           => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_exchange_rate                => null, --IN  NUMBER   DEFAULT NULL,
                          p_exchange_rate_date           => null, --IN  DATE     DEFAULT NULL,
                          p_amount                       => l_amount, -- -183.40, --IN  NUMBER,
                          p_factor_discount_amount       => null, --IN  NUMBER   DEFAULT NULL,                  ????
                          p_receipt_number               => l_bank_trx_number, --IN  OUT NOCOPY VARCHAR2 ,
                          p_receipt_date                 => l_trx_date, --IN  DATE     DEFAULT NULL,
                          p_gl_date                      => l_trx_date, --IN  DATE     DEFAULT NULL,
                                     p_maturity_date           => l_trx_date, --IN  DATE     DEFAULT NULL,
                                     p_postmark_date           => null, --IN  DATE     DEFAULT NULL,
                                     p_customer_id             => l_customer_id, --null, --IN  NUMBER   DEFAULT NULL,    bill_to_customer_id
                                     p_customer_name           => null, --IN  VARCHAR2 DEFAULT NULL,
                                     p_customer_number         => null, --IN VARCHAR2  DEFAULT NULL,
                                     p_customer_bank_account_id => null, --IN NUMBER   DEFAULT NULL,
                                     p_customer_bank_account_num   => null, --IN  VARCHAR2  DEFAULT NULL,
                                     p_customer_bank_account_name  => null, --IN  VARCHAR2  DEFAULT NULL,
                                     p_payment_trxn_extension_id  => null, --IN NUMBER DEFAULT NULL,
        --???                             p_location                 => l_location, --IN  VARCHAR2 DEFAULT NULL,
                                     p_customer_site_use_id     => l_bill_to_site_use_id, -- null, --IN  NUMBER  DEFAULT NULL,
                                     p_default_site_use         => null, --IN VARCHAR2  DEFAULT 'Y', --bug4448307-4509459
                                     p_customer_receipt_reference => null, --IN  VARCHAR2  DEFAULT NULL,                            ????
            --*                         p_override_remit_account_flag => 'Y', --IN  VARCHAR2 DEFAULT NULL,
                          p_remittance_bank_account_id   => l_remit_bank_acct_use_id, --L_BANK_ACCOUNT_ID, --10043, --IN  NUMBER   DEFAULT NULL,
                          p_remittance_bank_account_num  => null, --'019057300006', --IN  VARCHAR2 DEFAULT NULL,
                          p_remittance_bank_account_name => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_deposit_date                 => l_trx_date,  --IN  DATE     DEFAULT NULL,
                          p_receipt_method_id            => L_RECEIPT_METHOD_ID, --IN  NUMBER   DEFAULT NULL,
                          p_receipt_method_name          => null, --IN  VARCHAR2 DEFAULT NULL,                                  
                          p_doc_sequence_value           => null, --IN  NUMBER   DEFAULT NULL,
                          p_ussgl_transaction_code       => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_anticipated_clearing_date    => l_trx_date, --IN  DATE     DEFAULT NULL,
                          p_called_from                  => null, --IN VARCHAR2 DEFAULT NULL,
                                     p_attribute_rec         => null, --=> attribute_rec_const, --IN  attribute_rec_type        DEFAULT attribute_rec_const,                ???????
                           -- ******* Global Flexfield parameters *******
                                     p_global_attribute_rec  => null, --=> global_attribute_rec_const, --IN  global_attribute_rec_type DEFAULT global_attribute_rec_const,          ?????????
                          p_receipt_comments                     => null, --'01-MAY-2012', --IN  VARCHAR2 DEFAULT NULL,                                                                    ????
                          --   ***  Notes Receivable Additional Information  ***
                                     p_issuer_name                  => null, --IN VARCHAR2  DEFAULT NULL,
                                     p_issue_date                   => null, --IN DATE   DEFAULT NULL,
                                     p_issuer_bank_branch_id        => null, --IN NUMBER  DEFAULT NULL,
            --PG              p_org_id                       => l_org_id, --IN NUMBER  DEFAULT NULL,
            --PG                         p_installment                  => null,
                          --   ** OUT NOCOPY variables
                                     p_cr_id          => l_cr_id, --OUT NOCOPY NUMBER
                        --BEGIN PG
                           -- Receipt application parameters
                        --**************************** NEW PARAMETERS FOR APPLY *******************************
                              p_customer_trx_id         => null, --3780703, --IN ra_customer_trx.customer_trx_id%TYPE DEFAULT NULL,
                              p_trx_number              => l_invoice_number, --IN ra_customer_trx.trx_number%TYPE DEFAULT NULL,
                        --*      p_installment             => 1, --null, --IN ar_payment_schedules.terms_sequence_number%TYPE DEFAULT NULL,
                              p_applied_payment_schedule_id => null, --    IN ar_payment_schedules.payment_schedule_id%TYPE DEFAULT NULL,  --?????????
                        --*      p_amount_applied          =>  3675.00, --IN ar_receivable_applications.amount_applied%TYPE DEFAULT NULL,
                              -- this is the allocated receipt amount
                        --*      p_amount_applied_from     => l_amount, -- IN ar_receivable_applications.amount_applied_from%TYPE DEFAULT NULL,
                              p_trans_to_receipt_rate   => null, -- IN ar_receivable_applications.trans_to_receipt_rate%TYPE DEFAULT NULL,
                        --*      p_discount                => 0, -- IN ar_receivable_applications.earned_discount_taken%TYPE DEFAULT NULL,
                              p_apply_date              =>  l_trx_date,  --IN ar_receivable_applications.apply_date%TYPE DEFAULT NULL,
                              p_apply_gl_date           =>  l_trx_date,  --IN ar_receivable_applications.gl_date%TYPE DEFAULT NULL,
                              app_ussgl_transaction_code  => null, --  IN ar_receivable_applications.ussgl_transaction_code%TYPE DEFAULT NULL,
                              p_customer_trx_line_id      => null, --  IN ar_receivable_applications.applied_customer_trx_line_id%TYPE DEFAULT NULL,
                              p_line_number             => null, --  IN ra_customer_trx_lines.line_number%TYPE DEFAULT NULL,
                        --*      p_show_closed_invoices    => 'N', --  IN VARCHAR2 DEFAULT 'N', /* Bug fix 2462013 */
                              p_move_deferred_tax       => null, --  IN VARCHAR2 DEFAULT 'Y',
                              p_link_to_trx_hist_id     => null, --  IN ar_receivable_applications.link_to_trx_hist_id%TYPE DEFAULT NULL,
                              app_attribute_rec           => null, --  IN attribute_rec_type DEFAULT attribute_rec_const,
                          -- ******* Global Flexfield parameters *******
                              app_global_attribute_rec    => null, --  IN global_attribute_rec_type DEFAULT global_attribute_rec_const,
                              app_comments                => null, --  IN ar_receivable_applications.comments%TYPE DEFAULT NULL,
                              p_call_payment_processor    => null, --  IN VARCHAR2 DEFAULT FND_API.G_FALSE,
                              p_org_id                    => v_org_id --IN NUMBER  DEFAULT NULL,  --******** DONE PG
                        --END PG
                                      );

                    if l_return_status != 'S' then
                        v_error_message := 'Error: Create_and_apply - RStatus: '||l_return_status||' Msg_data: ' ||l_msg_data;  -- temporary ******************||' Statement_line_id: '|| l_statement_line_id ;
                        dbms_output.put_line(v_error_message);
                    end if; --if l_return_status != 'S' then

                end if; --if l_customer_id is null or l_invoice_number is null then  --pgreen 06/16/14



                if (l_customer_id is null or l_invoice_number is null) or l_return_status != 'S' or l_apply_flag = 'N' then
        --end pgreen 12/18/13          
                  
                  l_return_status := null;
                  APPS.AR_RECEIPT_API_PUB.Create_cash(
                           -- Standard API parameters.
                      p_api_version      => 1.0, --IN  NUMBER,
                      p_init_msg_list    => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                      p_commit           => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                      p_validation_level => FND_API.G_VALID_LEVEL_FULL, --IN  NUMBER   := FND_API.G_VALID_LEVEL_FULL,
                      x_return_status    => l_return_status, --OUT NOCOPY VARCHAR2 ,
                      x_msg_count        => l_msg_count, --OUT NOCOPY NUMBER ,
                      x_msg_data         => l_msg_data, --OUT NOCOPY VARCHAR2 ,
                                 -- Receipt info. parameters
                      p_usr_currency_code            => null, --IN  VARCHAR2 DEFAULT NULL, --the translated currency code
                      p_currency_code                => l_currency_code, --'GBP', --IN  VARCHAR2 DEFAULT NULL,
                      p_usr_exchange_rate_type       => null, --IN  VARCHAR2 DEFAULT NULL,
                      p_exchange_rate_type           => null, --L_EXCHANGE_RATE_TYPE, --IN  VARCHAR2 DEFAULT NULL,
                      p_exchange_rate                => null, --IN  NUMBER   DEFAULT NULL,
                      p_exchange_rate_date           => null, --L_EXCHANGE_RATE_DATE, --IN  DATE     DEFAULT NULL,
                      p_amount                       => l_amount, -- -183.40, --IN  NUMBER,
                      p_factor_discount_amount       => null, --IN  NUMBER   DEFAULT NULL,                  ????
                      p_receipt_number               => l_bank_trx_number, --IN  OUT NOCOPY VARCHAR2 ,
                      p_receipt_date                 => l_trx_date, --IN  DATE     DEFAULT NULL,
                      p_gl_date                      => l_trx_date, --IN  DATE     DEFAULT NULL,
                                 p_maturity_date           => null, --IN  DATE     DEFAULT NULL,
                                 p_postmark_date           => null, --IN  DATE     DEFAULT NULL,
                                 p_customer_id             => null, --IN  NUMBER   DEFAULT NULL,
                                 p_customer_name           => null, --IN  VARCHAR2 DEFAULT NULL,
                                 p_customer_number         => null, --IN VARCHAR2  DEFAULT NULL,
                                 p_customer_bank_account_id => null, --IN NUMBER   DEFAULT NULL,
                                 p_customer_bank_account_num   => null, --IN  VARCHAR2  DEFAULT NULL,
                                 p_customer_bank_account_name  => null, --IN  VARCHAR2  DEFAULT NULL,
                                 p_payment_trxn_extension_id  => null, --IN NUMBER DEFAULT NULL,
                                 p_location                 => null, --IN  VARCHAR2 DEFAULT NULL,
                                 p_customer_site_use_id     => null, --IN  NUMBER  DEFAULT NULL,
                                 p_default_site_use         => null, --IN VARCHAR2  DEFAULT 'Y', --bug4448307-4509459
                                 p_customer_receipt_reference => null, --IN  VARCHAR2  DEFAULT NULL,                            ????
                                 p_override_remit_account_flag => null, --IN  VARCHAR2 DEFAULT NULL,
                      p_remittance_bank_account_id   => l_remit_bank_acct_use_id, --L_BANK_ACCOUNT_ID, --10043, --IN  NUMBER   DEFAULT NULL,
                      p_remittance_bank_account_num  => null, --'019057300006', --IN  VARCHAR2 DEFAULT NULL,
                      p_remittance_bank_account_name => null, --IN  VARCHAR2 DEFAULT NULL,
                      p_deposit_date                 => null, --IN  DATE     DEFAULT NULL,
                      p_receipt_method_id            => L_RECEIPT_METHOD_ID, --IN  NUMBER   DEFAULT NULL,
                      p_receipt_method_name          => null, --IN  VARCHAR2 DEFAULT NULL,                                  
                      p_doc_sequence_value           => null, --IN  NUMBER   DEFAULT NULL,
                      p_ussgl_transaction_code       => null, --IN  VARCHAR2 DEFAULT NULL,
                      p_anticipated_clearing_date    => l_trx_date, --IN  DATE     DEFAULT NULL,
                      p_called_from                  => null, --IN VARCHAR2 DEFAULT NULL,
                      p_attribute_rec                => l_attribute_rec, --null, --=>
         --                         attribute_rec_const, --IN   attribute_rec_type        DEFAULT attribute_rec_const,                ???????
                       -- ******* Global Flexfield parameters *******
        --              p_global_attribute_rec  => l_global_attribute_rec, --DEFAULT global_attribute_rec_const,          ?????????
                      p_comments                     => l_comment, --'01-MAY-2012', --IN  VARCHAR2 DEFAULT NULL,                                                                    ????
                      --   ***  Notes Receivable Additional Information  ***
                                 p_issuer_name                  => null, --IN VARCHAR2  DEFAULT NULL,
                                 p_issue_date                   => null, --IN DATE   DEFAULT NULL,
                                 p_issuer_bank_branch_id        => null, --IN NUMBER  DEFAULT NULL,
                      p_org_id                       => v_org_id, --IN NUMBER  DEFAULT NULL,
                                 p_installment                  => null,
                      --   ** OUT NOCOPY variables
                                 p_cr_id          => l_cr_id --OUT NOCOPY NUMBER
                                  );
                    if l_return_status != 'S' then
                        v_error_message := 'Error: Create_cash - RStatus: '||l_return_status||' Msg_data: ' ||l_msg_data; -- TEMPORATY *******||' Statement_line_id: '|| l_statement_line_id ;
                        dbms_output.put_line(v_error_message);
                    end if; --if l_return_status != 'S' then


                end if; --if l_customer_id is null or l_invoice_number is null then


             end if; --if l_exist_cnt = 0 then


--*****************************************************
            elsif v_receipt_type = 'MISC' then
                null;
           --check if already exists
                l_exist_cnt := 0;

                select count(*)
                into l_exist_cnt 
                from AR_CASH_RECEIPTS_V 
                where org_id = v_org_id
                and receipt_number = l_bank_trx_number --'999721212509610'
                and receipt_date = l_trx_date
                and type = 'MISC'
                and currency_code = l_currency_code                   --????????????????  temporary
                and amount = l_amount 
                and remit_bank_acct_use_id = l_remit_bank_acct_use_id
                and remit_bank_account = l_BANK_ACCOUNT_NUM
                and receipt_status in ('UNAPP','APP','UNID') --pgreen 07/08/14
                ;

                if l_exist_cnt = 0 then
                    select count(*)
                    into l_activity_flag
                    from AR_RECEIVABLES_TRX_ALL  rt
                    where rt.org_id = v_org_id
                    and rt.name = l_activity_type;

                  if l_activity_flag = 1 then
                
                      l_activity := l_activity_type;
        --              l_activity := 'Miscellaneous cash';
                      l_attribute_rec.attribute5 := l_bank_reference;
                      l_return_status := null;

                      APPS.AR_RECEIPT_API_PUB.create_misc(
                        -- Standard API parameters.
                          p_api_version                  => 1.0, --IN  NUMBER,
                          p_init_msg_list                => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                          p_commit                       => FND_API.G_TRUE, --IN  VARCHAR2 := FND_API.G_FALSE,
                          p_validation_level             => FND_API.G_VALID_LEVEL_FULL, --IN  NUMBER   := FND_API.G_VALID_LEVEL_FULL,
                          x_return_status                => l_return_status, --OUT NOCOPY VARCHAR2 ,
                          x_msg_count                    => l_msg_count, --OUT NOCOPY NUMBER ,
                          x_msg_data                     => l_msg_data, --OUT NOCOPY VARCHAR2 ,
                        -- Misc Receipt info. parameters

                          p_usr_currency_code            => null, --IN  VARCHAR2 DEFAULT NULL, --the translated currency code
                          p_currency_code                => l_currency_code, --IN  VARCHAR2 DEFAULT NULL,
                          p_usr_exchange_rate_type       => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_exchange_rate_type           => null, --L_EXCHANGE_RATE_TYPE, --IN  VARCHAR2 DEFAULT NULL,
                          p_exchange_rate                => null, --IN  NUMBER   DEFAULT NULL,
                          p_exchange_rate_date           => null, --L_EXCHANGE_RATE_DATE, --IN  DATE     DEFAULT NULL,

                          p_amount                       =>  L_AMOUNT , --IN  NUMBER,
                          p_receipt_number               => l_bank_trx_number, --IN  OUT NOCOPY VARCHAR2 ,
                          p_receipt_date                 => l_trx_date, --IN  DATE     DEFAULT NULL,
                          p_gl_date                      => l_trx_date, --IN  DATE     DEFAULT NULL,
                          p_receivables_trx_id           => null, --IN  NUMBER   DEFAULT NULL,
                          p_activity                     => l_activity, --'Miscellaneous Non A/R Receipt', --IN  VARCHAR2 DEFAULT NULL,
                          p_misc_payment_source          => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_tax_code                     => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_vat_tax_id                   => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_tax_rate                     => null, --IN  NUMBER   DEFAULT NULL,
                          p_tax_amount                   => null, --IN  NUMBER   DEFAULT NULL,
                          p_deposit_date                 => null, --IN  DATE     DEFAULT NULL,
                          p_reference_type               => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_reference_num                => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_reference_id                 => null, --IN  NUMBER   DEFAULT NULL,
                          p_remittance_bank_account_id   => l_remit_bank_acct_use_id, --IN  NUMBER   DEFAULT NULL,
                          p_remittance_bank_account_num  => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_remittance_bank_account_name => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_receipt_method_id            => L_RECEIPT_METHOD_ID, --IN  NUMBER   DEFAULT NULL,
                          p_receipt_method_name          => null, --IN  VARCHAR2 DEFAULT NULL,
                          p_doc_sequence_value           => null, --IN  NUMBER   DEFAULT NULL,
                          p_ussgl_transaction_code       => null, --IN  VARCHAR2 DEFAULT NULL,                      --??????????????????????????????????
                          p_anticipated_clearing_date    => l_trx_date, --IN  DATE     DEFAULT NULL,
                          p_attribute_record             => l_attribute_rec, --null, --=> attribute_rec_const, --IN  attribute_rec_type        DEFAULT attribute_rec_const,
                          p_global_attribute_record      => null, --=> global_attribute_rec_const, --    IN  global_attribute_rec_type DEFAULT global_attribute_rec_const,
                          p_comments                     => l_comment, --IN  VARCHAR2 DEFAULT NULL,
                          p_org_id                       => v_org_id, --IN NUMBER  DEFAULT NULL,
                          p_misc_receipt_id              => l_misc_receipt_id, --OUT NOCOPY NUMBER,
                          p_called_from                  => null, --IN VARCHAR2 DEFAULT NULL,
                          p_payment_trxn_extension_id    => null --IN ar_cash_receipts.payment_trxn_extension_id%TYPE DEFAULT NULL ) /* Bug fix 3619780*/
                      );

                        if l_return_status != 'S' then
                            v_error_message := 'Error: create_misc - RStatus: '||l_return_status||' Msg_data: ' ||l_msg_data; -- TEMPORATY *******||' Statement_line_id: '|| l_statement_line_id ;
                            dbms_output.put_line(v_error_message);
                        end if; --if l_return_status != 'S' then


                  else --  if l_activity_flag = 1 then
                    null; 
                    --error no activity!!!!!!!!!!
                  end if; --  if l_activity_flag = 1 then


                end if; --if l_exist_cnt = 0 then

--*****************************************************
            
            end if; -- if v_receipt_type = 'CASH' then
            
            if l_return_status = 'S' then
                update QSTAR_CYBERSOURCE_DETAIL c
                set c.posted_date = sysdate
                where c.cybersource_id = v_cybersource_id(v_loop_index ); 
                
            else
                update QSTAR_CYBERSOURCE_DETAIL c
                set c.status = sysdate||' '||l_return_status||' '||l_msg_count||' '||l_msg_data
                where c.cybersource_id = v_cybersource_id(v_loop_index ); 
                     
            end if; --if l_return_status = 'S' then


        else --ics_credit
            
            l_bank_trx_number := v_r_type||v_merchant_ref_number;
            l_trx_date := v_statement_date;
            l_remit_bank_acct_use_id := v_BANK_ACCT_USE_ID;
            l_customer_id := null;
            l_bill_to_site_use_id := null;
            l_apply_flag := 'Y';
        
            update QSTAR_CYBERSOURCE_DETAIL c
            set c.posted_date = sysdate
            where c.cybersource_id = v_cybersource_id(v_loop_index );           

        
        end if; --if v_transaction_type != 'ics_credit' then

--        COMMIT;

      end if; --if v_error_flag = 0 then
      
      COMMIT;
         
    end loop; -- Package
    
--    commit;
    
   elsif nvl(v_tot_sli_amount,0) != 0 then  --pgreen 10/30/14
    null; --Error Message Cybersource Receipts dont match with JPMorgan ************************

        begin
            update qstce_statement_log
            set create_cc_receipts_message = v_r_type||'- Receipt Credit Card v_cybersource_amount: '||v_cybersource_amount||' v_tot_sli_amount: '|| v_tot_sli_amount
            where bank_account_id = p_bank_account_id
            and statement_number = p_statement_number;
              
        exception
          when others then
            insert into qstce_statement_log (bank_account_id, statement_number, create_cc_receipts_message, statement_log_id)
                values (p_bank_account_id, p_statement_number, v_r_type||'- Receipt Credit Card v_cybersource_amount: '||v_cybersource_amount||' v_tot_sli_amount: '|| v_tot_sli_amount,
                qstce_statement_log_id.nextval);
                         
        end;


   end if; --if v_cybersource_amount = v_tot_sli_amount then

  end loop; --cc_rec in cc_cur loop

/*  --pgreen 09/26/14 temporary ************************************************
  if l_session_id is not null then
    utl_http.end_response(http_resp);
  end if; -- if l_session_id is not null
*/
  
END IF; --if v_error_flag = 0 then


end create_cc_receipts;   


------------------
 PROCEDURE ZUORA_INVOICE_MAIN (p_bank_code in varchar2, p_bank_account_num in varchar2, 
                                p_bank_account_id in number, p_statement_number in varchar2,
                                p_payment_number in varchar2, p_invoice_number out varchar2)   AS 
  p_soap_action  varchar2(30);
  p_payload clob;
  c_soap_envelope clob ;
  l_soap_request clob;
  l_soap_response varchar2(32767);
  http_req utl_http.req;
--  http_resp utl_http.resp;
  v_length   NUMBER;

--  l_session_id varchar2(32767);
  l_payment_id varchar2(32767);
  l_invoice_id varchar2(32767);
--  l_invoice_number varchar2(32767);
  l_err_msg varchar2(32767);
  
--  l_zuora_password varchar2(50); --pgreen 04/3/15
l_message_name varchar2(100) := null;--pgreen 04/3/15

  
l_cnt number := 0;

  begin

                 dbms_output.put_line( 'ZUORA_soap_call -- 0');

--pgreen 04/3/15 if l_session_id is null then
if l_zuora_password is null then--pgreen 04/3/15

 p_soap_action := 'login';
 
 --begin pgreen 04/3/15
      SELECT L.ATTRIBUTE5
     into l_zuora_password
     FROM fnd_lookup_values_vl  L
     WHERE L.lookup_type = 'QSTCE_TRANS_CODE_PROCESSING'
        and nvl(l.attribute6, p_bank_code) = p_bank_code    
        and nvl(l.attribute9, p_bank_account_num) = p_bank_account_num
        AND sysdate  BETWEEN L.START_DATE_ACTIVE AND NVL(L.END_DATE_ACTIVE, SYSDATE+1)     
     AND L.ATTRIBUTE2 = 'PASSWORD'
     AND L.ATTRIBUTE4 = 'ZUORA'
     ;

 --end pgreen 04/3/15
/*
--Dev
 p_payload := 

             '<soapenv:Body>
                <api:login>
                   <api:username>integration.user_dev@quest.com</api:username>
                   <api:password>dell_d0d</api:password>
                </api:login>
             </soapenv:Body>';    

*/
--Prod
/*
     p_payload := 

             '<soapenv:Body>
                <api:login>
                   <api:username>integration.user@quest.com</api:username>
                   <api:password>Quest123456#</api:password>
                </api:login>
             </soapenv:Body>';    
*/
     p_payload := 

             '<soapenv:Body>
                <api:login>
                   <api:username>integration.user@software.dell.com</api:username>
                   <api:password>'||l_zuora_password||'</api:password>
                </api:login>
             </soapenv:Body>';    


    c_soap_envelope := '<?xml version=''1.0'' encoding=''UTF-8''?>
            <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:api="http://api.zuora.com/">
              </soapenv:Header>'
              ||p_payload||'</soapenv:Envelope>';
              

    ZUORA_INVOICE_PROCESS (c_soap_envelope, p_soap_action, l_soap_response);
dbms_output.put_line( 'SOAP Response #A *******: '  || l_soap_response);
 
    l_session_id := substr(l_soap_response, instr(l_soap_response,'<ns1:Session>')+13,
                        instr(l_soap_response,'</ns1:Session>') - instr(l_soap_response,'<ns1:Session>') -13);
                dbms_output.put_line( 'l_session_id: ' ||l_session_id );
 --begin pgreen 04/3/15
    if l_session_id is null then
            l_message_name := 'Unable to obtain Zuora Session Id';
            null;
            begin
                update qstce_statement_log
                set create_cc_receipts_message = l_message_name
                where bank_account_id = p_bank_account_id
                and statement_number = p_statement_number;
                  
            exception
              when others then
                insert into qstce_statement_log (bank_account_id, statement_number, create_cc_receipts_message, statement_log_id)
                    values (p_bank_account_id, p_statement_number, l_message_name, qstce_statement_log_id.nextval);
                             
            end;          
            
            commit;
    end if; --if l_session_id is null then
 
--pgreen 04/3/15 end if; --l_session_id
 end if; -- if l_zuora_password is null then--pgreen 04/3/15


if l_session_id is not null then

--end pgreen 04/3/15

-----------------------------  
--new          
--l_payment_number := 'P-00000040';


p_soap_action := 'query';

    p_payload := 
     '<soapenv:Header>
          <api:SessionHeader>
              <api:session>'||l_session_id||'</api:session>
          </api:SessionHeader>
      </soapenv:Header>
      <soapenv:Body>
          <api:query>
              <api:queryString>select id from payment where paymentnumber='''||p_payment_number||'''</api:queryString>
          </api:query>
      </soapenv:Body>';

    c_soap_envelope := '<?xml version=''1.0'' encoding=''UTF-8''?>
            <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:api="http://api.zuora.com/">'
              ||p_payload||'</soapenv:Envelope>';

    ZUORA_INVOICE_PROCESS (c_soap_envelope, p_soap_action, l_soap_response);
 

                dbms_output.put_line( 'SOAP Response #2 *******: '  || l_soap_response);
    

    l_payment_id := substr(l_soap_response, instr(l_soap_response,'<ns2:Id>')+8,
                        instr(l_soap_response,'</ns2:Id>') - instr(l_soap_response,'<ns2:Id>') -8);
                dbms_output.put_line( 'l_payment_id: ' ||l_payment_id );

------------------------
p_soap_action := 'query';

    p_payload := 
     '<soapenv:Header>
          <api:SessionHeader>
              <api:session>'||l_session_id||'</api:session>
          </api:SessionHeader>
      </soapenv:Header>
      <soapenv:Body>
          <api:query>
              <api:queryString>select InvoiceId from InvoicePayment where paymentId='''||l_payment_id||'''</api:queryString>
          </api:query>
      </soapenv:Body>';

    c_soap_envelope := '<?xml version=''1.0'' encoding=''UTF-8''?>
            <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:api="http://api.zuora.com/">'
              ||p_payload||'</soapenv:Envelope>';

    ZUORA_INVOICE_PROCESS (c_soap_envelope, p_soap_action, l_soap_response);

                dbms_output.put_line( 'SOAP Response #3 *******: '  || l_soap_response);
    

    l_invoice_id := substr(l_soap_response, instr(l_soap_response,'<ns2:InvoiceId>')+15,
                        instr(l_soap_response,'</ns2:InvoiceId>') - instr(l_soap_response,'<ns2:InvoiceId>') -15);
                dbms_output.put_line( 'l_invoice_id: ' ||l_invoice_id );



------------------------
p_soap_action := 'query';

    p_payload := 
     '<soapenv:Header>
          <api:SessionHeader>
              <api:session>'||l_session_id||'</api:session>
          </api:SessionHeader>
      </soapenv:Header>
      <soapenv:Body>
          <api:query>
              <api:queryString>select InvoiceNumber from Invoice where Id='''||l_invoice_id||'''</api:queryString>
          </api:query>
      </soapenv:Body>';

    c_soap_envelope := '<?xml version=''1.0'' encoding=''UTF-8''?>
            <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:api="http://api.zuora.com/">'
              ||p_payload||'</soapenv:Envelope>';

    ZUORA_INVOICE_PROCESS (c_soap_envelope, p_soap_action, l_soap_response);

                dbms_output.put_line( 'SOAP Response #4 *******: '  || l_soap_response);
    
 
    p_invoice_number := substr(l_soap_response, instr(l_soap_response,'<ns2:InvoiceNumber>')+19,
                        instr(l_soap_response,'</ns2:InvoiceNumber>') - instr(l_soap_response,'<ns2:InvoiceNumber>') -19);
                dbms_output.put_line( 'p_invoice_number: ' ||p_invoice_number );


 --   v_zuora_invoice_number := l_invoice_number;

end if; --if l_session_id is not null then      pgreen 04/3/15
------------------------



-- do at end

--    utl_http.end_response(http_resp);    --pgreen 09/26/14 temporary
    
--    UTL_TCP.CLOSE_ALL_CONNECTIONS; 
                   
  EXCEPTION
    WHEN Utl_Http.request_failed    THEN
              l_err_msg := Utl_Http.get_detailed_sqlerrm;
              l_message_name := substr('Request_Failed: ' || l_err_msg,1,2000);
                 begin
                    update qstce_statement_log
                    set create_cc_receipts_message = l_message_name
                    where bank_account_id = p_bank_account_id
                    and statement_number = p_statement_number;
                      
                exception
                  when others then
                    insert into qstce_statement_log (bank_account_id, statement_number, create_cc_receipts_message, statement_log_id)
                        values (p_bank_account_id, p_statement_number, l_message_name, qstce_statement_log_id.nextval);
                                 
                end;   
                commit;       
            dbms_output.put_line(    'Request_Failed: ' || Utl_Http.get_detailed_sqlerrm    );
    /* raised by URL http://xxx.oracle.com/ */
    WHEN Utl_Http.http_server_error    THEN
              l_err_msg := Utl_Http.get_detailed_sqlerrm;
              l_message_name := substr('Http_Server_Error: ' || l_err_msg,1,2000);
                 begin
                    update qstce_statement_log
                    set create_cc_receipts_message = l_message_name
                    where bank_account_id = p_bank_account_id
                    and statement_number = p_statement_number;
                      
                exception
                  when others then
                    insert into qstce_statement_log (bank_account_id, statement_number, create_cc_receipts_message, statement_log_id)
                        values (p_bank_account_id, p_statement_number, l_message_name, qstce_statement_log_id.nextval);
                                 
                end;          
                commit;       
              dbms_output.put_line(    'Http_Server_Error: ' || Utl_Http.get_detailed_sqlerrm    );
    /* raised by URL http://otn.oracle.com/xxx */
    WHEN Utl_Http.http_client_error     THEN
              l_err_msg := Utl_Http.get_detailed_sqlerrm;
              l_message_name := substr('Http_Client_Error: ' || l_err_msg,1,2000);
                 begin
                    update qstce_statement_log
                    set create_cc_receipts_message = l_message_name
                    where bank_account_id = p_bank_account_id
                    and statement_number = p_statement_number;
                      
                exception
                  when others then
                    insert into qstce_statement_log (bank_account_id, statement_number, create_cc_receipts_message, statement_log_id)
                        values (p_bank_account_id, p_statement_number, l_message_name, qstce_statement_log_id.nextval);
                                 
                end;          
                 commit;       
            dbms_output.put_line(    'Http_Client_Error: ' || Utl_Http.get_detailed_sqlerrm    );
    WHEN OTHERS THEN
              l_err_msg := Utl_Http.get_detailed_sqlerrm;
              if l_err_msg is not null then
                l_message_name := substr('ZUORA_soap_call -- ' || l_err_msg,1,2000);
              elsif l_message_name is not null and l_session_id is null then 
                l_message_name := 'ZUORA_soap_call -- ' ||l_message_name;
              end if;
              select count(*)
              into l_cnt
              from qstce_statement_log
              where bank_account_id = p_bank_account_id
              and statement_number = p_statement_number;
              if l_cnt != 0 then
                    update qstce_statement_log
                    set create_cc_receipts_message = l_message_name
                    where bank_account_id = p_bank_account_id
                    and statement_number = p_statement_number;
                      
              else
                    insert into qstce_statement_log (bank_account_id, statement_number, create_cc_receipts_message, statement_log_id)
                        values (p_bank_account_id, p_statement_number, l_message_name, qstce_statement_log_id.nextval);
                                 
              end if;          
              commit;       
          dbms_output.put_line( 'ZUORA_soap_call -- '||SQLERRM);



 END ZUORA_INVOICE_MAIN;
 
 procedure ZUORA_INVOICE_PROCESS (l_soap_request in clob, p_soap_action in varchar2, l_soap_response out varchar2) as
 
--  p_soap_action  varchar2(30);
  p_payload clob;
  c_soap_envelope clob ;
--  l_soap_request clob;
--  l_soap_response varchar2(32767);
  http_req utl_http.req;
--  http_resp utl_http.resp;
  v_length   NUMBER;
 
begin
 --    l_soap_request := c_soap_envelope;

                dbms_output.put_line( 'SOAP Request .... '||l_soap_request);

    v_length := nvl(length(l_soap_request), 0);

    if p_soap_action = 'login' then
        UTL_HTTP.set_transfer_timeout(1200);

--        UTL_HTTP.SET_WALLET ('file:/apps/oracle/admin/R12TST/wallet');
        UTL_HTTP.SET_WALLET ('file:/home/oracle/WALLET'); 
        
        
    end if; --if p_soap_action = 'Login' then

/*
--Dev
    http_req:= utl_http.begin_request
               ( 'https://apisandbox.zuora.com/apps/services/a/52.0'
               , 'POST'
               , 'HTTP/1.1'
               );
*/
--Prod
    http_req:= utl_http.begin_request
               ( 'https://www.zuora.com/apps/services/a/52.0'
               , 'POST'
               , 'HTTP/1.1'
               );

    utl_http.set_header(http_req, 'Content-Type', 'text/xml; charset=UTF-8');
    utl_http.set_header(http_req, 'Content-Length', v_length);
    utl_http.set_header(http_req, 'SOAPAction', p_soap_action);

                dbms_output.put_line( 'ZUORA_soap_call -- 5.1');

                dbms_output.put_line( 'ZUORA_soap_call -- START'||to_char(sysdate, 'DD/MM/YYYY hh:mi:ss'));
                dbms_output.put_line( 'v_length='||v_length);

                dbms_output.put_line( 'ZUORA_soap_call -- 5.3');
    utl_http.write_text(http_req, substr(l_soap_request, 1, 4000));

                dbms_output.put_line( 'http_resp.status_code .... '||http_resp.status_code);


--***************************************************************************************
    -- the actual call to the service is made here
    http_resp:= utl_http.get_response(http_req);
--***************************************************************************************

                dbms_output.put_line('http_resp.status_code .... '||http_resp.status_code);

    utl_http.read_text(http_resp, l_soap_response, 4000);    
                dbms_output.put_line( 'SOAP Response: '  || l_soap_response);

    utl_http.end_response(http_resp);    --pgreen 09/26/14 temporary
  
 end ZUORA_INVOICE_PROCESS;
 

END QSTCE_BANK_RECONCILIATION;
/

