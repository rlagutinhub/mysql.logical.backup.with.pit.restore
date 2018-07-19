#!/bin/bash
# ----------------------------------------------------------------------------------------------------
# NAME:    MYSQL.LOGICAL.BACKUP.WITH.PIT.RESTORE.SH
# DESC:    LOGICAL BACKUP MYSQL WITH PIT RESTORE
# DATE:    04.07.2018
# LANG:    BASH
# AUTOR:   LAGUTIN R.A.
# CONTACT: RLAGUTIN@MTA4.RU
# ----------------------------------------------------------------------------------------------------
#
# https://dev.mysql.com/doc/refman/5.7/en/mysqldump.html
# https://dev.mysql.com/doc/refman/5.7/en/mysqlbinlog.html
# https://dev.mysql.com/doc/refman/5.7/en/mysqlbinlog-backup.html
# https://dev.mysql.com/doc/refman/5.7/en/point-in-time-recovery.html
# https://www.percona.com/blog/2013/02/08/how-to-createrestore-a-slave-using-gtid-replication-in-mysql-5-6/
#
# Scheduling: 0 7 * * * /backup/mysql.logical.backup.with.pit.restore.sh full
# Scheduling: 0 */4 * * * /backup/mysql.logical.backup.with.pit.restore.sh log

# ----------------------------------------------------------------------------------------------------
# VARIABLES
# ----------------------------------------------------------------------------------------------------

# DATE FORMAT
#MYSQL_BACKUP_DATE=`date +%Y.%m.%d`
MYSQL_BACKUP_DATE=$(date +%Y-%m-%d.%H-%M-%S)

# HOSTNAME
#HOSTNAME=`uname -n`
HOST=$(hostname -s) # Short name
DOM=$(hostname -d)  # Domain name
IP=$(hostname -i)   # IP

# MYSQL
MYSQL_USER=root
MYSQL_PASS=1qaz@WSX
MYSQL_HOST=localhost
MYSQL_PORT=3306
# MYSQL_DB="testdb"
MYSQL_DB="testdb, testdb2"
# MYSQL_DB="testdb, testdb2, mysql"

# BACKUP
MYSQL_BACKUP_DIR=/backup
MYSQL_BACKUP_LOG=backup.log
MYSQL_BACKUP_ROT=1440 # Delete backup old min. 1 day = 1440 min
# MYSQL_BACKUP_ROT=1

# BACKUP THRESHOLD
MYSQL_BACKUP_DISK=$MYSQL_BACKUP_DIR # backup mount dir
MYSQL_BACKUP_DISK_THRESHOLD=10      # free space, precent %

# MAIL
MAIL_SERVER="mail.example.com:25" # Example mail.example.com:25 or localhost:25
MAIL_FROM="MySQL Logical Backup <$HOST@example.com>" # MAIL_FROM
MAIL_TO="lagutin_ra@example.com" # Delimiter space
# MAIL_TO="user1@example.com"
# MAIL_TO="user2@example.com"
# MAIL_TO="user3@example.com"
# MAIL_TO="user1@example.com user2@example.com user3@example.com"
MAIL_VERBOSE="ONLY_FAIL"
# MAIL_VERBOSE="FAIL_OK"
# MAIL_VERBOSE="OK"

# SCRIPT
SCRIPT_FILE=$0
SCRIPT_ARGS=$@
SCRIPT_LOG=${MYSQL_BACKUP_DIR}/$(basename $SCRIPT_FILE).${MYSQL_BACKUP_DATE}.log

# BASH COLOR
SETCOLOR_BLUE="echo -en \\033[1;34m"
SETCOLOR_WHITE="echo -en \\033[0;39m"
SETCOLOR_BLACK="echo -en \\033[0;30m"
SETCOLOR_RED="echo -en \\033[0;31m"
SETCOLOR_GREEN="echo -en \\033[0;32m"
SETCOLOR_CYAN="echo -en \\033[0;36m"
SETCOLOR_MAGENTA="echo -en \\033[1;31m"
SETCOLOR_LIGHTRED="echo -en \\033[1;31m"
SETCOLOR_YELLOW="echo -en \\033[1;33m"
SETCOLOR_BLACK_BG="echo -en \\033[0;40m"
SETCOLOR_RED_BG="echo -en \\033[0;41m"
SETCOLOR_GREEN_BG="echo -en \\033[0;42m"

# ----------------------------------------------------------------------------------------------------
# FUNCTIONS
# ----------------------------------------------------------------------------------------------------

function LOG() {

    if [ ! -d $MYSQL_BACKUP_DIR ]; then

        mkdir -p $MYSQL_BACKUP_DIR

    fi

    : > $SCRIPT_LOG # create log file

    #clear
    exec &> >(tee -a $SCRIPT_LOG) # Save script stdout, stdin to logfile

}

function RUN() {

    $SETCOLOR_BLUE; echo -en 'MYSQL ЛОГ. РЕЗ. КОПИРОВАНИЕ (mysqldump), BINLOG BACKUP (mysqlbinlog) С ВОЗМОЖНОСТЬЮ PIT ВОССТАНОВЛЕНИЯ.';$SETCOLOR_WHITE; echo -e
    $SETCOLOR_CYAN; echo -en '----------------------------------------------------------------------------------------------------';$SETCOLOR_WHITE; echo -e

    echo -en "DATE: "; $SETCOLOR_YELLOW; echo -en $MYSQL_BACKUP_DATE; $SETCOLOR_WHITE; echo -e
    echo -en "EXEC: "; $SETCOLOR_YELLOW; echo -en $SCRIPT_FILE $SCRIPT_ARGS; $SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "HOST: "; $SETCOLOR_YELLOW; echo -en $HOST; $SETCOLOR_WHITE; echo -e
    echo -en "DOM:  "; $SETCOLOR_YELLOW; echo -en $DOM; $SETCOLOR_WHITE; echo -e
    echo -en "IP:   "; $SETCOLOR_YELLOW; echo -en $IP; $SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "MYSQL_USER:       "; $SETCOLOR_YELLOW; echo -en $MYSQL_USER; $SETCOLOR_WHITE; echo -e
    echo -en "MYSQL_PASS:       "; $SETCOLOR_YELLOW; echo -en "******"; $SETCOLOR_WHITE; echo -e
    echo -en "MYSQL_HOST:       "; $SETCOLOR_YELLOW; echo -en $MYSQL_HOST; $SETCOLOR_WHITE; echo -e
    echo -en "MYSQL_PORT:       "; $SETCOLOR_YELLOW; echo -en $MYSQL_PORT; $SETCOLOR_WHITE; echo -e
    echo -en "MYSQL_DB:         "; $SETCOLOR_YELLOW; echo -en $MYSQL_DB; $SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "MYSQL_BACKUP_DIR: "; $SETCOLOR_YELLOW; echo -en $MYSQL_BACKUP_DIR'/current/'; $SETCOLOR_WHITE; echo -e
    echo -en "MYSQL_BACKUP_LOG: "; $SETCOLOR_YELLOW; echo -en $MYSQL_BACKUP_DIR'/current/'$MYSQL_BACKUP_LOG; $SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "MYSQL_BACKUP_DISK:           "; $SETCOLOR_YELLOW; echo -en $MYSQL_BACKUP_DISK; $SETCOLOR_WHITE; echo -e
    echo -en "MYSQL_BACKUP_DISK_THRESHOLD: "; $SETCOLOR_YELLOW; echo -en $MYSQL_BACKUP_DISK_THRESHOLD'%'; $SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "MAIL_SERVER:  "; $SETCOLOR_YELLOW; echo -en $MAIL_SERVER; $SETCOLOR_WHITE; echo -e
    echo -en "MAIL_FROM:    "; $SETCOLOR_YELLOW; echo -en $MAIL_FROM; $SETCOLOR_WHITE; echo -e
    echo -en "MAIL_TO:      "; $SETCOLOR_YELLOW; echo -en $MAIL_TO; $SETCOLOR_WHITE; echo -e
    echo -en "MAIL_VERBOSE: "; $SETCOLOR_YELLOW; echo -en $MAIL_VERBOSE; $SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "SCRIPT_FILE: "; $SETCOLOR_YELLOW; echo -en $SCRIPT_FILE; $SETCOLOR_WHITE; echo -e
    echo -en "SCRIPT_ARGS: "; $SETCOLOR_YELLOW; echo -en $SCRIPT_ARGS; $SETCOLOR_WHITE; echo -e
    echo -en "SCRIPT_LOG:  "; $SETCOLOR_YELLOW; echo -en $SCRIPT_LOG; $SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "MYSQL_DOCS: "; $SETCOLOR_BLUE; echo -en "https://dev.mysql.com/doc/refman/5.7/en/mysqldump.html"; $SETCOLOR_WHITE; echo -e
    echo -en "            "; $SETCOLOR_BLUE; echo -en "https://dev.mysql.com/doc/refman/5.7/en/mysqlbinlog.html"; $SETCOLOR_WHITE; echo -e
    echo -en "            "; $SETCOLOR_BLUE; echo -en "https://dev.mysql.com/doc/refman/5.7/en/mysqlbinlog-backup.html"; $SETCOLOR_WHITE; echo -e
    echo -en "            "; $SETCOLOR_BLUE; echo -en "https://dev.mysql.com/doc/refman/5.7/en/point-in-time-recovery.html"; $SETCOLOR_WHITE; echo -e
    echo -en "            "; $SETCOLOR_BLUE; echo -en "https://www.percona.com/blog/2013/02/08/how-to-createrestore-a-slave-using-gtid-replication-in-mysql-5-6/"; $SETCOLOR_WHITE; echo -e
    $SETCOLOR_CYAN; echo -en '----------------------------------------------------------------------------------------------------';$SETCOLOR_WHITE; echo -e

}

