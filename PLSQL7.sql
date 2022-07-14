--1
 CREATE [OR REPLACE] TRIGGER nume_trigger
{BEFORE | AFTER } eveniment [OF coloana_tabel] ON nume_tabel
[FOR EACH ROW]
[FOLLOWS | PRECEDES alt_trigger]
[ENABLE / DISABLE ]
[DECLARE
    declaration statements]
BEGIN
    executable statements
[EXCEPTION
    exception_handling statements]
END;

--LOGGING
drop table logs;
create table logs (
    id number,
    table_name varchar2(256),
    transaction_name varchar2(16),
    user_name varchar2(256),
    transaction_date date,
    message varchar2(256)
    );
    
set serveroutput on;
create or replace trigger studenti_log
before insert on studenti
for each row
declare
    v_id logs.id%type;
begin
    --extragem id ul maxim din logs
    select max(id) into v_id from logs;
    if v_id is null then 
        v_id := 0;
    end if; 
    
    insert into logs values (v_id + 1, 
                            'STUDENTI',
                            'INSERT',
                            USER,
                            SYSDATE,
                            'Inserted student with id '|| :new.id 
                            || ' named '|| :new.nume 
                            || ' ' || :new.prenume);
end studenti_log;

insert into studenti(id, nr_matricol, nume, prenume) values(6001,'123bd','Kinder','Bueno');
insert into studenti(id, nr_matricol, nume, prenume) values(6002,'123ef','Andrzej','Sapkowski');
insert into studenti(id, nr_matricol, nume, prenume) values(6003,'123gh','Susan','Cain');

--delete from studenti where id in (6001, 6002, 6003);
--delete from logs where id in (1,2,3);
select * from logs;

--////////////////////////////////////////////////
--Asigurarea integritatii dintre tabelele hoodies si watches
drop table watches;
create table watches (
    id number,
    watch_name varchar2(256),
    hoodie_id number
    );

insert into watches values(1, 'rolex', 3);
insert into watches values(1, 'rolex', 6);
insert into watches values(2, 'patek', 1);
insert into watches values(3, 'omega', 4);
insert into watches values(4, 'cartier', 11);
insert into watches values(6, 'Tiffany', 9);
insert into watches values(6, 'Tiffany', 10);
insert into watches values(6, 'Tiffany', 11);
insert into watches values(8, 'seiko', 7);
insert into watches values(9, 'casio', 7);
insert into watches values(11, 'hamilton', 8);
insert into watches values(11, 'hamilton', 11);
select * from watches;

drop table hoodies;
create table hoodies (
    id number,
    hoodie_name varchar2(256),
    watch_id number
    );

insert into hoodies values(1, 'nike', 2);
insert into hoodies values(3, 'zara', 1);
insert into hoodies values(4, 'hnm', 3);
insert into hoodies values(6, 'hermes', 1);
insert into hoodies values(7, 'prada', 8);
insert into hoodies values(7, 'prada', 9);
insert into hoodies values(8, 'levis', 11);
insert into hoodies values(9, 'tommy', 6);
insert into hoodies values(10, 'abibas', 6);
insert into hoodies values(11, 'mike', 4);
insert into hoodies values(11, 'mike', 6);
insert into hoodies values(11, 'mike', 11);
select * from hoodies;

--trigger pentru insert
create or replace trigger watches_insert
before insert on watches
for each row
declare
    v_hoodies number;
    v_hoodie_name hoodies.hoodie_name%type;
    v_new_hoodie_id hoodies.id%type;
    
    hoodie_inexistent EXCEPTION;
    PRAGMA EXCEPTION_INIT(hoodie_inexistent, -20001);
