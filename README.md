# MariaDB convert old types columns

This procedure is usefull to convert all columns typed datetime, time, timestamp and decimal created with Mariadb version under 10.1.2 or mySql 5.6 (Mariadb 10.0 for decimal) 
Since Mariadb 10.5, a tag is added on the columm type to indicate old version.

The procedure browses databases and tables which have columns tagged /* mariadb-5.3 */ or /*old*/ and just alter table to modify columns with the same definition.
/!\ only simple definitions are supported : type, nullable, default value, comment, numeric precision (for decimal), numeric scale (for decimal), unsigned or not (for decimal)

The procedure throw one alter by table even if there are many columns to modify (ALTER TABLE... MODIFY ..., MODIFY...)

## Tags example:
datetime /* mariadb-5.3 */
decimal(7,3) /*old*/

## Procedure name : 
    convertOldTypes()

## Note for phpMyAdmin :
Delete delimiter at beginning and end
PhpMyAdmin manages delimiter himself, this is under the SQL field.
Modify Delimiter from ; to // (for example). 

## Launch procedure :
    CALL convertOldTypes;

### References :
<https://mariadb.com/kb/en/datetime/>

<https://mariadb.com/kb/en/datetime/#internal-format>