function HELP() {

    $SETCOLOR_BLUE; echo -en 'Требуемые параметры MySQL';$SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "Важно: "; $SETCOLOR_RED; echo -en "Бинырный лог на MySQL сервере должнен быть включен и формат бинарных логов должен быть ROW."; $SETCOLOR_WHITE; echo -e
    $SETCOLOR_RED; echo -en "       Важно, что бинарные логи можно распологать на выделенном диске, а не в раб. каталоге mysql."; $SETCOLOR_WHITE; echo -e
    echo -e
    $SETCOLOR_WHITE; echo -en "Добавьте следующие переменные в my.cnf в секцию [mysqld]"; $SETCOLOR_WHITE; echo -e

    $SETCOLOR_YELLOW;

cat << EOF

    server-id                      = 1
    # read-only                    = 1
    skip-slave-start               = 1
    # log-slave-updates            = 1

    log-bin                        = /var/lib/mysql/mysql-bin
    log-bin-index                  = /var/lib/mysql/mysql-bin.index
    max-binlog-size                = 1024M
    binlog-format                  = ROW
    binlog-row-image               = full
    expire-logs-days               = 14
    sync-binlog                    = 1

EOF

    $SETCOLOR_BLUE; echo -en 'Параметры запуска';$SETCOLOR_WHITE; echo -e
    echo -e
    $SETCOLOR_YELLOW; echo -en "$0 {full|log}";$SETCOLOR_WHITE; echo -e
    echo -e
    $SETCOLOR_BLUE; echo -en 'Лог. рез. копирования (mysqldump)';$SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "Важно: "; $SETCOLOR_RED; echo -en "Если включена GTID репликация, то при бэкапе с помощью mysqldump будет следующий WARNING - внимание на него не обращать."; $SETCOLOR_WHITE; echo -e

    $SETCOLOR_RED;

cat << EOF
       Warning: A partial dump from a server that has GTIDs will by default include the GTIDs of all transactions,
            even those that changed suppressed parts of the database. If you don't want to restore GTIDs,
            pass --set-gtid-purged=OFF. To make a complete dump, pass --all-databases --triggers --routines --events.

EOF

    $SETCOLOR_YELLOW;

cat << EOF
    mysqldump \\
     -u root \\
     -h localhost \\
     -p1qaz@WSX \\
     --default-character-set=utf8 \\
     --max-allowed-packet=1G \\
     --single-transaction \\
     --routines \\
     --events \\
     --triggers \\
     --flush-logs \\
     --master-data=2 \\
     --databases "db1" "db2" > ~/db.sql

EOF

    $SETCOLOR_BLUE; echo -en 'Опрелите MASTER_LOG_FILE и MASTER_LOG_POS';$SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "Важно: "; $SETCOLOR_RED; echo -en "Если включена GTID репликация, то в дамп файл будет также включена информация GTID state at the beginning of the backup."; $SETCOLOR_WHITE; echo -e

    $SETCOLOR_WHITE;
cat << EOF

Если выполнен бэкап одной БД, или если выполнен бэкап нескольких БД, или выполнен бэкап всех БД, не важно - 
в дамп файле будет указана только одна запись о MASTER_LOG_FILE и MASTER_LOG_POS (и GTID) - бинарный лог общий!

EOF

    $SETCOLOR_YELLOW; echo -en "    cat db.sql | grep -A 5 'Position to start replication or point-in-time recovery from'"; $SETCOLOR_WHITE; echo -e
    $SETCOLOR_CYAN; echo -en "    -- CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000002', MASTER_LOG_POS=194;"; $SETCOLOR_WHITE; echo -e
    echo -e
    $SETCOLOR_BLUE; echo -en 'Рез. копирование бинарных логов (mysqlbinlog)';$SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "Важно: "; $SETCOLOR_RED; echo -en "Перед каждым бэкапом бинарных логов делайте mysqladmin flush-logs и после чего бэкапте все бинарные логи, кроме самого нового."; $SETCOLOR_WHITE; echo -e

    $SETCOLOR_WHITE;
cat << EOF

Сделайте бэкапы всех бинарных логов начиная с бинарного лога, что указан в MASTER_LOG_FILE и до самого актуального.

EOF

    $SETCOLOR_YELLOW; echo -en "    cat /binlog/mysql-bin.index"; $SETCOLOR_GREEN; echo -en " # список всех бинарных логов"; $SETCOLOR_WHITE; echo -e
    echo -e

    $SETCOLOR_YELLOW;

cat << EOF
    mysqlbinlog \\
     --read-from-remote-server \\
     --host=localhost \\
     --raw --result-file=/backup/ \\
     mysql-bin.000002 \\
     mysql-bin.000003 \\
     mysql-bin.000004 \\
     mysql-bin.000005

EOF

    $SETCOLOR_BLUE; echo -en 'Процедура восстановления на момент времени';$SETCOLOR_WHITE; echo -e
    echo -e
    echo -en "Важно: "; $SETCOLOR_RED_BG; echo -en 'Вся необходимая информация для восстановления из текущей рез. копии находится в '$MYSQL_BACKUP_DIR'/current/'$MYSQL_BACKUP_LOG; $SETCOLOR_WHITE; echo -e
    echo -e
    $SETCOLOR_WHITE; echo -en "Предварительно удалите восстанавливаемую БД"; $SETCOLOR_WHITE; echo -e
    echo -e
    $SETCOLOR_YELLOW; echo -en "    DROP DATABASE testdb;"; $SETCOLOR_WHITE; echo -e
    echo -e

    $SETCOLOR_WHITE; echo -en "Создайте пустую БД и выполните в нее восстановление из Full бэкапа"; $SETCOLOR_WHITE; echo -e
    echo -e

    echo -en "Важно: "; $SETCOLOR_RED; echo -en "Поскльку дамп включает бэкап нескольких БД, то восстановление выполнить обязательно с аргументом one-database, в кот. указать восстанавливаемую БД!"; $SETCOLOR_WHITE; echo -e
    $SETCOLOR_RED;

cat << EOF
       Ошибка восстановления с включенныи GTID - https://www.percona.com/blog/2013/02/08/how-to-createrestore-a-slave-using-gtid-replication-in-mysql-5-6/
        ERROR 1840 (HY000) at line 33: @@GLOBAL.GTID_PURGED can only be set when @@GLOBAL.GTID_EXECUTED is empty.
        Решение, перед восстановлением (только на сервере где восстанавливаете, или мастер или славе) сбросьте пар-ы reset master;

EOF

    $SETCOLOR_YELLOW;
cat << EOF
    CREATE DATABASE testdb;
    mysql --one-database testdb < ~/db.sql

EOF

    $SETCOLOR_BLUE; echo -en 'Определите point-in-time для восстановления из бинарного лога';$SETCOLOR_WHITE; echo -e
    echo -e

    echo -en "Важно: "; $SETCOLOR_RED; echo -en "Стартовая позиция и первый бинарный файл должны соот-ь MASTER_LOG_FILE и MASTER_LOG_POS, что определены при фул бэкапе."; $SETCOLOR_WHITE; echo -e
    $SETCOLOR_RED;

cat << EOF
       Поскольку используется ROW формат бинарного лога, то чтобы определить точку восстановления, его надо декодировать.
       Из полученного SQL файла восстанавливать не рекомендуется, так как его формат изменен. Используйте этот файл только для анализа.
       Пар-р database заставит проиграть бинарные логи только для определенной в аргументе БД, а не для всех БД.

EOF

    $SETCOLOR_YELLOW;
cat << EOF
    mysqlbinlog \\
     --base64-output=DECODE-ROWS -vv \\
     --skip-gtids \\
     --start-position=194 \\
     --database=testdb \\
     mysql-bin.000002 \\
     mysql-bin.000003 \\
     mysql-bin.000004 \\
     mysql-bin.000005 \\
     > ~/db.decode.binlog.sql
     
    less db.decode.binlog.sql

EOF

    $SETCOLOR_WHITE;
cat << EOF
Например, нужно выполнить восстановление до выполнения INSERT INTO testdb.example VALUES (5, '5'); те не включать.
Согласно анализу данная транзакция была выполнена в 21:52:17

EOF

    $SETCOLOR_BLUE; echo -en 'Point-in-time восстановление'; $SETCOLOR_WHITE; echo -e
    echo -e

    echo -en "Важно: "; $SETCOLOR_RED; echo -en "При восстановление уберите пар-р декодирования base64-output и укажите PIT stop-datetime."; $SETCOLOR_WHITE; echo -e

    $SETCOLOR_YELLOW;
cat << EOF

    mysqlbinlog \\
     --skip-gtids \\
     --start-position=194 \\
     --stop-datetime="2018-07-02 21:52:16" \\
     --database=testdb \\
     mysql-bin.000002 \\
     mysql-bin.000003 \\
     mysql-bin.000004 \\
     mysql-bin.000005 \\
     | mysql

EOF

    $SETCOLOR_WHITE; echo -e

}