begin
    --verificam daca hoodie_id exista in
    --tabela de hoodies
    select count(*) into v_hoodies 
        from hoodies where id = :new.hoodie_id;
        
    --daca v_hoodies e 0 inseamna ca 
    --nu exista hoodie-ul cu id-ul respectiv si aruncam o exceptie
    if (v_hoodies = 0) then
        raise hoodie_inexistent;
    end if;
    
    --exista hoodie-ul, deci inseram in hoodies
    select hoodie_name into v_hoodie_name
        from hoodies where id = :new.hoodie_id and rownum = 1;
        
    insert into hoodies values(:new.hoodie_id,
                                v_hoodie_name,
                                :new.id);
exception
    when hoodie_inexistent then
        raise_application_error (-20001,'Hoodie-ul cu ID-ul ' || :new.hoodie_id || ' nu exista in baza de date.');
end;

select * from hoodies;
--delete from hoodies where id = 11 and watch_id = 12;
insert into watches values(12, 'ragnar', 11); --ok
insert into watches values(12, 'ragnar', 99); --whoops

--trigger pentru delete
create or replace trigger watches_delete
before delete on watches
for each row
declare
    v_hoodies number;
begin
    --verificam daca hoodie_id exista in
    --tabela de hoodies
    select count(*) into v_hoodies 
        from hoodies where watch_id = :old.id;
        
    --daca v_hoodies e 0, nu facem nimic deoarece
    --nu avem ce hoodie sa stergem
    --dar daca este pozitiv, atunci stergem hoodie-urile
    --ce au watch_id = :old.hoodie_id;
    if (v_hoodies > 0) then
        delete from hoodies where watch_id = :old.id;
    end if;
end;

delete from watches where id = 1;
select * from hoodies;

--////////////////////////////////////////////////
--Erori Mutating Table
set serveroutput on;
create or replace trigger node_delete_bad
after delete on note
for each row
disable --!!!!!!!!!!!!!!
declare
    v_numar_note_de_10 number;
begin
    dbms_output.put_line('Incercam sa stergem nota id='|| :old.id
                        || ' si valoare= ' || :old.valoare);
    
    --vrem sa vedem cate note de 10 au mai ramas
    select count(*) into v_numar_note_de_10
        from note where valoare = 10;
        
    dbms_output.put_line('Numarul de note de 10 de la momentul
                            stergerii este ' || v_numar_note_de_10);
end node_delete_bad;

delete from note where id in (500,501);
select * from note where id = 500;

--cream un tabel unde ne salvam notele sterse
drop table note_save;
create table note_save (
    id number,
    id_student number,
    valoare number
    );

create or replace trigger note_delete_good
for delete on note
disable --!!!!!!
compound trigger
  --zona variabile
  v_numar_note number;
  
  before statement is
  begin
    dbms_output.put_line('Stergere start');
  end before statement;
  
  before each row is
  begin
    dbms_output.put_line('Stergem nota cu ID: '|| :old.id || ' si valoarea: ' || :old.valoare);
  end before each row;
  
  after each row is
  begin
     insert into note_save values(:old.id, :old.id_student, :old.valoare);
     dbms_output.put_line('Am inserat nota' || :old.id || ' in note_save');
     
     --ne da mutating table!
--     select count(*) into v_numar_note from note;
--     dbms_output.put_line('END: Mai sunt '|| v_numar_note || ' note.');
  end after each row;
  
  after statement is
  begin
     select count(*) into v_numar_note from note;
     dbms_output.put_line('END: Mai sunt '|| v_numar_note || ' note.'); 
     dbms_output.put_line('Stergere end');
  end after statement;
  
end note_delete_good;

delete from note where id in (500,501,502);
select * from note_save;
rollback;
select * from note where id = 500;


--////////////////////////////////////
--TRIGGERE INSTEAD OF

--crearea unui view
create view view_student as select * from studenti;

create or replace trigger delete_student
  instead of delete on view_student
begin
  dbms_output.put_line('Stergem pe:' || :old.nume);
  delete from note where id_student=:old.id;
  delete from prieteni where id_student1=:old.id;
  delete from prieteni where id_student2=:old.id;
  delete from studenti where id=:old.id;
end;
delete from view_student where id = 5;
select * from studenti where id = 5;
select * from note where id_student = 5;
rollback;