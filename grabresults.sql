USE information_schema;
select concat("ALTER TABLE ",table_name," DISCARD TABLESPACE;")  AS discard_tablespace
into outfile '/tmp/discard.sql'
from information_schema.tables 
where TABLE_SCHEMA=@databasename;

USE information_schema;
select concat("ALTER TABLE ",table_name," IMPORT TABLESPACE;") AS import_tablespace
into outfile '/tmp/import.sql'
from information_schema.tables 
where TABLE_SCHEMA=@databasename;

USE information_schema;
SELECT 
concat ("ALTER TABLE ", rc.CONSTRAINT_SCHEMA, ".",rc.TABLE_NAME," DROP FOREIGN KEY ", rc.CONSTRAINT_NAME,";") AS drop_keys
into outfile '/tmp/drop.sql'
FROM REFERENTIAL_CONSTRAINTS AS rc
where CONSTRAINT_SCHEMA = @databasename;

USE information_schema;
SELECT
CONCAT ("ALTER TABLE ", 
KCU.CONSTRAINT_SCHEMA, ".",
KCU.TABLE_NAME," 
ADD CONSTRAINT ", 
KCU.CONSTRAINT_NAME, " 
FOREIGN KEY ", "
(`",KCU.COLUMN_NAME,"`)", " 
REFERENCES `",REFERENCED_TABLE_NAME,"` 
(`",REFERENCED_COLUMN_NAME,"`)" ," 
ON UPDATE " ,(SELECT UPDATE_RULE FROM REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = KCU.CONSTRAINT_NAME AND CONSTRAINT_SCHEMA = KCU.CONSTRAINT_SCHEMA)," 
ON DELETE ",(SELECT DELETE_RULE FROM REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_NAME = KCU.CONSTRAINT_NAME AND CONSTRAINT_SCHEMA = KCU.CONSTRAINT_SCHEMA),";") AS add_keys
into outfile '/tmp/add.sql'
FROM KEY_COLUMN_USAGE AS KCU
WHERE KCU.CONSTRAINT_SCHEMA = @databasename
AND KCU.POSITION_IN_UNIQUE_CONSTRAINT >= 0
AND KCU.CONSTRAINT_NAME NOT LIKE 'PRIMARY';

