DELIMITER //

CREATE OR REPLACE PROCEDURE convertOldTypes()
BLOCK_DB_TABLE: BEGIN
    DECLARE handler_db_table TINYINT DEFAULT FALSE;
    DECLARE var_db_name TEXT;
    DECLARE var_table_name TEXT;

    DECLARE cur_db_table CURSOR FOR
        SELECT Columns.TABLE_SCHEMA, Columns.TABLE_NAME
        FROM information_schema.COLUMNS as Columns
                 LEFT JOIN information_schema.TABLES as Tables ON
            Tables.TABLE_SCHEMA=Columns.TABLE_SCHEMA
                AND Tables.TABLE_NAME=Columns.TABLE_NAME
        WHERE
            (DATA_TYPE IN ('datetime', 'timestamp', 'time', 'decimal'))
          AND (COLUMN_TYPE LIKE '%mariadb-5.3%' OR COLUMN_TYPE LIKE '%old%')
          AND TABLE_TYPE LIKE 'BASE TABLE'
        GROUP BY Columns.TABLE_SCHEMA, Columns.TABLE_NAME;

    DECLARE cur_columns CURSOR FOR
        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_COMMENT, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_TYPE
        FROM information_schema.COLUMNS as Columns
        WHERE
            (DATA_TYPE IN ('datetime', 'timestamp', 'time', 'decimal'))
          AND (COLUMN_TYPE LIKE '%mariadb-5.3%' OR COLUMN_TYPE LIKE '%old%')
          AND TABLE_SCHEMA LIKE var_db_name
          AND TABLE_NAME LIKE var_table_name
        ORDER BY Columns.TABLE_SCHEMA, Columns.TABLE_NAME, COLUMN_NAME;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET handler_db_table = true;

    OPEN cur_db_table;
    loop_base_table: LOOP
        FETCH cur_db_table INTO var_db_name, var_table_name;

        IF handler_db_table THEN
            LEAVE loop_base_table;
        END IF;

        SET @alterSql = CONCAT('ALTER TABLE ', var_db_name, '.', var_table_name);

        BLOCK_COL: BEGIN
            DECLARE handler_column TINYINT DEFAULT FALSE;
            DECLARE var_col_name TEXT;
            DECLARE var_data_type TEXT;
            DECLARE var_is_nullable TEXT;
            DECLARE var_col_default TEXT;
            DECLARE var_col_comment TEXT;
            DECLARE var_numeric_precision TEXT;
            DECLARE var_numeric_scale TEXT;
            DECLARE var_col_type TEXT;

            DECLARE CONTINUE HANDLER FOR NOT FOUND SET handler_column = true;

            SET @modifySql = NULL;

            OPEN cur_columns;
            loop_colonne: LOOP
                FETCH cur_columns INTO
                    var_col_name,
                    var_data_type,
                    var_is_nullable,
                    var_col_default,
                    var_col_comment,
                    var_numeric_precision,
                    var_numeric_scale,
                    var_col_type;

                if handler_column THEN
                    LEAVE loop_colonne;
                END IF;

                IF (var_data_type NOT LIKE 'decimal') THEN
                    SET @modifySql = CONCAT(
                            IF(@modifySql IS NOT NULL,CONCAT (@modifySql, ','),''),
                            ' MODIFY ',
                            var_col_name,
                            ' ', var_data_type,
                            IF(var_is_nullable LIKE 'YES',' NULL',' NOT NULL'),
                            IF(var_col_default IS NULL,'',CONCAT(' DEFAULT ',var_col_default)),
                            IF(var_col_comment NOT LIKE '',CONCAT(' COMMENT "', var_col_comment, '"'),'')
                                     );
                ELSE
                    SET @modifySql = CONCAT(
                            IF(@modifySql IS NOT NULL,CONCAT (@modifySql, ','),''),
                            ' MODIFY ',
                            var_col_name,
                            ' ', REPLACE(var_col_type,'/*old*/',''),
                            IF(var_is_nullable LIKE 'YES',' NULL',' NOT NULL'),
                            IF(var_col_default IS NULL,'',CONCAT(' DEFAULT ',var_col_default)),
                            IF(var_col_comment NOT LIKE '',CONCAT(' COMMENT "', var_col_comment, '"'),'')
                                     );
                END IF;
            END LOOP;
            CLOSE cur_columns;
        END BLOCK_COL;

        SET @alterSql = CONCAT(@alterSql, @modifySql);

        # SELECT @alterSql; # debug
        PREPARE stmt FROM @alterSql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;

    CLOSE cur_db_table;
END BLOCK_DB_TABLE;

DELIMITER //
