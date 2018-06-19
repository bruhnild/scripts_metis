  REM script to backup PostgresSQL databases
 @ECHO off



 FOR /f "tokens=1-4 delims=/ " %%i IN ("%date%") DO (

 SET dow=%%i
 SET month=%%j
 SET day=%%k
 SET year=%%l
 )
 
rem set fic=sav_%date:~6,4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%.dump
 
set vheure=%time:~0,2%
if /i %vheure% lss 10 set vheure=0%time:~1,1%
 
set vmin=%time:~3,2%
if /i %vmin% lss 10 set vmin=0%time:~4,1%
 
set vsec=%time:~6,2%
if /i %vsec% lss 10 set vsec=0%time:~7,1%
 
set fic=_%date:~6,4%%date:~3,2%%date:~0,2%_%vheure%%vmin%%vsec%.dump
 
 
 
 md C:\github_repo\github_repo_batch\batch\dump_restore_sql\dump\dump_localhost\%DATE:/=-%
 

 SET datestr=%DATE:/=_%
 REM SET datestr=%month%_%day%_%year%
 rem SET db1=optimisation_diag
 rem SET db2=postgres
 rem SET db3=routing
 rem SET db4=thd_isere
 SET db5=territoire
 rem SET db6=l49
 REM db5=visite_technique
 
 ECHO datestr is %datestr%

 SET BACKUP_FILE1=C:\github_repo\github_repo_batch\batch\dump_restore_sql\dump\dump_localhost\%DATE:/=-%\%db1%_%datestr%.sql
 SET FIlLENAME1=%db1%_%datestr%.sql

 SET BACKUP_FILE2=C:\github_repo\github_repo_batch\batch\dump_restore_sql\dump\dump_localhost\%DATE:/=-%\%db2%_%datestr%.sql
 SET FIlLENAME2=%db2%_%datestr%.sql

 SET BACKUP_FILE3=C:\github_repo\github_repo_batch\batch\dump_restore_sql\dump\dump_localhost\%DATE:/=-%\%db3%_%datestr%.sql
 SET FIlLENAME3=%db3%_%datestr%.sql

 SET BACKUP_FILE4=C:\github_repo\github_repo_batch\batch\dump_restore_sql\dump\dump_localhost\%DATE:/=-%\%db4%_%datestr%.sql
 SET FIlLENAME4=%db4%_%datestr%.sql

 SET BACKUP_FILE5=C:\github_repo\github_repo_batch\batch\dump_restore_sql\dump\dump_localhost\%DATE:/=-%\%db5%_%datestr%.sql
 SET FIlLENAME5=%db5%_%datestr%.sql

 SET BACKUP_FILE5=C:\github_repo\github_repo_batch\batch\dump_restore_sql\dump\dump_localhost\%DATE:/=-%\%db6%_%datestr%.sql
 SET FIlLENAME6=%db6%_%datestr%.sql

 ECHO Backup file name is %FIlLENAME1% , %FIlLENAME2% , %FIlLENAME3% , %FIlLENAME4%, %FIlLENAME5%, %FIlLENAME6%

 ECHO off
 cd C:\Program Files\PostgreSQL\9.4\bin\

 pg_dump -U postgres -h localhost -p 5432 %db1%  > %BACKUP_FILE1%
 pg_dump -U postgres -h localhost -p 5432 %db2%  > %BACKUP_FILE2%
 pg_dump -U postgres -h localhost -p 5432 %db3%  > %BACKUP_FILE3%
 pg_dump -U postgres -h localhost -p 5432 %db4%  > %BACKUP_FILE4%
 pg_dump -U postgres -h localhost -p 5432 %db5%  > %BACKUP_FILE5%
 pg_dump -U postgres -h localhost -p 5432 %db6%  > %BACKUP_FILE6%
 REM pg_dump -U postgres -h localhost -p 5432 %db5%  > %BACKUP_FILE5%

 ECHO DONE !
 PAUSE