function ELAPSED_TIME_BEFORE() {

    DATE_BEFORE=$(date +%s)

}

function ELAPSED_TIME_AFTER() {

    DATE_AFTER="$(date +%s)"
    ELAPSED="$(expr $DATE_AFTER - $DATE_BEFORE)"
    HOURS=$(($ELAPSED / 3600))
    ELAPSED=$(($ELAPSED - $HOURS * 3600))
    MINUTES=$(($ELAPSED / 60))
    SECONDS=$(($ELAPSED - $MINUTES * 60))

    echo -e
    echo -en "Время выполнения: "; $SETCOLOR_RED;
    echo -en "$HOURS часов $MINUTES минут $SECONDS сек"
    $SETCOLOR_WHITE;
    echo -e; echo -e

}

function SEND_MAIL() {

    if [ -f $SCRIPT_LOG ]; then

        # cat "$SCRIPT_LOG" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"
        if [ "$(cat $SCRIPT_LOG | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | grep "BINARY LOG BACKUP")" ]; then

            local MAILSUB="MYSQL BINARY LOG BACKUP: ${HOST}"

        elif [ "$(cat $SCRIPT_LOG | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | grep "FULL LOGICAL BACKUP")" ]; then

            local MAILSUB="MYSQL FULL LOGICAL BACKUP: ${HOST}"

        fi

        if [ "$(cat $SCRIPT_LOG | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | grep -wi -e "warn" -e "warning" -e "err" -e "error" -e "fatal" -e "fail" -e "crit" -e "critical" -e "panic")" ]; then

            local MAILSUB=$MAILSUB' - FAIL'
            local EXEC_STATUS="FAIL"

        else

            local MAILSUB=$MAILSUB' - OK'
            local EXEC_STATUS="OK"

        fi

        # echo $MAILSUB
        # echo $MAIL_SERVER
        # echo $MAIL_FROM
        # echo $MAIL_TO
        # echo $SCRIPT_LOG

        if [ "$MAIL_VERBOSE" == "ONLY_FAIL" ] && [ "$EXEC_STATUS" == "FAIL" ]; then

            cat $SCRIPT_LOG | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | $(which mail) -v \
              -S smtp="smtp://$MAIL_SERVER" \
              -s "$MAILSUB" \
              -S from="$MAIL_FROM" \
              "$MAIL_TO"

            local SEND_MAIL_STATUS="$?"
            local MAIL_STATUS="YES"

        elif [ "$MAIL_VERBOSE" == "OK" ] && [ "$EXEC_STATUS" == "OK" ]; then

            cat $SCRIPT_LOG | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | $(which mail) -v \
              -S smtp="smtp://$MAIL_SERVER" \
              -s "$MAILSUB" \
              -S from="$MAIL_FROM" \
              "$MAIL_TO"

            local SEND_MAIL_STATUS="$?"
            local MAIL_STATUS="YES"

        elif [ "$MAIL_VERBOSE" == "FAIL_OK" ]; then

            cat $SCRIPT_LOG | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | $(which mail) -v \
              -S smtp="smtp://$MAIL_SERVER" \
              -s "$MAILSUB" \
              -S from="$MAIL_FROM" \
              "$MAIL_TO"

            local SEND_MAIL_STATUS="$?"
            local MAIL_STATUS="YES"

        else

            local MAIL_STATUS="NOT"

        fi

    fi

    if [ "$MAIL_STATUS" == "YES" ]; then

        if [ "$SEND_MAIL_STATUS" != "0" ]; then

            echo -e
            $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' SEND_MAIL ';  $SETCOLOR_GREEN; echo -en '# эл. письмо должно быть отправлено.'; $SETCOLOR_WHITE; echo -e

        else

            echo -e
            $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' SEND_MAIL ';  $SETCOLOR_GREEN; echo -en '# эл. письмо должно быть отправлено.'; $SETCOLOR_WHITE; echo -e

        fi

    fi

}

