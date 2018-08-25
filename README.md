## MYSQL ЛОГ. РЕЗ. КОПИРОВАНИЕ (mysqldump), BINLOG BACKUP (mysqlbinlog) С ВОЗМОЖНОСТЬЮ PIT ВОССТАНОВЛЕНИЯ.

#### Требуемые параметры MySQL

Важно: Бинырный лог на MySQL сервере должнен быть включен и формат бинарных логов должен быть ROW.
       Важно, что бинарные логи можно распологать на выделенном диске, а не в раб. каталоге mysql.

Добавьте следующие переменные в my.cnf в секцию [mysqld]

```console
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
```

#### Параметры запуска

```console
./mysql.logical.backup.with.pit.restore.sh {full|log}
```

#### Лог. рез. копирования (mysqldump)

Важно: Если включена GTID репликация, то при бэкапе с помощью mysqldump будет следующий WARNING - внимание на него не обращать.
       Warning: A partial dump from a server that has GTIDs will by default include the GTIDs of all transactions,
            even those that changed suppressed parts of the database. If you don't want to restore GTIDs,
            pass --set-gtid-purged=OFF. To make a complete dump, pass --all-databases --triggers --routines --events.

```console
    mysqldump \
     -u root \
     -h localhost \
     -p1qaz@WSX \
     --default-character-set=utf8 \
     --max-allowed-packet=1G \
     --single-transaction \
     --routines \
     --events \
     --triggers \
     --flush-logs \
     --master-data=2 \
     --databases "db1" "db2" > ~/db.sql
```

#### Опрелите MASTER_LOG_FILE и MASTER_LOG_POS

Важно: Если включена GTID репликация, то в дамп файл будет также включена информация GTID state at the beginning of the backup.

Если выполнен бэкап одной БД, или если выполнен бэкап нескольких БД, или выполнен бэкап всех БД, не важно -
в дамп файле будет указана только одна запись о MASTER_LOG_FILE и MASTER_LOG_POS (и GTID) - бинарный лог общий!

```console
    cat db.sql | grep -A 5 'Position to start replication or point-in-time recovery from'
    -- CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000002', MASTER_LOG_POS=194;
```

#### Рез. копирование бинарных логов (mysqlbinlog)

Важно: Перед каждым бэкапом бинарных логов делайте mysqladmin flush-logs и после чего бэкапте все бинарные логи, кроме самого нового.

Сделайте бэкапы всех бинарных логов начиная с бинарного лога, что указан в MASTER_LOG_FILE и до самого актуального.

```console
    cat /binlog/mysql-bin.index # список всех бинарных логов

    mysqlbinlog \
     --read-from-remote-server \
     --host=localhost \
     --raw --result-file=/backup/ \
     mysql-bin.000002 \
     mysql-bin.000003 \
     mysql-bin.000004 \
     mysql-bin.000005
```

#### Процедура восстановления на момент времени

Важно: Вся необходимая информация для восстановления из текущей рез. копии находится в /backup/current/backup.log

#### Предварительно удалите восстанавливаемую БД

```console
    DROP DATABASE testdb;
```

#### Создайте пустую БД и выполните в нее восстановление из Full бэкапа

Важно: Поскльку дамп включает бэкап нескольких БД, то восстановление выполнить обязательно с аргументом one-database, в кот. указать восстанавливаемую БД! Директива one-database будет применять sql команды только где указанная БД определена операторм use базой данных по умолчанию.

       Ошибка восстановления с включенныи GTID - https://www.percona.com/blog/2013/02/08/how-to-createrestore-a-slave-using-gtid-replication-in-mysql-5-6/
        ERROR 1840 (HY000) at line 33: @@GLOBAL.GTID_PURGED can only be set when @@GLOBAL.GTID_EXECUTED is empty.
        Решение, перед восстановлением (только на сервере где восстанавливаете, или мастер или славе) сбросьте пар-ы reset master;

```console
    CREATE DATABASE testdb;
    mysql --one-database testdb < ~/db.sql или pv ~/db.sql | mysql --one-database testdb
```

В случае, если sql с применением gzip

```console
    CREATE DATABASE testdb;
    gunzip < db.sql.gz | mysql --one-database testdb или pv db.sql.gz | gunzip | mysql --one-database testdb
```

#### Определите point-in-time для восстановления из бинарного лога

Важно: Стартовая позиция и первый бинарный файл должны соот-ь MASTER_LOG_FILE и MASTER_LOG_POS, что определены при фул бэкапе.
       Поскольку используется ROW формат бинарного лога, то чтобы определить точку восстановления, его надо декодировать.
       Из полученного SQL файла восстанавливать не рекомендуется, так как его формат изменен. Используйте этот файл только для анализа.
       Пар-р database заставит проиграть бинарные логи только для определенной в аргументе БД, а не для всех БД.

```console
    mysqlbinlog \
     --base64-output=DECODE-ROWS -vv \
     --skip-gtids \
     --start-position=194 \
     --database=testdb \
     mysql-bin.000002 \
     mysql-bin.000003 \
     mysql-bin.000004 \
     mysql-bin.000005 \
     | gzip -9 > db.binlog.decode.$(date +"%Y%m%d%H%M").sql.gz

    gunzip < db.binlog.decode.201808251509.sql.gz | less
```

Например, нужно выполнить восстановление до выполнения INSERT INTO testdb.example VALUES (5, '5'); те не включать.
Согласно анализу данная транзакция была выполнена в 21:52:17

#### Point-in-time восстановление

Важно: При восстановление уберите пар-р декодирования base64-output и укажите PIT stop-datetime.

```console
    mysqlbinlog \
     --skip-gtids \
     --start-position=194 \
     --stop-datetime="2018-07-02 21:52:16" \
     --database=testdb \
     mysql-bin.000002 \
     mysql-bin.000003 \
     mysql-bin.000004 \
     mysql-bin.000005 \
     | mysql
```

Или можно выполнить восстановление с прогрессбаром

```console
    mysqlbinlog \
     --skip-gtids \
     --start-position=194 \
     --stop-datetime="2018-07-02 21:52:16" \
     --database=testdb \
     mysql-bin.000002 \
     mysql-bin.000003 \
     mysql-bin.000004 \
     mysql-bin.000005 \
     | mysql
```

Или можно сформировать sql файл и применить его отдельно с прогрессбаром

```console
    pv | mysqlbinlog \
     --skip-gtids \
     --start-position=194 \
     --stop-datetime="2018-07-02 21:52:16" \
     --database=testdb \
     mysql-bin.000002 \
     mysql-bin.000003 \
     mysql-bin.000004 \
     mysql-bin.000005 \
     | gzip -9 > db.binlog.$(date +"%Y%m%d%H%M").sql.gz
     
     pv db.binlog.201808251510.sql.gz | gunzip | mysql testdb
```

---

![alt text](https://github.com/rlagutinhub/mysql.logical.backup.with.pit.restore/blob/master/screen1.png)
![alt text](https://github.com/rlagutinhub/mysql.logical.backup.with.pit.restore/blob/master/screen2.png)
