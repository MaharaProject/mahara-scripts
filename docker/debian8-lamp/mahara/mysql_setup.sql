create database `mahara-db` character set UTF8;
create user `maharauser`@localhost IDENTIFIED BY 'mahara';
grant all on `mahara-db`.* to `maharauser`@localhost IDENTIFIED BY 'mahara'