function CHECK_ROOT() {

    if [ "$(id -u)" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_ROOT ';  $SETCOLOR_GREEN; echo -en '# '$SCRIPT_FILE' должен быть выполнен от суперпользователя root.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' CHECK_ROOT ';  $SETCOLOR_GREEN; echo -en '# '$SCRIPT_FILE' должен быть выполнен от суперпользователя root.'; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - PROG NAME
function CHECK_PID() {

    if [ $(/usr/sbin/pidof -x $(which mysqldump)) ] || [ $(/usr/sbin/pidof -x $(which mysqlbinlog)) ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_PID ';  $SETCOLOR_GREEN; echo -en '# mysqldump и mysqlbinlog не должны выполняется в момент запуска скрипта.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' CHECK_PID ';  $SETCOLOR_GREEN; echo -en '# mysqldump и mysqlbinlog не должны выполняется в момент запуска скрипта.'; $SETCOLOR_WHITE; echo -e

    fi

    # if [ $(ps -ef | grep -i "$1" | grep -v "grep" | wc -l) -gt 0 ]; then

    #     echo "Error: CHECK_PID - $1 already running."
    #     return 1

    # else

    #     return 0

    # fi

}

# $1 - $MYSQL_BACKUP_DIR
function OLD_MYSQL_BACKUP_DIR() {

    local MYSQL_BACKUP_DIR=$1

    if [ -d $MYSQL_BACKUP_DIR/current ]; then

        mv $MYSQL_BACKUP_DIR/current $MYSQL_BACKUP_DIR/old.$MYSQL_BACKUP_DATE

    fi

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' OLD_MYSQL_BACKUP_DIR ';  $SETCOLOR_GREEN; echo -en '# '$MYSQL_BACKUP_DIR'/current должны быть переименована в '$MYSQL_BACKUP_DIR'/old.'$MYSQL_BACKUP_DATE'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' OLD_MYSQL_BACKUP_DIR ';  $SETCOLOR_GREEN; echo -en '# '$MYSQL_BACKUP_DIR'/current должны быть переименована в '$MYSQL_BACKUP_DIR'/old.'$MYSQL_BACKUP_DATE'.'; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - $MYSQL_BACKUP_DIR
function CHECK_MYSQL_BACKUP_DIR() {

    local MYSQL_BACKUP_DIR=$1

    if [ ! -d $MYSQL_BACKUP_DIR/current ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_BACKUP_DIR ';  $SETCOLOR_GREEN; echo -en '# '$MYSQL_BACKUP_DIR'/current должна сущестовать.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_BACKUP_DIR ';  $SETCOLOR_GREEN; echo -en '# '$MYSQL_BACKUP_DIR'/current должна сущестовать.'; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - $MYSQL_BACKUP_DIR
function CREATE_MYSQL_BACKUP_DIR() {

    local MYSQL_BACKUP_DIR=$1

    if [ ! -d $MYSQL_BACKUP_DIR/current ]; then

        mkdir -p $MYSQL_BACKUP_DIR/current

    fi

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CREATE_MYSQL_BACKUP_DIR ';  $SETCOLOR_GREEN; echo -en '# создание папки текущей рез. копии '$MYSQL_BACKUP_DIR'/current.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' CREATE_MYSQL_BACKUP_DIR ';  $SETCOLOR_GREEN; echo -en '# создание папки текущей рез. копии '$MYSQL_BACKUP_DIR'/current.'; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - $MYSQL_BACKUP_DISK
# $2 - $MYSQL_BACKUP_DISK_THRESHOLD
function CHECK_FREE_DISK_SPACE() {

    # local check_free_disk_space=$(df -k $1 | tail -n1 | awk -F " " '{print($4)}' | awk -F "%" '{print($1)}' | awk '{print($1)}') # AIX
    local check_free_disk_space=$(df -k $1 | tail -n1 | awk -F " " '{print($5)}' | awk -F "%" '{print($1)}' | awk '{print($1)}') # Linux
    # echo $check_free_disk_space

    if [ $(( 100 - check_free_disk_space )) -ge $2 ]; then

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' CHECK_FREE_DISK_SPACE ';  $SETCOLOR_GREEN; echo -en '# свободное место на диске хранения рез. копий '$(( 100 - check_free_disk_space ))'% должно быть > чем threshold '$2'%.'; $SETCOLOR_WHITE; echo -e

    else

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_FREE_DISK_SPACE ';  $SETCOLOR_GREEN; echo -en '# свободное место на диске хранения рез. копий '$(( 100 - check_free_disk_space ))'% должно быть > чем threshold '$2'%.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

}

# $1 - $MYSQL_USER
# $2 - $MYSQL_PASS
# $3 - $MYSQL_HOST
# $4 - $MYSQL_PORT
function CHECK_MYSQL_CON() {

    local MYSQL_USER=$1
    local MYSQL_PASS=$2
    local MYSQL_HOST=$3
    local MYSQL_PORT=$4

    $(which mysql) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" -s -N -e "exit" 2> /dev/null

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_CON ';  $SETCOLOR_GREEN; echo -en '# проверка подключения к mysql серверу '$MYSQL_HOST':'$MYSQL_PORT'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_CON ';  $SETCOLOR_GREEN; echo -en '# проверка подключения к mysql серверу '$MYSQL_HOST':'$MYSQL_PORT'.'; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - $MYSQL_USER
# $2 - $MYSQL_PASS
# $3 - $MYSQL_HOST
# $4 - $MYSQL_PORT
function CHECK_MYSQL_VAR() {

    local MYSQL_USER=$1
    local MYSQL_PASS=$2
    local MYSQL_HOST=$3
    local MYSQL_PORT=$4

    local CHECK_MYSQL_VAR_COUNT=0

    local MYSQL_SERVER_ID=$($(which mysql) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" -s -N -e "select @@global.server_id;" 2> /dev/null)
    local MYSQL_LOG_BIN=$($(which mysql) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" -s -N -e "select @@global.log_bin;" 2> /dev/null)
    local MYSQL_LOG_BIN_BASENAME=$($(which mysql) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" -s -N -e "select @@global.log_bin_basename;" 2> /dev/null)
    local MYSQL_LOG_BIN_INDEX=$($(which mysql) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" -s -N -e "select @@global.log_bin_index;" 2> /dev/null)
    local MYSQL_BINLOG_FORMAT=$($(which mysql) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" -s -N -e "select @@global.binlog_format;" 2> /dev/null)

    if [ -z $MYSQL_SERVER_ID ] || [ "$MYSQL_SERVER_ID" == "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_VAR ';  $SETCOLOR_GREEN; echo -en '# server_id='$MYSQL_SERVER_ID' ошибка проверки значения переменной.'; $SETCOLOR_WHITE; echo -e
        local CHECK_MYSQL_VAR_COUNT=$(( CHECK_MYSQL_VAR_COUNT + 1 ))

    fi

    if [ -z $MYSQL_LOG_BIN ] || [ "$MYSQL_LOG_BIN" == "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_VAR ';  $SETCOLOR_GREEN; echo -en '# log_bin='$MYSQL_LOG_BIN' ошибка проверки значения переменной.'; $SETCOLOR_WHITE; echo -e
        local CHECK_MYSQL_VAR_COUNT=$(( CHECK_MYSQL_VAR_COUNT + 1 ))

    fi

    if [ -z $MYSQL_LOG_BIN_BASENAME ] || [ "$MYSQL_LOG_BIN_BASENAME" == "NULL" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_VAR ';  $SETCOLOR_GREEN; echo -en '# log_bin_basename='$MYSQL_LOG_BIN_BASENAME' ошибка проверки значения переменной'; $SETCOLOR_WHITE; echo -e
        local CHECK_MYSQL_VAR_COUNT=$(( CHECK_MYSQL_VAR_COUNT + 1 ))

    fi

    if [ -z $MYSQL_LOG_BIN_INDEX ] || [ "$MYSQL_LOG_BIN_INDEX" == "NULL" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_VAR ';  $SETCOLOR_GREEN; echo -en '# log_bin_index='$MYSQL_LOG_BIN_INDEX' ошибка проверки значения переменной.'; $SETCOLOR_WHITE; echo -e
        local CHECK_MYSQL_VAR_COUNT=$(( CHECK_MYSQL_VAR_COUNT + 1 ))

    fi

    if [ -z $MYSQL_BINLOG_FORMAT ] || [ "$MYSQL_BINLOG_FORMAT" != "ROW" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_VAR ';  $SETCOLOR_GREEN; echo -en '# binlog_format='$MYSQL_BINLOG_FORMAT' ошибка проверки значения переменной.'; $SETCOLOR_WHITE; echo -e
        local CHECK_MYSQL_VAR_COUNT=$(( CHECK_MYSQL_VAR_COUNT + 1 ))

    fi

    if [ $CHECK_MYSQL_VAR_COUNT -gt 0 ]; then

        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_VAR ';  $SETCOLOR_GREEN; echo -en '# binlog должнен быть включен и формат binlog должен быть row.'; $SETCOLOR_WHITE; echo -e
        $SETCOLOR_CYAN; echo -en '     MYSQL_SERVER_ID='$MYSQL_SERVER_ID; $SETCOLOR_WHITE; echo -e
        $SETCOLOR_CYAN; echo -en '     MYSQL_LOG_BIN='$MYSQL_LOG_BIN; $SETCOLOR_WHITE; echo -e
        $SETCOLOR_CYAN; echo -en '     MYSQL_LOG_BIN_BASENAME='$MYSQL_LOG_BIN_BASENAME; $SETCOLOR_WHITE; echo -e
        $SETCOLOR_CYAN; echo -en '     MYSQL_LOG_BIN_INDEX='$MYSQL_LOG_BIN_INDEX; $SETCOLOR_WHITE; echo -e
        $SETCOLOR_CYAN; echo -en '     MYSQL_BINLOG_FORMAT='$MYSQL_BINLOG_FORMAT; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - $MYSQL_USER
# $2 - $MYSQL_PASS
# $3 - $MYSQL_HOST
# $4 - $MYSQL_PORT
# $5 - $MYSQL_DB
function CHECK_MYSQL_DB() {

    local MYSQL_USER=$1
    local MYSQL_PASS=$2
    local MYSQL_HOST=$3
    local MYSQL_PORT=$4
    local MYSQL_DB=$5

    local CHECK_MYSQL_DB_COUNT=0

    local MYSQL_DB_ARR=$(echo $MYSQL_DB | tr "," "\n")
    # echo $MYSQL_DB_ARR

    if [ -z "$MYSQL_DB_ARR" ] && [ "$MYSQL_DB_ARR" == "" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_DB ';  $SETCOLOR_GREEN; echo -en '# база данных должна сущестовать.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    for DB in $MYSQL_DB_ARR; do

        local CHECK_MYSQL_DB_EXIST=$($(which mysql) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" -s -N -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$DB';" 2> /dev/null)
        local CHECK_MYSQL_DB_INNODB=$($(which mysql) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" -s -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DB' and ENGINE<>'InnoDB';" 2> /dev/null)

        # echo $DB
        # echo $CHECK_MYSQL_DB_EXIST
        # echo $CHECK_MYSQL_DB_INNODB

        if [ -z "$CHECK_MYSQL_DB_EXIST" ] || [ "$CHECK_MYSQL_DB_EXIST" == "" ]; then

            $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_DB ';  $SETCOLOR_GREEN; echo -en '# база данных '$DB' должна существовать.'; $SETCOLOR_WHITE; echo -e
            local CHECK_MYSQL_DB_COUNT=$(( CHECK_MYSQL_DB_COUNT + 1 ))

        else

            if [ -z "$CHECK_MYSQL_DB_INNODB" ] || [ "$CHECK_MYSQL_DB_INNODB" == "" ]; then

                $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_DB ';  $SETCOLOR_GREEN; echo -en '# получить список всех таблиц и их тип sorage engeene для базы данных '$DB; $SETCOLOR_WHITE; echo -e
                local CHECK_MYSQL_DB_COUNT=$(( CHECK_MYSQL_DB_COUNT + 1 ))

            else

                if [ $CHECK_MYSQL_DB_INNODB -gt 0 ]; then

                    $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_DB ';  $SETCOLOR_GREEN; echo -en '# все таблицы базы данных '$DB' должны иметь тип storage engeene innodb.'; $SETCOLOR_WHITE; echo -e
                    local CHECK_MYSQL_DB_COUNT=$(( CHECK_MYSQL_DB_COUNT + 1 ))

                fi

            fi

        fi

    done

    if [ $CHECK_MYSQL_DB_COUNT -gt 0 ]; then

        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' CHECK_MYSQL_DB ';  $SETCOLOR_GREEN; echo -en '# все таблицы в базах данных '$MYSQL_DB' должны иметь тип storage engeene innodb.'; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - $MYSQL_USER
# $2 - $MYSQL_PASS
# $3 - $MYSQL_HOST
# $4 - $MYSQL_PORT
# $5 - $MYSQL_DB
# $6 - $MYSQL_BACKUP_DIR
# $7 - $MYSQL_BACKUP_LOG
# $8 - $MYSQL_BACKUP_DATE
function FULL_LOGICAL_BACKUP() {

    local MYSQL_USER=$1
    local MYSQL_PASS=$2
    local MYSQL_HOST=$3
    local MYSQL_PORT=$4
    local MYSQL_DB=$5
    local MYSQL_BACKUP_DIR=$6
    local MYSQL_BACKUP_LOG=$7
    local MYSQL_BACKUP_DATE=$8

    local MYSQL_DB_ARR=$(echo $MYSQL_DB | tr "," "\n")
    # echo $MYSQL_DB_ARR

    if [ -z "$MYSQL_DB_ARR" ] && [ "$MYSQL_DB_ARR" == "" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' FULL_LOGICAL_BACKUP ';  $SETCOLOR_GREEN; echo -en '# список баз данных должен быть определен.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    local MYSQLDUMP_CRED=$MYSQL_BACKUP_DIR/current/cred.cnf
    local MYSQLDUMP_BACKUP_FILE=$MYSQL_BACKUP_DIR/current/backup.sql.gz

    echo "[client]"                  > $MYSQLDUMP_CRED
    echo "user=$MYSQL_USER"         >> $MYSQLDUMP_CRED
    echo "password=$MYSQL_PASS"     >> $MYSQLDUMP_CRED
    echo "host=$MYSQL_HOST"         >> $MYSQLDUMP_CRED
    echo "port=$MYSQL_PORT"         >> $MYSQLDUMP_CRED

    $(which mysqldump) \
      --defaults-extra-file="$MYSQLDUMP_CRED" \
      --default-character-set=utf8 \
      --max-allowed-packet=1G \
      --single-transaction \
      --routines \
      --events \
      --triggers \
      --master-data=2 \
      --flush-logs \
      --databases $MYSQL_DB_ARR | $(which gzip) -9 > "$MYSQLDUMP_BACKUP_FILE"
      # --all-databases | $(which gzip) -9 > "$MYSQLDUMP_BACKUP_FILE"
      # --user="$MYSQL_USER" \
      # --password="$MYSQL_PASS" \
      # --host="$MYSQL_HOST" \
      # --port="$MYSQL_PORT" \
      # "$4" > $5/$4.$6.sql

    if [ "$?" != "0" ]; then

        rm -f $MYSQLDUMP_CRED
        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' FULL_LOGICAL_BACKUP ';  $SETCOLOR_GREEN; echo -en '# рез. копирование базы данных '$MYSQL_DB' с помощью mysqldump.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        rm -f $MYSQLDUMP_CRED
        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' FULL_LOGICAL_BACKUP ';  $SETCOLOR_GREEN; echo -en '# рез. копирование базы данных '$MYSQL_DB' с помощью mysqldump.'; $SETCOLOR_WHITE; echo -e

        echo 'MYSQL_USER='$MYSQL_USER          > $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
        echo 'MYSQL_PASS='$MYSQL_PASS         >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
        echo 'MYSQL_HOST='$MYSQL_HOST         >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
        echo 'MYSQL_PORT='$MYSQL_PORT         >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
        echo 'MYSQL_DB='$MYSQL_DB             >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
        echo 'BACKUP_DATE='$MYSQL_BACKUP_DATE >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
        echo '--------------------'                          >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
        # : > $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG

    fi

}

# $1 - $MYSQL_BACKUP_DIR
# $2 - $MYSQL_BACKUP_LOG
function LOG_START_POSITION() {

    local MYSQL_BACKUP_DIR=$1
    local MYSQL_BACKUP_LOG=$2

    local STR_LOG_START_POSITION=$($(which gunzip) < $MYSQL_BACKUP_DIR/current/*.sql.gz | grep 'Position to start replication or point-in-time recovery from' -A 5 | grep 'MASTER')

    if [ ! -n "$STR_LOG_START_POSITION" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' LOG_START_POSITION ';  $SETCOLOR_GREEN; echo -en '# определение MASTER_LOG_FILE и MASTER_LOG_POS '$STR_LOG_START_POSITION'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    # CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000021', MASTER_LOG_POS=154;
    local MASTER_LOG_FILE_TMP=$(echo $STR_LOG_START_POSITION | awk -F " " '{print($5)}' | awk -F "=" '{print($2)}')
    local MASTER_LOG_POS_TMP=$(echo $STR_LOG_START_POSITION | awk -F " " '{print($6)}' | awk -F "=" '{print($2)}')
    local MASTER_LOG_FILE=$(echo "${MASTER_LOG_FILE_TMP//[\',;]/}")
    local MASTER_LOG_POS=$(echo "${MASTER_LOG_POS_TMP//[\',;]/}")

    if [ ! -n "$MASTER_LOG_FILE" ] || [ ! -n "$MASTER_LOG_POS" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' LOG_START_POSITION ';  $SETCOLOR_GREEN; echo -en '# определение MASTER_LOG_FILE '$MASTER_LOG_FILE' и MASTER_LOG_POS '$MASTER_LOG_POS'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' LOG_START_POSITION ';  $SETCOLOR_GREEN; echo -en '# определение MASTER_LOG_FILE '$MASTER_LOG_FILE' и MASTER_LOG_POS '$MASTER_LOG_POS'.'; $SETCOLOR_WHITE; echo -e

        echo 'MASTER_LOG_FILE='$MASTER_LOG_FILE >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
        echo 'MASTER_LOG_POS='$MASTER_LOG_POS   >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
        echo '--------------------'                            >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG

    fi

}

# $1 - $MYSQL_USER
# $2 - $MYSQL_PASS
# $3 - $MYSQL_HOST
# $4 - $MYSQL_PORT
function FLUSH_LOGS () {

    local MYSQL_USER=$1
    local MYSQL_PASS=$2
    local MYSQL_HOST=$3
    local MYSQL_PORT=$4

    $(which mysqladmin) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" flush-logs 2> /dev/null

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' FLUSH_LOGS ';  $SETCOLOR_GREEN; echo -en '# выполнение сброса (flush) бинарных и всех других логов на диск перед выполнением бэкапа.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' FLUSH_LOGS ';  $SETCOLOR_GREEN; echo -en '# выполнение сброса (flush) бинарных и всех других логов на диск перед выполнением бэкапа.'; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - $MYSQL_USER
# $2 - $MYSQL_PASS
# $3 - $MYSQL_HOST
# $4 - $MYSQL_PORT
function LOG_INDEX_FILE () {

    local MYSQL_USER=$1
    local MYSQL_PASS=$2
    local MYSQL_HOST=$3
    local MYSQL_PORT=$4

    local LOG_INDEX_FILE=$($(which mysql) --user="$MYSQL_USER" --password="$MYSQL_PASS" --host="$MYSQL_HOST" --port="$MYSQL_PORT" -s -N -e "select @@global.log_bin_index;" 2> /dev/null)

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' LOG_INDEX_FILE ';  $SETCOLOR_GREEN; echo -en '# определение индексного файла бинарных логов '$LOG_INDEX_FILE'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    echo $LOG_INDEX_FILE

}

# $1 - $MYSQL_BACKUP_DIR
# $2 - $MYSQL_BACKUP_LOG
function MASTER_LOG_FILE () {

    local MYSQL_BACKUP_DIR=$1
    local MYSQL_BACKUP_LOG=$2

    local MASTER_LOG_FILE=$(cat $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG | grep MASTER_LOG_FILE | awk -F "=" '{print($2)}')

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' MASTER_LOG_FILE ';  $SETCOLOR_GREEN; echo -en '# определение MASTER_LOG_FILE '$MASTER_LOG_FILE'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    echo $MASTER_LOG_FILE

}

# $1 - $MYSQL_BACKUP_DIR
# $2 - $MYSQL_BACKUP_LOG
function FIRST_LOG_FILE () {

    local MYSQL_BACKUP_DIR=$1
    local MYSQL_BACKUP_LOG=$2

    local FIRST_LOG_FILE=$(cat $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG | tail -n 1)

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' FIRST_LOG_FILE ';  $SETCOLOR_GREEN; echo -en '# определение названия файла бинарного лога, начиная с кот. выполнить рез. копирование '$FIRST_LOG_FILE'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    if [ "$FIRST_LOG_FILE" == "--------------------" ]; then

        # local FIRST_LOG_FILE=$(MASTER_LOG_FILE $MYSQL_BACKUP_DIR $MYSQL_BACKUP_LOG)
        local FIRST_LOG_FILE=

    fi

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' FIRST_LOG_FILE ';  $SETCOLOR_GREEN; echo -en '# определение названия файла бинарного лога, начиная с кот. выполнить рез. копирование '$FIRST_LOG_FILE'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    echo $FIRST_LOG_FILE

}

# $1 - $MYSQL_USER
# $2 - $MYSQL_PASS
# $3 - $MYSQL_HOST
# $4 - $MYSQL_PORT
function LAST_LOG_FILE () {

    local MYSQL_USER=$1
    local MYSQL_PASS=$2
    local MYSQL_HOST=$3
    local MYSQL_PORT=$4

    local LOG_INDEX_FILE=$(LOG_INDEX_FILE $MYSQL_USER $MYSQL_PASS $MYSQL_HOST $MYSQL_PORT)
    # echo 'LOG_INDEX_FILE='$LOG_INDEX_FILE

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' LAST_LOG_FILE ';  $SETCOLOR_GREEN; echo -en '# определение индексного файла бинарных логов '$LOG_INDEX_FILE'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    if [ ! -f $LOG_INDEX_FILE ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' LAST_LOG_FILE ';  $SETCOLOR_GREEN; echo -en '# определение индексного файла бинарных логов '$LOG_INDEX_FILE'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    local LAST_LOG_FILE=$(cat $LOG_INDEX_FILE | head -n -1 | tail -n 1)

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' LAST_LOG_FILE ';  $SETCOLOR_GREEN; echo -en '# определение названия файла бинарного лога, до кот. выполнить рез. копирование '$LAST_LOG_FILE'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    echo $(basename $LAST_LOG_FILE)

}

# $1 - $MYSQL_USER
# $2 - $MYSQL_PASS
# $3 - $MYSQL_HOST
# $4 - $MYSQL_PORT
# $5 - $MYSQL_BACKUP_DIR
# $6 - $MYSQL_BACKUP_LOG
function LOG_FILE_STR() {

    local MYSQL_USER=$1
    local MYSQL_PASS=$2
    local MYSQL_HOST=$3
    local MYSQL_PORT=$4
    local MYSQL_BACKUP_DIR=$5
    local MYSQL_BACKUP_LOG=$6

    local FIRST_LOG_FILE_COUNT=0
    local LAST_LOG_FILE_COUNT=0

    local LOG_INDEX_FILE=$(LOG_INDEX_FILE $MYSQL_USER $MYSQL_PASS $MYSQL_HOST $MYSQL_PORT)
    local MASTER_LOG_FILE=$(MASTER_LOG_FILE $MYSQL_BACKUP_DIR $MYSQL_BACKUP_LOG)
    local FIRST_LOG_FILE=$(FIRST_LOG_FILE $MYSQL_BACKUP_DIR $MYSQL_BACKUP_LOG)
    local LAST_LOG_FILE=$(LAST_LOG_FILE $MYSQL_USER $MYSQL_PASS $MYSQL_HOST $MYSQL_PORT)

    # echo 'LOG_INDEX_FILE='$LOG_INDEX_FILE
    # echo 'MASTER_LOG_FILE='$MASTER_LOG_FILE
    # echo 'FIRST_LOG_FILE='$FIRST_LOG_FILE
    # echo 'LAST_LOG_FILE='$LAST_LOG_FILE

    for LOG_FILE in $(cat $LOG_INDEX_FILE); do

        # echo $LOG_FILE
        if [ -z "$FIRST_LOG_FILE" ] || [ "$FIRST_LOG_FILE" == "" ]; then

            if [ "$(basename $LOG_FILE)" == "$MASTER_LOG_FILE" ]; then

                local FIRST_LOG_FILE=$MASTER_LOG_FILE
                local FIRST_LOG_FILE_COUNT=$(( FIRST_LOG_FILE_COUNT + 1 ))

            fi

        else

            if [ "$(basename $LOG_FILE)" == "$FIRST_LOG_FILE" ]; then

                local FIRST_LOG_FILE_COUNT=$(( FIRST_LOG_FILE_COUNT + 1 ))
                continue

            fi

        fi

        if [ "$(basename $LOG_FILE)" == "$LAST_LOG_FILE" ]; then

            local LAST_LOG_FILE_COUNT=$(( LAST_LOG_FILE_COUNT + 1 ))

        fi

        if [ $LAST_LOG_FILE_COUNT -gt 0 ]; then

            # echo $(basename $LOG_FILE)
            local LOG_FILE_STR=$(echo $LOG_FILE_STR $(basename $LOG_FILE))
            echo $(basename $LOG_FILE) >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG
            break

        fi

        if [ $FIRST_LOG_FILE_COUNT -gt 0 ]; then

            # echo $(basename $LOG_FILE)
            local LOG_FILE_STR=$(echo $LOG_FILE_STR $(basename $LOG_FILE))
            echo $(basename $LOG_FILE) >> $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG

        fi

    done

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' LOG_FILE_STR ';  $SETCOLOR_GREEN; echo -en '# список бинарных лог файлов '$LOG_FILE_STR' начиниая с '$FIRST_LOG_FILE' и заканчивая '$LAST_LOG_FILE'.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    echo $LOG_FILE_STR

}

# $1 - $MYSQL_USER
# $2 - $MYSQL_PASS
# $3 - $MYSQL_HOST
# $4 - $MYSQL_PORT
# $5 - $MYSQL_BACKUP_DIR
# $6 - $MYSQL_BACKUP_LOG
function BACKUP_LOGS() {

    local MYSQL_USER=$1
    local MYSQL_PASS=$2
    local MYSQL_HOST=$3
    local MYSQL_PORT=$4
    local MYSQL_BACKUP_DIR=$5
    local MYSQL_BACKUP_LOG=$6

    local LOG_FILE_STR=$(LOG_FILE_STR $MYSQL_USER $MYSQL_PASS $MYSQL_HOST $MYSQL_PORT $MYSQL_BACKUP_DIR $MYSQL_BACKUP_LOG)

    $(which mysqlbinlog) \
      --user="$MYSQL_USER" \
      --password="$MYSQL_PASS" \
      --host="$MYSQL_HOST" \
      --port="$MYSQL_PORT" \
      --read-from-remote-server \
      --raw \
      --verify-binlog-checksum \
      --result-file="$MYSQL_BACKUP_DIR"/current/ \
      $LOG_FILE_STR 2> /dev/null

    if [ "$?" != "0" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' BACKUP_LOGS ';  $SETCOLOR_GREEN; echo -en '# рез. копирования бинарных логов с помощью mysqlbinlog.'; $SETCOLOR_WHITE; echo -e
        $SETCOLOR_CYAN; echo -en '     LOG_FILE_STR='$LOG_FILE_STR; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' BACKUP_LOGS ';  $SETCOLOR_GREEN; echo -en '# рез. копирования бинарных логов с помощью mysqlbinlog.'; $SETCOLOR_WHITE; echo -e
        $SETCOLOR_CYAN; echo -en '     LOG_FILE_STR='$LOG_FILE_STR; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - $MYSQL_BACKUP_DIR
# $2 - $MYSQL_BACKUP_LOG
function CHECK_BACKUP_LOGS() {

    local MYSQL_BACKUP_DIR=$1
    local MYSQL_BACKUP_LOG=$2

    if [ ! -f "$MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG" ]; then

        $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_BACKUP_LOGS ';  $SETCOLOR_GREEN; echo -en '# backup log '$MYSQL_BACKUP_DIR'/current/'$MYSQL_BACKUP_LOG' должен существовать.'; $SETCOLOR_WHITE; echo -e
        SEND_MAIL; exit 1

    fi

    local CHECK_BACKUP_LOGS_COUNT=0
    local CHECK_BACKUP_LOGS_COUNT_ERR=0

    for BACKUP_LOG in $(cat $MYSQL_BACKUP_DIR/current/$MYSQL_BACKUP_LOG); do

        if [ $CHECK_BACKUP_LOGS_COUNT -ne 2 ]; then

            if [ "$BACKUP_LOG" == "--------------------" ]; then

                local CHECK_BACKUP_LOGS_COUNT=$(( CHECK_BACKUP_LOGS_COUNT + 1 ))
                continue

            fi

        else

            if [ ! -f "$MYSQL_BACKUP_DIR/current/$BACKUP_LOG" ]; then

                $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' CHECK_BACKUP_LOGS ';  $SETCOLOR_GREEN; echo -en '# binlog '$MYSQL_BACKUP_DIR'/current/'$BACKUP_LOG' должен существовать.'; $SETCOLOR_WHITE; echo -e
                local CHECK_BACKUP_LOGS_COUNT_ERR=$(( CHECK_BACKUP_LOGS_COUNT_ERR + 1 ))

            fi

        fi

    done

    if [ $CHECK_BACKUP_LOGS_COUNT_ERR -gt 0 ]; then

        SEND_MAIL; exit 1

    else

        $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' CHECK_BACKUP_LOGS ';  $SETCOLOR_GREEN; echo -en '# все бинарные логи в рез. копии должны сущестовать.'; $SETCOLOR_WHITE; echo -e

    fi

}

# $1 - $MYSQL_BACKUP_DIR
# $2 - $MYSQL_BACKUP_ROT
function DEL_OLD_BACKUP() {

    local MYSQL_BACKUP_DIR=$1
    local MYSQL_BACKUP_ROT=$2

    # local MYSQL_BACKUP_OLD_DEL=$2
    # for DEL_DIR in $(ls -1tr $MYSQL_BACKUP_DIR | grep '^old' | tail -n $MYSQL_BACKUP_OLD_DEL); do
    #     if [ -d "$MYSQL_BACKUP_DIR/$DEL_DIR" ]; then
    #         echo "$MYSQL_BACKUP_DIR/$DEL_DIR"
    #     fi
    # done

    for DEL_DIR in $(find $MYSQL_BACKUP_DIR -type d -name "*old.*" -mmin +$MYSQL_BACKUP_ROT 2>/dev/null); do

        rm -rf "$DEL_DIR"

        if [ "$?" != "0" ]; then

            $SETCOLOR_RED_BG; echo -en 'FAIL'; $SETCOLOR_WHITE; echo -en ' DEL_OLD_BACKUP ';  $SETCOLOR_GREEN; echo -en '# удаление бэкапа '$DEL_DIR' старше чем '$MYSQL_BACKUP_ROT' минут.'; $SETCOLOR_WHITE; echo -e
            SEND_MAIL; exit 1

        else

            $SETCOLOR_GREEN_BG; echo -en ' OK '; $SETCOLOR_WHITE; echo -en ' DEL_OLD_BACKUP ';  $SETCOLOR_GREEN; echo -en '# удаление бэкапа '$DEL_DIR' старше чем '$MYSQL_BACKUP_ROT' минут.'; $SETCOLOR_WHITE; echo -e

        fi

    done

}

# ----------------------------------------------------------------------------------------------------
# MAIN

# LOG
# RUN
# ELAPSED_TIME_BEFORE
# ELAPSED_TIME_AFTER
# SEND_MAIL
# CHECK_ROOT
# CHECK_PID
# OLD_MYSQL_BACKUP_DIR
# CHECK_MYSQL_BACKUP_DIR
# CREATE_MYSQL_BACKUP_DIR
# CHECK_FREE_DISK_SPACE
# CHECK_MYSQL_CON
# CHECK_MYSQL_VAR
# CHECK_MYSQL_DB
# FULL_LOGICAL_BACKUP
# LOG_START_POSITION
# FLUSH_LOGS
# LOG_INDEX_FILE
# MASTER_LOG_FILE
# FIRST_LOG_FILE
# LAST_LOG_FILE
# LOG_FILE_STR
# BACKUP_LOGS
# CHECK_BACKUP_LOGS
# DEL_OLD_BACKUP
# ----------------------------------------------------------------------------------------------------

LOG; RUN

case $1 in

    full)

        $SETCOLOR_WHITE; echo -en 'FULL LOGICAL BACKUP'; $SETCOLOR_WHITE; echo -e; echo -e

        ELAPSED_TIME_BEFORE; # sleep 2
        CHECK_ROOT; CHECK_PID
        CHECK_FREE_DISK_SPACE "$MYSQL_BACKUP_DISK" "$MYSQL_BACKUP_DISK_THRESHOLD"
        CHECK_MYSQL_CON "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_HOST" "$MYSQL_PORT"
        CHECK_MYSQL_VAR "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_HOST" "$MYSQL_PORT"
        CHECK_MYSQL_DB "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_DB"
        OLD_MYSQL_BACKUP_DIR "$MYSQL_BACKUP_DIR"
        CREATE_MYSQL_BACKUP_DIR "$MYSQL_BACKUP_DIR"
        FULL_LOGICAL_BACKUP "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_DB" "$MYSQL_BACKUP_DIR" "$MYSQL_BACKUP_LOG" "$MYSQL_BACKUP_DATE"
        LOG_START_POSITION "$MYSQL_BACKUP_DIR" "$MYSQL_BACKUP_LOG"
        DEL_OLD_BACKUP "$MYSQL_BACKUP_DIR" "$MYSQL_BACKUP_ROT"
        ELAPSED_TIME_AFTER
        SEND_MAIL
        exit 0

        ;;

    log)

        $SETCOLOR_WHITE; echo -en 'BINARY LOG BACKUP'; $SETCOLOR_WHITE; echo -e; echo -e

        ELAPSED_TIME_BEFORE; # sleep 2
        CHECK_ROOT; CHECK_PID
        CHECK_MYSQL_BACKUP_DIR "$MYSQL_BACKUP_DIR"
        CHECK_FREE_DISK_SPACE "$MYSQL_BACKUP_DISK" "$MYSQL_BACKUP_DISK_THRESHOLD"
        CHECK_MYSQL_CON "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_HOST" "$MYSQL_PORT"
        CHECK_MYSQL_VAR "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_HOST" "$MYSQL_PORT"
        CHECK_MYSQL_DB "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_DB"
        FLUSH_LOGS "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_HOST" "$MYSQL_PORT"

        # MASTER_LOG_FILE $MYSQL_BACKUP_DIR $MYSQL_BACKUP_LOG
        # LOG_INDEX_FILE $MYSQL_USER $MYSQL_PASS $MYSQL_HOST $MYSQL_PORT
        # FIRST_LOG_FILE $MYSQL_BACKUP_DIR $MYSQL_BACKUP_LOG
        # LAST_LOG_FILE $MYSQL_USER $MYSQL_PASS $MYSQL_HOST $MYSQL_PORT
        # LOG_FILE_STR $MYSQL_USER $MYSQL_PASS $MYSQL_HOST $MYSQL_PORT $MYSQL_BACKUP_DIR $MYSQL_BACKUP_LOG

        BACKUP_LOGS "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_BACKUP_DIR" "$MYSQL_BACKUP_LOG"
        CHECK_BACKUP_LOGS "$MYSQL_BACKUP_DIR" "$MYSQL_BACKUP_LOG"
        ELAPSED_TIME_AFTER
        SEND_MAIL
        exit 0

        ;;

    *)

        HELP

esac

exit 0
