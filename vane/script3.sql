--procedimiento

create or replace procedure my_proc(prompt varchar2) is

	aux number; -- declaración de variables

begin
	select count('x') into aux from routes;
	dbms_output.put_line(prompt || aux);

exception
	when no_data_found then dbms_output.put_line('No hay datos');
	when too_many_rows then dbms_output.put_line('demasiadas filas');
	when others then dbms_output.put_line('ERROR');
end;
/

begin my_proc('EL NÚMERO DE RUTAS ES: '); end;
/

-- El comando anterior tiene un alias que es:

exec my_proc('NÚMERO DE RUTAS: ');
